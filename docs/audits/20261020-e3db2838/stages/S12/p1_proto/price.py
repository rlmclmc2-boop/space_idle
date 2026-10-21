"""Audit-only exact-price experiment, with an independent Decimal oracle.

The bounded candidate does not materialize a billion-level price. The fixed
benchmark records that gap as failure rather than reporting a smaller scene.
"""
from __future__ import annotations

from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR, localcontext
import math


def _rounded(value: Decimal) -> int:
    if value < 0:
        raise ValueError("negative price")
    if value == 0:
        return 0
    if value < 100:
        return int((value / 10).to_integral_value(rounding=ROUND_FLOOR) * 10 + 5)
    step = Decimal(10) ** (value.adjusted() - 1)
    return int(((value / step + Decimal("0.5")).to_integral_value(rounding=ROUND_FLOOR) * step).to_integral_value(rounding=ROUND_CEILING))


def quote(base: float, multiplier: float, level: int) -> int:
    """S09 branch order; oversized results use S11 decimal-factor meaning."""
    if not math.isfinite(base) or not math.isfinite(multiplier) or base < 0 or multiplier <= -1 or level < 1:
        raise ValueError("invalid quote input")
    if level == 1 or base == 0:
        return math.ceil(base)
    growth = 1.0 + multiplier
    try:
        ordinary = base * growth ** (level - 1)
    except OverflowError:
        ordinary = math.inf
    if math.isfinite(ordinary):
        if ordinary <= 0:
            return 0
        if ordinary < 100:
            return math.ceil(math.floor(ordinary / 10) * 10.0 + 5.0)
        step = 10.0 ** (math.floor(math.log(ordinary) / math.log(10) + 1e-12) - 1)
        return math.ceil(math.floor(ordinary / step + 0.5) * step)
    with localcontext() as ctx:
        # Two significant digits normally suffice; guard exact boundaries
        # by comparing independently rounded lower/upper precision runs.
        for precision in (64, 128, 256, 512, 1024):
            ctx.prec = precision
            ctx.rounding = ROUND_FLOOR
            lo = Decimal(str(base)) * Decimal(str(growth)) ** (level - 1)
            ctx.rounding = ROUND_CEILING
            hi = Decimal(str(base)) * Decimal(str(growth)) ** (level - 1)
            a, b = _rounded(lo), _rounded(hi)
            if a == b:
                return a
    raise ArithmeticError("quote bounds ambiguous")


def oracle(base: float, multiplier: float, level: int) -> int:
    """Independent high-precision direct power; practical finite scenes only."""
    if level < 1 or not math.isfinite(base) or not math.isfinite(multiplier):
        raise ValueError("invalid")
    if base == 0:
        return 0
    with localcontext() as ctx:
        ctx.prec = max(100, int(level * math.log10(1 + multiplier)) + 80)
        value = Decimal(str(base)) * Decimal(str(1.0 + multiplier)) ** (level - 1)
        return _rounded(value)


def material(level: int, interval: int = 20, per_tier: int = 10) -> int:
    if level < 1 or interval <= 0 or per_tier < 0:
        raise ValueError("invalid material rule")
    return per_tier * (level // interval) if level % interval == 0 else 0
