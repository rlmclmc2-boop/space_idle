"""Isolate and render the deterministic Heavy ordnance-VFX review, never a player save."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--reuse", type=Path, help="Directory previously created by this ordnance launcher")
    parser.add_argument("--prepare-only", action="store_true", help="Prepare/import without graphical execution")
    parser.add_argument("--kind", choices=("missile","beam","mixed"), default="missile")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--after-only", action="store_true", help="Capture only new visuals; retain both paired simulation runs")
    parser.add_argument("--single-source", action="store_true")
    parser.add_argument("--durable-target", type=float, default=0.0, help="Explicit synthetic initial enemy HP; no production configuration changes")
    parser.add_argument("--interrupt-target", action="store_true", help="Headless lifecycle fixture: force target loss while missiles are queued")
    parser.add_argument("--offcenter-source", action="store_true", help="One active port missile pod, with an inert center mount")
    args = parser.parse_args()
    if args.offcenter_source and (not args.single_source or args.kind != "missile"):
        parser.error("--offcenter-source requires --single-source --kind missile")
    if args.interrupt_target and (not args.single_source or args.kind != "missile"):
        parser.error("--interrupt-target requires --single-source --kind missile")
    if not args.godot:
        parser.error("Supply a Godot 4 executable")
    work = PROJECT.parent / "test/work"
    work.mkdir(parents=True, exist_ok=True)
    if args.reuse:
        area = args.reuse.resolve()
        if area.parent != work.resolve() or not (area / "isolated-ordnance.json").is_file():
            parser.error("--reuse requires a directory created by this launcher")
    else:
        area = Path(tempfile.mkdtemp(prefix="toon-ordnance-", dir=work)).resolve()
    (area / "isolated-ordnance.json").write_text(json.dumps({"source": str(PROJECT), "fixture": "Heavy_Battleship", "type": "presentation-only"}))
    game = area / "space-battleship"
    game.mkdir(exist_ok=True)
    for name in ("scripts", "data", "assets", "config_excel", "dev", "addons"):
        shutil.copytree(PROJECT / name, game / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", "source", "review", "~$*", "*.blend1"))
    for name in ("project.godot", "main.tscn", "level_editor.tscn"):
        shutil.copy2(PROJECT / name, game / name)
    env = os.environ.copy()
    for name, relative in {"APPDATA": "roaming", "LOCALAPPDATA": "local", "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config", "XDG_CACHE_HOME": "cache"}.items():
        env[name] = str(area / "userdata" / relative)
        Path(env[name]).mkdir(parents=True, exist_ok=True)
    command = [str(Path(args.godot).resolve()), "--path", str(game), "--audio-driver", "Dummy"]
    print(json.dumps({"area": str(area), "output": str(area / ("Heavy_Battleship-" + args.kind))}), flush=True)
    def run_checked(argv, logfile, timeout=240):
        with logfile.open("w", encoding="utf-8") as log:
            code = subprocess.run(argv, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
        runtime = logfile.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in runtime.splitlines() if any(word in line for word in ("SCRIPT ERROR", "SHADER ERROR", "ERROR:")) and "Failed to read the root certificate store." not in line]
        if code or errors:
            print(runtime, flush=True)
            raise SystemExit(code or 1)
        return runtime
    run_checked(command + ["--headless", "--editor", "--import", "--quit"], area / "import.log")
    if args.prepare_only:
        return
    output = area / ("Heavy_Battleship-" + args.kind)
    flags = ["--prototype-" + args.kind + "-fixture"] + (["--ordnance-check-only"] if args.check_only else []) + (["--ordnance-after-only"] if args.after_only else [])
    if args.offcenter_source: flags += ["--prototype-offcenter-source"]
    if args.interrupt_target: flags += ["--interrupt-target"]
    if args.single_source: flags += ["--prototype-single-weapon=" + ("longLaser" if args.kind == "beam" else "missile")]
    if args.durable_target > 0: flags += ["--durable-target=" + str(args.durable_target)]
    print(run_checked(command + (["--headless"] if args.check_only else []) + ["--resolution", "1335x859", "--script", "res://dev/toon_ship/ordnance_review.gd", "--", "--output=" + str(output), "--prototype-fixture=Heavy_Battleship", *flags], area / "ordnance.log"), flush=True)



if __name__ == "__main__":
    main()
