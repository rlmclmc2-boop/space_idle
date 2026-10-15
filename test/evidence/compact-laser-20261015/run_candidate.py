"""Run the focused compact-laser contract with one explicit candidate DLL."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[3]
candidate = Path(r"D:\CodexBuild\space_idle\compact-laser-20261015\bin\space_native.dll")
work = root / "test" / "work"
work.mkdir(exist_ok=True)
reused = len(sys.argv) == 3 and sys.argv[1] == "--reuse"
area = Path(sys.argv[2]) if reused else Path(tempfile.mkdtemp(prefix="compact-laser-", dir=work))
game = area / "space-battleship"
source = root / "space-battleship"
tests = area / "test"
if not reused:
    game.mkdir()
    for name in ("scripts", "shaders", "tools", "data", "config_excel", "assets", "addons", "dev"):
        shutil.copytree(source / name, game / name,
                        ignore=shutil.ignore_patterns("__pycache__", ".import_state.json", "~$*", "*.blend", "*.blend1"))
    for name in ("project.godot", "main.tscn", "level_editor.tscn"):
        shutil.copy2(source / name, game / name)
    shutil.copy2(root / "太空战舰.xlsx", area / "太空战舰.xlsx")
    (game / "bin").mkdir()
    shutil.copy2(candidate, game / "bin" / "space_native.dll")
    shutil.copy2(source / "addons" / "native_battle" / "space_native.gdextension.in",
                 game / "space_native.gdextension")
    tests.mkdir()
shutil.copy2(root / "test" / "test_compact_laser.gd", tests / "test_compact_laser.gd")
env = os.environ.copy()
for key, relative in (("APPDATA", "userdata/roaming"), ("LOCALAPPDATA", "userdata/local"),
                      ("XDG_DATA_HOME", "userdata/data"), ("XDG_CONFIG_HOME", "userdata/config"),
                      ("XDG_CACHE_HOME", "userdata/cache"), ("PYTHONPYCACHEPREFIX", "pycache")):
    folder = area / relative
    folder.mkdir(parents=True, exist_ok=True)
    env[key] = str(folder)
godot = source / "engine" / "Godot_v4.7.2-stable_win64.exe"
def run(args, label):
    with (area / (label + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run([str(godot), *args], cwd=game, env=env,
                                stdout=log, stderr=subprocess.STDOUT, timeout=180)
    print((area / (label + ".log")).read_text(encoding="utf-8", errors="replace"))
    return result.returncode
print(f"Artifacts: {area}", flush=True)
code = 0 if reused else run(["--headless", "--editor", "--import", "--quit", "--path", str(game)], "import")
if code == 0:
    code = run(["--headless", "--path", str(game), "--script", str(tests / "test_compact_laser.gd")], "test")
sys.exit(code)
