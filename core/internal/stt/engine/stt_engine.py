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


def emit(event, **fields):
    print(json.dumps(dict(event=event, **fields), ensure_ascii=False), flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model-dir", required=True)
    p.add_argument("--manifest", required=True)
    p.add_argument("--provider", choices=["cpu", "cuda"], required=True)
    p.add_argument("--language", default="auto")
    p.add_argument("--standby", action="store_true")
    p.add_argument("--wav")  # Manual validation uses the same decode/flush path.
    a = p.parse_args()
    import numpy as np
    import sherpa_onnx

    m = json.loads(a.manifest)
    files = {key.lower(): os.path.join(a.model_dir, m[key])
             for key in ("Encoder", "Decoder", "Joiner", "Tokens")}
    def recognizer(provider):
        return sherpa_onnx.OnlineRecognizer.from_transducer(
            **files, provider=provider, num_threads=4, enable_endpoint_detection=True)
    try:
        r = recognizer(a.provider)
    except Exception:
        if a.provider != "cuda":
            raise
        print("No se pudo iniciar CUDA; se reintenta con CPU", file=sys.stderr, flush=True)
        r = recognizer("cpu")
    commands = queue.Queue()
    def receive():
        for line in sys.stdin:
            commands.put(line.strip())
        commands.put("eof")
    threading.Thread(target=receive, daemon=True).start()
    while True:
        s = r.create_stream()
        if m.get("languageOption"):
            s.set_option("language", "" if a.language == "auto" else a.language)

        if a.standby:
            emit("loaded")
            command = commands.get()
            if command in ("cancel", "stop", "eof"):
                return
            if command != "start":
                raise RuntimeError("Orden del motor no válida")
        proc, wav = None, None
        diagnostics = deque(maxlen=8)
        segments, previous = [], ""
        last_activity = 0.0
        def text():
            return " ".join(segments + [r.get_result(s).strip()]).strip()
        def decode(data):
            nonlocal previous, last_activity
            samples = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768
            now = time.monotonic()
            if now - last_activity >= 0.1:
                emit("activity", active=bool(np.sqrt(np.mean(samples * samples)) >= 0.015))
                last_activity = now
            s.accept_waveform(16000, samples)
            while r.is_ready(s):
                r.decode_stream(s)
            current = text()
            if current and current != previous:
                emit("partial", text=current)
                previous = current
            if r.is_endpoint(s):
                segment = r.get_result(s).strip()
                if segment:
                    segments.append(segment)
                r.reset(s)
                if m.get("languageOption"):
                    s.set_option("language", "" if a.language == "auto" else a.language)
        try:
            if a.wav:
                wav = wave.open(a.wav, "rb")
                if (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) != (16000, 1, 2):
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
            with selectors.DefaultSelector() as selector:
                if proc:
                    selector.register(proc.stdout, selectors.EVENT_READ)
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
                    if wav:
                        data = wav.readframes(1600)
                        if not data:
                            command = "stop"
                            break
                        time.sleep(0.1)
                    else:
                        if not selector.select(0.05):
                            continue
                        data = os.read(proc.stdout.fileno(), 3200)
                        if not data:
                            raise RuntimeError("No se pudo abrir el micrófono: pw-record terminó " +
                                               b"".join(diagnostics).decode(errors="replace").strip())
                    pending += data
                    size = len(pending) // 2 * 2
                    if size:
                        decode(pending[:size])
                        pending = pending[size:]
                if command == "stop":
                    s.accept_waveform(16000, np.zeros(32000, dtype=np.float32))
                    while r.is_ready(s):
                        r.decode_stream(s)
                    s.input_finished()
                    while r.is_ready(s):
                        r.decode_stream(s)
                    emit("final", text=text())
        finally:
            if wav:
                wav.close()
            if proc:
                proc.terminate()
                try:
                    proc.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
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
