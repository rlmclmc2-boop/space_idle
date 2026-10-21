"""Independent fixed-config Decimal check of Godot's compact interval export.

Exploratory audit evidence only. No game script or unbounded wallet is used.
"""
from __future__ import annotations

from decimal import Context, Decimal, ROUND_CEILING, ROUND_FLOOR, localcontext
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
G = Decimal.from_float(1.0 + 0.2)


def as_decimal(pair: list[str | int]) -> Decimal:
    return Decimal(f"{pair[0]}E{pair[1]}")


def main() -> None:
    rows = [json.loads(line) for line in (ROOT / "exploratory_approx_math_3.stdout.log").read_text(encoding="utf-8").splitlines() if line.startswith("{")]
    assert len(rows) == 1
    reported = rows[0]
    assert as_decimal(reported["growth"]) == G
    assert reported["first_overflow_target"] == 3873
    checked = []
    for row in reported["results"]:
        count = int(row["count"])
        lower = as_decimal(row["lower"])
        upper = as_decimal(row["upper"])
        with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_FLOOR)):
            raw_lower = Decimal(50) * G ** 257 * ((G ** count - 1) / (G - 1))
            oracle_lower = Decimal("0.95") * raw_lower
        with localcontext(Context(prec=120, Emax=999_999_999, Emin=-999_999_999, rounding=ROUND_CEILING)):
            raw_upper = Decimal(50) * G ** 257 * ((G ** count - 1) / (G - 1))
            oracle_upper = Decimal("1.05") * raw_upper
        assert lower <= oracle_lower <= oracle_upper <= upper, count
        assert row["fee_ratio_ok"] and row["ordered"]
        checked.append({"count": count, "lower_ok": True, "upper_ok": True, "fee_ratio_ok": True})

    prices = json.loads((ROOT / "generated_wallets/godot_prices_3873.json").read_text(encoding="utf-8"))
    failures = []
    first_target = 258
    last_target = 3874
    with localcontext(Context(prec=400, Emax=999_999_999, Emin=-999_999_999)):
        raw = Decimal(50) * G ** (first_target - 1)
        for target in range(first_target, last_target + 1):
            cost = Decimal(prices[target - 2])
            if not (Decimal("0.95") * raw <= cost <= Decimal("1.05") * raw):
                failures.append(target)
            raw *= G
    assert not failures, failures[:10]
    output = {
        "kind": "independent_approx_interval_oracle",
        "growth_exact": str(G),
        "intervals": checked,
        "checked_targets": [first_target, last_target],
        "checked_target_count": last_target - first_target + 1,
        "finite_complete_through_target": reported["first_overflow_target"] - 1,
        "finite_price_input_sha256": hashlib.sha256((ROOT / "generated_wallets/godot_prices_3873.json").read_bytes()).hexdigest(),
        "finite_failures": failures,
    }
    print(json.dumps(output, sort_keys=True))


if __name__ == "__main__":
    main()
