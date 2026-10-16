"""Reuse the two imported five-suite projects with representable enemy health."""
from pathlib import Path
import argparse
import hashlib
import json

from run_five import (BASE, CASES, CANDIDATE, DLL, ENGINE, EVIDENCE, MAIN, ORDER,
                      ROOT, WORK, asset_manifest, driver_source, run_one, sha)


def positive_driver():
    original = driver_source()
    old = "e.hp=1e100;e.max_hp=1e100"
    new = "e.hp=1e30;e.max_hp=1e30"
    assert original.count(old) == 1
    updated = original.replace(old, new)
    updated = updated.replace(" row.dps_mode=OS.get_environment(\"DPS_MODE\")",
                              " row.dps_mode=OS.get_environment(\"DPS_MODE\")\n if row.dps_mode==\"on\":row.dps_snapshot=g.damage_stats.snapshot()", 1)
    focus = " var sampling_focus=root.has_focus()"
    assert updated.count(focus) == 1
    updated = updated.replace(focus, " for focus_attempt in 12:\n  DisplayServer.window_move_to_foreground()\n  await process_frame\n  if root.has_focus():break\n var sampling_focus=root.has_focus()", 1)
    assert updated.count(new) == 1
    return updated


def main(pilot):
    assert ROOT.exists() and WORK.exists() and DLL.is_file() and ENGINE.is_file()
    main_project = WORK / "main/space-battleship"
    candidate_project = WORK / "candidate/space-battleship"
    assert main_project.is_dir() and candidate_project.is_dir()
    assert asset_manifest(main_project) == asset_manifest(candidate_project)
    patched = positive_driver()
    driver_hash = hashlib.sha256(patched.encode("utf-8")).hexdigest()
    receipt_file = EVIDENCE / "receipt-positive.json"
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE}, "case_order": list(CASES),
               "run_order": list(ORDER), "baseline_driver_sha256": sha(BASE / "driver.gd"),
               "positive_driver_sha256": driver_hash, "new_dll_sha256": sha(DLL),
               "engine_sha256": sha(ENGINE), "health_override": {"from": "1e100", "to": "1e30"}, "runs": []}
    if receipt_file.exists():
        previous = json.loads(receipt_file.read_text(encoding="utf-8"))
        assert all(previous[key] == receipt[key] for key in receipt if key != "runs")
        receipt = previous
    for project in (main_project, candidate_project):
        path = project / "port_perf.gd"
        if path.read_text(encoding="utf-8") != patched:
            path.write_text(patched, encoding="utf-8")
    completed = {(run["case"], run["position"], run["mode"]) for run in receipt["runs"]}
    for case in CASES:
        for index, mode in enumerate(ORDER, 1):
            if pilot and (case != "mixed" or index > 3):
                continue
            if (case, index, mode) in completed:
                continue
            project = main_project if mode == "main" else candidate_project
            run_one(case, index, mode, project, receipt, prefix="positive-", receipt_name="receipt-positive.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pilot", action="store_true")
    args = parser.parse_args()
    main(args.pilot)
