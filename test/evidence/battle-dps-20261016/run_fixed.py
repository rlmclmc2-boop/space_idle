"""Paired five-suite comparison with the approved pulse speed and measurable HP."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

from run_five import (BASE, CASES, CANDIDATE, DLL, ENGINE, EVIDENCE, MAIN, ORDER,
                      ROOT, WORK, asset_manifest, run_one, sha)
from run_positive import positive_driver


def main(pilot):
    assert ROOT.exists() and WORK.exists() and DLL.is_file() and ENGINE.is_file()
    projects = {mode: WORK / mode / "space-battleship" for mode in ("main", "candidate")}
    assert all((project / "project.godot").is_file() for project in projects.values())
    fixed_data = ROOT / "space-battleship/data/game_data.json"
    game_data = json.loads(fixed_data.read_text(encoding="utf-8"))
    pulse = game_data["equipment"]["laser"][0]
    assert pulse["para1"] == 30 and pulse["dmg"] == 350 and pulse["cd"] == 1.5
    patched = positive_driver()
    driver_hash = hashlib.sha256(patched.encode("utf-8")).hexdigest()
    receipt_file = EVIDENCE / "receipt-fixed.json"
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE,
                          "main_pulse_repair": "c2dbeba7", "candidate_pulse_repair": "c2dbeba7"},
               "case_order": list(CASES), "run_order": list(ORDER),
               "baseline_driver_sha256": sha(BASE / "driver.gd"),
               "fixed_driver_sha256": driver_hash, "game_data_sha256": sha(fixed_data),
               "new_dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE),
               "pulse": {"para1": 30, "dmg": 350, "cd": 1.5},
               "health_override": {"from": "1e100", "to": "1e30"}, "runs": []}
    if receipt_file.exists():
        previous = json.loads(receipt_file.read_text(encoding="utf-8"))
        assert all(previous[key] == receipt[key] for key in receipt if key != "runs")
        receipt = previous
    for project in projects.values():
        target = project / "data/game_data.json"
        if target.read_bytes() != fixed_data.read_bytes():
            shutil.copyfile(fixed_data, target)
        driver_path = project / "port_perf.gd"
        if driver_path.read_text(encoding="utf-8") != patched:
            driver_path.write_text(patched, encoding="utf-8")
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    completed = {(run["case"], run["position"], run["mode"]) for run in receipt["runs"]}
    for case in CASES:
        for index, mode in enumerate(ORDER, 1):
            if pilot and (case != "mixed" or index > 3):
                continue
            if (case, index, mode) in completed:
                continue
            project = projects["main"] if mode == "main" else projects["candidate"]
            run_one(case, index, mode, project, receipt, prefix="fixed-", receipt_name="receipt-fixed.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pilot", action="store_true")
    args = parser.parse_args()
    main(args.pilot)
