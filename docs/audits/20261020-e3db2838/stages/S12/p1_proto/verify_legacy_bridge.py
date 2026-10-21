"""Independent exact wallet readback for the old-value Godot MAX boundary."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from ledger import CurrencyValue
from price import quote

ROOT = Path(__file__).resolve().parent
MATERIAL = 9007199254740991


def old(kind: str):
    return {
        "old_exponent": {"m": 1.0, "e": 1_000_000_000.0},
        "old_exponent_max": {"m": 1.0, "e": 1e308},
        "old_v1_decimal": {"v": 1, "i": "9" * 5000},
        "old_float_half": 0.5,
        "old_int_130": 130,
    }[kind]


def v3_value(encoded) -> CurrencyValue:
    if encoded == 0:
        return CurrencyValue.from_integer(0)
    assert set(encoded) == {"v", "blocks"} and encoded["v"] == 3
    return CurrencyValue.from_terms([(int(x["p"]), int(x["d"])) for x in encoded["blocks"]])


def material(count: int) -> int:
    tier = (1 + count) // 20
    return 10 * tier * (tier + 1) // 2


def main() -> None:
    results = []
    for kind in ("old_exponent", "old_exponent_max", "old_v1_decimal", "old_float_half", "old_int_130"):
        stem = f"exploratory_legacy_{kind}_freeze"
        meta = json.loads((ROOT / f"{stem}.meta.json").read_text(encoding="utf-8"))
        raw = (ROOT / f"{stem}.stdout.log").read_bytes()
        assert meta["exit_code"] == 0 and not meta["timed_out"]
        assert meta["stdout_sha256"] == hashlib.sha256(raw).hexdigest()
        assert meta["scenario_inputs"] == {"S12_LEGACY_KIND": kind}
        run = next(json.loads(line) for line in raw.decode().splitlines()
                   if line.startswith("{") and "exploratory_max_approx_query" in line)
        before = CurrencyValue.decode(old(kind))
        if kind == "old_float_half":
            assert before.compare(CurrencyValue.from_integer(quote(50.0, 0.2, 2))) < 0
            assert run["state"] == "not_affordable" and run["quoted"] == {}
            assert run["live_unchanged_on_failure"] and run["post_level"] == 1
            results.append({"kind": kind, "status": "first_price_unaffordable"})
            continue
        assert run["state"] == "committed" and run["success"]
        fee = CurrencyValue.decode(run["quoted"]["resource_debit"])
        after = v3_value(run["post_wallet"])
        assert before.compare(fee) >= 0
        assert before.subtract(fee).compare(after) == 0
        count = int(run["count"])
        assert run["post_level"] == count + 1
        assert run["quoted"]["material_debit"] == material(count)
        assert run["post_material"] == MATERIAL - material(count)
        results.append({"kind": kind, "status": "exact_old_minus_debit_equals_new",
                        "count": count, "result_blocks": len(after.blocks)})
    print(json.dumps({"kind": "independent_legacy_godot_quote_debit_readback", "results": results}, sort_keys=True))


if __name__ == "__main__":
    main()
