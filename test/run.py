"""Run one existing test in an isolated workspace beneath test/work."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    tests = Path(__file__).resolve().parent
    workspace = tests.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("test", choices=sorted(p.name for p in tests.iterdir()
                        if p.suffix in {".py", ".gd"} and p.name != "run.py"))
    parser.add_argument("--godot", type=Path, default=workspace / "space-battleship/engine/Godot_v4.7.2-stable_win64.exe")
    args = parser.parse_args()
    work = tests / "work"
    work.mkdir(exist_ok=True)
    area = Path(tempfile.mkdtemp(prefix=Path(args.test).stem + "-", dir=work))
    if os.name == "nt":
        # mkdtemp restricts Windows ACLs to its creator; artifact viewers also
        # need the workspace's inherited access. Apply before creating children.
        subprocess.run(["icacls", str(area), "/inheritance:e"], check=True,
                       stdout=subprocess.DEVNULL)
    game = area / "space-battleship"
    game.mkdir()
    source = workspace / "space-battleship"
    for name in ("scripts", "tools", "data", "config_excel", "assets"):
        shutil.copytree(source / name, game / name,
                        ignore=shutil.ignore_patterns("__pycache__", ".import_state.json", "~$*"))
    for name in ("project.godot", "main.tscn"):
        shutil.copy2(source / name, game / name)
    shutil.copy2(workspace / "太空战舰.xlsx", area / "太空战舰.xlsx")
    isolated_tests = area / "test"
    isolated_tests.mkdir()
    for path in tests.iterdir():
        if path.is_file() and path.suffix in {".py", ".gd", ".uid"}:
            shutil.copy2(path, isolated_tests / path.name)
    (game / ".runtime").mkdir()
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    env["PYTHONPYCACHEPREFIX"] = str(area / "pycache")
    env["SPACE_BATTLESHIP_PYTHON"] = sys.executable
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True)
    print(f"Artifacts: {area}", flush=True)

    def run(command, label):
        with (area / (label + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=game, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=180)
        print((area / (label + ".log")).read_text(encoding="utf-8", errors="replace"))
        return result.returncode

    if args.test.endswith(".py"):
        return run([sys.executable, str(isolated_tests / args.test)], "test")
    godot = str(args.godot.resolve())
    code = run([godot, "--headless", "--editor", "--import", "--quit", "--path", str(game)], "import")
    if code:
        return code
    return run([godot, "--path", str(game), "--script", str(isolated_tests / args.test)], "test")


if __name__ == "__main__":
    raise SystemExit(main())
