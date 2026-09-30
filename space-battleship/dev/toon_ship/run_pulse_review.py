"""Isolate and render the deterministic Heavy pulse-VFX review, never a player save."""
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
    parser.add_argument("--reuse", type=Path, help="Directory previously created by this pulse launcher")
    parser.add_argument("--prepare-only", action="store_true", help="Prepare/import without graphical execution")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Supply a Godot 4 executable")
    work = PROJECT.parent / "test/work"
    work.mkdir(parents=True, exist_ok=True)
    if args.reuse:
        area = args.reuse.resolve()
        if area.parent != work.resolve() or not (area / "isolated-pulse.json").is_file():
            parser.error("--reuse requires a directory created by this launcher")
    else:
        area = Path(tempfile.mkdtemp(prefix="toon-pulse-", dir=work)).resolve()
    (area / "isolated-pulse.json").write_text(json.dumps({"source": str(PROJECT), "fixture": "Heavy_Battleship", "type": "presentation-only"}))
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
    print(json.dumps({"area": str(area), "output": str(area / "Heavy_Battleship-pulse")}), flush=True)
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
    output = area / "Heavy_Battleship-pulse"
    print(run_checked(command + ["--resolution", "1335x859", "--script", "res://dev/toon_ship/pulse_review.gd", "--", "--output=" + str(output), "--prototype-fixture=Heavy_Battleship", "--prototype-pulse-fixture"], area / "pulse.log"), flush=True)



if __name__ == "__main__":
    main()
