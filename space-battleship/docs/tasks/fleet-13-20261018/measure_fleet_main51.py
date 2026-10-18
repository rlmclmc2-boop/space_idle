"""Replay the existing five full-picture high-load fixtures on two checkouts.

Usage: python measure_fleet.py BASELINE_GAME_DIR CANDIDATE_GAME_DIR
The native DLL and copied perf_driver.gd/probe.gd/counter_probe.gd must already
be present in both game directories. This runner never builds the DLL.
"""
from pathlib import Path
import gzip
import hashlib
import json
import os
import shutil
import statistics
import subprocess
import sys

before = Path(sys.argv[1]).resolve()
after = Path(sys.argv[2]).resolve()
here = Path(__file__).resolve().parent
fixture_dir = here.parents[1] / "knowledge/tasks/ai-tech-five-weapon-replay-20261017"
output = here / "evidence/main51-performance"
output.mkdir(parents=True, exist_ok=True)
engine = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
python = "D:/CodexTools/venv/godot-native/Scripts/python.exe"
cases = ("mixed", "laser", "cannon", "missile", "longLaser")
summary = {"baseline": "51a7e1b9bc5784927e7d5b232a112194d990a41c", "cases": {}}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(project: Path, case: str, label: str) -> dict:
    assert digest(project / "bin/space_native.dll") == "b89310037fb78690470ffe8d47e37c264b15ff9b1828ba345a6f323d159068da"
    fixture = "mixed_fixture.gd" if case == "mixed" else "combat_stress_fixture.gd"
    shutil.copy2(fixture_dir / fixture, project / "combat_stress_fixture.gd")
    runtime = project / ".runtime"
    runtime.mkdir(exist_ok=True)
    for name in ("uncapped-port.json", "uncapped-port.png"):
        (runtime / name).unlink(missing_ok=True)
    env = os.environ.copy()
    user = runtime / "fleet-perf-user"
    for key, suffix in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
        folder = user / suffix
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="absent", WEAPON_CASE=case,
               MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON=python)
    command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--max-fps", "0", "--disable-vsync", "--script", "res://port_perf.gd"]
    target = output / f"{case}-{label}"
    with target.with_suffix(".log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    log_text = target.with_suffix(".log").read_text(encoding="utf-8", errors="replace")
    print(f"{case}-{label}: exit={result.returncode} done={'PORT_PERF_DONE' in log_text} errors={log_text.count('SCRIPT ERROR')}", flush=True)
    if result.returncode or "PORT_PERF_DONE" not in log_text or "SCRIPT ERROR" in log_text:
        raise RuntimeError(f"{case}-{label} failed; see {target.with_suffix('.log')}")
    source_json = runtime / "uncapped-port.json"
    source_png = runtime / "uncapped-port.png"
    assert source_json.exists() and source_png.exists()
    row = json.loads(source_json.read_text(encoding="utf-8"))
    assert row["native_admitted"] and row["actual_1x_pass"] and row["performance_sample_valid"]
    assert row["warm_steps"] == 240 and row["sample_steps"] == 480
    assert row["sampling_config"]["stat_cache_enabled"] and not row["sampling_config"]["save_enabled"]
    assert row["sampling_config"]["engine_max_fps"] == 0 and row["sampling_config"]["vsync"] == 0
    assert len(row["frames_us_raw"]) == len(row["phases"]) == len(row["frame_trace"])
    with gzip.open(str(target) + ".json.gz", "wt", encoding="utf-8") as packed:
        json.dump(row, packed, ensure_ascii=False, separators=(",", ":"))
    shutil.copy2(source_png, str(target) + ".png")
    return row


for case in cases:
    a = run(before, case, "before")
    b = run(after, case, "after")
    gameplay_before = {key: value for key, value in a["events"].items() if key != "equipment_stats"}
    gameplay_after = {key: value for key, value in b["events"].items() if key != "equipment_stats"}
    assert gameplay_before == gameplay_after, f"{case}: gameplay event mismatch"
    assert a["stress"]["counts"] == b["stress"]["counts"], f"{case}: stress mismatch"
    entry = {}
    for label, row in (("before", a), ("after", b)):
        values = sorted(row["frames_us_raw"])
        entry[label] = {"frames": len(values), "mean_ms": statistics.mean(values) / 1000,
                        "p95_ms": values[int((len(values) - 1) * .95)] / 1000,
                        "main_mean_ms": statistics.mean(p["main_end_us"]-p["main_begin_us"] for p in row["phases"]) / 1000,
                        "draw_mean": statistics.mean(row["drawcalls_raw"]),
                        "events": row["events"], "stress_counts": row["stress"]["counts"]}
    entry["delta_mean_ms"] = entry["after"]["mean_ms"] - entry["before"]["mean_ms"]
    entry["all_events_equal"] = a["events"] == b["events"]
    entry["gameplay_events_equal"] = gameplay_before == gameplay_after
    entry["equipment_stats_delta"] = b["events"].get("equipment_stats", 0) - a["events"].get("equipment_stats", 0)
    summary["cases"][case] = entry
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"CASE_OK {case} mean_ms {entry['before']['mean_ms']:.3f} -> {entry['after']['mean_ms']:.3f} gameplay_events_equal=true all_events_equal={entry['all_events_equal']} equipment_stats_delta={entry['equipment_stats_delta']}", flush=True)
print("FLEET_PERF_DONE five cases", flush=True)
