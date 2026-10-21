"""Independent direct-power oracle for all exploratory MAX-50000 prices.

The Godot generator advances rounded decimal intervals from one level to the
next. This oracle instead calculates each overflow level directly by binary
exponentiation of the *exact binary64* growth factor in directed Decimal
contexts. It compares the two independently rounded bounds to each compact
export entry and escalates precision on a boundary. The finite domain is
checked against the earlier, separately exported main Godot quote stream.
"""
from __future__ import annotations

from decimal import (
    Decimal, Context, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP,
    localcontext,
)
import hashlib
import json
from pathlib import Path
import time

OUT = Path(__file__).resolve().parent / "generated_wallets"
GROWTH = Decimal.from_float(1.0 + 0.2)
BASE = Decimal(50)
PRECISIONS = (40, 80, 160, 320)


def direct_bound(level: int, precision: int, rounding: str) -> Decimal:
    """One independently restarted exponentiation, no rolling price state."""
    ctx = Context(prec=precision, rounding=rounding, Emin=-999_999_999,
                  Emax=999_999_999)
    exponent = level - 1
    power = GROWTH
    product = Decimal(1)
    while exponent:
        if exponent & 1:
            product = ctx.multiply(product, power)
        exponent //= 2
        if exponent:
            power = ctx.multiply(power, power)
    return ctx.multiply(BASE, product)


def rounded_integer(bound: Decimal) -> int:
    assert bound > 100
    step_power = bound.adjusted() - 1
    step = Decimal(1).scaleb(step_power)
    with localcontext() as ctx:
        ctx.prec = max(320, len(bound.as_tuple().digits) + 8)
        rounded = bound.quantize(step, rounding=ROUND_HALF_UP)
    return int(rounded)


def independent_quote(level: int) -> tuple[int, int]:
    for precision in PRECISIONS:
        lo = rounded_integer(direct_bound(level, precision, ROUND_FLOOR))
        hi = rounded_integer(direct_bound(level, precision, ROUND_CEILING))
        if lo == hi:
            return lo, precision
    raise ArithmeticError(f"unresolved direct-power interval at level {level}")


def exact(entry) -> int:
    if isinstance(entry, str):
        assert entry.isdecimal() and (entry == "0" or not entry.startswith("0"))
        return int(entry)
    assert isinstance(entry, list) and len(entry) == 2
    leading, power = entry
    assert type(leading) is int and type(power) is int and 10 <= leading <= 100 and power >= 0
    return leading * 10**power


def main():
    begun = time.perf_counter()
    compact_path = OUT / "godot_prices_50000_compact.json"
    raw = compact_path.read_bytes()
    compact = json.loads(raw)
    earlier = json.loads((OUT / "godot_prices_3873.json").read_bytes())
    assert len(compact) == 50_000 and len(earlier) == 3873
    earlier_mismatch = []
    for index, reference in enumerate(earlier):
        if exact(compact[index]) != int(reference):
            earlier_mismatch.append(index + 2)
    assert not earlier_mismatch, earlier_mismatch[:5]

    full_stream_hash = hashlib.sha256()
    overflow_mismatch = []
    precision_counts = {str(p): 0 for p in PRECISIONS}
    hundred_carries = 0
    checked = 0
    first_overflow = None
    for index, entry in enumerate(compact):
        level = index + 2
        observed = exact(entry)
        full_stream_hash.update(str(observed).encode() + b"\n")
        # The independent earlier Godot export recorded first float overflow
        # at target 3873; levels 2..3872 use its original finite readback.
        if level < 3873:
            continue
        if first_overflow is None:
            first_overflow = level
        checked += 1
        independent, precision = independent_quote(level)
        precision_counts[str(precision)] += 1
        if isinstance(entry, list) and entry[0] == 100:
            hundred_carries += 1
        if observed != independent and len(overflow_mismatch) < 20:
            overflow_mismatch.append({"level": level, "observed": str(observed), "independent": str(independent)})
    print(json.dumps({
        "kind": "independent_direct_power_50000",
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "count": len(compact),
        "finite_prior_mismatches": len(earlier_mismatch),
        "first_overflow": first_overflow,
        "overflow_checked": checked,
        "overflow_mismatches": len(overflow_mismatch),
        "first_mismatches": overflow_mismatch[:3],
        "precision_counts": precision_counts,
        "hundred_leading_carries": hundred_carries,
        "full_line_stream_sha256": full_stream_hash.hexdigest(),
        "elapsed_seconds": time.perf_counter() - begun,
    }, sort_keys=True))
    assert not overflow_mismatch


if __name__ == "__main__":
    main()
