"""Trace only the existing laser high-load fixture on main51 and the candidate.

The injected GDScript lives temporarily at the project root and is deleted after
each run. Production scripts and the native DLL are never modified.
"""
from pathlib import Path
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys

before = Path(sys.argv[1]).resolve()
after = Path(sys.argv[2]).resolve()
task = Path(__file__).resolve().parent
fixture = task.parents[1] / "knowledge/tasks/ai-tech-five-weapon-replay-20261017/combat_stress_fixture.gd"
out = task / "evidence/equipment-stats-trace"
out.mkdir(parents=True, exist_ok=True)
engine = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
python = "D:/CodexTools/venv/godot-native/Scripts/python.exe"
source = (before / "port_perf.gd").read_text(encoding="utf-8")
source = source.replace(
    "var sample_events:Dictionary={}",
    "var sample_events:Dictionary={}\nvar equipment_stats_trace:Array=[]",
    1,
)
source = source.replace(
    "func count_event(kind:String,info:Dictionary)->void:\n",
    "func count_event(kind:String,info:Dictionary)->void:\n"
    " if kind==\"equipment_stats\":\n"
    "  var g=current_scene.game\n"
    "  equipment_stats_trace.append({\"step\":current_scene.logical_step_count(true),\"clock\":g.production_time(),\"payload\":info.duplicate(true),\"attack_counter\":g.profile.enhancementAttacks,\"incoming_counter\":g.profile.enhancementHits})\n",
    1,
)
source = source.replace(" sample_events.clear()", " sample_events.clear();equipment_stats_trace.clear()", 1)
source = source.replace(" row.events=sample_events", " row.events=sample_events\n row.equipment_stats_trace=equipment_stats_trace", 1)
assert "row.equipment_stats_trace=equipment_stats_trace" in source


def run(project: Path, label: str) -> dict:
    dll = project / "bin/space_native.dll"
    assert hashlib.sha256(dll.read_bytes()).hexdigest() == "b89310037fb78690470ffe8d47e37c264b15ff9b1828ba345a6f323d159068da"
    temporary = project / "fleet_equipment_trace.gd"
    assert not temporary.exists(), f"refusing to overwrite {temporary}"
    shutil.copy2(fixture, project / "combat_stress_fixture.gd")
    runtime = project / ".runtime"
    runtime.mkdir(exist_ok=True)
    for name in ("uncapped-port.json", "uncapped-port.png"):
        (runtime / name).unlink(missing_ok=True)
    env = os.environ.copy()
    user = runtime / "fleet-equipment-trace-user"
    for key, suffix in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
        folder = user / suffix
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="absent", WEAPON_CASE="laser",
               MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON=python)
    temporary.write_text(source, encoding="utf-8")
    try:
        command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--max-fps", "0", "--disable-vsync", "--script", "res://fleet_equipment_trace.gd"]
        with (out / f"laser-{label}.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        log_text = (out / f"laser-{label}.log").read_text(encoding="utf-8", errors="replace")
        assert result.returncode == 0 and "PORT_PERF_DONE" in log_text and "SCRIPT ERROR" not in log_text, label
        row = json.loads((runtime / "uncapped-port.json").read_text(encoding="utf-8"))
        assert row["sample_steps"] == 480 and row["native_admitted"] and row["actual_1x_pass"]
        with gzip.open(out / f"laser-{label}.json.gz", "wt", encoding="utf-8") as packed:
            json.dump(row, packed, separators=(",", ":"))
        print(label, "equipment_stats", len(row["equipment_stats_trace"]), flush=True)
        return row
    finally:
        temporary.unlink(missing_ok=True)


a = run(before, "before")
b = run(after, "after")


def digest(row: dict) -> dict:
    groups = {}
    for event in row["equipment_stats_trace"]:
        payload = event["payload"]
        key = (payload.get("category", ""), bool(payload.get("counter_only", False)))
        groups[str(key)] = groups.get(str(key), 0) + 1
    return groups


summary = {
    "fixture": "laser",
    "main51": digest(a),
    "candidate": digest(b),
    "event_delta": len(b["equipment_stats_trace"]) - len(a["equipment_stats_trace"]),
    "all_other_events_equal": {k: v for k, v in a["events"].items() if k != "equipment_stats"} == {k: v for k, v in b["events"].items() if k != "equipment_stats"},
    "final_player_equal": a["state_after"]["player"] == b["state_after"]["player"],
    "final_loadout_equal": a["state_after"]["loadout"] == b["state_after"]["loadout"],
    "final_attack_counter": [a["kernel_metrics"]["attack_counter"], b["kernel_metrics"]["attack_counter"]],
    "final_incoming_counter": [a["kernel_metrics"]["incoming_counter"], b["kernel_metrics"]["incoming_counter"]],
}
(out / "audit.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, ensure_ascii=False), flush=True)
