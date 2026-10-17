"""Exercise the shipped entry in a portable isolated path before main merge."""
from pathlib import Path
import importlib.util
import json
import os
import subprocess
import sys

root = Path(sys.argv[1]).resolve()
git_dir = Path(sys.argv[2]).resolve()
spec = importlib.util.spec_from_file_location("player_entry", root / "tools/play_main.py")
entry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)
entry.ROOT = root
original_run = entry.run
original_call = entry.subprocess.call

def run(args, cwd, env=None):
    if args[:3] == ["git", "branch", "--show-current"]:
        # This review checkout is a task branch; the production entry requires main.
        return "main"
    if args[0] == "git":
        args = ["git", "--git-dir", str(git_dir), "--work-tree", str(root), *args[1:]]
    return original_run(args, cwd, env)

def call(args, cwd, env=None):
    return original_call([*args, "--quit-after", "2"], cwd=cwd, env=env)

entry.run = run
entry.subprocess.call = call
os.environ["SPACE_BATTLESHIP_VERIFY_WINDOW"] = "1"
receipts = []
for n in (1, 2):
    code = entry.main()
    path = root / "test/work/player-window-check/player-launch.json"
    receipt = json.loads(path.read_text(encoding="utf-8"))
    receipts.append(receipt)
    print("ENTRY_RUN", n, "exit", code, "head", receipt["head"], "base", receipt["accepted_runtime"], flush=True)
    if code:
        raise SystemExit(code)
assert receipts[0] == receipts[1]
assert receipts[0]["head"] == "679712193b55394096c33f3825228064e5b93268"
print("ENTRY_REPEAT_OK", flush=True)
