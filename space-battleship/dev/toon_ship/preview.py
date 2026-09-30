"""Import and run only this prototype with isolated project and user directories."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
ENGINE = PROJECT / "engine/Godot_v4.7.2-stable_win64.exe"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["toon", "smooth", "close", "no-rim", "original", "acceptance", "full-loadout"], default="toon")
    parser.add_argument("--snapshot",type=Path,default=PROJECT/".userdata/roaming/Godot/app_userdata/太空战舰 · 深空远征/progress.json")
    parser.add_argument("--reuse", type=Path)
    parser.add_argument("--interactive", action="store_true")
    args = parser.parse_args()
    if not args.snapshot.is_file():
        parser.error("Provide an existing --snapshot; the live save is never opened by Godot.")
    saved=json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
    if saved.get("selectedShip")!="Heavy_Battleship" or len(saved.get("loadout",{}).get("weapons",[]))!=8:
        parser.error("This prototype validates only the existing eight-slot Heavy_Battleship.")
    if args.reuse:
        area = args.reuse.resolve()
        assert area.parent == PROJECT.parent / "test/work" and area.name.startswith("toon-ship-")
    else:
        area = Path(tempfile.mkdtemp(prefix="toon-ship-", dir=PROJECT.parent / "test/work"))
        subprocess.run(["icacls",str(area),"/inheritance:e"],check=True,stdout=subprocess.DEVNULL)
    game = area / "space-battleship"
    game.mkdir(exist_ok=True)
    for name in ("scripts","data","assets","config_excel","dev","addons"):
        shutil.copytree(PROJECT / name, game / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__","source","~$*","*.blend1"))
    for name in ("project.godot","main.tscn","level_editor.tscn"):
        shutil.copy2(PROJECT / name,game / name)
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    for name in ("APPDATA","LOCALAPPDATA"):
        Path(env[name]).mkdir(parents=True,exist_ok=True)
    if args.snapshot.exists():
        save_dir=Path(env["APPDATA"])/"Godot/app_userdata/太空战舰 · 深空远征"
        save_dir.mkdir(parents=True,exist_ok=True)
        shutil.copy2(args.snapshot,save_dir/"progress.json")
    command = [str(ENGINE),"--path",str(game)]
    with (area / "import.log").open("w",encoding="utf-8") as log:
        code = subprocess.run(command+["--headless","--editor","--import","--quit"],
                              env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180).returncode
    imported = (area / "import.log").read_text(encoding="utf-8",errors="replace")
    if code or "SCRIPT ERROR" in imported or "Parse Error" in imported:
        print(imported)
        raise SystemExit(code or 1)
    output = area / args.mode
    if args.mode == "full-loadout":
        command += ["--resolution","1335x859","--script","res://dev/toon_ship/full_loadout_check.gd","--","--output="+str(output),"--prototype-saved-loadout"]
    elif args.mode == "acceptance":
        command += ["--resolution","1335x859","--script","res://dev/toon_ship/acceptance.gd","--","--output="+str(output),"--prototype-saved-loadout"]
    else:
        command += ["--resolution","1335x859","res://dev/toon_ship_test.tscn","--"]
    if args.mode not in ("full-loadout", "acceptance"): command += ["--prototype-capture="+str(output),"--prototype-saved-loadout"]
    if not args.interactive:
        command += ["--prototype-exit"]
    if args.mode=="smooth": command += ["--prototype-smooth"]
    if args.mode=="close": command += ["--prototype-close"]
    if args.mode=="no-rim": command += ["--prototype-no-rim"]
    if args.mode=="original": command += ["--prototype-original"]
    with (area / (args.mode+".log")).open("w",encoding="utf-8") as log:
        if args.interactive:
            process = subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
            print(json.dumps({"area":str(area),"pid":process.pid,"mode":args.mode}))
            return
        code = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120).returncode
    runtime = (area / (args.mode+".log")).read_text(encoding="utf-8",errors="replace")
    print(runtime)
    print(json.dumps({"area":str(area),"output":str(output)}))
    runtime_errors = [line for line in runtime.splitlines() if any(word in line for word in ("SCRIPT ERROR","SHADER ERROR","ERROR:")) and "Failed to read the root certificate store." not in line]
    if code or runtime_errors:
        raise SystemExit(code or 1)


if __name__=="__main__":
    main()
