"""Archive the original 25 replay samples, including any failed identity gates."""
from pathlib import Path
import gzip
import hashlib
import json
import math
import shutil
import statistics

base = Path(__file__).resolve().parent
root = base.parents[2]
results = base / "suite/results"
out = root / "space-battleship/docs/knowledge/tasks/ai-tech-five-weapon-replay-20261017"
out.mkdir(parents=True, exist_ok=True)
cases = ("mixed", "laser", "cannon", "missile", "longLaser")
sequence = (("absent", "A"), ("closed", "B"), ("open", "C"), ("closed", "D"), ("absent", "E"))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def p95(values):
    return sorted(values)[math.ceil(len(values) * 0.95) - 1] / 1000

report = {"cases": {}, "all_valid": True, "all_events_equal": True, "all_stress_equal": True}
for case in cases:
    rows = []
    for state, part in sequence:
        name = f"{case}-{state}-{part}"
        data = json.loads((results / f"{name}.json").read_text(encoding="utf-8"))
        frames = data["frames_us_raw"]
        phases = data["phases"]
        log = (results / f"{name}.log").read_text(encoding="utf-8", errors="replace")
        valid = (data["performance_sample_valid"] and data["actual_1x_pass"]
                 and data["native_admitted"] and data["warm_steps"] == 240
                 and data["sample_steps"] == 480 and data["enemies_alive"] == 15
                 and len(frames) == len(phases) == len(data["frame_trace"])
                 and all(p["post_draw_us"] - p["previous_post_us"] == f
                         for p, f in zip(phases, frames))
                 and "PORT_PERF_DONE" in log and "SCRIPT ERROR" not in log)
        report["all_valid"] &= bool(valid)
        rows.append({"name": name, "valid": bool(valid), "frames": len(frames),
                     "frame_mean_ms": statistics.mean(frames) / 1000,
                     "frame_p95_ms": p95(frames), "events": data["events"],
                     "stress_counts": data["stress"]["counts"]})
        for suffix in (".json", "-system-load.json"):
            source = results / f"{name}{suffix}"
            with source.open("rb") as src, gzip.open(out / f"{name}{suffix}.gz", "wb", compresslevel=9) as dst:
                shutil.copyfileobj(src, dst)
        shutil.copy2(results / f"{name}.log", out / f"{name}.log")
        if state == "open" or case == "mixed" and part in ("A", "B"):
            shutil.copy2(results / f"{name}.png", out / f"{name}.png")
    events_equal = all(r["events"] == rows[0]["events"] for r in rows)
    stress_equal = all(r["stress_counts"] == rows[0]["stress_counts"] for r in rows)
    report["all_events_equal"] &= events_equal
    report["all_stress_equal"] &= stress_equal
    report["cases"][case] = {"runs": rows, "events_equal": events_equal,
                             "stress_equal": stress_equal}

report["native_sha256"] = sha(base / "space-battleship/bin/space_native.dll")
report["fixture_sha256"] = {name: sha(base / f"suite/{name}_fixture.gd")
                             for name in ("mixed", "combat_stress")}
report["engine_sha256"] = sha(Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"))
(out / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
shutil.copy2(base / "suite/suite-final.log", out / "suite-final.log")
for name in ("run.py", "suite.py", "mixed_fixture.gd", "combat_stress_fixture.gd"):
    shutil.copy2(base / "suite" / name, out / name)
for name in ("instrument.py", "package_replay.py"):
    shutil.copy2(base / name, out / name)
shutil.copy2(base / "space-battleship/port_perf.gd", out / "perf_driver.gd")
print("REPLAY_PACKAGE", json.dumps({k: report[k] for k in ("all_valid", "all_events_equal", "all_stress_equal")}))
