"""Final serial graphical comparison, reusing the already imported two projects."""
from pathlib import Path
import gzip
import hashlib
import json
import os
import subprocess

from run_five import CASES, DLL, ENGINE, EVIDENCE, MAIN, ORDER, ROOT, WORK, asset_manifest, private_env, run_one, sha
from run_final import final_driver

CANDIDATE = "ae6f5d15"
PREFIX = "review-"


def main():
    projects = {mode: WORK / mode / "space-battleship" for mode in ("main", "candidate")}
    assert all((project / "project.godot").is_file() for project in projects.values())
    assert DLL.is_file() and ENGINE.is_file()
    path = Path("space-battleship/scripts/battle_slice_runtime.gd")
    gitdir = Path(os.environ.get("DPS_GIT_DIR", str(ROOT.parent / "battle-dps-publish-20261016.git")))
    if not gitdir.exists():
        gitdir = ROOT / ".git"
    before = subprocess.run(["git", f"--git-dir={gitdir}", "show", f"7882538b:{path.as_posix()}"], cwd=ROOT,
                            capture_output=True, check=True).stdout
    current = subprocess.run(["git", f"--git-dir={gitdir}", "show", f"{CANDIDATE}:{path.as_posix()}"], cwd=ROOT,
                             capture_output=True, check=True).stdout
    target = projects["candidate"] / "scripts/battle_slice_runtime.gd"
    assert target.read_bytes().replace(b"\r\n", b"\n") in (before, current)
    assert (ROOT / path).read_bytes().replace(b"\r\n", b"\n") == current
    target.write_bytes(current)
    with (WORK / "candidate" / "review-import.log").open("w", encoding="utf-8") as output:
        result = subprocess.run([str(ENGINE), "--path", str(projects["candidate"]), "--headless", "--editor", "--import", "--quit"],
                                env=private_env("review-import-candidate"), stdout=output, stderr=subprocess.STDOUT, timeout=240)
    log = (WORK / "candidate" / "review-import.log").read_text(encoding="utf-8", errors="replace")
    assert result.returncode == 0 and "SCRIPT ERROR" not in log
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    driver = final_driver()
    fixed_data = ROOT / "space-battleship/data/game_data.json"
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE,
                          "control_visual_patches": {name: sha(EVIDENCE / name) for name in ("control-chain-visual.patch", "control-chain-followup.patch")}},
               "reuse": "Two imported projects from followup; candidate script replaced at exact commit; unchanged DLL/assets/driver.",
               "candidate_script_sha256": sha(target), "case_order": list(CASES), "run_order": list(ORDER),
               "driver_sha256": hashlib.sha256(driver.encode("utf-8")).hexdigest(),
               "game_data_sha256": sha(fixed_data), "dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE), "runs": []}
    for case in CASES:
        case_driver = driver if case != "longLaser" else driver.replace("e.shield=1e33;e.max_shield=1e33", "e.shield=1e25;e.max_shield=1e25")
        for project in projects.values():
            (project / "port_perf.gd").write_text(case_driver, encoding="utf-8")
        for position, mode in enumerate(ORDER, 1):
            project = projects["main"] if mode == "main" else projects["candidate"]
            run_one(case, position, mode, project, receipt, prefix=PREFIX, receipt_name="receipt-review.json")
            with gzip.open(EVIDENCE / f"{PREFIX}{case}-{position}-{mode}.json.gz", "rt", encoding="utf-8") as source:
                row = json.load(source)
            assert row["enemies_alive"] == 15 and row["sample_steps"] == 480 and row["warm_steps"] == 240
            assert row["native_admitted"] and row["handoffs"] == 0 and row["performance_sample_valid"]
    print("REVIEW_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
