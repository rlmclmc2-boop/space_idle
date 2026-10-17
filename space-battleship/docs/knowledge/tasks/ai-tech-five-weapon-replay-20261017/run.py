"""Run one existing high-load fixture in an isolated project and user directory."""
from pathlib import Path
import ctypes
from ctypes import wintypes
import json
import os
import shutil
import subprocess
import sys
import threading
import time

class SystemLoad:
    def __init__(self):
        self.rows = []
        self.done = threading.Event()
        self.thread = threading.Thread(target=self.collect, daemon=True)

    def collect(self):
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.GetSystemTimes.argtypes = [ctypes.POINTER(wintypes.FILETIME)] * 3
        previous = None
        while not self.done.is_set():
            stamps = [wintypes.FILETIME() for _ in range(3)]
            if api.GetSystemTimes(*[ctypes.byref(x) for x in stamps]):
                values = [(x.dwHighDateTime << 32) | x.dwLowDateTime for x in stamps]
                row = {"unix": time.time(), "idle_100ns": values[0], "kernel_100ns": values[1], "user_100ns": values[2]}
                if previous:
                    idle = values[0] - previous[0]
                    total = values[1] + values[2] - previous[1] - previous[2]
                    row["system_cpu_busy_percent"] = 100 * (1 - idle / total) if total else None
                self.rows.append(row)
                previous = values
            self.done.wait(0.5)

    def start(self):
        self.thread.start()

    def stop(self):
        self.done.set()
        self.thread.join()

base = Path(__file__).resolve().parent
root = base.parents[2]
state, case, run = sys.argv[1:4]
assert state in ("absent", "closed", "open")
assert case in ("mixed", "laser", "cannon", "missile", "longLaser")
project = root / "work/ai-tech-perf-20261017/absent/space-battleship" if state == "absent" else base.parent / "space-battleship"
results = base / "results"
results.mkdir(exist_ok=True)
shutil.copy2(base / ("mixed_fixture.gd" if case == "mixed" else "combat_stress_fixture.gd"), project / "combat_stress_fixture.gd")
user = base / "users" / state / case / run
env = os.environ.copy()
for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
    env[key] = str(user / folder)
    Path(env[key]).mkdir(parents=True, exist_ok=True)
env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE=state, WEAPON_CASE=case, MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
engine = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility", "--max-fps", "0", "--disable-vsync", "--script", "res://port_perf.gd"]
name = f"{case}-{state}-{run}"
for ext in ("json", "png"):
    (project / ".runtime" / ("uncapped-port." + ext)).unlink(missing_ok=True)
load = SystemLoad()
load.start()
try:
    with (results / (name + ".log")).open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=project, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240)
finally:
    load.stop()
(results / (name + "-system-load.json")).write_text(json.dumps(load.rows), encoding="utf-8")
for ext in ("json", "png"):
    source = project / ".runtime" / ("uncapped-port." + ext)
    if source.exists():
        shutil.copy2(source, results / (name + "." + ext))
log = (results / (name + ".log")).read_text(encoding="utf-8", errors="replace")
print(name, "exit", result.returncode, "script_errors", log.count("SCRIPT ERROR"), "done", "PORT_PERF_DONE" in log, flush=True)
path = results / (name + ".json")
if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))
    print("summary", {"valid": data.get("performance_sample_valid"), "actual_1x": data.get("actual_1x_pass"), "native": data.get("native_admitted"), "warm_steps": data.get("warm_steps"), "steps": data.get("sample_steps"), "frames": len(data.get("frames_us_raw", [])), "events": data.get("events"), "mean_us": round(sum(data["frames_us_raw"]) / len(data["frames_us_raw"]))}, flush=True)
if result.returncode or "SCRIPT ERROR" in log or "PORT_PERF_DONE" not in log or not path.exists():
    raise SystemExit(1)
