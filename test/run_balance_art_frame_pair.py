"""Pair the existing visible 1x/60 Hz native main-scene driver before/after art."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import threading
import statistics
import psutil

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "test/work"
ENGINE = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
DLL = ROOT / "test/native-build/project/bin/space_native.dll"
SCRIPT = ROOT / "test/qa_battle_consistency_real.gd"
PARTS = ("scripts", "shaders", "tools", "data", "assets", "addons", "dev", "project.godot", "main.tscn")
REFS = (("before", "a5fa51bdae92c817caab1071a8b2a4242c0e503b"),
        ("after", "25fa50757ad4317f2d0a5c34154f11ccc26a81d7"))

MIXED = os.environ.get("PERF_MIXED_OPENING") == "1"
UNCAPPED = os.environ.get("PERF_UNCAPPED") == "1"
BRACKET = os.environ.get("PERF_BRACKET") == "1"
LABEL = ("balance-art-mixed" if MIXED else "balance-art") + ("-uncapped" if UNCAPPED else "") + ("-bracket" if BRACKET else "")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def checked(command, cwd, env, log, timeout):
    with log.open("w", encoding="utf8") as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    data = log.read_text(encoding="utf8", errors="replace")
    if result.returncode or "SCRIPT ERROR" in data or "ERROR:" in data:
        raise RuntimeError(f"{log}: exit={result.returncode}\n{data[-3500:]}")

def run(label, ref):
    area = Path(tempfile.mkdtemp(prefix=f"{LABEL}-{label}-", dir=WORK))
    subprocess.run(["icacls", str(area), "/inheritance:e"], check=True,
                   stdout=subprocess.DEVNULL)
    archive = area / "source.tar"
    with archive.open("wb") as output:
        subprocess.run(["git", "archive", ref, *("space-battleship/" + p for p in PARTS)],
                       cwd=ROOT, stdout=output, check=True)
    with tarfile.open(archive) as source:
        source.extractall(area, filter="data")
    archive.unlink()
    project = area / "space-battleship"
    (project / "bin").mkdir(exist_ok=True)
    shutil.copy2(DLL, project / "bin/space_native.dll")
    shutil.copy2(project / "addons/native_battle/space_native.gdextension.in",
                 project / "addons/native_battle/space_native.gdextension")
    shutil.copy2(SCRIPT, project / SCRIPT.name)
    shutil.copy2(ROOT / "test/combat_stress_fixture.gd", project / "combat_stress_fixture.gd")
    (project / ".runtime").mkdir(exist_ok=True)
    env = os.environ.copy()
    for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"),
                        ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                        ("XDG_CACHE_HOME", "cache")):
        path = area / "userdata" / folder
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env.update(PERF_NATIVE="1", PERF_SIDE=label, PERF_ART_PAIR="1", PERF_MIXED_OPENING="1" if MIXED else "0", PERF_UNCAPPED="1" if UNCAPPED else "0")
    engine = str(ENGINE)
    checked([engine, "--headless", "--editor", "--import", "--quit", "--path", str(project)],
            project, env, area / "import.log", 180)
    # Read-only host sampling runs alongside the visible fixture, never during import.
    host_samples = []
    sampling_done = threading.Event()
    def sample_host():
        while not sampling_done.is_set():
            host_samples.append(psutil.cpu_percent(interval=0.5))
    def process_cpu():
        rows = {}
        for item in psutil.process_iter(["pid", "name", "cpu_times"]):
            try:
                times = item.info["cpu_times"]
                if times is not None:
                    rows[item.info["pid"]] = (item.info["name"], times.user + times.system)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return rows
    before_cpu = process_cpu()
    monitor = threading.Thread(target=sample_host, daemon=True)
    monitor.start()
    try:
        checked([engine, "--path", str(project), "--audio-driver", "Dummy",
                 "--resolution", "1373x883", "--disable-vsync", "--script", "res://" + SCRIPT.name],
                project, env, area / "visible-native.log", 180)
    finally:
        sampling_done.set()
        monitor.join(timeout=1)
    after_cpu = process_cpu()
    top_cpu = sorted(((name, round(seconds - before_cpu[pid][1], 3))
                      for pid, (name, seconds) in after_cpu.items() if pid in before_cpu
                      and seconds > before_cpu[pid][1]), key=lambda row: row[1], reverse=True)[:12]
    host_load = {"scope": "whole visible process including warmup and diagnostics",
                 "cpu_sample_count": len(host_samples),
                 "system_cpu_median_percent": round(statistics.median(host_samples), 2) if host_samples else None,
                 "system_cpu_max_percent": round(max(host_samples), 2) if host_samples else None,
                 "top_process_cpu_seconds": top_cpu}
    (area / "system-load.json").write_text(json.dumps(host_load, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    result = json.loads((project / ".runtime/clean-sample-acceptance.json").read_text(encoding="utf8"))
    result["host_load"] = host_load
    result["evidence"] = {"ref":ref,"owner":"balance integration thread",
                          "engine_sha256":sha(ENGINE),"dll_sha256":sha(DLL),
                          "game_data_sha256":sha(project / "data/game_data.json"),
                          "visual_data_sha256":sha(project / "data/ship_weapon_visuals.json"),
                          "harness_sha256":sha(SCRIPT),"area":str(area)}
    out = WORK / f"{LABEL}-{label}-full-frame.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(label, "evidence", out, "steps", result["sample_steps"],
          "focused", result["sample_focus_start"], result["sample_focus_end"],
          "logic_hz", round(result["logic_hz"], 2), flush=True)
    return result

if __name__ == "__main__":
    WORK.mkdir(exist_ok=True)
    if BRACKET and not (MIXED and UNCAPPED):
        raise ValueError("bracket requires the same uncapped mixed fixture")
    before = run("before1" if BRACKET else "before", REFS[0][1])
    after = run(*REFS[1])
    before2 = run("before2", REFS[0][1]) if BRACKET else None
    for row in (before, after, before2) if BRACKET else (before, after):
        assert row["runtime_config_start"]["stat_cache_enabled"] is True
        assert row["runtime_config_start"]["save_enabled"] is False
        assert row["native_active"] is True and row["handoffs"] == 0
        assert row["actual_1x_pass"]
        assert row["engine_max_fps"] == (0 if UNCAPPED else 60) and row["vsync_mode"] == 0
        if not BRACKET:assert row["sample_steps"] == 240
    if MIXED:
        expected={"swarm":5,"anchor":5,"shielded":5}
        for row in (before,after,before2) if BRACKET else (before,after):
            subjects=row["visual_subjects"]
            assert len(subjects)==15
            assert {name:sum(item["archetype_id"]==name for item in subjects) for name in expected}==expected
            assert len({item["texture"] for item in subjects})==3
        assert {item["ship_key"] for item in after["visual_subjects"]}=={"enemy_opening_triangle_energy","enemy_opening_slab_energy","enemy_opening_u_energy"}
    if BRACKET:
        frame_first = statistics.median(before["frames_us_raw"])
        frame_last = statistics.median(before2["frames_us_raw"])
        main_first = sum(before["main_us_raw"]) / before["sample_steps"]
        main_last = sum(before2["main_us_raw"]) / before2["sample_steps"]
        stable = (abs(frame_first / frame_last - 1) <= 0.05
                  and abs(main_first / main_last - 1) <= 0.05)
        same_events = all((row["sample_steps"], row["fires"], row["hits"]) ==
                          (before2["sample_steps"], before2["fires"], before2["hits"])
                          for row in (before, after, before2))
        focused = all(row["sample_focus_start"] and row["sample_focus_end"]
                      and not row["background_unfocused"] for row in (before, after, before2))
        if not (stable and same_events and focused):
            print("BRACKET_INVALID stable", stable, "same_events", same_events,
                  "focused", focused, "raw evidence preserved", flush=True)
            raise SystemExit(2)
    print("BALANCE_ART_FULL_FRAME_PAIR complete", flush=True)
