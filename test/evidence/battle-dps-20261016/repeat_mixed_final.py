"""Resolve only the unstable final mixed bracket."""
import hashlib
import json

from run_five import (BASE, DLL, ENGINE, EVIDENCE, ORDER, WORK, asset_manifest,
                      run_one, sha)
from run_final import final_driver


def main():
    projects = {mode: WORK / mode / "space-battleship" for mode in ("main", "candidate")}
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    driver = final_driver()
    receipt_file = EVIDENCE / "receipt-mixed-repeat-final.json"
    receipt = {"reason": "final mixed first/last main drift 10.80 percent",
               "source_receipt": "receipt-final.json", "case": "mixed", "run_order": list(ORDER),
               "shield_override": {"shield": "1e33", "max_shield": "1e33", "shieldRecovery": 0},
               "enemy_hp": "1e100", "driver_sha256": hashlib.sha256(driver.encode("utf-8")).hexdigest(),
               "new_dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE),
               "baseline_driver_sha256": sha(BASE / "driver.gd"), "runs": []}
    if receipt_file.exists():
        previous = json.loads(receipt_file.read_text(encoding="utf-8"))
        assert all(previous[key] == receipt[key] for key in receipt if key != "runs")
        receipt = previous
    for project in projects.values():
        path = project / "port_perf.gd"
        if path.read_text(encoding="utf-8") != driver:
            path.write_text(driver, encoding="utf-8")
    completed = {(run["position"], run["mode"]) for run in receipt["runs"]}
    for index, mode in enumerate(ORDER, 1):
        if (index, mode) in completed:
            continue
        project = projects["main"] if mode == "main" else projects["candidate"]
        run_one("mixed", index, mode, project, receipt,
                prefix="mixed-repeat-final-", receipt_name="receipt-mixed-repeat-final.json")


if __name__ == "__main__":
    main()
