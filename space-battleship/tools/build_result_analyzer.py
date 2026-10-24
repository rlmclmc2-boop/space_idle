"""Build the portable lab from its entrypoint closure and explicit dynamic data."""
import argparse
import filecmp
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from script_dependencies import closure

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/analyzer_required_data.json"


def required_files(configuration=None) -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get('version') != 2 or 'scripts' in manifest:
        raise ValueError('Analyzer manifest must use version 2 entrypoint-derived scripts')
    entries = json.loads((ROOT / 'tools/supported_entrypoints.json').read_text(encoding='utf-8'))
    portable = entries['entries']['portable_lab']
    reached, references = closure(ROOT, portable['roots'], portable['resource_aliases'])
    manifest['scripts'] = sorted(name.removeprefix('scripts/') for name in reached if name.startswith('scripts/'))
    unexpected = reached - {'scripts/' + name for name in manifest['scripts']} - set(portable['roots']) - set(portable['resource_aliases'].values())
    if unexpected:
        raise ValueError(f'Unpackaged scene/resource dependencies: {sorted(unexpected)}')
    data = set(manifest["data"])
    allowed = {'data/' + name for name in data} | set(manifest['assets']) | set(manifest['workbooks']) | set(manifest['runtime_paths'])
    if references - allowed:
        raise ValueError(f'Undeclared analyzer resource references: {sorted(references - allowed)}')
    if set(manifest["dynamic_data"]) - data:
        raise ValueError("Dynamic analyzer data must also be in the data allowlist")
    config_source = (ROOT / "scripts/hyperspace_config.gd").read_text(encoding="utf-8")
    dynamic_loop = re.search(r'for name in \[(.*?)\]:\s*\n\s*var parsed=.*?"res://data/"\+name', config_source, re.S)
    if dynamic_loop is None:
        raise ValueError("Analyzer dynamic data read changed; update its manifest")
    dynamic_names = set(re.findall(r'"([^"/]+\.json)"', dynamic_loop.group(1)))
    schema = json.loads(configuration.files["data/hyperspace_entity_schema.json"] if configuration is not None else (ROOT / "data/hyperspace_entity_schema.json").read_bytes())
    dynamic_names.update(schema["frozen_inputs"])
    if dynamic_names - set(manifest["dynamic_data"]):
        raise ValueError(f"Undeclared dynamic analyzer data: {sorted(dynamic_names - set(manifest['dynamic_data']))}")
    for name in manifest["data"]:
        source = ROOT / "data" / name
        if ("data/"+name not in configuration.files) if configuration is not None else not source.is_file():
            raise FileNotFoundError(source)
    for name in manifest["assets"]:
        source = ROOT / name
        if not source.is_file():
            raise FileNotFoundError(source)
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
    # A package is an exact closure, not an overlay retaining retired scripts.
    if output.exists() and any(output.iterdir()):
        raise ValueError("Use a new empty output directory for an exact analyzer package")
    from config_snapshot import Store
    configuration=Store(ROOT).capture().runtime()
    manifest = required_files(configuration)
    engine = (engine or ROOT / "engine/Godot_v4.7.2-stable_win64.exe").resolve()
    if not engine.is_file():
        raise FileNotFoundError(engine)
    output.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps({"tool": "battle-simulation-lab", "version": 3, "configuration_generation":configuration.identity}), encoding="utf-8")
    (output / 'analyzer_required_data.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    for folder in ("scripts", "data", "assets/fonts", "config_excel", "runtime", "results"):
        (output / folder).mkdir(parents=True, exist_ok=True)
    # Generated CSV/PNG output is data, not an editor asset to reimport.
    (output / "results/.gdignore").touch()
    for name in manifest["scripts"]:
        (output / 'scripts' / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "scripts" / name, output / "scripts" / name)
    configuration.materialize(output)
    for name in manifest["assets"]:
        (output / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, output / name)
    for name in ("project.godot", "main.tscn", "entry.gd", "start.bat", "周期关卡工具.cmd"):
        shutil.copy2(ROOT / "tools/result_analyzer" / name, output / name)
    runtime = output / "runtime/analyzer.exe"
    if not runtime.exists() or not filecmp.cmp(engine, runtime, shallow=False):
        shutil.copy2(engine, runtime)
    # Provenance describes staged bytes, never a later reread of the source tree.
    provenance = {"version": 1, "kind": "portable_lab", "scripts": {
        "scripts/" + name: hashlib.sha256((output / "scripts" / name).read_bytes()).hexdigest()
        for name in manifest["scripts"]}, "engine_sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
        "configuration_generation": configuration.identity, "native": "not_used"}
    (output / "execution-provenance.json").write_text(json.dumps(provenance, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    (output / "使用说明.txt").write_text(
        "双击 start.bat 启动。敌舰群页生成组合，自动关卡页从当前组合生成关卡并导出 Excel；周期关卡页可读取 generated_levels.json。\n"
        "结果写入本目录的 results 文件夹。当前窗口没有独立批量战斗或结果分析页。\n"
        "Built-in configuration and workbook templates are frozen in this package. No source repository or external mon.xlsx is required.\n", encoding="utf-8")
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
