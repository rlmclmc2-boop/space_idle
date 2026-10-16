"""Serial graphical follow-up using the original five fixtures and one reused project per side."""
from pathlib import Path
import gzip
import hashlib
import importlib.util
import json
import shutil
import subprocess

from run_five import BASE, CASES, DLL, ENGINE, EVIDENCE, MAIN, ORDER, ROOT, WORK, asset_manifest, prepare_project, private_env, run_one, sha
from run_final import final_driver

CANDIDATE = "7882538b"
PREFIX = "followup-"


def import_main(project):
    with (WORK / "main" / "followup-import.log").open("w", encoding="utf-8") as output:
        result = subprocess.run([str(ENGINE), "--path", str(project), "--headless", "--editor", "--import", "--quit"],
                                env=private_env("followup-import-main"), stdout=output, stderr=subprocess.STDOUT, timeout=240)
    log = (WORK / "main" / "followup-import.log").read_text(encoding="utf-8", errors="replace")
    assert result.returncode == 0 and "SCRIPT ERROR" not in log


def main():
    assert ROOT.exists() and DLL.is_file() and ENGINE.is_file() and not WORK.exists()
    spec = importlib.util.spec_from_file_location("baseline_counters", BASE / "instrument_counters.py")
    counters = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(counters)
    driver = final_driver()
    projects = {"main": prepare_project("main", MAIN, driver, counters.instrument_counters),
                "candidate": prepare_project("candidate", CANDIDATE, driver, counters.instrument_counters)}
    main_dir = WORK / "main"
    for patch in ("control-chain-visual.patch", "control-chain-followup.patch"):
        subprocess.run(["git", "apply", str(EVIDENCE / patch)], cwd=main_dir, check=True)
    fixed_data = ROOT / "space-battleship/data/game_data.json"
    for project in projects.values():
        shutil.copyfile(fixed_data, project / "data/game_data.json")
    import_main(projects["main"])
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE, "control_visual_patches":
                          {name: sha(EVIDENCE / name) for name in ("control-chain-visual.patch", "control-chain-followup.patch")}},
               "case_order": list(CASES), "run_order": list(ORDER),
               "driver_sha256": hashlib.sha256(driver.encode("utf-8")).hexdigest(),
               "game_data_sha256": sha(fixed_data), "dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE), "runs": []}
    for case in CASES:
        case_driver = driver if case != "longLaser" else driver.replace("e.shield=1e33;e.max_shield=1e33", "e.shield=1e25;e.max_shield=1e25")
        for project in projects.values():
            (project / "port_perf.gd").write_text(case_driver, encoding="utf-8")
        for position, mode in enumerate(ORDER, 1):
            project = projects["main"] if mode == "main" else projects["candidate"]
            run_one(case, position, mode, project, receipt, prefix=PREFIX, receipt_name="receipt-followup.json")
            path = EVIDENCE / f"{PREFIX}{case}-{position}-{mode}.json.gz"
            with gzip.open(path, "rt", encoding="utf-8") as source:
                row = json.load(source)
            assert row["enemies_alive"] == 15 and row["sample_steps"] == 480 and row["warm_steps"] == 240
            assert row["native_admitted"] and row["handoffs"] == 0 and row["performance_sample_valid"]
    print("FOLLOWUP_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
