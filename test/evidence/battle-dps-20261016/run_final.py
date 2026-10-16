"""Final paired five-suite run: approved visuals and nonlethal measurable shield."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

from run_five import (BASE, CASES, CANDIDATE, DLL, ENGINE, EVIDENCE, MAIN, ORDER,
                      ROOT, WORK, asset_manifest, run_one, sha)
from run_positive import positive_driver


def final_driver():
    source = positive_driver()
    old = "e.hp=1e30;e.max_hp=1e30"
    assert source.count(old) == 1
    return source.replace(old, "e.hp=1e100;e.max_hp=1e100;e.shield=1e33;e.max_shield=1e33;e.shieldRecovery=0")


def main(pilot):
    assert ROOT.exists() and WORK.exists() and DLL.is_file() and ENGINE.is_file()
    projects = {mode: WORK / mode / "space-battleship" for mode in ("main", "candidate")}
    assert all((project / "project.godot").is_file() for project in projects.values())
    fixed_data = ROOT / "space-battleship/data/game_data.json"
    pulse = json.loads(fixed_data.read_text(encoding="utf-8"))["equipment"]["laser"][0]
    assert pulse["para1"] == 30 and pulse["dmg"] == 350 and pulse["cd"] == 1.5
    driver = final_driver()
    driver_hash = hashlib.sha256(driver.encode("utf-8")).hexdigest()
    receipt_file = EVIDENCE / "receipt-final.json"
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE,
                          "main_pulse_repair": "c2dbeba7", "candidate_pulse_repair": "c2dbeba7",
                          "chain_visual_repair": "3c5bc2a989366213627e0a52dedbb7ec4c24e487"},
               "case_order": list(CASES), "run_order": list(ORDER),
               "baseline_driver_sha256": sha(BASE / "driver.gd"),
               "final_driver_sha256": driver_hash, "game_data_sha256": sha(fixed_data),
               "new_dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE),
               "chain_visual_script_patch_sha256": sha(EVIDENCE / "control-chain-visual.patch"),
               "pulse": {"para1": 30, "dmg": 350, "cd": 1.5},
               "shield_override": {"shield": "1e33", "max_shield": "1e33", "shieldRecovery": 0},
               "enemy_hp": "1e100", "runs": []}
    if receipt_file.exists():
        previous = json.loads(receipt_file.read_text(encoding="utf-8"))
        assert all(previous[key] == receipt[key] for key in receipt if key != "runs")
        receipt = previous
    for project in projects.values():
        target = project / "data/game_data.json"
        if target.read_bytes() != fixed_data.read_bytes():
            shutil.copyfile(fixed_data, target)
        path = project / "port_perf.gd"
        if path.read_text(encoding="utf-8") != driver:
            path.write_text(driver, encoding="utf-8")
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    completed = {(run["case"], run["position"], run["mode"]) for run in receipt["runs"]}
    for case in CASES:
        for index, mode in enumerate(ORDER, 1):
            if pilot and (case != "missile" or index > 3):
                continue
            if (case, index, mode) in completed:
                continue
            project = projects["main"] if mode == "main" else projects["candidate"]
            run_one(case, index, mode, project, receipt, prefix="final-", receipt_name="receipt-final.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pilot", action="store_true")
    args = parser.parse_args()
    main(args.pilot)
