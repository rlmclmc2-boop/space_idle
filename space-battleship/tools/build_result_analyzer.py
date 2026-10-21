"""Build the portable battle simulation lab from an explicit dependency allowlist."""
import argparse
import filecmp
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/analyzer_required_data.json"
SCRIPT_REF = re.compile(r'res://scripts/([^"\']+\.gd)')
DATA_REF = re.compile(r'res://data/([^"\']+\.json)')


def required_files() -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    scripts = set(manifest["scripts"])
    data = set(manifest["data"])
    for name in scripts:
        source = ROOT / "scripts" / name
        if not source.is_file():
            raise FileNotFoundError(source)
        contents = source.read_text(encoding="utf-8")
        missing_scripts = set(SCRIPT_REF.findall(contents)) - scripts
        missing_data = set(DATA_REF.findall(contents)) - data
        if missing_scripts or missing_data:
            raise ValueError(f"Unlisted analyzer dependency in {name}: scripts={sorted(missing_scripts)}, data={sorted(missing_data)}")
    if set(manifest["dynamic_data"]) - data:
        raise ValueError("Dynamic analyzer data must also be in the data allowlist")
    config_source = (ROOT / "scripts/hyperspace_config.gd").read_text(encoding="utf-8")
    dynamic_loop = re.search(r'for name in \[(.*?)\]:\s*\n\s*var parsed=.*?"res://data/"\+name', config_source, re.S)
    if dynamic_loop is None:
        raise ValueError("Analyzer dynamic data read changed; update its manifest")
    dynamic_names = set(re.findall(r'"([^"/]+\.json)"', dynamic_loop.group(1)))
    schema = json.loads((ROOT / "data/hyperspace_entity_schema.json").read_text(encoding="utf-8"))
    dynamic_names.update(schema["frozen_inputs"])
    if dynamic_names - set(manifest["dynamic_data"]):
        raise ValueError(f"Undeclared dynamic analyzer data: {sorted(dynamic_names - set(manifest['dynamic_data']))}")
    for name in manifest["data"]:
        source = ROOT / "data" / name
        if not source.is_file():
            raise FileNotFoundError(source)
    for name in manifest["assets"] + manifest["workbooks"]:
        source = ROOT / name
        if not source.is_file():
            raise FileNotFoundError(source)
    source_mon = ROOT / manifest["external_workbooks"]["source_mon"]
    if not source_mon.is_file():
        raise FileNotFoundError(source_mon)
    entry = (ROOT / "tools/result_analyzer/entry.gd").read_text(encoding="utf-8")
    if set(SCRIPT_REF.findall(entry)) - scripts:
        raise ValueError("Analyzer entry script has an unlisted script dependency")
    return manifest


def check_import_log(log_text: str, path: Path) -> None:
    lines = log_text.splitlines()
    certificate_error = "ERROR: Failed to read the root certificate store."
    certificate_trace = "   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)"
    certificate_count = 0
    for index, line in enumerate(lines):
        if "SCRIPT ERROR" in line or "Parse Error" in line:
            raise RuntimeError(f"Analyzer import script error: {path}: {line}")
        if not line.lstrip().startswith("ERROR:"):
            continue
        if (line == certificate_error and index + 1 < len(lines)
                and lines[index + 1] == certificate_trace):
            certificate_count += 1
            if certificate_count == 1:
                continue
        raise RuntimeError(f"Analyzer import error: {path}: {line}")


def build(output: Path, engine: Path | None = None) -> None:
    output = output.resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError("Output must be outside the game project")
    # Never remove an existing directory or overwrite arbitrary user files.
    marker = output / "analyzer-package.json"
    if output.exists() and any(output.iterdir()) and not marker.is_file():
        raise ValueError("Nonempty output is not an analyzer package")
    manifest = required_files()
    engine = (engine or ROOT / "engine/Godot_v4.7.2-stable_win64.exe").resolve()
    if not engine.is_file():
        raise FileNotFoundError(engine)
    output.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps({"tool": "battle-simulation-lab", "version": 2,
                                  "source_mon": str((ROOT / "config_excel/mon.xlsx").resolve())}), encoding="utf-8")
    shutil.copy2(MANIFEST, output / "analyzer_required_data.json")
    for folder in ("scripts", "data", "assets/fonts", "config_excel", "runtime", "results"):
        (output / folder).mkdir(parents=True, exist_ok=True)
    # Generated CSV/PNG output is data, not an editor asset to reimport.
    (output / "results/.gdignore").touch()
    for name in manifest["scripts"]:
        shutil.copy2(ROOT / "scripts" / name, output / "scripts" / name)
    for name in manifest["data"]:
        if name == "game_data.json":
            continue
        shutil.copy2(ROOT / "data" / name, output / "data" / name)
    data = json.loads((ROOT / "data/game_data.json").read_text(encoding="utf-8"))
    # Enemy rows are read directly from the original mon.xlsx at runtime.
    data.pop("enemies", None)
    (output / "data/game_data.json").write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    names = {"equipment": {k: rows[0].get("name", "") for k, rows in data["equipment"].items() if rows}}
    (output / "data/analysis_display_names.json").write_text(json.dumps(names, ensure_ascii=False), encoding="utf-8")
    for name in manifest["assets"] + manifest["workbooks"]:
        shutil.copy2(ROOT / name, output / name)
    for name in ("project.godot", "main.tscn", "entry.gd", "start.bat", "周期关卡工具.cmd"):
        shutil.copy2(ROOT / "tools/result_analyzer" / name, output / name)
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
    check_import_log(log_text, output / "build.log")
    print(output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT.parent / "战斗模拟工具")
    parser.add_argument("--engine", type=Path, help="Godot 4.7.2 executable (default: project engine)")
    args = parser.parse_args()
    build(args.output, args.engine)
