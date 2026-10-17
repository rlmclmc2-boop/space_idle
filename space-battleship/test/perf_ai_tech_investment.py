"""Compare five AI input settings in the rich whole-game fixture.

Runs the current checkout with isolated user data and the verified native DLL.
No full asset copy or player save is created.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
FIXTURE = WORKSPACE / "test/fixtures/galaxy_1_complete.json"
GODOT = Path(r"D:\放置\space-battleship\engine\Godot_v4.7.2-stable_win64.exe")
DLL_SHA = "dccd40b52e086444edd7291d2bead736b96f7876a53f989df5549a1d4f99b30a"


def main() -> int:
    if not FIXTURE.is_file() or not GODOT.is_file():
        raise FileNotFoundError("Unified rich fixture or Godot executable missing")
    import hashlib
    dll = PROJECT / "bin/space_native.dll"
    if not dll.is_file() or hashlib.sha256(dll.read_bytes()).hexdigest() != DLL_SHA:
        raise RuntimeError("Current checkout has no verified matching native DLL")
    work = WORKSPACE / "test/work"
    work.mkdir(parents=True, exist_ok=True)
    area = Path(tempfile.mkdtemp(prefix="ai-tech-perf-", dir=work))
    project = PROJECT
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
    headless = os.environ.get("PERF_HEADLESS") == "1"
    env.update(PERF_RICH="1", PERF_REALTIME="1", PERF_PAGES="0,1", PERF_FRAMES="480", PERF_BALANCE="1e80", PERF_CAPTURE="0" if headless else "1")
    engine = [str(GODOT), "--path", str(project)]
    print(f"Evidence: {area}", flush=True)
    with (area / "import.log").open("w", encoding="utf-8") as output:
        subprocess.run([*engine, "--headless", "--editor", "--import", "--quit"], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240, check=True)
    results = {}
    for mode in ("zero", "iron", "uranium", "both", "both_1000"):
        env["PERF_AI_INPUTS"] = mode
        with (area / f"{mode}.log").open("w", encoding="utf-8") as output:
            subprocess.run([*engine, *(["--headless"] if headless else []), "--audio-driver", "Dummy", "--disable-vsync", "--script", "res://test/perf_ai_tech_investment.gd"], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240, check=True)
        rows = json.loads((project / ".runtime/ai-tech-investment-perf.json").read_text(encoding="utf-8"))
        results[mode] = rows
        (area / f"{mode}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        for page in (0, 1):
            image = project / f".runtime/page-{page}.png"
            if image.is_file():
                image.replace(area / f"{mode}-page-{page}.png")
        for row in rows:
            print(json.dumps({k: row[k] for k in ("inputs", "page", "resource_events", "snapshot_calls", "row_rebuilds", "row_count", "node_delta", "main_us", "frames_us", "projectiles", "missile_queue")}, ensure_ascii=False), flush=True)
    (area / "summary.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
