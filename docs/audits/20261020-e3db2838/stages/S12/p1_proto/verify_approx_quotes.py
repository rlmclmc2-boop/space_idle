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


def sparse_terms(encoded: dict) -> dict[int, int]:
    """Read signed base-10000 coefficients without expanding vacant positions."""
    assert set(encoded) == {"v", "blocks"} and encoded["v"] == 4
    assert isinstance(encoded["blocks"], list)
    terms = {}
    previous = None
    for pair in encoded["blocks"]:
        assert isinstance(pair, list) and len(pair) == 2
        position_text, digit = pair
        assert isinstance(position_text, str) and position_text.lstrip("-").isdigit()
        position = int(position_text)
        assert str(position) == position_text and isinstance(digit, int) and not isinstance(digit, bool)
        assert -5000 <= digit <= 4999 and digit != 0
        assert previous is None or position > previous
        terms[position] = digit
        previous = position
    assert not terms or terms[previous] > 0
    return terms


def integer_terms(value: int) -> dict[int, int]:
    assert value >= 0
    result = {}
    position = 0
    while value:
        value, digit = divmod(value, 10000)
        if digit:
            result[position] = digit
        position += 1
    return result


def sparse_normalize(*operands: tuple[int, dict[int, int]]) -> dict[int, int]:
    """Exact sparse sum; carry only at occupied neighbors."""
    coefficients = {}
    normalized = {}
    for factor, terms in operands:
        for position, digit in terms.items():
            coefficients[position] = coefficients.get(position, 0) + factor * digit
    while coefficients:
        position = min(coefficients)
        digit = coefficients.pop(position)
        carry = (digit + 5000) // 10000
        remainder = digit - carry * 10000
        if remainder:
            normalized[position] = remainder
        if carry:
            coefficients[position + 1] = coefficients.get(position + 1, 0) + carry
            if coefficients[position + 1] == 0:
                del coefficients[position + 1]
    return normalized


def sparse_sign(*operands: tuple[int, dict[int, int]]) -> int:
    normalized = sparse_normalize(*operands)
    if not normalized:
        return 0
    highest = normalized[max(normalized)]
    return (highest > 0) - (highest < 0)


def decimal_sparse(terms: dict[int, int]) -> Decimal:
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999)):
        result = Decimal(0)
        for position, digit in terms.items():
            result += Decimal(digit) * Decimal(f"1E{4*position}")
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
    assert sparse_normalize((1, {0: 10000}), (-1, {1: 1})) == {}
    assert sparse_normalize((1, {0: -10000}), (1, {1: 1})) == {}
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
    old_terms = {250000000: 1}  # independent fixture: exactly 10^1,000,000,000
    fee_terms = sparse_terms(quote["resource_debit"])
    new_terms = sparse_terms(huge["post_wallet"])
    low_terms = sparse_terms(quote["bound_certificate"]["lower"])
    upper_terms = sparse_terms(quote["bound_certificate"]["upper"])
    assert upper_terms == fee_terms  # the quoted upper bound is the debit
    residual = sparse_normalize((1, old_terms), (-1, fee_terms), (-1, new_terms))
    assert residual == {}  # exact low-block identity, without expanding the gap
    assert sparse_sign((1, old_terms), (-1, fee_terms), (-1, new_terms), (-1, {0: 1})) == -1
    assert sparse_sign((1, old_terms), (-1, fee_terms)) >= 0
    assert sparse_sign((1, low_terms), (-1, fee_terms)) <= 0
    assert sparse_sign((28, low_terms), (1, integer_terms(24)), (-25, fee_terms)) >= 0
    prefix = sum(costs[:256])
    prefix_terms = integer_terms(prefix)
    tail_lower = decimal_sparse(sparse_normalize((1, low_terms), (-1, prefix_terms)))
    tail_upper = decimal_sparse(sparse_normalize((1, upper_terms), (-1, prefix_terms)))
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_FLOOR)):
        raw_lower = Decimal(50) * G ** 257 * ((G ** (count - 256) - 1) / (G - 1))
        original_lower = Decimal("0.95") * raw_lower
    with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_CEILING)):
        raw_upper = Decimal(50) * G ** 257 * ((G ** (count - 256) - 1) / (G - 1))
        original_upper = Decimal("1.05") * raw_upper
    # Decimal independently cross-checks the tail scale; exact prefix removal
    # and all wallet/fee identities above use integer sparse arithmetic.
    assert tail_lower <= original_lower and original_upper <= tail_upper
    assert int(quote["material_debit"]) == material(count)
    assert int(huge["post_material"]) == 9007199254740991 - material(count)
    assert int(huge["post_level"]) == 1 + count
    assert huge["boundary_next"]["count"] == count + 1
    assert int(huge["boundary_next"]["material_due"]) > 9007199254740991
    assert huge["post_profile_bytes"] < 16 * 1024 * 1024
    results.append({"fixture": "compact_billion", "count": count, "material_exact": True,
                    "direct_decimal_tail_scale_crosscheck": True,
                    "exact_256_prefix_digits": len(str(prefix)),
                    "exact_sparse_wallet_residual_blocks": len(residual),
                    "exact_sparse_fee_ratio_check": True, "quoted_equals_actual_debit": True,
                    "resource_fee_decimal_magnitude": decimal_sparse(fee_terms).adjusted()})
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
