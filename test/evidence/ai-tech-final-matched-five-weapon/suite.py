"""Five existing high-load cases, bracketed absent/closed/open/closed/absent."""
from pathlib import Path
import json
import subprocess
import sys

base = Path(__file__).resolve().parent
results = base / "results"
cases = ["mixed", "laser", "cannon", "missile", "longLaser"]
sequence = [("absent", "A"), ("closed", "B"), ("open", "C"), ("closed", "D"), ("absent", "E")]

def read(case, state, part):
    name = f"{case}-{state}-{part}"
    path = results / (name + ".json")
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    log = (results / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    assert "PORT_PERF_DONE" in log and "SCRIPT ERROR" not in log, name
    assert data["warm_steps"] == 240 and data["sample_steps"] == 480, name
    assert data["performance_sample_valid"] and data["actual_1x_pass"] and data["native_admitted"], name
    assert data["sampling_config"]["stat_cache_enabled"] and not data["sampling_config"]["save_enabled"], name
    assert data["sampling_config"]["engine_max_fps"] == 0 and data["sampling_config"]["vsync"] == 0, name
    assert len(data["frames_us_raw"]) == len(data["phases"]) == len(data["frame_trace"]), name
    assert all(phase["post_draw_us"] - phase["previous_post_us"] == frame for phase, frame in zip(data["phases"], data["frames_us_raw"])), name
    return data

failures = []
for case in cases:
    rows = []
    for state, part in sequence:
        data = read(case, state, part)
        if data is None:
            command = [sys.executable, str(base / "run.py"), state, case, part]
            result = subprocess.run(command, capture_output=True, text=True, timeout=300)
            print(result.stdout, flush=True)
            if result.returncode:
                print(result.stderr, flush=True)
                raise RuntimeError(f"{case}-{state}-{part} failed")
            data = read(case, state, part)
        rows.append(data)
    if not all(row["events"] == rows[0]["events"] for row in rows):
        failures.append(f"{case}: event counts changed")
        print("EVENT_MISMATCH", case, [row["events"] for row in rows], flush=True)
    if not all(row["stress"]["counts"] == rows[0]["stress"]["counts"] for row in rows):
        failures.append(f"{case}: stress counts changed")
        print("STRESS_MISMATCH", case, [row["stress"]["counts"] for row in rows], flush=True)
    print("SUITE_CASE_OK", case, "frames", [len(row["frames_us_raw"]) for row in rows], flush=True)
if failures:
    raise RuntimeError("; ".join(failures))
print("SUITE_OK five cases", flush=True)
