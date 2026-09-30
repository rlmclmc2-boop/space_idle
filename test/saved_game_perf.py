"""Profile a snapshot of the current save without writing to the player's project or save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "space-battleship"
MODULES = {
    "main": ["advance_game_time", "advance_turrets", "refresh_visible_cards", "refresh_navigation", "refresh_draw_layers", "on_event", "draw_battle", "draw_stars", "draw_vertical_battle_hud", "refresh_system_nav", "queue_damage_number", "flush_damage_numbers", "damage_text_position", "advance_projectile_visuals", "sync_beam_visuals"],
    "game": ["tick", "advance_planets", "advance_auto_gen", "advance_hightech", "advance_furnace", "tick_projectiles", "save_progress", "active_research", "stat", "jewel_equipment_stat", "invalidate_stat_cache"],
    "crew_system": ["advance", "get_modifier", "system_effect", "system_level", "tab_badge"],
    "planet_buffs": ["totals"],
    "planet_buildings": ["multiplier", "preview"],
    "galaxy_system": ["advance"],
    "equipment_tab": ["refresh", "refresh_stats", "refresh_detail", "refresh_live"],
    "planet_panel": ["_process", "refresh"],
    "reactor_panel": ["_process", "refresh"],
    "crew_panel": ["refresh"],
    "hightech_construction": ["_process", "_draw"],
}
MODULES["game"] += ["advance_jewel_repair", "sync_jewel_defence_damage", "jewel_hit_player", "jewel_attack", "jewel_fire", "hit_enemy", "hit_player", "tick_long_laser", "spawn_group", "advance_jewel_repeats", "capture_refit_health", "apply_refit_health", "add_crew_exp", "collect"]
MODULES["crew_system"] += ["gain_exp"]

def instrument(source, module):
    for name in MODULES[module]:
        pattern = rf"^func {name}\((.*)\)(.*):$"
        match = re.search(pattern, source, re.M)
        if not match:
            continue
        args = [p.strip().split(":")[0].split("=")[0].strip() for p in match[1].split(",") if p.strip()]
        call = f'_perf_original_{name}({", ".join(args)})'
        void = "-> void" in match[2]
        wrapper = match[0] + "\n\tvar _started := Time.get_ticks_usec()\n"
        wrapper += "\t" + (call if void else "var _value = " + call) + "\n"
        wrapper += f'\tEngine.get_meta("saved_perf").record("{module}.{name}",Time.get_ticks_usec()-_started)\n'
        if not void: wrapper += "\treturn _value\n"
        wrapper += "\n" + match[0].replace("func " + name + "(", "func _perf_original_" + name + "(")
        source = source[:match.start()] + wrapper + source[match.end():]
    return source

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--instrument", action="store_true")
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--reuse", type=Path, help="Reuse this probe's isolated imports; never the source project")
    parser.add_argument("--fps", type=int, default=0)
    parser.add_argument("--speed", type=float, default=0)
    args = parser.parse_args()
    area = args.reuse.resolve() if args.reuse else Path(tempfile.mkdtemp(prefix="saved-perf-" + args.label + "-", dir=ROOT / "test/work"))
    assert area.parent == (ROOT / "test/work").resolve() and area.name.startswith("saved-perf-")
    subprocess.run(["icacls", str(area), "/inheritance:e"], check=True, stdout=subprocess.DEVNULL)
    game = area / "space-battleship"
    for name in ("scripts", "data", "assets"):
        if name != "assets" or not args.reuse:
            shutil.copytree(SOURCE / name, game / name, dirs_exist_ok=True)
    for name in ("project.godot", "main.tscn"):
        shutil.copy2(SOURCE / name, game / name)
    (game / ".runtime").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "test/saved_game_perf.gd", game / "saved_game_perf.gd")
    save = args.snapshot or next((SOURCE / ".userdata").rglob("progress.json"))
    snapshot = save.read_bytes()
    (area / "input-save.json").write_bytes(snapshot)
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    target = Path(env["APPDATA"]) / "Godot/app_userdata/太空战舰 · 深空远征/progress.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(snapshot)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True, exist_ok=True)
    if args.instrument:
        for module in MODULES:
            path = game / "scripts" / (module + ".gd")
            path.write_text(instrument(path.read_text(encoding="utf-8"), module), encoding="utf-8")
    engine = SOURCE / "engine/Godot_v4.7.2-stable_win64.exe"
    print("Evidence:", area, flush=True)
    for label, flags in [("import", ["--headless", "--editor", "--import", "--quit"]), ("probe", ["--resolution", "1373x883", "--script", "res://saved_game_perf.gd", "--", f"--perf-fps={args.fps}", f"--perf-speed={args.speed}"])]:
        with (area / (label + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run([str(engine), "--path", str(game), *flags], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        output = (area / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:
            raise RuntimeError(f"{label} exit={result.returncode}\n" + output[-6000:])
    report = json.loads((game / ".runtime/saved-perf.json").read_text(encoding="utf-8"))
    report["save_sha256"] = hashlib.sha256(snapshot).hexdigest()
    report["label"] = args.label
    report["fps_cap"] = args.fps
    report["instrumented"] = args.instrument
    (area / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (area / (args.label + ".json")).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    for row in report["pages"]:
        print(row["page"], row["frame"], "CPU", row["main"], flush=True)
    assert save.read_bytes() == snapshot, "Input save changed during probe"

if __name__ == "__main__":
    main()
