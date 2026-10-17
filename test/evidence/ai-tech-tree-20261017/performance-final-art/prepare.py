"""Adapt the existing five-case high-load driver in isolated projects only."""
from pathlib import Path
import importlib.util

base = Path(__file__).resolve().parent
repo = base.parents[2]
source = repo / "test/evidence/stage4-7-main-comparison-20261017"
projects = {
    "absent": base / "absent/space-battleship",
    "integrated": repo / "test/work/test_ai_tech_tree-d1p4hun_/space-battleship",
}
old = "scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)"
new = """scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1 if OS.get_environment("AI_TECH_PERF_STATE")=="open" else 0)
 if OS.get_environment("AI_TECH_PERF_STATE")!="absent":
  assert(g.call("select_tech","singularity"),"research active before sampling")
  assert(scene.hightech_page.art_enabled,"final static art enabled")
  assert(scene.hightech_page.is_visible_in_tree()==(OS.get_environment("AI_TECH_PERF_STATE")=="open"),"technology page visibility")"""
for side, project in projects.items():
    driver = (source / "perf_driver.gd").read_text(encoding="utf-8")
    driver = driver.removesuffix("\\n")  # Retained evidence has literal trailing escape.
    assert driver.count(old) == 1
    driver = driver.replace(old, new)
    target = project / "port_perf.gd"
    target.write_text(driver, encoding="utf-8")
    spec = importlib.util.spec_from_file_location("counters", source / "instrument_counters.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.instrument_counters(project)
    print(side, target)
for name in ("mixed_fixture.gd", "combat_stress_fixture.gd"):
    (base / name).write_bytes((source / name).read_bytes())
