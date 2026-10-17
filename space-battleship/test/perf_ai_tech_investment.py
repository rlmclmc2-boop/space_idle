"""Compare zero and dual-resource AI research input in the rich whole-game fixture.

Uses the workspace's existing test/fixtures/galaxy_1_complete.json and an
isolated project copy. No player save or source project cache is written.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
FIXTURE = WORKSPACE / "test/fixtures/galaxy_1_complete.json"
GODOT = Path(r"D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe")


def main() -> int:
    if not FIXTURE.is_file() or not GODOT.is_file():
        raise FileNotFoundError("Unified rich fixture or Godot executable missing")
    work = WORKSPACE / "test/work"
    work.mkdir(parents=True, exist_ok=True)
    area = Path(tempfile.mkdtemp(prefix="ai-tech-perf-", dir=work))
    project = area / "space-battleship"
    shutil.copytree(
        PROJECT,
        project,
        ignore=shutil.ignore_patterns(".godot", ".runtime", "*.blend", "*.blend1", "__pycache__"),
    )
    shutil.copy2(PROJECT / "test/perf_ai_tech_investment.gd", project / "probe.gd")
    shutil.copy2(FIXTURE, project / "galaxy_fixture.json")
    (project / ".runtime").mkdir(exist_ok=True)
    env = os.environ.copy()
    for key, folder in (
        ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
        ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"),
        ("LOCALAPPDATA", "local"),
    ):
        location = area / "userdata" / folder
        location.mkdir(parents=True, exist_ok=True)
        env[key] = str(location)
    env.update(PERF_RICH="1", PERF_REALTIME="1", PERF_PAGES="0,1", PERF_FRAMES="480", PERF_BALANCE="1e80")
    engine = [str(GODOT), "--path", str(project)]
    print(f"Evidence: {area}", flush=True)
    with (area / "import.log").open("w", encoding="utf-8") as output:
        subprocess.run([*engine, "--headless", "--editor", "--import", "--quit"], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240, check=True)
    results = {}
    for mode in ("zero", "both"):
        env["PERF_AI_INPUTS"] = mode
        with (area / f"{mode}.log").open("w", encoding="utf-8") as output:
            subprocess.run([*engine, "--headless", "--audio-driver", "Dummy", "--disable-vsync", "--script", "res://probe.gd"], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240, check=True)
        rows = json.loads((project / ".runtime/ai-tech-investment-perf.json").read_text(encoding="utf-8"))
        results[mode] = rows
        (area / f"{mode}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        for row in rows:
            print(json.dumps({k: row[k] for k in ("inputs", "page", "resource_events", "snapshot_calls", "row_rebuilds", "row_count", "node_delta", "main_us", "frames_us", "projectiles", "missile_queue")}, ensure_ascii=False), flush=True)
    (area / "summary.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
