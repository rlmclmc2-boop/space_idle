"""Read every frozen process independently of the aggregate runner verdict."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    aggregate = json.loads((ROOT / "exploratory_p1_exit_cold_1.json").read_text(encoding="utf-8"))
    freeze = json.loads((ROOT.parent / "P1_EXIT_COLD_FREEZE.json").read_text(encoding="utf-8"))
    assert aggregate["freeze"] == freeze and len(aggregate["results"]) == 40
    failures = []
    maxima = {}
    for row in aggregate["results"]:
        kind, repetition = row["class"], row["run"]
        stem = f"exploratory_exit_cold_{kind}_{repetition:02d}"
        meta = json.loads((ROOT / f"{stem}.meta.json").read_text(encoding="utf-8"))
        stdout = (ROOT / f"{stem}.stdout.log").read_bytes()
        stderr = (ROOT / f"{stem}.stderr.log").read_bytes()
        assert meta["exit_code"] == 0 and not meta["timed_out"]
        assert meta["stdout_sha256"] == hashlib.sha256(stdout).hexdigest()
        assert meta["stderr_sha256"] == hashlib.sha256(stderr).hexdigest()
        assert meta["godot_sha256"] == freeze["godot_sha256"]
        record = next(json.loads(line) for line in stdout.decode("utf-8").splitlines()
                      if line.startswith("{") and "exploratory_max_approx_query" in line)
        assert record["state"] == ("cancelled" if kind == "cancel" else "committed")
        for key, source_key in (("count", "count"), ("frame_work_us", "max_frame_query_work_us"),
                                ("heartbeat_gap_us", "max_heartbeat_gap_us"), ("commit_us", "commit_wall_us"),
                                ("cancel_stop_us", "cancel_stop_latency_us")):
            assert row[key] == record[source_key], (stem, key)
        for metric in ("frame_work_us", "heartbeat_gap_us", "cancel_stop_us"):
            maxima[metric] = max(maxima.get(metric, 0), row[metric])
        if row["frame_work_us"] > 4000:
            failures.append({"class": kind, "run": repetition, "frame_work_us": row["frame_work_us"]})
        assert row["heartbeat_gap_us"] <= 50000
        if kind == "cancel":
            assert 0 < row["cancel_stop_us"] <= 100000 and record["live_unchanged_on_failure"]
        else:
            assert record["remaining_matches"] and record["material_matches"] and record["level_matches"]
    assert failures == [{"class": "far", "run": 3, "frame_work_us": 5610},
                        {"class": "far", "run": 8, "frame_work_us": 16700}]
    assert not aggregate["all_gates_passed"]
    print(json.dumps({"kind": "independent_p1_exit_cold_readback", "processes": 40,
                      "failures": failures, "maxima": maxima, "verdict": "FAIL"}, sort_keys=True))


if __name__ == "__main__":
    main()
