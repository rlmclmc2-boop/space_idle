"""Run the fixed saved-game performance probe in a private project and user directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from saved_game_perf import ROOT, SOURCE

SNAPSHOT = ROOT / "test/work/performance-20260930/input-save.json"
FUNCTIONS = {
    "main": {
        "simulation": ["advance_game_time"],
        "animation": ["advance_turrets", "advance_projectile_visuals", "sync_beam_visuals"],
        "ui": ["refresh_visible_cards", "refresh_navigation", "refresh_draw_layers", "refresh_fps_label", "refresh_scientists", "refresh_hightech_card", "refresh_system_nav", "refresh_crew_tab_badge"],
        "layout": ["layout_jewel_workspace", "layout_overlay_controls", "layout_reactor_page", "refresh_structure", "build_ui"],
        "text": ["text_at", "fit_battle_text", "set_ui_value", "ui_state_changed"],
        "render": ["draw_battle", "draw_stars", "draw_vertical_battle_hud", "draw_resources", "draw_overlay", "draw_chrome", "draw_background", "draw_ship", "draw_projectile_fx", "draw_enemy_weapon_components"],
        "effect": ["draw_battle_particles", "weapon_impact", "weapon_flash", "weapon_smoke", "weapon_sparks"],
        "enemy": ["enemy_pose", "enemy_render_position", "enemy_weapon_components"],
        "weapon": ["weapon_key", "weapon_visual_profile", "compose_weapon_components", "player_weapon_components"],
    },
    "game": {
        "battle": ["tick", "spawn_group", "change_state", "leave"],
        "projectile": ["tick_projectiles", "tick_long_laser", "lock_long_laser"],
        "collision": ["hit_enemy", "hit_player", "jewel_hit_player"],
        "weapon": ["fire", "jewel_attack", "jewel_fire", "weapon_cooldown_after_shot"],
        "simulation": ["advance_planets", "advance_auto_gen", "advance_hightech", "advance_furnace", "advance_jewel_repeats", "advance_jewel_repair"],
        "stat": ["stat", "jewel_equipment_stat", "invalidate_stat_cache", "equipment_stat"],
        "data": ["save_progress", "active_research", "collect", "add_crew_exp", "capture_refit_health", "refresh_crew_level_effects"],
    },
    "crew_system": {"simulation": ["advance", "gain_exp", "changed"], "stat": ["get_modifier", "system_effect", "system_level"]},
    "planet_buffs": {"stat": ["totals"]},
    "planet_buildings": {"stat": ["multiplier", "preview"]},
    "galaxy_system": {"simulation": ["advance"]},
    "equipment_tab": {"ui": ["refresh", "refresh_stats", "refresh_detail", "refresh_pending", "refresh_slots", "refresh_affordability"]},
    "crew_panel": {"ui": ["refresh", "refresh_member", "refresh_row", "refresh_selection", "refresh_jobs", "refresh_targets", "refresh_job_availability", "refresh_detail", "refresh_detail_status", "refresh_actions"]},
    "planet_panel": {"ui": ["refresh", "refresh_sample", "refresh_card"]},
    "reactor_panel": {"ui": ["refresh"]},
    "galaxy_panel": {"ui": ["refresh", "refresh_sample", "refresh_detail"]},
    "hightech_construction": {"animation": ["_process", "_draw"]},
    "reactor_visual": {"animation": ["_process", "_draw"]},
    "galaxy_map": {"animation": ["_process"]},
    "ui_text": {"text": ["t", "data_text"]},
}

AB = {
    "battle_logic": {"game": ["tick"]},
    "projectile_logic": {"game": ["tick_projectiles"]},
    "projectile_visual": {"main": ["advance_projectile_visuals", "sync_beam_visuals"]},
    "effects": {"main": ["draw_battle_particles", "weapon_flash", "weapon_smoke", "weapon_sparks"]},
    "ui_update": {"main": ["refresh_visible_cards", "refresh_navigation", "refresh_fps_label"]},
    "animation": {"main": ["advance_turrets"], "reactor_visual": ["_process"], "galaxy_map": ["_process"]},
}

def wrap(source, name, category, module):
    pattern = rf"^func {re.escape(name)}\((.*)\)(.*):$"
    match = re.search(pattern, source, re.M)
    if not match:
        return source, False
    args = [p.strip().split(":")[0].split("=")[0].strip() for p in match[1].split(",") if p.strip()]
    void = "-> void" in match[2]
    call = f'_diag_original_{name}({", ".join(args)})'
    original = match[0].replace("func " + name + "(", "func _diag_original_" + name + "(")
    body = match[0] + "\n"
    body += "\tvar _diag_started := Time.get_ticks_usec()\n"
    body += "\t" + (call if void else "var _diag_result = " + call) + "\n"
    body += f'\tEngine.get_meta("diag_meter").record("{category}","{module}.{name}",Time.get_ticks_usec()-_diag_started)\n'
    if not void:
        body += "\treturn _diag_result\n"
    body += "\n" + original
    return source[:match.start()] + body + source[match.end():], True

def add_guard(source, name, mode, returns=""):
    pattern = rf"^func {re.escape(name)}\(.*\).+:$"
    match = re.search(pattern, source, re.M)
    if not match:
        return source, False
    if mode == "projectile_logic" and name == "tick_projectiles":
        insertion = '\n\tif Engine.get_meta("diag_mode","")=="projectile_logic":\n\t\tprojectiles.clear()\n\t\treturn'
    else:
        insertion = f'\n\tif Engine.get_meta("diag_mode","")=="{mode}":return {returns}'
    return source[:match.end()] + insertion + source[match.end():], True

def prepare(area, detail):
    game = area / "space-battleship"
    for name in ("scripts", "data", "assets"):
        if name != "assets" or not (game / name).exists():
            shutil.copytree(SOURCE / name, game / name, dirs_exist_ok=True)
    for name in ("project.godot", "main.tscn"):
        shutil.copy2(SOURCE / name, game / name)
    (game / ".runtime").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "test/saved_game_diagnosis.gd", game / "saved_game_diagnosis.gd")
    # All guards live only in this copied project; source gameplay files stay byte-for-byte intact.
    for module in set(FUNCTIONS) | {"main", "game"}:
        path = game / "scripts" / (module + ".gd")
        source = path.read_text(encoding="utf-8")
        for mode, mapping in AB.items():
            for name in mapping.get(module, []):
                if detail:
                    continue
                source, found = add_guard(source, name, mode)
                if not found:
                    raise ValueError(f"Guard target missing: {module}.{name}")
        if module == "main":
            source = source.replace('var visible_projectiles: Array = [] if accelerated_visual_mode else game.projectiles', 'var visible_projectiles: Array = [] if accelerated_visual_mode or Engine.get_meta("diag_mode","")=="projectile_visual" else game.projectiles')
            source = source.replace('for enemy in game.enemies:\n\t\tif enemy.hp <= 0:', 'for enemy in game.enemies:\n\t\tif Engine.get_meta("diag_mode","")=="enemy_visual":continue\n\t\tif enemy.hp <= 0:')
            source = source.replace('if control.get(property) != value:\n\t\tcontrol.set(property,value)', 'if control.get(property) != value:\n\t\tif Engine.has_meta("diag_meter"):Engine.get_meta("diag_meter").ui_write(str(property))\n\t\tif Engine.get_meta("diag_mode","")=="text_update" and property=="text":return\n\t\tcontrol.set(property,value)')
            if detail:
                source = re.sub(r'\b([A-Za-z_][A-Za-z_0-9]*)\.queue_redraw\(\)', r'diag_queue_redraw(\1)', source)
                source += '\nfunc diag_queue_redraw(item: CanvasItem) -> void:\n\tEngine.get_meta("diag_meter").redraw_request()\n\titem.queue_redraw()\n'
        if detail:
            for category, names in FUNCTIONS.get(module, {}).items():
                for name in names:
                    source, _ = wrap(source, name, category, module)
            if module == "game":
                source = source.replace('var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)', 'Engine.get_meta("diag_meter").save_write()\n\tvar file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)')
        path.write_text(source, encoding="utf-8")
    return game

def run_probe(area, mode, detail, fps, speed, long_minutes):
    game = prepare(area, detail)
    snapshot = SNAPSHOT.read_bytes()
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    target = Path(env["APPDATA"]) / "Godot/app_userdata/太空战舰 · 深空远征/progress.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(snapshot)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True, exist_ok=True)
    engine = SOURCE / "engine/Godot_v4.7.2-stable_win64.exe"
    if not (game / ".godot").exists():
        with (area / "import.log").open("w", encoding="utf-8") as log:
            result = subprocess.run([str(engine), "--path", str(game), "--headless", "--editor", "--import", "--quit"], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        if result.returncode:
            raise RuntimeError((area / "import.log").read_text(encoding="utf-8", errors="replace")[-6000:])
    name = f'{mode}-{speed:g}' + (f'-fps{fps}' if fps else '') + f'-{"detail" if detail else "plain"}'
    flags = ["--path", str(game), "--resolution", "1373x883", "--script", "res://saved_game_diagnosis.gd", "--", f"--diag-mode={mode}", f"--diag-fps={fps}", f"--diag-speed={speed}", f"--diag-long-minutes={long_minutes}", f"--diag-name={name}"]
    print("RUN", name, "at", area, flush=True)
    with (area / (name + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run([str(engine), *flags], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=max(240, long_minutes * 75 + 120))
    output = (area / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:
        raise RuntimeError(f"{name} exit={result.returncode}\n" + output[-9000:])
    report_path = game / ".runtime" / (name + ".json")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["save_sha256"] = hashlib.sha256(snapshot).hexdigest()
    (area / (name + ".json")).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    assert SNAPSHOT.read_bytes() == snapshot
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--area", type=Path)
    parser.add_argument("--mode", default="baseline")
    parser.add_argument("--detail", action="store_true")
    parser.add_argument("--fps", type=int, default=0)
    parser.add_argument("--speed", type=float, default=1.0)
    parser.add_argument("--long-minutes", type=int, default=0)
    args = parser.parse_args()
    area = args.area.resolve() if args.area else Path(tempfile.mkdtemp(prefix="saved-diagnosis-", dir=ROOT / "test/work"))
    assert area.parent == (ROOT / "test/work").resolve() and area.name.startswith("saved-diagnosis-")
    area.mkdir(exist_ok=True)
    report = run_probe(area, args.mode, args.detail, args.fps, args.speed, args.long_minutes)
    for page in report["pages"]:
        print(page["page"], page["frame_stats"], "cpu", page["cpu_stats"], "gpu", page["gpu_stats"], flush=True)
    print("EVIDENCE", area, flush=True)

if __name__ == "__main__":
    main()
