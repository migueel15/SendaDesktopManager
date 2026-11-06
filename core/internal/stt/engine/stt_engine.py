"""Private JSON-lines recognizer process; stdout contains protocol events only."""
import argparse
from collections import deque
import json
import os
import queue
import selectors
import signal
import subprocess
import sys
import threading
import time
import wave

np = None  # numpy, imported in main so the protocol test can replace it
_emit_lock = threading.Lock()

RATE = 16000
FRAME = 320  # 20 ms
FRAME_S = 0.02
# Offline models (Parakeet) stream by re-transcribing, after Phonon's stream_asr.py. Parakeet int8
# decodes about 26x real time on CPU, so a round's window stays under BEFORE_S + SOFT_MAX_S + its
# lag (about a second of work) and the stop only re-transcribes the last seconds.
BEFORE_S = 8.0  # left context of a round after a commit
SOFT_MAX_S = 16.0  # a round with more pending audio commits it, except the last SOFT_OVERLAP_S
SOFT_OVERLAP_S = 2.0
RELEASE_BEFORE_S = 6.0  # left context of the window transcribed at stop
RELEASE_OVERLAP_S = 2.0  # last seconds of a round the stop may still revise
ROUND_GAP_S = 0.4
QUIET_REUSE_S = 0.1  # stop reuses the last round when only silence followed it
FREEZE_AFTER_S = 5.0  # the dock freezes a word this old even if two rounds never agreed on it


def emit(event, **fields):
    with _emit_lock:
        print(json.dumps(dict(event=event, **fields), ensure_ascii=False), flush=True)


def frames_of(seconds):
    return round(seconds / FRAME_S)


def words_of(result, offset):
    """[(word, absolute start s)] from an offline result; a token opening with a space starts a word."""
    out = []
    for token, start in zip(result.tokens, result.timestamps):
        if not out or token.startswith(" "):
            out.append([token, start + offset])
        else:
            out[-1][0] += token
    return [(w.strip(), s) for w, s in out if w.strip()]


def span(words, start_f, end_f):
    a, b = start_f * FRAME_S, end_f * FRAME_S
    return [(w, t) for w, t in words if a <= t < b]


def text_of(words):
    return " ".join(w for w, _ in words)


def after(words, edge):
    """The words after the one starting at `edge`: a later round's timestamps for the same word
    may move a frame or two, so the closest word within 0.25 s stands for it."""
    if edge is None:
        return words
    near = min(range(len(words)), key=lambda i: abs(words[i][1] - edge), default=None)
    if near is not None and abs(words[near][1] - edge) <= 0.25:
        return words[near + 1:]
    return [w for w in words if w[1] > edge]


class Levels:
    """Frame levels and a causal energy VAD: speech is above max(noise floor + 12 dB, -55 dBFS),
    with the floor at the 10th percentile of the last 30 s and three frames of hangover."""

    def __init__(self):
        self.db, self.mask, self.heard = [], [], False
        self.buf = np.zeros(0, dtype=np.float32)
        self.floor, self.hang = None, 0

    def feed(self, samples):
        self.buf = np.concatenate([self.buf, samples])
        n = len(self.buf) // FRAME
        if not n:
            return
        x = self.buf[:n * FRAME].reshape(n, FRAME).astype(np.float64)
        self.buf = self.buf[n * FRAME:]
        for v in 20 * np.log10(np.sqrt((x * x).mean(axis=1) + 1e-12) + 1e-9):
            i = len(self.db)
            self.db.append(float(v))
            if self.floor is None or i % 10 == 0:
                self.floor = float(np.percentile(self.db[-1500:], 10))
            if v > max(self.floor + 12, -55):
                self.hang, speech = 3, True
            elif self.hang:
                self.hang, speech = self.hang - 1, True
            else:
                speech = False
            self.mask.append(speech)
            self.heard = self.heard or speech

    def speech(self, start, end):
        return any(self.mask[start:end])


class Rolling:
    """Live text from an offline recognizer. Each round transcribes the pending audio with left
    context; past SOFT_MAX_S of pending audio a round commits its words. The stop keeps the last
    round's words up to RELEASE_OVERLAP_S before its end and transcribes only what follows.

    Rounds re-decode the pending audio, so a word can change from one round to the next (a comma,
    its case). The dock shows as stable only words two rounds in a row agree on, and keeps them
    unchanged until the end of the dictation, or freezes a word after FREEZE_AFTER_S anyway; the
    final text still comes from the best decode."""

    def __init__(self, transcribe):
        self.transcribe = transcribe  # (samples, offset s) -> [(word, absolute start s)]
        self.audio = np.zeros(RATE * 30, dtype=np.float32)
        self.n = 0
        self.levels = Levels()
        self.pieces = []  # committed word lists, contiguous from the start
        self.pend = 0  # frame where the committed audio ends
        self.last = None  # (pend, end frame, words, committed pieces) of the last round
        self.next_at = 0.0
        self.frozen = []  # words shown as stable; they never change during the dictation
        self.candidates = []  # the previous round's stable words after the frozen ones

    def feed(self, samples):
        need = self.n + len(samples)
        if need > len(self.audio):
            grown = np.zeros(max(need, 2 * len(self.audio)), dtype=np.float32)
            grown[:self.n] = self.audio[:self.n]
            self.audio = grown
        self.audio[self.n:need] = samples
        self.n = need
        self.levels.feed(samples)

    def frames(self):
        return (self.n + FRAME - 1) // FRAME

    def committed(self, k=None):
        return [w for piece in self.pieces[:k] for w in piece]

    def words(self, start, end):
        x = self.audio[start * FRAME:min(end * FRAME, self.n)]
        return self.transcribe(x, start * FRAME_S) if len(x) >= RATE // 10 else []

    def quiet(self):
        """Only silence since just before the last round's end, by the VAD and by level."""
        if self.last is None:
            return False
        db = self.levels.db
        f = max(0, self.last[1] - frames_of(QUIET_REUSE_S))
        if f >= len(db) or self.levels.speech(f, len(db)):
            return False
        lv = 10 ** (np.asarray(db, dtype=np.float64) / 20)
        lo, hi = np.percentile(lv, 5), np.percentile(lv, 95)
        return bool(lv[f:].max() < lo + 0.1 * (hi - lo))

    def round(self, now):
        """A round when one is due: (text to show, its frozen prefix), else None."""
        have, pend = self.frames(), self.pend
        if now < self.next_at or have - pend < 25 or not self.levels.heard or self.quiet():
            return None
        k = len(self.pieces)
        words = self.words(max(0, pend - frames_of(BEFORE_S)), have)
        self.last = (pend, have, words, k)
        current = self.committed(k) + span(words, pend, have)
        stable = self.committed(k) + span(words, pend, have - frames_of(RELEASE_OVERLAP_S))
        cut = have - frames_of(SOFT_OVERLAP_S)
        if have - pend > frames_of(SOFT_MAX_S):
            self.pieces.append(span(words, pend, cut))
            self.pend = cut
        self.next_at = time.monotonic() + ROUND_GAP_S
        return self.show(current, stable, have * FRAME_S)

    def show(self, current, stable, now_s):
        edge = self.frozen[-1][1] if self.frozen else None
        tail = after(stable, edge)
        n = 0
        while n < len(tail) and n < len(self.candidates) and tail[n][0] == self.candidates[n][0]:
            n += 1
        while n < len(tail) and tail[n][1] < now_s - FREEZE_AFTER_S:
            n += 1  # a word rounds keep disagreeing on must not hold back the rest
        self.frozen += tail[:n]
        self.candidates = tail[n:]
        edge = self.frozen[-1][1] if self.frozen else None
        return text_of(self.frozen + after(current, edge)), text_of(self.frozen)

    def finish(self):
        end = self.frames()
        if self.last is not None:
            pend, f1, words, k = self.last
            t_cut = f1 - frames_of(RELEASE_OVERLAP_S)
            if t_cut - pend >= 25:
                if self.quiet():
                    return text_of(self.committed(k) + span(words, pend, end))
                rel = self.words(max(0, t_cut - frames_of(RELEASE_BEFORE_S)), end)
                return text_of(self.committed(k) + span(words, pend, t_cut) + span(rel, t_cut, end))
        if end > self.pend:  # no round past the last commit: only the open stretch
            words = self.words(max(0, self.pend - frames_of(RELEASE_BEFORE_S)), end)
            return text_of(self.committed() + span(words, self.pend, end))
        return text_of(self.committed())


def main():
    global np
    p = argparse.ArgumentParser()
    p.add_argument("--model-dir", required=True)
    p.add_argument("--manifest", required=True)
    p.add_argument("--provider", choices=["cpu", "cuda"], required=True)
    p.add_argument("--language", default="auto")
    p.add_argument("--standby", action="store_true")
    p.add_argument("--wav")  # Manual validation uses the same decode/flush path.
    a = p.parse_args()
    import numpy
    import sherpa_onnx
    np = numpy

    m = json.loads(a.manifest)
    files = {key.lower(): os.path.join(a.model_dir, m[key])
             for key in ("Encoder", "Decoder", "Joiner", "Tokens")}
    offline = m.get("kind") == "offline-transducer"
    def recognizer(provider):
        if offline:
            return sherpa_onnx.OfflineRecognizer.from_transducer(
                **files, provider=provider, num_threads=4, model_type="nemo_transducer")
        return sherpa_onnx.OnlineRecognizer.from_transducer(
            **files, provider=provider, num_threads=4, enable_endpoint_detection=True)
    try:
        r = recognizer(a.provider)
    except Exception:
        if a.provider != "cuda":
            raise
        print("No se pudo iniciar CUDA; se reintenta con CPU", file=sys.stderr, flush=True)
        r = recognizer("cpu")
    def transcribe(samples, offset):
        whole = r.create_stream()
        whole.accept_waveform(RATE, samples)
        r.decode_stream(whole)
        return words_of(whole.result, offset)
    commands = queue.Queue()
    def receive():
        for line in sys.stdin:
            commands.put(line.strip())
        commands.put("eof")
    threading.Thread(target=receive, daemon=True).start()
    while True:
        s = None if offline else r.create_stream()
        if s and m.get("languageOption"):
            s.set_option("language", "" if a.language == "auto" else a.language)

        if a.standby:
            emit("loaded")
            command = commands.get()
            if command in ("cancel", "stop", "eof"):
                return
            if command != "start":
                raise RuntimeError("Orden del motor no válida")
        proc, wav, reader = None, None, None
        halt = threading.Event()
        chunks = queue.Queue()  # audio bytes, None at the end of a WAV, or the recorder's error
        diagnostics = deque(maxlen=8)
        segments, previous = [], None
        rolling = Rolling(transcribe) if offline else None
        last_activity = 0.0
        def text():
            return " ".join(segments + [r.get_result(s).strip()]).strip()
        def show(current, stable):
            nonlocal previous
            if current and (current, stable) != previous:
                emit("partial", text=current, stable=stable)
                previous = (current, stable)
        def decode(data):
            nonlocal last_activity
            samples = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768
            now = time.monotonic()
            if now - last_activity >= 0.1:
                emit("activity", active=bool(np.sqrt(np.mean(samples * samples)) >= 0.015))
                last_activity = now
            if offline:
                rolling.feed(samples)
                return
            s.accept_waveform(RATE, samples)
            while r.is_ready(s):
                r.decode_stream(s)
            show(text(), " ".join(segments))
            if r.is_endpoint(s):
                segment = r.get_result(s).strip()
                if segment:
                    segments.append(segment)
                r.reset(s)
                if m.get("languageOption"):
                    s.set_option("language", "" if a.language == "auto" else a.language)
        def read_audio():
            # Reading runs apart from decoding, so a long offline round never stalls the recorder.
            try:
                with selectors.DefaultSelector() as selector:
                    if proc:
                        selector.register(proc.stdout, selectors.EVENT_READ)
                    while not halt.is_set():
                        if wav:
                            data = wav.readframes(1600)
                            if not data:
                                chunks.put(None)
                                return
                            time.sleep(0.1)
                        else:
                            if not selector.select(0.05):
                                continue
                            data = os.read(proc.stdout.fileno(), 3200)
                            if not data:
                                raise RuntimeError("No se pudo abrir el micrófono: pw-record terminó " +
                                                   b"".join(diagnostics).decode(errors="replace").strip())
                        chunks.put(data)
            except Exception as error:
                if not halt.is_set():
                    chunks.put(error)
        try:
            if a.wav:
                wav = wave.open(a.wav, "rb")
                if (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) != (RATE, 1, 2):
                    raise RuntimeError("El WAV debe ser PCM mono de 16 bits a 16000 Hz")
            else:
                try:
                    proc = subprocess.Popen(["pw-record", "--rate", "16000", "--channels", "1",
                                             "--format", "s16", "--raw", "-"], stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE)
                except OSError as error:
                    raise RuntimeError("No se pudo abrir el micrófono: " + str(error)) from error
                def drain():
                    while chunk := proc.stderr.read(1024):
                        diagnostics.append(chunk)
                drainer = threading.Thread(target=drain, daemon=True)
                drainer.start()
            reader = threading.Thread(target=read_audio, daemon=True)
            reader.start()
            emit("ready")
            command, pending = "", b""
            while not command:
                try:
                    command = commands.get_nowait()
                    if command not in ("stop", "cancel", "eof"):
                        raise RuntimeError("Orden del motor no válida")
                    break
                except queue.Empty:
                    pass
                received = []
                try:
                    received.append(chunks.get(timeout=0.05))
                    while True:
                        received.append(chunks.get_nowait())
                except queue.Empty:
                    pass
                for item in received:
                    if item is None:
                        command = "stop"
                        break
                    if isinstance(item, Exception):
                        raise item
                    pending += item
                size = len(pending) // 2 * 2
                if size:
                    decode(pending[:size])
                    pending = pending[size:]
                if rolling and not command:
                    shown = rolling.round(time.monotonic())
                    if shown:
                        show(*shown)
            if command == "stop":
                # Audio already read when the stop arrived still belongs to the dictation.
                while True:
                    try:
                        item = chunks.get_nowait()
                    except queue.Empty:
                        break
                    if isinstance(item, bytes):
                        pending += item
                if len(pending) >= 2:
                    decode(pending[:len(pending) // 2 * 2])
            if command == "stop" and offline:
                emit("final", text=rolling.finish())
            elif command == "stop":
                s.accept_waveform(RATE, np.zeros(32000, dtype=np.float32))
                while r.is_ready(s):
                    r.decode_stream(s)
                s.input_finished()
                while r.is_ready(s):
                    r.decode_stream(s)
                emit("final", text=text())
        finally:
            halt.set()
            if proc:
                proc.terminate()
                try:
                    proc.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
            if reader:
                reader.join(1)
            if wav:
                wav.close()
            if proc:
                drainer.join()
                proc.stdout.close()
                proc.stderr.close()

        if not a.standby or command == "eof":
            return


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        main()
    except Exception as error:
        emit("error", message=str(error))
        sys.exit(1)
