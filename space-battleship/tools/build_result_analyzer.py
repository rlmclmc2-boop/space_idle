"""Build the portable battle simulation lab from an explicit dependency allowlist."""
import argparse
import filecmp
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = (
    "ui_text.gd", "fleet_result_analyzer.gd", "fleet_analysis_panel.gd", "fleet_design_cards.gd", "fleet_batch_retest.gd",
    "database.gd", "game.gd", "number_format.gd", "crew_system.gd", "ship_visuals.gd",
    "balance_game.gd", "balance_database.gd", "balance_metrics.gd", "balance_timeline.gd",
    "enemy_fleet_simulator.gd", "player_loadout_generator.gd", "fleet_battle_sampling.gd",
    "fleet_battle_runner.gd", "enemy_fleet_panel.gd", "player_loadout_panel.gd", "fleet_battle_panel.gd",
    "fleet_level_generator.gd", "fleet_level_panel.gd", "mon_group_xlsx.gd",
    "cycle_level_generator.gd", "cycle_level_panel.gd", "cycle_level_xlsx.gd",
)

def build(output: Path) -> None:
    output = output.resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError("Output must be outside the game project")
    # Never remove an existing directory or overwrite arbitrary user files.
    marker = output / "analyzer-package.json"
    if output.exists() and any(output.iterdir()) and not marker.is_file():
        raise ValueError("Nonempty output is not an analyzer package")
    output.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps({"tool": "battle-simulation-lab", "version": 2,
                                  "source_mon": str((ROOT / "config_excel/mon.xlsx").resolve())}), encoding="utf-8")
    for folder in ("scripts", "data", "assets/fonts", "config_excel", "runtime", "results"):
        (output / folder).mkdir(parents=True, exist_ok=True)
    # Generated CSV/PNG output is data, not an editor asset to reimport.
    (output / "results/.gdignore").touch()
    for name in SCRIPTS:
        shutil.copy2(ROOT / "scripts" / name, output / "scripts" / name)
    for name in ("ui_text.json", "ui_text_contract.json", "battle_result_analysis.json", "enemy_fleet_analysis.json", "auto_level_generation.json", "level_generation_config.json"):
        shutil.copy2(ROOT / "data" / name, output / "data" / name)
    data = json.loads((ROOT / "data/game_data.json").read_text(encoding="utf-8"))
    # Enemy rows are read directly from the original mon.xlsx at runtime.
    data.pop("enemies", None)
    (output / "data/game_data.json").write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    names = {"equipment": {k: rows[0].get("name", "") for k, rows in data["equipment"].items() if rows}}
    (output / "data/analysis_display_names.json").write_text(json.dumps(names, ensure_ascii=False), encoding="utf-8")
    shutil.copy2(ROOT / "assets/fonts/NotoSansSC.ttf", output / "assets/fonts/NotoSansSC.ttf")
    shutil.copy2(ROOT / "config_excel/monGroup.xlsx", output / "config_excel/monGroup.xlsx")
    shutil.copy2(ROOT / "config_excel/level.xlsx", output / "config_excel/level.xlsx")
    for name in ("project.godot", "main.tscn", "entry.gd", "start.bat", "周期关卡工具.cmd"):
        shutil.copy2(ROOT / "tools/result_analyzer" / name, output / name)
    engine = ROOT / "engine/Godot_v4.7.2-stable_win64.exe"
    runtime = output / "runtime/analyzer.exe"
    if not runtime.exists() or not filecmp.cmp(engine, runtime, shallow=False):
        shutil.copy2(engine, runtime)
    (output / "使用说明.txt").write_text(
        "双击 start.bat 启动。在敌舰群窗口的“周期关卡”页，选择已有 generated_levels.json，设置周期并预览，随后导出 Excel。\n"
        "依次生成双方组合后，在批量战斗页开始测试；批次写入本目录的 results 文件夹。\n"
        "战斗结束后，在结果分析页点“分析当前批次”，或选择旧批次目录；数据不足可直接在该页定向复测并合并结果。\n"
        "六个分析文件写回所选批次目录；生成关卡与补测写入批次下的 generated_levels。运行时直接读取相邻 space-battleship/config_excel/mon.xlsx，请保留两者的相对位置；无需启动游戏、Python 或安装 Godot。不会读取游戏存档。\n", encoding="utf-8")
    # Import only this independent project; never touch player directories.
    env = os.environ.copy()
    env["APPDATA"] = str(output / ".build-user/roaming")
    env["LOCALAPPDATA"] = str(output / ".build-user/local")
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    with (output / "build.log").open("w", encoding="utf-8") as log:
        subprocess.run([str(output / "runtime/analyzer.exe"), "--headless", "--path", str(output),
                        "--editor", "--import", "--quit"], env=env, stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=90)
    log_text = (output / "build.log").read_text(encoding="utf-8")
    if "SCRIPT ERROR" in log_text or "Parse Error" in log_text:
        raise RuntimeError(f"Analyzer import failed: {output / 'build.log'}")
    print(output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT.parent / "战斗模拟工具")
    build(parser.parse_args().output)
