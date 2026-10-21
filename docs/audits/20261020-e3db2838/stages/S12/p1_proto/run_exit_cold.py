"""Ten new isolated Godot processes per frozen P1 exit class and cancel control."""
from __future__ import annotations

import json
import hashlib
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
FREEZE = ROOT.parent / "P1_EXIT_COLD_FREEZE_2.json"
OUTPUT_PREFIX = "exploratory_exit_cold_2"


def _canonical_bytes(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def verify_freeze(freeze: dict) -> None:
    assert hashlib.sha256(_canonical_bytes(Path(__file__))).hexdigest() == freeze["runner_sha256"]
    for name, expected in freeze["source_git_byte_sha256"].items():
        path = f"docs/audits/20261020-e3db2838/stages/S12/p1_proto/{name}"
        raw = subprocess.check_output(["git", "show", f"{freeze['source_commit']}:{path}"], cwd=ROOT)
        assert hashlib.sha256(raw).hexdigest() == expected, name
        assert hashlib.sha256(_canonical_bytes(ROOT / name)).hexdigest() == expected, f"working file changed: {name}"


def complete_gates(results: list[dict]) -> bool:
    gate_keys = {"state", "frame_work", "heartbeat", "cancel", "no_failed_write"}
    expected_rows = {(kind, repetition) for kind in ("exact", "middle", "far", "cancel")
                     for repetition in range(1, 11)}
    return len(results) == 40 and {(row.get("class"), row.get("run")) for row in results} == expected_rows and all(
        set(row.get("gates", {})) == gate_keys
        and row.get("state") == ("cancelled" if row.get("class") == "cancel" else "committed")
        and all(value is True for value in row["gates"].values())
        for row in results
    )


def main() -> None:
    freeze = json.loads(FREEZE.read_text(encoding="utf-8"))
    verify_freeze(freeze)
    results = []
    for kind, script in freeze["cases"].items():
        for repetition in range(1, 11):
            stem = f"{OUTPUT_PREFIX}_{kind}_{repetition:02d}"
            proc = subprocess.run([sys.executable, str(ROOT / "run_probe.py"), script, stem],
                                  cwd=ROOT, capture_output=True, text=True)
            meta = json.loads((ROOT / f"{stem}.meta.json").read_text(encoding="utf-8"))
            output = (ROOT / f"{stem}.stdout.log").read_text(encoding="utf-8")
            records = [json.loads(line) for line in output.splitlines()
                       if line.startswith("{") and "exploratory_max_approx_query" in line]
            if proc.returncode or meta["timed_out"] or len(records) != 1:
                results.append({"class": kind, "run": repetition, "state": "execution_failed",
                                "exit_code": proc.returncode, "timed_out": meta["timed_out"]})
                continue
            record = records[0]
            expected = "cancelled" if kind == "cancel" else "committed"
            gates = {
                "state": record["success"] and record["state"] == expected,
                "frame_work": 0 <= record["max_frame_query_work_us"] <= 4000,
                "heartbeat": 0 < record["max_heartbeat_gap_us"] <= 50000,
                "cancel": 0 < record["cancel_stop_latency_us"] <= 100000 if kind == "cancel" else True,
                "no_failed_write": record["live_unchanged_on_failure"] if kind == "cancel" else True,
            }
            results.append({"class": kind, "run": repetition, "state": record["state"],
                            "count": record["count"], "query_total_us": record["total_wall_us"],
                            "frame_work_us": record["max_frame_query_work_us"],
                            "heartbeat_gap_us": record["max_heartbeat_gap_us"],
                            "cancel_stop_us": record["cancel_stop_latency_us"],
                            "commit_us": record["commit_wall_us"], "gates": gates})
    summary = {"kind": "p1_cold_process_exit_matrix", "freeze": freeze,
               "all_gates_passed": complete_gates(results),
               "results": results}
    print(json.dumps(summary, sort_keys=True))
    if not summary["all_gates_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
