"""Audit-only independent semantic controls; never a game integration PASS."""
import copy
import unittest

from ledger import CurrencyValue, MAX_I64
from price import quote
from transaction_model import (
    MATERIAL_ID, collect, commit_purchase, fixture, ordered_batch,
    plan_purchase, refund_all,
)


def amount(profile):
    return CurrencyValue.decode(profile["resources"]["1"]).small_decimal()


class TransactionControls(unittest.TestCase):
    def test_three_slots_resource_first(self):
        profile = fixture()
        receipt = ordered_batch(profile)
        self.assertEqual(receipt, {
            "changed": ["weapons_0", "defence_0"],
            "rejected": [{"slot": "weapons_1", "reason": "insufficient_resource"}],
        })
        self.assertEqual(amount(profile), 0)
        self.assertEqual([v["level"] for v in profile["loadout"].values()], [2, 19, 2])
        self.assertEqual([e["kind"] for e in profile["events"]],
                         ["resources_changed", "upgrade", "resources_changed", "upgrade", "upgrades_completed"])

    def test_middle_slot_material_only(self):
        profile = fixture(wallet=1730)
        receipt = ordered_batch(profile)
        self.assertEqual(receipt["rejected"], [{"slot": "weapons_1", "reason": "insufficient_material"}])
        self.assertEqual(amount(profile), 1600)
        self.assertEqual(profile["hyperspace"]["materials"][MATERIAL_ID], 0)
        self.assertEqual([v["level"] for v in profile["loadout"].values()], [2, 19, 2])

    def test_batch_exact_and_one_below(self):
        total = sum(quote(50.0, 0.2, level) for level in range(2, 12))
        batch = fixture(wallet=total)
        status, plan = plan_purchase(batch, "weapons_0", 10)
        self.assertEqual(status, "ready")
        self.assertEqual(plan.resource_cost, total)
        self.assertEqual(commit_purchase(batch, plan)["status"], "committed")
        self.assertEqual((amount(batch), batch["loadout"]["weapons_0"]["level"]), (0, 11))
        singles = fixture(wallet=total)
        for _ in range(10):
            status, plan = plan_purchase(singles, "weapons_0", 1)
            self.assertEqual(status, "ready")
            commit_purchase(singles, plan)
        self.assertEqual((amount(singles), singles["loadout"]["weapons_0"]["level"]), (0, 11))
        short = fixture(wallet=total - 1)
        original = copy.deepcopy(short)
        self.assertEqual(plan_purchase(short, "weapons_0", 10)[0], "insufficient_resource")
        self.assertEqual(short, original)

    def test_stale_without_effects(self):
        profile = fixture()
        status, plan = plan_purchase(profile, "weapons_0", 1)
        self.assertEqual(status, "ready")
        profile["evolution"]["interval"] = 2
        before = copy.deepcopy(profile)
        self.assertEqual(commit_purchase(profile, plan), {"status": "stale"})
        self.assertEqual(profile, before)
        self.assertEqual(commit_purchase(copy.deepcopy(fixture()), plan), {"status": "stale"})

    def test_aggregate_refund_overflow(self):
        profile = fixture(wallet=100, material_wallet=MAX_I64)
        profile["loadout"]["weapons_0"]["level"] = 2
        profile["loadout"]["defence_0"]["level"] = 20
        before = copy.deepcopy(profile)
        self.assertEqual(refund_all(profile, ("weapons_0", "defence_0"))["status"], "material_overflow")
        self.assertEqual(profile, before)

    def test_collect_source_credit_and_preflight(self):
        profile = fixture(wallet=100)
        source = {"id": "1", "amount": 5, "production_base": 3, "hightech": False}
        profile["drops"].append(source)
        self.assertEqual(collect(profile, source)["status"], "committed")
        self.assertEqual(amount(profile), 105)
        self.assertEqual((profile["run_resources"]["1"], profile["furnaceIncomePeak"]), (5, 3))
        self.assertEqual(len(profile["resourceSamples"]), 1)
        self.assertEqual(profile["drops"], [])
        self.assertEqual(collect(profile, source), {"status": "missing_source"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
