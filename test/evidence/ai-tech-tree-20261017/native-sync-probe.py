"""Build a focused real-DLL probe from the accepted five-case scene fixture."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
fixture = root / "test/evidence/ai-tech-tree-20261017/performance-final-art/perf_driver.gd"
project = root / "test/work/test_ai_tech_tree-d1p4hun_/space-battleship"
source = fixture.read_text(encoding="utf-8")
source = source.split(" scene.retained_contacts_enabled=true", 1)[0]
source = source.replace(' assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal main batch scheduler enabled")\n', "")
source += '''
 assert(admitted and g.native_execution!=null,"real native residency")
 var baseline=float(g.equipment_stat("laser",140))
 var before_handoffs=g.native_handoff_count
 g.profile.aiTechProgress.weapon_accuracy=59.99
 assert(g.select_tech("weapon_accuracy"),"select attack research")
 g.advance_hightech(0.02)
 assert(g.native_execution==null and g.native_handoff_count==before_handoffs+1,"research completion hands off before stat mutation")
 assert(g.hightech_level("weapon_accuracy")==1 and float(g.equipment_stat("laser",140))>baseline,"attack technology takes effect immediately")
 print("NATIVE_TECH_UPGRADE_PASS level=",g.hightech_level("weapon_accuracy")," handoffs=",g.native_handoff_count)
 g.profile.aiTechLevels.unification=1
 g.invalidate_stat_cache()
 assert(g.admit_native_compiled_execution("native_rich15_layer2"),"re-admit real kernel for income peak")
 var before_peak=float(g.equipment_stat("laser",140))
 before_handoffs=g.native_handoff_count
 g.resource_samples.append({"time":g.economy_time(),"production_time":g.production_time(),"id":"1","amount":6000.0,"origin":"drop"})
 AITech.record_income(g,"1")
 assert(g.native_execution==null and g.native_handoff_count==before_handoffs+1,"income peak hands off before factor mutation")
 assert(g.profile.aiIncomePeak["1"]>=100.0 and float(g.equipment_stat("laser",140))>before_peak,"peak factor takes effect immediately")
 print("NATIVE_TECH_PEAK_PASS peak=",g.profile.aiIncomePeak["1"]," handoffs=",g.native_handoff_count)
 quit(0)
'''
# The accepted fixture defines UI above run; add the technology helper there.
source = source.replace("extends SceneTree\n", 'extends SceneTree\nconst AITech=preload("res://scripts/ai_tech_tree.gd")\n', 1)
(project / "scripts/ai_tech_tree.gd").write_bytes((root / "space-battleship/scripts/ai_tech_tree.gd").read_bytes())
(project / "native_ai_tech_probe.gd").write_text(source, encoding="utf-8")
shutil.copy2(root / "test/evidence/ai-tech-tree-20261017/performance-final-art/mixed_fixture.gd", project / "combat_stress_fixture.gd")
user = root / "test/work/native-probe-user"
env = os.environ.copy()
for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
    path = user / folder
    path.mkdir(parents=True, exist_ok=True)
    env[key] = str(path)
env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="open", WEAPON_CASE="mixed", MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
engine = "D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
log_path = root / "test/evidence/ai-tech-tree-20261017/native-sync-probe.log"
with log_path.open("w", encoding="utf-8") as log:
    result = subprocess.run([engine, "--path", str(project), "--rendering-method", "gl_compatibility", "--max-fps", "0", "--disable-vsync", "--script", "res://native_ai_tech_probe.gd"], cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
text = log_path.read_text(encoding="utf-8", errors="replace")
assert result.returncode == 0 and "SCRIPT ERROR" not in text
assert "NATIVE_TECH_UPGRADE_PASS" in text and "NATIVE_TECH_PEAK_PASS" in text
print("NATIVE_SYNC_PASS real DLL, upgrade and income-peak handoffs")
