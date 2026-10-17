"""Package raw five-case evidence and derive measured three-state comparisons."""
from pathlib import Path
import gzip
import hashlib
import json
import math
import shutil
import statistics

base = Path(__file__).resolve().parent
repo = base.parents[2]
results = base / "results"
out = repo / "test/evidence/ai-tech-tree-20261017/performance-final-art"
out.mkdir(parents=True, exist_ok=True)
cases = ["mixed", "laser", "cannon", "missile", "longLaser"]
sequence = [("absent", "A"), ("closed", "B"), ("open", "C"), ("closed", "D"), ("absent", "E")]
manifest = {}
table = []

def track(path):
    blob = path.read_bytes()
    manifest[path.name] = {"sha256": hashlib.sha256(blob).hexdigest(), "bytes": len(blob)}

def copy(source, target):
    shutil.copy2(source, target)
    track(target)

def pack(source, target):
    with source.open("rb") as original, gzip.open(target, "wb", compresslevel=9) as compressed:
        shutil.copyfileobj(original, compressed)
    track(target)

def p95(values):
    return sorted(values)[math.ceil(0.95 * len(values)) - 1] / 1000

def metrics(data, load):
    frames = data["frames_us_raw"]
    main = [phase["main_end_us"] - phase["main_begin_us"] for phase in data["phases"]]
    cpu = [sample["system_cpu_busy_percent"] for sample in load if sample.get("system_cpu_busy_percent") is not None]
    assert all(value >= 0 for value in main)
    return {
        "frames": len(frames),
        "frame_mean_ms": statistics.mean(frames) / 1000,
        "frame_p95_ms": p95(frames),
        "main_process_mean_ms": statistics.mean(main) / 1000,
        "main_process_p95_ms": p95(main),
        "system_cpu_busy_percent": statistics.mean(cpu),
        "logic_hz": data["logic_hz"],
        "game_wall_ratio": data["game_wall_ratio"],
    }

def average(a, b, key):
    return (a[key] + b[key]) / 2

for case in cases:
    rows = []
    data_rows = []
    for state, part in sequence:
        name = f"{case}-{state}-{part}"
        source_json = results / (name + ".json")
        source_load = results / (name + "-system-load.json")
        data = json.loads(source_json.read_text(encoding="utf-8"))
        load = json.loads(source_load.read_text(encoding="utf-8"))
        log = (results / (name + ".log")).read_text(encoding="utf-8", errors="replace")
        assert data["performance_sample_valid"] and data["actual_1x_pass"] and data["native_admitted"]
        assert data["warm_steps"] == 240 and data["sample_steps"] == 480 and data["enemies_alive"] == 15
        assert data["rendering_method"] == "gl_compatibility" and data["video_adapter"] == "NVIDIA GeForce RTX 2060"
        assert data["sampling_config"]["window"] == "(1373, 883)"
        assert data["sampling_config"]["stat_cache_enabled"] and not data["sampling_config"]["save_enabled"]
        assert data["sampling_config"]["engine_max_fps"] == 0 and data["sampling_config"]["vsync"] == 0
        assert "PORT_PERF_DONE" in log and "SCRIPT ERROR" not in log
        assert len(data["frames_us_raw"]) == len(data["phases"]) == len(data["frame_trace"])
        assert all(phase["post_draw_us"] - phase["previous_post_us"] == frame for phase, frame in zip(data["phases"], data["frames_us_raw"]))
        rows.append({"state": state, "part": part, **metrics(data, load)})
        data_rows.append(data)
        pack(source_json, out / (name + ".json.gz"))
        pack(source_load, out / (name + "-system-load.json.gz"))
        copy(results / (name + ".log"), out / (name + ".log"))
        if state == "open" or case == "mixed" and part in ("A", "B"):
            copy(results / (name + ".png"), out / (name + ".png"))
    assert all(data["events"] == data_rows[0]["events"] for data in data_rows), case
    assert all(data["stress"]["counts"] == data_rows[0]["stress"]["counts"] for data in data_rows), case
    absent_a, closed_b, opened, closed_d, absent_e = rows
    absent_mean = average(absent_a, absent_e, "frame_mean_ms")
    closed_mean = average(closed_b, closed_d, "frame_mean_ms")
    table.append({
        "case": case,
        "runs": rows,
        "absent_frame_mean_reference_ms": absent_mean,
        "closed_frame_mean_reference_ms": closed_mean,
        "closed_vs_absent_ms": closed_mean - absent_mean,
        "closed_vs_absent_percent": 100 * (closed_mean / absent_mean - 1),
        "open_vs_closed_ms": opened["frame_mean_ms"] - closed_mean,
        "open_vs_closed_percent": 100 * (opened["frame_mean_ms"] / closed_mean - 1),
        "absent_control_span_ms": abs(absent_a["frame_mean_ms"] - absent_e["frame_mean_ms"]),
        "closed_control_span_ms": abs(closed_b["frame_mean_ms"] - closed_d["frame_mean_ms"]),
        "events_equal": True,
        "stress_counts_equal": True,
    })

for name in ("suite.py", "run.py", "prepare.py", "report.py", "combat_stress_fixture.gd", "mixed_fixture.gd"):
    copy(base / name, out / name)
copy(base / "absent/space-battleship/port_perf.gd", out / "perf_driver.gd")
copy(base / "suite.log", out / "suite.log")

report = {
    "baseline_commit": "52a87c0e8db7e0fd5a9e4c01882a60515411bdca",
    "integrated_commit": "cc76d643e0d0ce6b080ac4a1752318d3c4d92245",
    "art_source_commit": "95adc077b1dd9baf2fdd4fbde1eda7f719c6fbb7",
    "states": {"absent": "baseline without AI technology tree", "closed": "integrated tree active, equipment tab displayed", "open": "integrated tree active, technology tab and final art displayed"},
    "metric_note": "main_process_* is timed main/battlefield _process wall time, including game tick and UI work; not pure BattleGame.tick CPU time",
    "godot_executable_sha256": hashlib.sha256(Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe").read_bytes()).hexdigest(),
    "native_module_sha256": hashlib.sha256((base / "absent/space-battleship/bin/space_native.dll").read_bytes()).hexdigest(),
    "cases": table,
}
report_path = out / "summary.json"
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
track(report_path)
lines = [
    "# AI tech tree final art: five high load cases",
    "",
    "Absent = baseline without the tree; Closed = integrated tree with equipment tab visible; Open = integrated tree with technology tab and final static art visible. Every case ran in A-B-C-D-E order (Absent, Closed, Open, Closed, Absent). The art was enabled in both integrated states.",
    "",
    "Godot 4.7.2, RTX 2060, OpenGL Compatibility, 1373x883, 1x/60 Hz, FPS cap 0, VSync off, cache on, save off. Each run used 240 warmup and 480 sampled logic steps with 15 live enemies. All 25 runs passed native admission, sample validity, 1x rate, frame phase closure, and identical combat event/stress counts within each case.",
    "",
    "Times below are milliseconds. Main process is wall time for `main/battlefield._process`, including game tick and UI; it is not isolated `BattleGame.tick` CPU time. Bracketed states are averaged. Their repeat span estimates run drift. Open differs in visible page, so its lower frame times cannot be attributed to a faster technology system.",
    "",
    "| Case | Absent frame mean/P95 | Closed frame mean/P95 | Open frame mean/P95 | Closed - absent | Open - closed | Repeat span absent/closed | Main process mean absent/closed/open |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
]
for case in table:
    a, b, c, d, e = case["runs"]
    absent_p95 = average(a, e, "frame_p95_ms")
    closed_p95 = average(b, d, "frame_p95_ms")
    absent_main = average(a, e, "main_process_mean_ms")
    closed_main = average(b, d, "main_process_mean_ms")
    lines.append(f"| {case['case']} | {case['absent_frame_mean_reference_ms']:.3f}/{absent_p95:.3f} | {case['closed_frame_mean_reference_ms']:.3f}/{closed_p95:.3f} | {c['frame_mean_ms']:.3f}/{c['frame_p95_ms']:.3f} | {case['closed_vs_absent_ms']:+.3f} ({case['closed_vs_absent_percent']:+.1f}%) | {case['open_vs_closed_ms']:+.3f} ({case['open_vs_closed_percent']:+.1f}%) | {case['absent_control_span_ms']:.3f}/{case['closed_control_span_ms']:.3f} | {absent_main:.3f}/{closed_main:.3f}/{c['main_process_mean_ms']:.3f} |")
lines.extend(["", "Raw 25 JSON traces and system load samples are stored as `.json.gz`; original logs, five open state PNGs, and mixed absent/closed PNGs are alongside them. See `summary.json` for every run and executable hashes. Run `report.py` from the original `test/work/ai-tech-perf-20261017` workspace to regenerate the package.", ""])
summary = out / "SUMMARY.md"
summary.write_text("\n".join(lines), encoding="utf-8")
track(summary)
(out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(summary.read_text(encoding="utf-8"))
print("PACKAGED", len(manifest), "files", round(sum(row["bytes"] for row in manifest.values()) / 1048576, 2), "MiB")
