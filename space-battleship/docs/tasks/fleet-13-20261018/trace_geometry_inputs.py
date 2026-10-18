"""Run the saved laser native-input probe on prepared isolated projects.

Usage: python trace_geometry_inputs.py MAIN51_GAME CANDIDATE_GAME OUTPUT_DIR
Both projects need imported assets, the existing DLL/GDExtension, probe.gd,
counter_probe.gd and combat_stress_fixture.gd. Never builds native code.
"""
from pathlib import Path
import gzip
import hashlib
import os
import subprocess
import sys

task = Path(__file__).resolve().parent
output = Path(sys.argv[3]).resolve()
output.mkdir(parents=True, exist_ok=True)
engine = "D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
for project, label in ((Path(sys.argv[1]).resolve(), "main51"), (Path(sys.argv[2]).resolve(), "candidate-fixed")):
    assert hashlib.sha256((project / "bin/space_native.dll").read_bytes()).hexdigest() == "b89310037fb78690470ffe8d47e37c264b15ff9b1828ba345a6f323d159068da"
    temporary = project / "fleet_geometry_input_probe.gd"
    assert not temporary.exists()
    temporary.write_bytes((task / "geometry_input_probe.gd").read_bytes())
    runtime = project / ".runtime"
    runtime.mkdir(exist_ok=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        folder = runtime / "geometry-probe-user" / key
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="absent", WEAPON_CASE="laser", MISSILE_CONTROL="legend",
               SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
    try:
        command = [engine, "--headless", "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--max-fps", "0", "--disable-vsync", "--script", "res://" + temporary.name]
        with (output / (label + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        log_text = (output / (label + ".log")).read_text(encoding="utf-8")
        assert result.returncode == 0 and "GEOMETRY_PROBE_DONE 721" in log_text and "SCRIPT ERROR" not in log_text
        for source, suffix in (("geometry-probe.json", ""), ("geometry-events.json", "-events")):
            with gzip.open(output / (label + suffix + ".json.gz"), "wb") as stream:
                stream.write((runtime / source).read_bytes())
        print(label, "GEOMETRY_PROBE_DONE", flush=True)
    finally:
        temporary.unlink(missing_ok=True)
