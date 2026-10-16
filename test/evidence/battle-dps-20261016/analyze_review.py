"""Summarize accepted full-frame traces and locate DPS refresh peaks."""
from bisect import bisect_left
import json
import statistics

from analyze_five import CASES, MODES, HERE, metrics, read


def frame_at_clock(row, clock):
    return min(range(len(row["frame_trace"])), key=lambda i: abs(row["frame_trace"][i]["clock"] - clock))


def main():
    result = {}
    for case in CASES:
        rows = [read(case, i, mode, "review-") for i, mode in enumerate(MODES, 1)]
        assert all(r["native_admitted"] and r["handoffs"] == 0 and r["performance_sample_valid"] and r["actual_1x_pass"] for r in rows)
        assert all(r["sample_steps"] == 480 and r["warm_steps"] == 240 and r["enemies_alive"] == 15 for r in rows)
        assert all(r["events"] == rows[0]["events"] and r["fires"] == rows[0]["fires"] and r["hits"] == rows[0]["hits"] for r in rows)
        stable_keys = set(rows[0]["state_after"]) - {"canonical_kernel", "kernel_hash"}
        assert all(all(r["state_after"][key] == rows[0]["state_after"][key] for key in stable_keys) for r in rows)
        base_kernel = rows[0]["state_after"]["canonical_kernel"]
        assert all(all(value == base_kernel[key] for key, value in r["state_after"]["canonical_kernel"].items() if key != "rng") and
                   r["state_after"]["canonical_kernel"]["rng"]["state"] == base_kernel["rng"]["state"] for r in rows)
        assert rows[2]["dps_snapshot"]["damage"] > 0
        stats = [metrics(r) for r in rows]
        on = rows[2]
        ends = [phase["post_draw_us"] for phase in on["phases"]]
        matched = {"purchase": [], "other": []}
        purchase_clocks = [p["clock"] for p in on["purchase_trace"]]
        for mark in on["dps_refresh_marks_us"]:
            index = bisect_left(ends, mark)
            assert index < len(ends) and on["phases"][index]["previous_post_us"] <= mark
            clock = on["frame_trace"][index]["clock"]
            kind = "purchase" if any(abs(clock - p) < 1.0 / 120.0 for p in purchase_clocks) else "other"
            times = [r["frames_us_raw"][frame_at_clock(r, clock)] / 1000 for r in rows]
            matched[kind].append({"clock": round(clock, 3), "full_ms": [round(value, 3) for value in times],
                                  "enabled_minus_controls_ms": round(times[2] - statistics.mean((times[0], times[1], times[3])), 3)})
        result[case] = {"full_mean_ms": [round(s["full_mean_ms"], 3) for s in stats],
                        "full_p95_ms": [round(s["full_p95_ms"], 3) for s in stats],
                        "main_mean_ms": [round(s["main_mean_ms"], 3) for s in stats],
                        "refresh_full_mean_ms": round(stats[2]["refresh_full_mean_ms"], 3),
                        "refresh_full_max_ms": round(stats[2]["refresh_full_max_ms"], 3),
                        "baseline_drift_percent": round(100 * abs(stats[3]["full_mean_ms"] - stats[0]["full_mean_ms"]) /
                                                        statistics.mean((stats[0]["full_mean_ms"], stats[3]["full_mean_ms"])), 2),
                        "refresh_matches": matched, "event_counts": rows[0]["events"],
                        "enabled_actual_damage": on["dps_snapshot"]["damage"]}
    (HERE / "analysis-review.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    for case, row in result.items():
        print(case, row["full_mean_ms"], "drift", row["baseline_drift_percent"],
              "refresh max", row["refresh_full_max_ms"],
              "purchase refreshes", len(row["refresh_matches"]["purchase"]), flush=True)


if __name__ == "__main__":
    main()
