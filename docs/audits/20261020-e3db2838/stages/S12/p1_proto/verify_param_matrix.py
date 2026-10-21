"""Independent readback of actual-main equipment inputs and parameterized quotes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

from run_param_matrix import CASES, MATERIAL
from verify_approx_quotes import integer_wallet, original_costs

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[5]
CONFIG = json.loads((ROOT / "actual_equipment_main31e793.json").read_text(encoding="utf-8"))


def read(stem: str) -> dict:
    return next(json.loads(line) for line in (ROOT / f"{stem}.stdout.log").read_text(encoding="utf-8").splitlines()
                if line.startswith("{") and "exploratory_max_approx_query" in line)


def material_due(start: int, count: int) -> int:
    lo, hi = start // 20, (start + count) // 20
    return 10 * (hi * (hi + 1) // 2 - lo * (lo + 1) // 2)


def main() -> None:
    commit = CONFIG["source_commit"]
    source = json.loads(subprocess.check_output(["git", "-C", str(REPO), "show", f"{commit}:space-battleship/data/game_data.json"]))
    raw = subprocess.check_output(["git", "-C", str(REPO), "show", f"{commit}:space-battleship/data/game_data.json"])
    evo_raw = subprocess.check_output(["git", "-C", str(REPO), "show", f"{commit}:space-battleship/data/equipment_evolution.json"])
    evolution = json.loads(evo_raw)
    assert hashlib.sha256(raw).hexdigest() == CONFIG["game_data_sha256"]
    assert hashlib.sha256(evo_raw).hexdigest() == CONFIG["evolution_sha256"]
    assert CONFIG["evolution"] == {k: evolution[k] for k in ("interval", "material_id", "material_cost_per_tier")}
    for slot, row in CONFIG["rows"].items():
        assert len(source["equipment"][slot]) == 1
        assert row == {key: source["equipment"][slot][0][key] for key in row}

    costs = original_costs()  # fixed Godot original-price export, targets 2..50001
    results = []
    for name, slot, start, material, mode, alteration, mutation in CASES:
        stem = f"exploratory_param_{name}_freeze"
        run = read(stem)
        meta = json.loads((ROOT / f"{stem}.meta.json").read_text(encoding="utf-8"))
        assert meta["exit_code"] == 0 and not meta["timed_out"] and run["success"]
        assert meta["scenario_inputs"] == {
            "S12_EQUIPMENT": slot, "S12_START_LEVEL": str(start), "S12_MATERIAL": str(material),
            "S12_WALLET_MODE": mode, "S12_CONFIG_ALTERATION": alteration, "S12_MUTATION": mutation,
        }
        assert run["equipment_id"] == slot and run["start_level"] == start
        if name == "laser19_material9":
            assert material_due(start, 1) == 10 > material
            assert run["state"] == "not_affordable" and run["quoted"] == {}
            assert run["post_level"] == start and run["post_material"] == material
            assert run["live_unchanged_on_failure"]
            results.append({"case": name, "state": "not_affordable_no_debit"})
            continue
        if alteration:
            assert run["state"] == "unsupported" and run["count"] == -1
            assert run["quoted"] == {} and run["live_unchanged_on_failure"]
            assert run["post_level"] == start and run["post_material"] == material
            results.append({"case": name, "state": "unsupported_no_debit"})
            continue
        if mutation:
            assert run["state"] == "stale_rejected" and run["live_unchanged_on_failure"]
            assert run["post_level"] == start and run["post_material"] == material
            results.append({"case": name, "state": "stale_no_debit"})
            continue
        quote = run["quoted"]
        count = quote["count"]
        assert quote["equipment_id"] == slot and quote["start_level"] == start
        assert quote["resource_id"] == "1" and run["state"] == "committed"
        assert start - 1 + count <= len(costs)
        exact = sum(costs[start - 1:start - 1 + count])
        wallet = (sum(costs[start - 1:start - 1 + (256 if mode == "exact_256" else 257)])
                  if mode in ("exact_256", "approx_256") else 10 ** 3800)
        lower = integer_wallet(quote["bound_certificate"]["lower"])
        fee = integer_wallet(quote["resource_debit"])
        assert lower <= exact <= fee <= (28 * lower + 24) // 25
        assert fee <= wallet and integer_wallet(run["post_wallet"]) == wallet - fee
        assert quote["material_debit"] == material_due(start, count)
        assert run["post_material"] == material - material_due(start, count)
        assert run["post_level"] == start + count
        if quote["mode"] in ("exact", "approx_fallback_exact_fee"):
            assert fee == exact
        if quote["mode"] == "approx":
            next_count = run["boundary_next"]["count"]
            assert next_count == count + 1
            boundary = run["boundary_next"]
            if boundary["state"] == "ready":
                assert integer_wallet(boundary["resource_upper"]) > wallet
            else:
                assert boundary["state"] == "unaffordable_material"
                assert int(boundary["material_due"]) > material
        results.append({"case": name, "state": quote["mode"], "count": count,
                        "exact_price_enclosed": True, "wallet_and_material_exact": True})
    print(json.dumps({"kind": "independent_parameterized_main_readback",
                      "game_data_sha256": CONFIG["game_data_sha256"],
                      "evolution_sha256": CONFIG["evolution_sha256"], "results": results}, sort_keys=True))


if __name__ == "__main__":
    main()
