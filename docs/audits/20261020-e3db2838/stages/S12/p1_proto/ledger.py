"""P1 audit-only narrow currency experiment; never imported by the game.

The representation is a sorted balanced base-10000 polynomial in powers of
10000. Exponents are Python integers, so a gap does not allocate its digits.
This is a mathematical reference/prototype, not a Godot performance result.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, localcontext
import math
import re
from typing import Any

BASE = 10_000
MIN_DIGIT, MAX_DIGIT = -5_000, 4_999
MAX_I64 = 9_223_372_036_854_775_807
SAFE_JSON_INT = 9_007_199_254_740_991
_POS = re.compile(r"(?:0|[1-9][0-9]*|-[1-9][0-9]*)\Z")
_DIGITS = re.compile(r"(?:0|[1-9][0-9]*)\Z")


def _terms(coefficient: int, decimal_shift: int) -> list[tuple[int, int]]:
    if coefficient == 0:
        return []
    group, remainder = divmod(decimal_shift, 4)
    coefficient *= 10**remainder
    sign = -1 if coefficient < 0 else 1
    coefficient = abs(coefficient)
    out = []
    while coefficient:
        coefficient, digit = divmod(coefficient, BASE)
        if digit:
            out.append((group, sign * digit))
        group += 1
    return out


def _normal(terms: list[tuple[int, int]]) -> tuple[tuple[int, int], ...]:
    pending: dict[int, int] = {}
    for position, digit in terms:
        pending[position] = pending.get(position, 0) + digit
    import heapq
    heap = list(pending)
    heapq.heapify(heap)
    out = []
    while heap:
        position = heapq.heappop(heap)
        digit = pending.pop(position, None)
        if digit is None:
            continue
        carry = (digit - MIN_DIGIT) // BASE
        digit -= carry * BASE
        if digit:
            out.append((position, digit))
        if carry:
            next_position = position + 1
            if next_position not in pending:
                pending[next_position] = 0
                heapq.heappush(heap, next_position)
            pending[next_position] += carry
    return tuple(out)


@dataclass(frozen=True)
class CurrencyValue:
    blocks: tuple[tuple[int, int], ...]

    @classmethod
    def from_terms(cls, terms: list[tuple[int, int]]) -> CurrencyValue:
        result = cls(_normal(terms))
        if result.blocks and result.blocks[-1][1] < 0:
            raise ValueError("negative currency")
        return result

    @classmethod
    def from_integer(cls, value: int) -> CurrencyValue:
        if type(value) is not int or value < 0:
            raise ValueError("invalid integer currency")
        return cls.from_terms(_terms(value, 0))

    @classmethod
    def from_float(cls, value: float) -> CurrencyValue:
        if not math.isfinite(value) or value < 0:
            raise ValueError("invalid float currency")
        numerator, denominator = value.as_integer_ratio()
        power = denominator.bit_length() - 1
        return cls.from_terms(_terms(numerator * 5**power, -power))

    @classmethod
    def from_legacy(cls, mantissa: float, exponent: float) -> CurrencyValue:
        if not math.isfinite(mantissa) or not math.isfinite(exponent):
            raise ValueError("nonfinite legacy value")
        if mantissa < 0 or exponent != math.floor(exponent):
            raise ValueError("invalid legacy value")
        numerator, denominator = mantissa.as_integer_ratio()
        power = denominator.bit_length() - 1
        return cls.from_terms(_terms(numerator * 5**power, int(exponent) - power))

    @classmethod
    def decode(cls, value: Any) -> CurrencyValue:
        if type(value) is int:
            if value > MAX_I64:
                raise ValueError("JSON integer outside legacy int64")
            return cls.from_integer(value)
        if type(value) is float:
            return cls.from_float(value)
        if type(value) is not dict:
            raise ValueError("invalid currency type")
        if set(value) == {"m", "e"} and type(value["m"]) in (int, float) and type(value["e"]) in (int, float):
            return cls.from_legacy(float(value["m"]), float(value["e"]))
        if set(value) == {"v", "i"} and value["v"] == 1 and type(value["i"]) is str:
            raw = value["i"]
            if not _DIGITS.fullmatch(raw) or int(raw) <= SAFE_JSON_INT:
                raise ValueError("noncanonical v1")
            return cls.from_integer(int(raw))
        if set(value) != {"v", "blocks"} or value["v"] != 4 or type(value["blocks"]) is not list:
            raise ValueError("invalid candidate shape")
        raw = value["blocks"]
        if not raw:
            raise ValueError("candidate zero must be integer zero")
        blocks = []
        for item in raw:
            if type(item) is not list or len(item) != 2 or type(item[0]) is not str or not _POS.fullmatch(item[0]) or type(item[1]) is not int:
                raise ValueError("invalid block")
            blocks.append((int(item[0]), item[1]))
        if not all(MIN_DIGIT <= d <= MAX_DIGIT and d and (i == 0 or blocks[i - 1][0] < p) for i, (p, d) in enumerate(blocks)):
            raise ValueError("noncanonical blocks")
        if blocks[-1][1] < 0:
            raise ValueError("negative candidate")
        return cls(tuple(blocks))

    def compare(self, other: CurrencyValue) -> int:
        # Balanced coefficients permit negative low blocks. The highest
        # nonzero term of the normalized difference determines its sign.
        difference = _normal(list(self.blocks) + [(p, -d) for p, d in other.blocks])
        return (difference[-1][1] > 0) - (difference[-1][1] < 0) if difference else 0

    def add(self, other: CurrencyValue) -> CurrencyValue:
        return CurrencyValue.from_terms(list(self.blocks) + list(other.blocks))

    def subtract(self, other: CurrencyValue) -> CurrencyValue:
        return CurrencyValue.from_terms(list(self.blocks) + [(p, -d) for p, d in other.blocks])

    def encode(self) -> int | dict:
        if not self.blocks:
            return 0
        # This form is deliberately resources-only. No global GrowthNumber
        # recognition or implicit migration of untouched legacy fields.
        return {"v": 4, "blocks": [[str(p), d] for p, d in self.blocks]}

    def small_decimal(self, max_power: int = 1000) -> Decimal:
        if any(abs(p) > max_power for p, _ in self.blocks):
            raise ValueError("decimal projection out of domain")
        if not self.blocks:
            return Decimal(0)
        with localcontext() as context:
            context.prec = max(100, 4 * (self.blocks[-1][0] - self.blocks[0][0] + 2) + 20)
            return sum((Decimal(d) * (Decimal(BASE) ** p) for p, d in self.blocks), Decimal(0))
