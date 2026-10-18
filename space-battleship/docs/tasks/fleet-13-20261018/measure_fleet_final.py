"""Replay the existing five full-picture high-load fixtures on two checkouts.

Usage: python measure_fleet_final.py BASELINE_GAME_DIR CANDIDATE_GAME_DIR
Both game directories need imported assets and the existing native DLL and
GDExtension. This runner copies the retained driver/probes, never builds the DLL.
"""
from pathlib import Path
import gzip
import hashlib
import json
import os
import shutil
import statistics
import subprocess
import sys

before = Path(sys.argv[1]).resolve()
after = Path(sys.argv[2]).resolve()
here = Path(__file__).resolve().parent
fixture_dir = here.parents[1] / "knowledge/tasks/ai-tech-five-weapon-replay-20261017"
output = Path(os.environ.get("FLEET_PERF_OUTPUT",str(here / "evidence/final-acceptance"))).resolve()
output.mkdir(parents=True, exist_ok=True)
engine = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
python = "D:/CodexTools/venv/godot-native/Scripts/python.exe"
cases = tuple(os.environ.get("FLEET_PERF_CASES","mixed,laser,cannon,missile,longLaser").split(","))
assert cases and set(cases)<=set(("mixed","laser","cannon","missile","longLaser"))
summary = {"baseline": "51a7e1b9bc5784927e7d5b232a112194d990a41c", "candidate":"68246c4926a176316f7843c3ae5574a9d98bb86b", "cases": {}, "pass_rule":"all events including equipment_stats, stress counters, full final public/native state; historical RNG seed and derived kernel_hash explicitly excluded from state equality", "run_order":"serial pairs; before/after order alternates by fixture"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(project: Path, case: str, label: str) -> dict:
    assert digest(project / "bin/space_native.dll") == "b89310037fb78690470ffe8d47e37c264b15ff9b1828ba345a6f323d159068da"
    target = output / f"{case}-{label}"
    if Path(str(target)+".json.gz").exists():
        with gzip.open(str(target)+".json.gz","rt",encoding="utf-8") as stream:
            cached=json.load(stream)
        assert cached["native_admitted"] and cached["actual_1x_pass"] and cached["performance_sample_valid"]
        assert cached["warm_steps"]==240 and cached["sample_steps"]==480
        print(f"{case}-{label}: reuse completed valid raw measurement",flush=True)
        return cached
    driver=(fixture_dir/"perf_driver.gd").read_text(encoding="utf-8")
    driver=driver.replace('get_extension("res://space_native.gdextension")','get_extension("res://addons/native_battle/space_native.gdextension")')
    (project/"port_perf.gd").write_text(driver,encoding="utf-8")
    shutil.copy2(here/"perf_probe.gd",project/"probe.gd")
    shutil.copy2(here/"perf_counter_probe.gd",project/"counter_probe.gd")
    fixture = "mixed_fixture.gd" if case == "mixed" else "combat_stress_fixture.gd"
    shutil.copy2(fixture_dir / fixture, project / "combat_stress_fixture.gd")
    runtime = project / ".runtime"
    runtime.mkdir(exist_ok=True)
    for name in ("uncapped-port.json", "uncapped-port.png"):
        (runtime / name).unlink(missing_ok=True)
    env = os.environ.copy()
    user = runtime / "fleet-perf-user"
    for key, suffix in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp")):
        folder = user / suffix
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update(PERF_NATIVE="1", AI_TECH_PERF_STATE="absent", WEAPON_CASE=case,
               MISSILE_CONTROL="legend", SPACE_BATTLESHIP_PYTHON=python)
    command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--max-fps", "0", "--disable-vsync", "--script", "res://port_perf.gd"]
    target = output / f"{case}-{label}"
    with target.with_suffix(".log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    log_text = target.with_suffix(".log").read_text(encoding="utf-8", errors="replace")
    print(f"{case}-{label}: exit={result.returncode} done={'PORT_PERF_DONE' in log_text} errors={log_text.count('SCRIPT ERROR')}", flush=True)
    if result.returncode or "PORT_PERF_DONE" not in log_text or "SCRIPT ERROR" in log_text:
        raise RuntimeError(f"{case}-{label} failed; see {target.with_suffix('.log')}")
    source_json = runtime / "uncapped-port.json"
    source_png = runtime / "uncapped-port.png"
    assert source_json.exists() and source_png.exists()
    row = json.loads(source_json.read_text(encoding="utf-8"))
    assert row["native_admitted"] and row["actual_1x_pass"] and row["performance_sample_valid"]
    assert row["warm_steps"] == 240 and row["sample_steps"] == 480
    assert row["sampling_config"]["stat_cache_enabled"] and not row["sampling_config"]["save_enabled"]
    assert row["sampling_config"]["engine_max_fps"] == 0 and row["sampling_config"]["vsync"] == 0
    assert len(row["frames_us_raw"]) == len(row["phases"]) == len(row["frame_trace"])
    with gzip.open(str(target) + ".json.gz", "wt", encoding="utf-8") as packed:
        json.dump(row, packed, ensure_ascii=False, separators=(",", ":"))
    shutil.copy2(source_png, str(target) + ".png")
    return row


def state_projection(state):
    import copy
    value=copy.deepcopy(state)
    value.pop("kernel_hash",None)
    value["canonical_kernel"]["rng"].pop("seed",None)
    return value


def differing_paths(a,b,path=""):
    if type(a)!=type(b):return [path+" (type)"]
    if isinstance(a,dict):
        return [p for k in sorted(a.keys()|b.keys()) for p in ([path+"/"+k+" (missing)"] if k not in a or k not in b else differing_paths(a[k],b[k],path+"/"+k))]
    if isinstance(a,list):
        return ([path+" (length)"] if len(a)!=len(b) else [p for i,(x,y) in enumerate(zip(a,b)) for p in differing_paths(x,y,path+"/"+str(i))])
    return [] if a==b else [path]


for index,case in enumerate(cases):
    if (index+int(os.environ.get("FLEET_PERF_REVERSE","0")))%2==0:
        a = run(before, case, "before")
        b = run(after, case, "after")
    else:
        b = run(after, case, "after")
        a = run(before, case, "before")
    gameplay_before = {key: value for key, value in a["events"].items() if key != "equipment_stats"}
    gameplay_after = {key: value for key, value in b["events"].items() if key != "equipment_stats"}

    entry = {}
    for label, row in (("before", a), ("after", b)):
        values = sorted(row["frames_us_raw"])
        entry[label] = {"frames": len(values), "mean_ms": statistics.mean(values) / 1000,
                        "p95_ms": values[int((len(values) - 1) * .95)] / 1000,
                        "main_mean_ms": statistics.mean(p["main_end_us"]-p["main_begin_us"] for p in row["phases"]) / 1000,
                        "draw_mean": statistics.mean(row["drawcalls_raw"]),
                        "events": row["events"], "stress_counts": row["stress"]["counts"]}
    for boundary in ("state_before","state_after"):
        differences=differing_paths(state_projection(a[boundary]),state_projection(b[boundary]))
        entry[boundary+"_equal"]=not differences
        entry[boundary+"_differences"]=differences
        entry[boundary+"_historical_rng_seed"]=[a[boundary]["canonical_kernel"]["rng"].get("seed"),b[boundary]["canonical_kernel"]["rng"].get("seed")]
    entry["stress_counts_equal"]=a["stress"]["counts"]==b["stress"]["counts"]
    entry["legendary_counts_equal"]=a["legendary_counts"]==b["legendary_counts"]
    entry["delta_p95_ms"]=entry["after"]["p95_ms"]-entry["before"]["p95_ms"]
    entry["delta_mean_ms"] = entry["after"]["mean_ms"] - entry["before"]["mean_ms"]
    entry["all_events_equal"] = a["events"] == b["events"]
    entry["gameplay_events_equal"] = gameplay_before == gameplay_after
    entry["equipment_stats_delta"] = b["events"].get("equipment_stats", 0) - a["events"].get("equipment_stats", 0)
    entry["correctness_pass"]=all(entry[k] for k in ("all_events_equal","state_before_equal","state_after_equal","stress_counts_equal","legendary_counts_equal"))
    summary["cases"][case] = entry
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"CASE_OK {case} mean_ms {entry['before']['mean_ms']:.3f} -> {entry['after']['mean_ms']:.3f} correctness={entry['correctness_pass']} all_events_equal={entry['all_events_equal']} equipment_stats_delta={entry['equipment_stats_delta']}", flush=True)
summary["all_requested_correctness_pass"]=all(e["correctness_pass"] for e in summary["cases"].values())
summary["all_five_correctness_pass"]=len(cases)==5 and summary["all_requested_correctness_pass"]
summary["first_pair_reversed"]=bool(int(os.environ.get("FLEET_PERF_REVERSE","0")))
(output / "summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
print("FLEET_PERF_DONE cases="+str(len(cases))+" correctness="+str(summary["all_requested_correctness_pass"]), flush=True)
