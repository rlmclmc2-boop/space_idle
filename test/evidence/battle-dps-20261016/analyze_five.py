"""Summarize accepted full-frame traces without changing the fixed workload."""
from pathlib import Path
from bisect import bisect_left
import argparse
import gzip
import json
import statistics

HERE = Path(__file__).resolve().parent
CASES = ("mixed", "laser", "cannon", "missile", "longLaser")
MODES = ("main", "off", "on", "main")


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))]


def read(case, position, mode, prefix):
    path = HERE / f"{prefix}{case}-{position}-{mode}.json.gz"
    with gzip.open(path, "rt", encoding="utf-8") as source:
        return json.load(source)


def metrics(data):
    frames = [value / 1000 for value in data["frames_us_raw"]]
    process = [(phase["main_end_us"] - phase["main_begin_us"]) / 1000 for phase in data["phases"]]
    ends = [phase["post_draw_us"] for phase in data["phases"]]
    refresh = []
    for mark in data["dps_refresh_marks_us"]:
        index = bisect_left(ends, mark)
        if index < len(frames) and data["phases"][index]["previous_post_us"] <= mark:
            refresh.append(index)
    return {"frames": len(frames), "full_mean_ms": statistics.mean(frames), "full_p95_ms": percentile(frames, .95),
            "full_p99_ms": percentile(frames, .99), "full_max_ms": max(frames),
            "main_mean_ms": statistics.mean(process), "main_p95_ms": percentile(process, .95),
            "refresh_count": len(refresh), "refresh_full_mean_ms": statistics.mean(frames[i] for i in refresh) if refresh else None,
            "refresh_full_max_ms": max((frames[i] for i in refresh), default=None),
            "refresh_main_mean_ms": statistics.mean(process[i] for i in refresh) if refresh else None,
            "refresh_main_max_ms": max((process[i] for i in refresh), default=None)}


def analyze(prefix):
    result = {"prefix": prefix, "cases": {}}
    for case in CASES:
        case_prefix = ("long-final-" if prefix == "final-" and case == "longLaser" else
                       "mixed-repeat-final-" if prefix == "final-" and case == "mixed" else prefix)
        data = [read(case, index, mode, case_prefix) for index, mode in enumerate(MODES, 1)]
        for row in data:
            assert row["native_admitted"] and row["handoffs"] == 0
            assert row["performance_sample_valid"] and row["actual_1x_pass"]
            assert row["sample_steps"] == 480 and row["warm_steps"] == 240
            assert row["runtime_config_start"]["stat_cache_enabled"] and not row["runtime_config_start"]["save_enabled"]
            assert len(row["state_before"]["enemies"]) == 15
            assert len(row["state_before"]["loadout"]["weapons"]) == 8
            assert len(row["state_before"]["loadout"]["defence"]) == 4
            if prefix == "final-":
                assert row["enemies_alive"] == 15
        if prefix == "final-":
            assert data[2]["dps_snapshot"]["damage"] > 0
        observed = [metrics(row) for row in data]
        events_equal = all(row["events"] == data[0]["events"] for row in data[1:])
        fires_equal = len({row["fires"] for row in data}) == 1
        hits_equal = len({row["hits"] for row in data}) == 1
        first, off, on, last = (row["full_mean_ms"] for row in observed)
        case_result = {"raw_prefix": case_prefix,
                       "modes": {f"{index}-{mode}": row for index, (mode, row) in enumerate(zip(MODES, observed), 1)},
                       "events_equal": events_equal, "fires_equal": fires_equal, "hits_equal": hits_equal,
                       "baseline_drift_percent": 100 * abs(last - first) / ((last + first) / 2),
                       "off_minus_bracket_ms": off - (first + last) / 2,
                       "on_minus_off_ms": on - off,
                       "event_counts": data[0]["events"],
                       "enabled_actual_damage": data[2].get("dps_snapshot", {}).get("damage")}
        result["cases"][case] = case_result
        print(case, "full mean main/off/on/main", *(round(x, 3) for x in (first, off, on, last)),
              "ms; drift", round(case_result["baseline_drift_percent"], 2), "%",
              "events equal", events_equal, "fires", fires_equal, "hits", hits_equal,
              "refresh max", observed[2]["refresh_full_max_ms"], flush=True)
    suffix = "final" if prefix == "final-" else "fixed" if prefix == "fixed-" else "positive" if prefix else "original"
    (HERE / f"analysis-{suffix}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--positive", action="store_true")
    parser.add_argument("--fixed", action="store_true")
    parser.add_argument("--final", action="store_true")
    args = parser.parse_args()
    assert sum((args.positive, args.fixed, args.final)) <= 1
    analyze("final-" if args.final else "fixed-" if args.fixed else "positive-" if args.positive else "")
