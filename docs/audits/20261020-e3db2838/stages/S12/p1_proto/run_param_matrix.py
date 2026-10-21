"""Fixed audit-only actual-equipment input matrix with isolated Godot runs."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
MATERIAL = 9007199254740991
CASES = [
    ("armour20_exact256", "armour", 20, MATERIAL, "exact_256", "", ""),
    ("shield257_fallback", "shield", 257, MATERIAL, "approx_256", "", ""),
    ("laser1_medium", "laser", 1, MATERIAL, "compact_medium", "", ""),
    ("missile100_medium", "missile", 100, MATERIAL, "compact_medium", "", ""),
    ("cannon1000_medium", "cannon", 1000, MATERIAL, "compact_medium", "", ""),
    ("longLaser10000_medium", "longLaser", 10000, MATERIAL, "compact_medium", "", ""),
    ("laser19_material9", "laser", 19, 9, "compact_medium", "", ""),
    ("laser19_material10", "laser", 19, 10, "compact_medium", "", ""),
    ("armour20_config_stale", "armour", 20, MATERIAL, "compact_medium", "", "config"),
    ("laser1_zero_unsupported", "laser", 1, MATERIAL, "compact_medium", "zero", ""),
    ("laser1_low_unsupported", "laser", 1, MATERIAL, "compact_medium", "low", ""),
    ("laser1_no_multiplier_unsupported", "laser", 1, MATERIAL, "compact_medium", "no_multiplier", ""),
    ("laser1_second_resource_unsupported", "laser", 1, MATERIAL, "compact_medium", "second_resource", ""),
    ("laser1_other_growth_unsupported", "laser", 1, MATERIAL, "compact_medium", "other_growth", ""),
]


def main() -> None:
    results = []
    for name, equipment, level, material, wallet, alteration, mutation in CASES:
        stem = f"exploratory_param_{name}_freeze"
        env = os.environ.copy()
        env.update({
            "S12_EQUIPMENT": equipment,
            "S12_START_LEVEL": str(level),
            "S12_MATERIAL": str(material),
            "S12_WALLET_MODE": wallet,
            "S12_CONFIG_ALTERATION": alteration,
            "S12_MUTATION": mutation,
        })
        proc = subprocess.run([sys.executable, str(ROOT / "run_probe.py"),
                               "max_approx_parameter_probe.gd", stem],
                              cwd=ROOT, env=env, capture_output=True, text=True)
        output = (ROOT / f"{stem}.stdout.log").read_text(encoding="utf-8")
        record = next(json.loads(line) for line in output.splitlines()
                      if line.startswith("{") and "exploratory_max_approx_query" in line)
        assert proc.returncode == 0 and record["success"], (name, proc.stderr, record)
        results.append({"name": name, "stem": stem, "state": record["state"],
                        "mode": record["mode"], "count": record["count"],
                        "start_level": level, "equipment": equipment})
    print(json.dumps({"kind": "parameterized_main_family_matrix", "results": results}, sort_keys=True))


if __name__ == "__main__":
    main()
