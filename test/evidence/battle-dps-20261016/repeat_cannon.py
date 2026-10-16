"""Resolve only the unstable fixed-speed cannon bracket."""
import argparse
import json

from run_five import (DLL, ENGINE, EVIDENCE, ORDER, ROOT, WORK, asset_manifest,
                      run_one, sha)
from run_positive import positive_driver


def main(number):
    projects = {mode: WORK / mode / "space-battleship" for mode in ("main", "candidate")}
    assert all((project / "project.godot").is_file() for project in projects.values())
    assert asset_manifest(projects["main"]) == asset_manifest(projects["candidate"])
    assert all(json.loads((project / "data/game_data.json").read_text(encoding="utf-8"))
               ["equipment"]["laser"][0]["para1"] == 30 for project in projects.values())
    assert all((project / "port_perf.gd").read_text(encoding="utf-8") == positive_driver()
               for project in projects.values())
    prefix = f"repeat{number}-" if number > 1 else "repeat-"
    receipt_name = f"receipt-repeat{number}-cannon.json" if number > 1 else "receipt-repeat-cannon.json"
    receipt = {"reason": "fixed-speed cannon main bracket drift; targeted stability repeat",
               "source_receipt": "receipt-fixed.json",
               "run_order": list(ORDER), "new_dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE), "runs": []}
    for index, mode in enumerate(ORDER, 1):
        project = projects["main"] if mode == "main" else projects["candidate"]
        run_one("cannon", index, mode, project, receipt, prefix=prefix, receipt_name=receipt_name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--number", type=int, default=1)
    args = parser.parse_args()
    assert args.number in (1, 2)
    main(args.number)
