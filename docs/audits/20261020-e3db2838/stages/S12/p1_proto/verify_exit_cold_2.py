"""Independently read all forty raw triplets for the second frozen P1 gate."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    aggregate = json.loads((ROOT / "exploratory_p1_exit_cold_2.json").read_text(encoding="utf-8-sig"))
    freeze = json.loads((ROOT.parent / "P1_EXIT_COLD_FREEZE_2.json").read_text(encoding="utf-8"))
    assert aggregate["freeze"] == freeze
    rows = aggregate["results"]
    expected = {(kind, run) for kind in ("exact", "middle", "far", "cancel") for run in range(1, 11)}
    assert len(rows) == 40 and {(row["class"], row["run"]) for row in rows} == expected
    gate_keys = {"state", "frame_work", "heartbeat", "cancel", "no_failed_write"}
    maxima: dict[str, int] = {}
    phase_maxima: dict[str, int] = {}
    failures = []
    for row in rows:
        kind, run = row["class"], row["run"]
        stem = f"exploratory_exit_cold_2_{kind}_{run:02d}"
        meta = json.loads((ROOT / f"{stem}.meta.json").read_text(encoding="utf-8"))
        stdout = (ROOT / f"{stem}.stdout.log").read_bytes()
        stderr = (ROOT / f"{stem}.stderr.log").read_bytes()
        assert meta["exit_code"] == 0 and not meta["timed_out"], stem
        assert meta["stdout_sha256"] == hashlib.sha256(stdout).hexdigest(), stem
        assert meta["stderr_sha256"] == hashlib.sha256(stderr).hexdigest(), stem
        assert meta["godot_sha256"] == freeze["godot_sha256"], stem
        records = [json.loads(line) for line in stdout.decode("utf-8").splitlines()
                   if line.startswith("{") and "exploratory_max_approx_query" in line]
        assert len(records) == 1, stem
        record = records[0]
        expected_state = "cancelled" if kind == "cancel" else "committed"
        assert record["state"] == expected_state and record["success"] is True, stem
        assert set(row["gates"]) == gate_keys, stem
        for key, source in (("count", "count"), ("frame_work_us", "max_frame_query_work_us"),
                            ("heartbeat_gap_us", "max_heartbeat_gap_us"),
                            ("commit_us", "commit_wall_us"),
                            ("cancel_stop_us", "cancel_stop_latency_us")):
            assert row[key] == record[source], (stem, key)
        assert row["gates"]["state"] is True
        assert row["gates"]["frame_work"] == (0 <= row["frame_work_us"] <= 4000)
        assert row["gates"]["heartbeat"] == (0 < row["heartbeat_gap_us"] <= 50000)
        assert row["gates"]["cancel"] == (0 < row["cancel_stop_us"] <= 100000 if kind == "cancel" else True)
        assert row["gates"]["no_failed_write"] == (record["live_unchanged_on_failure"] if kind == "cancel" else True)
        if kind == "cancel":
            assert record["live_unchanged_on_failure"] is True
        else:
            assert record["remaining_matches"] and record["material_matches"] and record["level_matches"]
        for gate, passed in row["gates"].items():
            if passed is not True:
                failures.append({"class": kind, "run": run, "gate": gate})
        for key in ("frame_work_us", "heartbeat_gap_us", "cancel_stop_us", "commit_us"):
            maxima[key] = max(maxima.get(key, 0), row[key])
        for phase, value in record["phase_max_us"].items():
            phase_maxima[phase] = max(phase_maxima.get(phase, 0), value)
    assert aggregate["all_gates_passed"] == (not failures)
    print(json.dumps({"kind": "independent_p1_exit_cold_2", "processes": 40,
                      "failures": failures, "maxima_us": maxima, "phase_maxima_us": phase_maxima,
                      "verdict": "PASS" if not failures else "FAIL"}, sort_keys=True))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
