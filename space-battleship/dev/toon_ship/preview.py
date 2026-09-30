"""Portable, isolated five-hull prototype preview. Never opens a live save in Godot."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
HULLS = ("Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", shutil.which("godot") or shutil.which("godot4")))
    parser.add_argument("--mode", choices=["toon", "smooth", "close", "no-rim", "original", "acceptance", "full-loadout", "mapping"], default="toon")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--snapshot", type=Path, help="Existing save copied read-only into an isolated runtime")
    source.add_argument("--fixture", choices=HULLS + ("all",), help="Explicit synthetic full-loadout fixture; no player save")
    parser.add_argument("--reuse", type=Path, help="Reuse a directory previously created by this launcher")
    parser.add_argument("--interactive", action="store_true")
    weapon_fixture = parser.add_mutually_exclusive_group()
    weapon_fixture.add_argument("--pulse-fixture", action="store_true", help="Synthetic same-hull all-pulse loadout for visual review")
    weapon_fixture.add_argument("--rail-fixture", action="store_true", help="Synthetic all-cannon loadout")
    weapon_fixture.add_argument("--missile-fixture", action="store_true", help="Synthetic all-missile loadout")
    weapon_fixture.add_argument("--beam-fixture", action="store_true", help="Synthetic all-continuous-beam loadout")
    args = parser.parse_args()
    if not args.godot or not Path(args.godot).is_file():
        parser.error("Supply --godot PATH to a Godot 4 executable, or put godot in PATH")
    if (args.pulse_fixture or args.rail_fixture or args.missile_fixture or args.beam_fixture) and not args.fixture:
        parser.error("Weapon fixture flags require an explicit synthetic --fixture")
    if args.interactive and args.fixture == "all":
        parser.error("Choose one hull for interactive preview")
    if args.snapshot:
        if not args.snapshot.is_file(): parser.error("Snapshot does not exist")
        saved = json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
        if saved.get("selectedShip") not in HULLS: parser.error("Unsupported snapshot hull")
    work = PROJECT.parent / "test/work"
    work.mkdir(parents=True, exist_ok=True)
    if args.reuse:
        area = args.reuse.resolve()
        if area.parent != work.resolve() or not area.name.startswith("toon-ship-") or not (area / "isolated-prototype.json").is_file():
            parser.error("--reuse must name a launcher-created test/work/toon-ship-* directory")
    else:
        area = Path(tempfile.mkdtemp(prefix="toon-ship-", dir=work)).resolve()
    (area / "isolated-prototype.json").write_text(json.dumps({"source": str(PROJECT), "fixture": args.fixture, "snapshot": bool(args.snapshot)}))
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
    if args.snapshot:
        base = Path(env["APPDATA"]) / "Godot" if os.name == "nt" else Path(env["XDG_DATA_HOME"]) / "godot"
        save_dir = base / "app_userdata/太空战舰 · 深空远征"
        save_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.snapshot, save_dir / "progress.json")
    command = [str(Path(args.godot).resolve()), "--path", str(game), "--audio-driver", "Dummy"]
    def run_checked(command, logfile, timeout=180):
        with logfile.open("w", encoding="utf-8") as log:
            code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
        runtime = logfile.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in runtime.splitlines() if any(word in line for word in ("SCRIPT ERROR", "SHADER ERROR", "ERROR:")) and "Failed to read the root certificate store." not in line]
        if code or errors:
            print(runtime)
            raise SystemExit(code or 1)
        return runtime
    run_checked(command + ["--headless", "--editor", "--import", "--quit"], area / "import.log")
    if args.mode == "mapping":
        print(run_checked(command + ["--headless", "--script", "res://dev/toon_ship/hybrid_mapping_check.gd"], area / "mapping.log"))
        print(json.dumps({"area": str(area)}))
        return
    for hull in HULLS if args.fixture == "all" else (args.fixture or saved["selectedShip"],):
        output = area / (hull + "-" + args.mode)
        checked = args.mode in ("acceptance", "full-loadout")
        run = command + ["--resolution", "1335x859"]
        run += ["--script", "res://dev/toon_ship/full_loadout_check.gd"] if checked else ["res://dev/toon_ship_test.tscn"]
        run += ["--", "--output=" + str(output)] if checked else ["--", "--prototype-capture=" + str(output)]
        run += ["--prototype-fixture=" + hull] if args.fixture else ["--prototype-saved-loadout"]
        if args.missile_fixture: run += ["--prototype-missile-fixture"]
        if args.beam_fixture: run += ["--prototype-beam-fixture"]
        if args.rail_fixture: run += ["--prototype-rail-fixture"]
        if args.pulse_fixture: run += ["--prototype-pulse-fixture"]
        if not args.interactive: run += ["--prototype-exit"]
        flags = {"smooth": "smooth", "close": "close", "no-rim": "no-rim", "original": "original"}
        if args.mode in flags: run += ["--prototype-" + flags[args.mode]]
        logfile = area / (hull + "-" + args.mode + ".log")
        if args.interactive:
            with logfile.open("w", encoding="utf-8") as log:
                process = subprocess.Popen(run, env=env, stdout=log, stderr=subprocess.STDOUT)
            print(json.dumps({"area": str(area), "pid": process.pid, "fixture": args.fixture}))
            return
        print(run_checked(run, logfile))
        print(json.dumps({"area": str(area), "output": str(output), "fixture": bool(args.fixture)}))


if __name__ == "__main__":
    main()
