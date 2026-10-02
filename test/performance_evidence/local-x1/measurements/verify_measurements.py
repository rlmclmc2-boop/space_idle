"""Check archived X1 sample sources and recalculate frame statistics."""

import hashlib
import gzip
import json
import subprocess
from collections import Counter
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
REPO = EVIDENCE.parents[3]
BASE = "e16abb40f12ca25a547d381b4ac643b979124cb0"
ORIGINAL = "5b7542db115783c51dbd7ce89587f53e28f97a71"
FINAL = "cfc9ef9402d49f4c9832bf1c878790d4b442b990"
MAIN = "space-battleship/scripts/main.gd"
TAB = "space-battleship/scripts/equipment_tab.gd"
GAME = "space-battleship/scripts/game.gd"
FILES = {
    "before": ("before-original-main.gd", BASE),
    "after": ("after-original-main.gd", ORIGINAL),
    "after2": ("after-original-main.gd", ORIGINAL),
    "control": ("after-original-main.gd", ORIGINAL),
    "final": ("final-main.gd", FINAL),
    "final2": ("final-main.gd", FINAL),
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def normalized(data):
    return data.replace(b"\r\n", b"\n")


def git_file(commit, path):
    return subprocess.check_output(["git", "show", f"{commit}:{path}"], cwd=REPO)


def archived(name):
    return gzip.decompress((EVIDENCE / (name + ".gz")).read_bytes())


def percentile(values, percentage):
    return values[int((len(values) - 1) * percentage)]


for name, commit, path in [
    ("before-original-main.gd", BASE, MAIN),
    ("after-original-main.gd", ORIGINAL, MAIN),
    ("final-main.gd", FINAL, MAIN),
    ("original-equipment-tab.gd", ORIGINAL, TAB),
    ("final-equipment-tab.gd", FINAL, TAB),
]:
    source = archived(name)
    assert normalized(source) == normalized(git_file(commit, path)), name
    print(name, sha256(source), "content matches", commit[:7])

game_sha = sha256(git_file(FINAL, GAME).replace(b"\n", b"\r\n"))
assert game_sha == "96e971eb0918301d746a8aebdbceac5bba16bd05c1f16536976d44672307d236"
for label, (source, _commit) in FILES.items():
    sample = json.loads(archived(f"{label}-frames.json").decode("utf-8"))
    rows = sample["rows"]
    meta = sample["metadata"]
    assert meta["label"] == label and meta["sample_frames"] == len(rows) == 3600
    assert meta["main_sha256"] == sha256(archived(source)), label
    assert meta["game_sha256"] == game_sha, label
    assert set(sample) == {"metadata", "rows"}
    assert set(rows[0]) == {
        "elapsed_us", "enemies", "events", "frame_us", "main_us",
        "projectiles", "stage", "state", "upgrade_level",
    }
    frame = sorted(row["frame_us"] / 1000 for row in rows)
    main = sorted(row["main_us"] / 1000 for row in rows)
    events = Counter()
    for row in rows:
        events.update(row["events"])
    print(
        label,
        "seconds", round(rows[-1]["elapsed_us"] / 1_000_000, 3),
        "frame P95/P99/max", *(round(value, 3) for value in
            [percentile(frame, .95), percentile(frame, .99), frame[-1]]),
        "over16.7", sum(value > 16.7 for value in frame),
        "main P99", round(percentile(main, .99), 3),
        "encounters/deaths/enhancements/planet/upgrade/save",
        *(events[key] for key in [
            "encounter", "explode", "enhancement_changed", "planet_changed",
            "upgrade", "save_success",
        ]),
    )
