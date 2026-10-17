"""One focused paid-research sample using the accepted full-scene driver."""
from pathlib import Path
import json
import os
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
out = root / "test/evidence/ai-tech-tree-20261017"
project = root / "test/work/test_ai_tech_tree-d1p4hun_/space-battleship"
source = (out / "performance-final-art/perf_driver.gd").read_text(encoding="utf-8")
source = source.replace('assert(g.call("select_tech","singularity"),"research active before sampling")', 'assert(g.call("select_tech","weapon_accuracy"),"research active before sampling")\n  g.profile.resources["1"]=1000000.0\n  assert(g.call("set_tech_input","1",1000),"paid research input")')
source = source.replace(' assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal main batch scheduler enabled")\n', '')
source = source.replace(' var state_before=state_digest(g)', ' var state_before=state_digest(g)\n var research_before=float(g.profile.aiTechProgress.get("weapon_accuracy",0.0))\n var resource_before=float(g.profile.resources["1"])')
source = source.replace(' row.state_after=state_digest(g)', ' row.state_after=state_digest(g)\n row.research_before=research_before\n row.research_after=float(g.profile.aiTechProgress.get("weapon_accuracy",0.0))\n row.resource_before=resource_before\n row.resource_after=float(g.profile.resources["1"])\n row.research_input=int(g.profile.aiTechInput["1"])')
assert "row.research_input=int" in source
(project / "scripts/ai_tech_tree.gd").write_bytes((root / "space-battleship/scripts/ai_tech_tree.gd").read_bytes())
(project / "paid_port_perf.gd").write_text(source, encoding="utf-8")
shutil.copy2(out / "performance-final-art/mixed_fixture.gd", project / "combat_stress_fixture.gd")
user = root / "test/work/paid-performance-user"
env = os.environ.copy()
for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
    path = user / folder
    path.mkdir(parents=True, exist_ok=True)
    env[key] = str(path)
env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="open", WEAPON_CASE="mixed", MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
engine = "D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
with (out / "paid-performance-probe.log").open("w", encoding="utf-8") as log:
    result = subprocess.run([engine, "--path", str(project), "--rendering-method", "gl_compatibility", "--max-fps", "0", "--disable-vsync", "--script", "res://paid_port_perf.gd"], cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
assert result.returncode == 0
log = (out / "paid-performance-probe.log").read_text(encoding="utf-8", errors="replace")
assert "PORT_PERF_DONE" in log and "SCRIPT ERROR" not in log
data = json.loads((project / ".runtime/uncapped-port.json").read_text(encoding="utf-8"))
assert data["native_admitted"] and data["performance_sample_valid"] and data["actual_1x_pass"]
assert data["research_after"] > data["research_before"] and data["resource_after"] < data["resource_before"]
assert data["research_input"] == 1000 and data["sample_steps"] == 480
(out / "paid-performance-probe.json").write_text(json.dumps({key: data[key] for key in ("native_admitted", "performance_sample_valid", "actual_1x_pass", "warm_steps", "sample_steps", "research_before", "research_after", "resource_before", "resource_after", "research_input", "handoffs", "game_seconds", "frames_us_raw")}, indent=2), encoding="utf-8")
shutil.copy2(project / ".runtime/uncapped-port.png", out / "paid-performance-probe.png")
print("PAID_PERF_PASS", data["research_before"], data["research_after"], data["resource_before"], data["resource_after"], "native", data["native_admitted"])
