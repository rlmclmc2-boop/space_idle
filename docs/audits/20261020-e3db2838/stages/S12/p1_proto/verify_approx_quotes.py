"""Independent integer/Decimal readback for fixed MAX-APPROX-v1 audit runs."""
from __future__ import annotations

from decimal import Context, Decimal, ROUND_CEILING, ROUND_FLOOR, localcontext
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRICE_PATH = ROOT / "generated_wallets/godot_prices_50000_compact.json"
EXPECTED_PRICE_SHA = "6b376b85a21a303481f1e64a88f44ec956777018edab1fbc636c540c40aa5f15"
G = Decimal.from_float(1.0 + 0.2)


def read(stem: str) -> dict:
    return next(json.loads(line) for line in (ROOT / f"{stem}.stdout.log").read_text(encoding="utf-8").splitlines() if line.startswith("{") and "exploratory_max_approx_query" in line)


def integer_wallet(encoded: dict) -> int:
    assert encoded.keys() == {"v", "blocks"} and encoded["v"] == 4
    return sum(int(digit) * 10000 ** int(position) for position, digit in encoded["blocks"])


def decimal_wallet(encoded: dict) -> Decimal:
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999)):
        result = Decimal(0)
        for position, digit in encoded["blocks"]:
            result += Decimal(digit) * Decimal(f"1E{4*int(position)}")
        return result


def material(count: int) -> int:
    k = (1 + count) // 20
    return 10 * (k * (k + 1) // 2)


def original_costs() -> list[int]:
    raw = json.loads(PRICE_PATH.read_text(encoding="utf-8"))
    assert len(raw) == 50000
    assert hashlib.sha256(PRICE_PATH.read_bytes()).hexdigest() == EXPECTED_PRICE_SHA
    return [int(row) if isinstance(row, str) else int(row[0]) * 10 ** int(row[1]) for row in raw]


def main() -> None:
    costs = original_costs()
    results = []
    for stem, wallet in [
        ("exploratory_approx_exact256_freeze", sum(costs[:256])),
        ("exploratory_approx_fallback256_freeze", sum(costs[:257])),
        ("exploratory_approx_medium_freeze", 10 ** 3800),
    ]:
        run = read(stem)
        quote = run["quoted"]
        count = int(quote["count"])
        fee = integer_wallet(quote["resource_debit"])
        lower = integer_wallet(quote["bound_certificate"]["lower"])
        exact = sum(costs[:count])
        assert quote["rule_version"] == "MAX-APPROX-v1"
        assert lower <= exact <= fee <= (28 * lower + 24) // 25
        assert fee <= (28 * exact + 24) // 25 and fee <= wallet
        assert integer_wallet(run["post_wallet"]) == wallet - fee
        assert int(quote["material_debit"]) == material(count)
        assert int(run["post_material"]) == 9007199254740991 - material(count)
        assert int(run["post_level"]) == 1 + count
        if count == 256:
            assert fee == exact
        exact_max = 0
        cumulative = 0
        for cost in costs:
            if cumulative + cost > wallet:
                break
            cumulative += cost
            exact_max += 1
        assert count <= exact_max
        if run["fixture"] == "compact_medium":
            boundary = run["boundary_next"]
            assert boundary["count"] == count + 1
            assert integer_wallet(boundary["resource_upper"]) > wallet
        assert run["post_profile_bytes"] < 16 * 1024 * 1024
        results.append({
            "fixture": run["fixture"], "count": count, "original_exact_max_within_export": exact_max,
            "exact_fee_within_certificate": True, "quoted_equals_actual_debit": True,
            "fee_over_exact_ppm": (fee - exact) * 1_000_000 // exact,
            "material_exact": True,
        })

    huge = read("exploratory_approx_billion_freeze")
    quote = huge["quoted"]
    count = int(quote["count"])
    fee = decimal_wallet(quote["resource_debit"])
    low = decimal_wallet(quote["bound_certificate"]["lower"])
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_FLOOR)):
        raw_lower = Decimal(50) * G ** 257 * ((G ** (count - 256) - 1) / (G - 1))
        original_lower = Decimal("0.95") * raw_lower
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_CEILING)):
        raw_upper = Decimal(50) * G ** 257 * ((G ** (count - 256) - 1) / (G - 1))
        original_upper = Decimal("1.05") * raw_upper
    # The exact 256-price prefix is negligible at this exponent but positive.
    assert low <= original_lower and original_upper <= fee
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999)):
        assert fee * 25 <= low * 28 + 24
    assert int(quote["material_debit"]) == material(count)
    assert int(huge["post_material"]) == 9007199254740991 - material(count)
    assert int(huge["post_level"]) == 1 + count
    assert huge["remaining_matches"] and huge["material_matches"] and huge["level_matches"]
    assert huge["boundary_next"]["count"] == count + 1
    assert int(huge["boundary_next"]["material_due"]) > 9007199254740991
    assert huge["post_profile_bytes"] < 16 * 1024 * 1024
    results.append({"fixture": "compact_billion", "count": count, "material_exact": True, "direct_decimal_tail_enclosed": True, "quoted_equals_actual_debit": True, "resource_fee_decimal_magnitude": fee.adjusted()})
    for stem in ["stale", "wallet_stale", "config_stale", "silent_replace", "tamper", "cancel"]:
        run = read(f"exploratory_approx_{stem}_freeze")
        assert run["success"] and run["live_unchanged_on_failure"]
        assert run["max_heartbeat_gap_us"] < 50_000
        assert run["state"] == ("cancelled" if stem == "cancel" else "stale_rejected")
        if stem == "cancel":
            assert 0 < run["cancel_stop_latency_us"] < 100_000
    print(json.dumps({"kind": "independent_approx_quote_readback", "price_export_sha256": EXPECTED_PRICE_SHA, "results": results}, sort_keys=True))


if __name__ == "__main__":
    main()
