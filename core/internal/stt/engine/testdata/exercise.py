"""Exercise the real Python protocol using fake recognizer/audio dependencies."""
import io
import json
import os
import runpy
import subprocess
import sys
import threading
import time
import types

mode = sys.argv[1]
events, options, providers = [], [], []
streams, recorders = [], []
resident = mode.startswith("resident-")
read_fd, write_fd = os.pipe()
sys.stdin = os.fdopen(read_fd)


class Samples:
    def astype(self, _):
        return self

    def __truediv__(self, _):
        return self


class Stream:
    def set_option(self, key, value):
        options.append((key, value))

    def accept_waveform(self, rate, samples):
        recognizer.frames += 1
        if mode == "decode-error" and recognizer.frames == 2:
            raise RuntimeError("fallo de decodificación")
        recognizer.current = ["", "hola", "mundo", "mundo final"][min(recognizer.frames, 3)]

    def input_finished(self):
        pass


class Recognizer:
    frames, current = 0, ""

    @staticmethod
    def from_transducer(**kwargs):
        providers.append(kwargs["provider"])
        assert kwargs["encoder"] == "/model/custom.onnx", kwargs
        if kwargs["provider"] == "cuda":
            raise RuntimeError("CUDA no disponible")
        return recognizer

    def create_stream(self):
        self.frames, self.current = 0, ""
        stream = Stream()
        streams.append(stream)
        return stream

    def is_ready(self, stream):
        return False

    def get_result(self, stream):
        return self.current

    def is_endpoint(self, stream):
        return self.frames == 1

    def reset(self, stream):
        self.current = ""


class Recorder:
    def __init__(self, args, **kwargs):
        assert args == ["pw-record", "--rate", "16000", "--channels", "1",
                        "--format", "s16", "--raw", "-"], args
        recorders.append(self)
        reader, self.writer = os.pipe()
        self.stdout = os.fdopen(reader, "rb")
        self.stderr = io.BytesIO(b"dispositivo ausente")
        self.stopped = threading.Event()
        self.worker = threading.Thread(target=self.produce)
        self.worker.start()

    def produce(self):
        try:
            if mode != "microphone-error":
                for _ in range(2):
                    if self.stopped.wait(0.06):
                        break
                    os.write(self.writer, bytes(3200))
                self.stopped.wait(1)
        finally:
            os.close(self.writer)

    def terminate(self):
        self.stopped.set()

    def wait(self, timeout=None):
        self.worker.join(timeout)
        assert not self.worker.is_alive(), "recorder not reaped"


class Output(io.StringIO):
    def write(self, value):
        if value.strip():
            event = json.loads(value)
            events.append(event)
            if resident and event["event"] == "loaded":
                assert all(r.stopped.is_set() and not r.worker.is_alive() for r in recorders)
                os.write(write_fd, b"start\n" if len(streams) <= 2 else b"cancel\n")
            if mode == "resident-cancel" and event["event"] == "ready" and len(streams) == 1:
                os.write(write_fd, b"cancel\n")
            if mode == "cancel" and event["event"] == "ready":
                os.write(write_fd, b"cancel\n")
            if (mode == "normal" or resident) and event.get("text") == "hola mundo":
                os.write(write_fd, b"stop\n")
        return len(value)


recognizer = Recognizer()
sys.modules["numpy"] = types.SimpleNamespace(
    frombuffer=lambda *a, **kw: Samples(), zeros=lambda *a, **kw: Samples(), float32=float)
sys.modules["sherpa_onnx"] = types.SimpleNamespace(OnlineRecognizer=Recognizer)
subprocess.Popen = Recorder
manifest = dict(Encoder="custom.onnx", Decoder="decoder", Joiner="joiner", Tokens="tokens",
                languageOption=True)
sys.argv = ["stt_engine.py", "--model-dir", "/model", "--manifest", json.dumps(manifest),
            "--provider", "cuda", "--language", "auto"]
if resident:
    sys.argv.append("--standby")
output = sys.stdout
sys.stdout = Output()
try:
    runpy.run_path(os.path.join(os.path.dirname(__file__), "../stt_engine.py"), run_name="__main__")
except SystemExit as error:
    assert mode in ("microphone-error", "decode-error") and error.code == 1, error
finally:
    sys.stdout = output
    os.close(write_fd)

assert events[0]["event"] == ("loaded" if resident else "ready"), events
assert providers == ["cuda", "cpu"], providers
assert options and all(option == ("language", "") for option in options), options
if resident:
    assert len(streams) == 3 and len({id(s) for s in streams}) == 3, streams
    assert len(recorders) == 2 and all(r.stopped.is_set() for r in recorders)
    expected = (["loaded", "ready", "partial", "partial", "final"] * 2 + ["loaded"]
                if mode == "resident-stop" else
                ["loaded", "ready", "loaded", "ready", "partial", "partial", "final", "loaded"])
    assert [e["event"] for e in events] == expected, events
    assert all(e["text"] == "hola mundo final" for e in events if e["event"] == "final"), events
elif mode == "normal":
    assert [e.get("text") for e in events[1:]] == ["hola", "hola mundo", "hola mundo final"], events
    assert events[-1]["event"] == "final", events
elif mode == "cancel":
    assert not any(e["event"] == "final" for e in events), events
else:
    expected = "micrófono" if mode == "microphone-error" else "decodificación"
    assert events[-1]["event"] == "error" and expected in events[-1]["message"], events
print("PASS", mode, json.dumps(events, ensure_ascii=False))
