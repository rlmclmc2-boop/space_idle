"""Pair the existing visible 1x/60 Hz native main-scene driver before/after art."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "test/work"
ENGINE = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
DLL = ROOT / "test/native-build/project/bin/space_native.dll"
SCRIPT = ROOT / "test/qa_battle_consistency_real.gd"
PARTS = ("scripts", "shaders", "tools", "data", "assets", "addons", "dev", "project.godot", "main.tscn")
REFS = (("before", "a5fa51bdae92c817caab1071a8b2a4242c0e503b"),
        ("after", "25fa50757ad4317f2d0a5c34154f11ccc26a81d7"))

MIXED = os.environ.get("PERF_MIXED_OPENING") == "1"
LABEL = "balance-art-mixed" if MIXED else "balance-art"

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
    env.update(PERF_NATIVE="1", PERF_SIDE=label, PERF_ART_PAIR="1", PERF_MIXED_OPENING="1" if MIXED else "0")
    engine = str(ENGINE)
    checked([engine, "--headless", "--editor", "--import", "--quit", "--path", str(project)],
            project, env, area / "import.log", 180)
    checked([engine, "--path", str(project), "--audio-driver", "Dummy",
             "--resolution", "1373x883", "--disable-vsync", "--script", "res://" + SCRIPT.name],
            project, env, area / "visible-native.log", 180)
    result = json.loads((project / ".runtime/clean-sample-acceptance.json").read_text(encoding="utf8"))
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
    before = run(*REFS[0])
    after = run(*REFS[1])
    for row in (before, after):
        assert row["runtime_config_start"]["stat_cache_enabled"] is True
        assert row["runtime_config_start"]["save_enabled"] is False
        assert row["native_active"] is True and row["handoffs"] == 0
        assert row["sample_steps"] == 240 and row["actual_1x_pass"]
    if MIXED:
        expected={"swarm":5,"anchor":5,"shielded":5}
        for row in (before,after):
            subjects=row["visual_subjects"]
            assert len(subjects)==15
            assert {name:sum(item["archetype_id"]==name for item in subjects) for name in expected}==expected
            assert len({item["texture"] for item in subjects})==3
        assert {item["ship_key"] for item in after["visual_subjects"]}=={"enemy_opening_triangle_energy","enemy_opening_slab_energy","enemy_opening_u_energy"}
    print("BALANCE_ART_FULL_FRAME_PAIR complete", flush=True)
