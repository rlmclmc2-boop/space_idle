"""Real process death and fresh Godot startup, using a caller-owned isolated copy."""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--project", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--godot", default="godot")
parser.add_argument("--case", help="Run one named scenario, e.g. legacy-staged")
args = parser.parse_args()
project = Path(args.project).resolve()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
assert "/test/work/" in str(project), "Use an isolated test/work project"
old = json.dumps({"version": 4, "highestLevel": 1, "resources": {"1": 111, "2": 222}}).encode()
new = json.dumps({"version": 4, "highestLevel": 1, "resources": {"1": 333, "2": 444}}).encode()
failures = 0
scenarios = [("legacy", "staged"), ("interrupt", "first-save"), *(('interrupt', p) for p in ["staged", "moved", "installed"]), *(('active', p) for p in ["staged", "moved", "installed"])]
if args.case:
    scenarios = [(mode, phase) for mode, phase in scenarios if f"{mode}-{phase}" == args.case]
    assert scenarios, "Unknown scenario"
for mode, phase in scenarios:
    case = project.parent / "userdata" / "import-recovery" / f"{mode}-{phase}"
    env = {**os.environ, "XDG_DATA_HOME": str(case / "data"), "XDG_CONFIG_HOME": str(case / "config"), "XDG_CACHE_HOME": str(case / "cache")}
    user = case / "data/godot/app_userdata/太空战舰 · 深空远征"
    user.mkdir(parents=True, exist_ok=True)
    primary = user / "progress.json"
    for suffix in ["", ".bak", ".import-prev", ".import-new", ".import-active", ".import-active.tmp", ".import-active.bak"]:
        (user / ("progress.json" + suffix)).unlink(missing_ok=True)
    primary.write_bytes(old)
    (user / "progress.json.bak").write_bytes(old + b"\n")
    if phase == "first-save":
        primary.unlink()
        (user / "progress.json.bak").unlink()
    cmd = [args.godot, "--headless", "--path", str(project), "--script", "../test/test_save_import_recovery.gd", "--"]
    if mode == "interrupt":
        stopped = subprocess.run(cmd + [mode, phase], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        (output / f"{mode}-{phase}-interrupted.log").write_bytes(stopped.stdout)
        (output / f"{mode}-{phase}-interrupted.exit").write_text(str(stopped.returncode) + "\n")
        if os.name == "posix":
            assert stopped.returncode == -9, "Expected actual SIGKILL process death"
        assert stopped.returncode != 0 and f"INTERRUPTION: {phase}".encode() in stopped.stdout, stopped.stdout.decode()
        assert (user / "progress.json.import-active").exists(), "The killed process leaves ownership"
    else:
        (user / "progress.json.import-new").write_bytes(new)
        if phase in ["moved", "installed"]:
            primary.rename(user / "progress.json.import-prev")
        if phase == "installed":
            primary.write_bytes(new)
        if mode == "active":
            (user / "progress.json.import-active").write_text(json.dumps({"pid": os.getpid()}))
    startup = subprocess.run(cmd + [("active" if mode == "active" else "recover"), phase], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    (output / f"{mode}-{phase}-startup.log").write_bytes(startup.stdout)
    (output / f"{mode}-{phase}.exit").write_text(str(startup.returncode) + "\n")
    print(startup.stdout.decode(), end="")
    if startup.returncode != 0:
        failures += 1
    if phase == "first-save":
        assert not primary.exists(), "No original disk save must remain absent after rollback"
    elif mode != "active":
        assert json.loads(primary.read_bytes())["resources"]["1"] == (333 if phase == "installed" else 111)
        if phase != "installed":
            assert primary.read_bytes() == old, "Abandoned incoming never replaces committed original"
    else:
        assert (user / "progress.json.import-active").exists()
        assert (user / "progress.json.import-new").read_bytes() == new
print(f"FRESH PROCESS IMPORT RECOVERY: {len(scenarios)} scenarios, {failures} failures")
raise SystemExit(bool(failures))
