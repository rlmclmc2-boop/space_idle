"""Audit-only deterministic correctness probes. Run in a fresh Python process."""
from __future__ import annotations

from decimal import Decimal
import json
import math
import random
import unittest

from ledger import CurrencyValue
from price import material, oracle, quote


class LedgerProbe(unittest.TestCase):
    def test_remote_gap_and_commutativity(self):
        base = CurrencyValue.decode({"m": 1.0, "e": 1_000_000_000.0})
        one = CurrencyValue.from_integer(1)
        upper = CurrencyValue.decode({"m": 1.0, "e": 1_000_000_100.0})
        less = base.subtract(one)
        self.assertEqual(less.add(one).compare(base), 0)
        self.assertEqual(less.add(upper).compare(upper.add(less)), 0)
        self.assertEqual(less.add(upper).subtract(upper).compare(less), 0)
        self.assertLess(len(json.dumps(less.encode())), 200)

    def test_cross_safe_json_and_income(self):
        wallet = CurrencyValue.from_integer(9_007_199_254_741_003)
        result = wallet.subtract(CurrencyValue.from_integer(10))
        self.assertEqual(result.small_decimal(), Decimal(9_007_199_254_740_993))
        for expected, change in ((9_007_199_254_740_994, 1), (9_007_199_254_740_992, -1)):
            changed = result.add(CurrencyValue.from_integer(change)) if change > 0 else result.subtract(CurrencyValue.from_integer(-change))
            self.assertEqual(changed.small_decimal(), Decimal(expected))
            self.assertEqual(CurrencyValue.decode(json.loads(json.dumps(changed.encode()))), changed)

    def test_random_small_against_independent_integer(self):
        rng = random.Random(20261021)
        for _ in range(1000):
            a, b = rng.randrange(10**50), rng.randrange(10**50)
            x, y = CurrencyValue.from_integer(a), CurrencyValue.from_integer(b)
            self.assertEqual(x.compare(y), (a > b) - (a < b))
            self.assertEqual(x.add(y).small_decimal(), Decimal(a + b))
            if a >= b:
                self.assertEqual(x.subtract(y).small_decimal(), Decimal(a - b))
            else:
                with self.assertRaises(ValueError):
                    x.subtract(y)

    def test_float_and_legacy_fraction(self):
        value = CurrencyValue.from_float(0.5)
        self.assertLess(value.compare(CurrencyValue.from_integer(1)), 0)
        self.assertEqual(CurrencyValue.from_float(1.5).subtract(CurrencyValue.from_integer(1)).small_decimal(), Decimal("0.5"))
        self.assertEqual(CurrencyValue.from_legacy(1.0, 1_000_000_000.0).compare(CurrencyValue.decode({"m": 1.0, "e": 1_000_000_000.0})), 0)

    def test_reject_bad_candidate(self):
        bad = [
            {"v": 4, "blocks": [["0", 0]]},
            {"v": 4, "blocks": [["0", -1]]},
            {"v": 4, "blocks": [["01", 1]]},
            {"v": 4, "blocks": [["0", 1], ["0", 2]]},
            {"v": 4, "blocks": [["0", 5000]]},
            {"v": 4, "blocks": [["0", 1.5]]},
            {"v": 4, "blocks": [["0", 1]], "extra": 1},
            {"v": 1, "i": "09007199254740993"},
            float("inf"), float("nan"), -1,
        ]
        for value in bad:
            with self.subTest(value=value), self.assertRaises(ValueError):
                CurrencyValue.decode(value)


class PriceProbe(unittest.TestCase):
    def test_frozen_low_amounts(self):
        base = 1e-300 * 1e-8
        self.assertEqual(quote(base, 0.195, 4001), 25)
        self.assertEqual(quote(base, math.exp(710 / 4000) - 1, 4001), 5)

    def test_zero_and_material(self):
        for level in (1, 20, 4001):
            self.assertEqual(quote(0.0, 0.2, level), 0)
        self.assertEqual((material(19), material(20), material(40)), (0, 10, 20))

    def test_batch_vs_steps(self):
        costs = [quote(50.0, 0.2, level) for level in range(2, 12)]
        self.assertEqual(sum(costs), sum(quote(50.0, 0.2, level) for level in range(2, 12)))
        self.assertEqual(sum(map(material, range(2, 21))), 10)

    def test_overflow_reference(self):
        for level in (3873, 4001):
            self.assertEqual(quote(50.0, 0.2, level), oracle(50.0, 0.2, level))


if __name__ == "__main__":
    unittest.main(verbosity=2)
