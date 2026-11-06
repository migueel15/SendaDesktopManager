"""Rolling re-transcription with a fake recognizer: one word per noise burst, named by its start."""
import importlib.util
import os
import sys

import numpy as np

spec = importlib.util.spec_from_file_location("engine", os.path.join(os.path.dirname(__file__), "../stt_engine.py"))
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)
engine.np = np
RATE, STEP = engine.RATE, 0.5  # a 0.3 s burst every 0.5 s
windows = []
flicker = False  # like a real decoder, words near the window's end change between rounds


def transcribe(x, offset):
    windows.append(len(x) / RATE)
    loud = np.abs(x) > 0.05
    words, i = [], 0
    while i < len(loud):
        if loud[i]:
            j = i
            while j < len(loud) and loud[j]:
                j += 1
            start = offset + i / RATE
            word = f"w{round(start / STEP)}"
            if flicker and start > offset + len(x) / RATE - 4 and len(windows) % 2:
                word += ","
            words.append((word, start))
            i = j
        i += 1
    return words


def speech(seconds, silence):
    rng = np.random.default_rng(1)
    x = np.zeros(int((seconds + silence) * RATE), dtype=np.float32)
    for k in range(int(seconds / STEP)):
        a = int(k * STEP * RATE)
        x[a:a + int(0.3 * RATE)] = rng.uniform(0.2, 0.4, int(0.3 * RATE)) * rng.choice([-1, 1], int(0.3 * RATE))
    x += rng.normal(0, 0.001, len(x)).astype(np.float32)
    return x, " ".join(f"w{k}" for k in range(int(seconds / STEP)))


def run(seconds, silence, late=0.0):
    windows.clear()
    x, expected = speech(seconds, silence)
    rolling, shown = engine.Rolling(transcribe), []
    for a in range(0, len(x), RATE // 10):
        rolling.feed(x[a:a + RATE // 10])
        # late: the stop arrives that long after the last round, as when it lands mid-round
        out = rolling.round(float("inf")) if a < len(x) - late * RATE else None
        if out:
            shown.append(out)
    rounds = len(windows)
    final = rolling.finish()
    assert shown and all(text.startswith(stable) for text, stable in shown), shown
    # the frozen prefix only grows
    assert all(b[1].startswith(a[1]) for a, b in zip(shown, shown[1:])), shown
    if flicker:
        assert len(shown[-1][1].split()) >= len(expected.split()) - 12, shown[-1]
        return rounds, windows[rounds:]
    assert final == expected, (final, expected)
    assert shown[-1][1] and expected.startswith(shown[-1][1]), shown[-1]
    limit = engine.BEFORE_S + engine.SOFT_MAX_S + 0.2
    assert max(windows) <= limit, (max(windows), limit)
    return rounds, windows[rounds:]


rounds, release = run(45, 0, late=0.4)  # long, ends while speaking: commits, short stop window
# the open stretch after a commit or after the last round's cut, with the stop's left context
limit = engine.RELEASE_BEFORE_S + max(engine.RELEASE_OVERLAP_S, engine.SOFT_OVERLAP_S + 0.5) + 0.4 + 0.2
assert len(release) == 1 and release[0] <= limit, (release, limit)
rounds, release = run(12, 2)  # trailing silence: the stop reuses the last round
assert release == [], release
flicker = True
run(45, 0, late=0.4)
print("PASS rolling")
