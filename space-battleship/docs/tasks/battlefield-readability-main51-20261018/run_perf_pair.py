"""Replay the repository's five-case GUI fixture on main51 and this candidate.

Usage: python run_perf_pair.py BASE_PROJECT CANDIDATE_PROJECT
Projects must have matching native DLLs installed and Godot imports ready.
Only the existing perf driver/fixtures and probes are copied; game script
instrumentation is restored byte-for-byte after the replay.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys

here = Path(__file__).resolve().parent
candidate_repo = here.parents[3]
source = candidate_repo / "space-battleship/docs/knowledge/tasks/ai-tech-five-weapon-replay-20261017"
probes = candidate_repo / "test/evidence/stage4-7-main-comparison-20261017"
projects = {"before": Path(sys.argv[1]).resolve(), "after": Path(sys.argv[2]).resolve()}
output = here / "evidence/performance-main51"
output.mkdir(parents=True, exist_ok=True)
engine = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
cases = ["mixed", "laser", "cannon", "missile", "longLaser"]


def percentile(values, share):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * share))]


def prepared(project):
    backups = {}
    for name in ("game.gd", "presented_battle_game.gd"):
        path = project / "scripts" / name
        backups[path] = path.read_bytes()
        functions = ["jewel_attack", "hit_enemy"] if name == "game.gd" else ["tick_projectiles"]
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        result = []
        for line in lines:
            result.append(line)
            for func in functions:
                if line.startswith(f"func {func}("):
                    result.append(f'\tpreload("res://counter_probe.gd").legacy_call("{func}")\n')
        path.write_text("".join(result), encoding="utf-8")
    driver = (source / "perf_driver.gd").read_text(encoding="utf-8")
    driver = driver.replace('res://space_native.gdextension', 'res://addons/native_battle/space_native.gdextension')
    (project / "port_perf.gd").write_text(driver, encoding="utf-8")
    for name in ("probe.gd", "counter_probe.gd"):
        shutil.copy2(probes / name, project / name)
    (project / ".runtime").mkdir(exist_ok=True)
    return backups


def execute(label, case, project):
    fixture = "mixed_fixture.gd" if case == "mixed" else "combat_stress_fixture.gd"
    shutil.copy2(source / fixture, project / "combat_stress_fixture.gd")
    user = output / "users" / label / case
    env = os.environ.copy()
    for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
        env[key] = str(user / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="closed", WEAPON_CASE=case,
               MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
    for ext in ("json", "png"):
        (project / ".runtime" / f"uncapped-port.{ext}").unlink(missing_ok=True)
    log = output / f"{case}-{label}.log"
    command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--max-fps", "0", "--disable-vsync", "--script", "res://port_perf.gd"]
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=240)
    for ext in ("json", "png"):
        shutil.copy2(project / ".runtime" / f"uncapped-port.{ext}", output / f"{case}-{label}.{ext}")
    data = json.loads((output / f"{case}-{label}.json").read_text(encoding="utf-8"))
    output_text = log.read_text(encoding="utf-8")
    assert result.returncode == 0 and "PORT_PERF_DONE" in output_text and "SCRIPT ERROR" not in output_text
    assert data["warm_steps"] == 240 and data["sample_steps"] == 480
    assert data["actual_1x_pass"] and data["performance_sample_valid"] and data["native_admitted"]
    assert len(data["frames_us_raw"]) == len(data["phases"]) == len(data["frame_trace"])
    frames = data["frames_us_raw"]
    busy = [frame for frame, phase in zip(frames, data["phases"]) if phase["logic_steps"] > 0]
    row = {"case": case, "revision": label, "frames": len(frames), "mean_us": round(sum(frames) / len(frames), 1),
           "p95_us": percentile(frames, .95), "p99_us": percentile(frames, .99),
           "busy_p95_us": percentile(busy, .95), "busy_frames": len(busy),
           "drawcalls_p95": percentile(data["drawcalls_raw"], .95),
           "primitives_p95": percentile(data["primitives_raw"], .95),
           "events": data["events"], "stress_counts": data["stress"]["counts"]}
    print("PERF_RUN", json.dumps(row, ensure_ascii=False), flush=True)
    return row


backups = {}
try:
    for label, project in projects.items():
        backups.update(prepared(project))
    rows = []
    for case in cases:
        pair = [execute(label, case, project) for label, project in projects.items()]
        assert pair[0]["events"] == pair[1]["events"], f"{case}: event mismatch"
        assert pair[0]["stress_counts"] == pair[1]["stress_counts"], f"{case}: stress mismatch"
        rows.extend(pair)
        print("PERF_CASE_MATCH", case, flush=True)
    (output / "summary.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PERF_PAIR_DONE", flush=True)
finally:
    for path, contents in backups.items():
        path.write_bytes(contents)
