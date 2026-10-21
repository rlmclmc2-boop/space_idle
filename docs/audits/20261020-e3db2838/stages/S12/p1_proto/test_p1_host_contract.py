"""Finite same-host protocol checks; no product integration claim."""
from __future__ import annotations

import copy
import unittest

from ledger import CurrencyValue, MAX_I64
from p1_host_contract import AuditHost
from transaction_model import fixture


def wallet(host: AuditHost) -> CurrencyValue:
    return CurrencyValue.decode(host.snapshot()["resources"]["1"])


class HostProtocol(unittest.TestCase):
    def test_single_exact_and_alias_stale(self):
        source = fixture(wallet=130)
        host = AuditHost(source)
        status, ticket = host.prepare("weapons_0", "x1")
        self.assertEqual(status, "ready")
        source["resources"]["1"] = 0  # input alias does not change owned value
        self.assertEqual(host.commit(ticket)["status"], "committed")
        self.assertEqual(wallet(host).small_decimal(), 65)
        self.assertEqual(host.commit(ticket), {"status": "stale"})
        host = AuditHost(fixture(wallet=200))
        status, ticket = host.prepare("weapons_0", "x1")
        self.assertEqual(status, "ready")
        self.assertEqual(host.load({"resources": {"1": {"bad": 1}}}), "invalid_profile")
        self.assertEqual(host.commit(ticket), {"status": "stale"})

    def test_x10_original_price_and_legacy_far_wallet(self):
        ordinary = AuditHost(fixture(wallet=2450))
        status, ticket = ordinary.prepare("weapons_0", "x10")
        self.assertEqual(status, "ready")
        self.assertEqual(ordinary.commit(ticket)["status"], "committed")
        self.assertEqual(ordinary.snapshot()["loadout"]["weapons_0"]["level"], 11)
        remote = fixture()
        remote["resources"]["1"] = {"m": 1.0, "e": 1_000_000_000.0}
        host = AuditHost(remote)
        before = wallet(host)
        status, ticket = host.prepare("weapons_0", "x1")
        self.assertEqual(status, "ready")
        self.assertEqual(host.commit(ticket)["status"], "committed")
        self.assertEqual(wallet(host).add(CurrencyValue.from_integer(65)).compare(before), 0)
        self.assertLess(len(str(host.snapshot()["resources"]["1"])), 200)
        self.assertEqual(host.prepare("weapons_0", "max")[0], "unsupported_mode")

    def test_legal_old_wallet_strings_do_not_hit_python_digit_limit(self):
        huge = {"v": 1, "i": "9" * 5000}
        source = fixture()
        source["resources"]["1"] = huge
        host = AuditHost(source)
        before = wallet(host)
        status, ticket = host.prepare("weapons_0", "x1")
        self.assertEqual(status, "ready")
        self.assertEqual(host.commit(ticket)["status"], "committed")
        self.assertEqual(wallet(host).add(CurrencyValue.from_integer(65)).compare(before), 0)
        self.assertEqual(CurrencyValue.decode({"m": 1.0, "e": 1e308}).subtract(CurrencyValue.from_integer(1)).add(CurrencyValue.from_integer(1)).compare(CurrencyValue.decode({"m": 1.0, "e": 1e308})), 0)

    def test_int64_level_boundary_no_write(self):
        source = fixture()
        source["loadout"]["weapons_0"]["level"] = MAX_I64 - 9
        host = AuditHost(source)
        before = host.snapshot()
        self.assertEqual(host.prepare("weapons_0", "x10")[0], "unsupported_level_representation")
        self.assertEqual(host.snapshot(), before)

    def test_ordered_partial_and_refund_atomic(self):
        host = AuditHost(fixture())
        result = host.batch(("weapons_0", "weapons_1", "defence_0"))
        self.assertEqual(result["changed"], ["weapons_0", "defence_0"])
        self.assertEqual(result["rejected"], [{"slot": "weapons_1", "reason": "insufficient_resource"}])
        self.assertEqual(wallet(host).small_decimal(), 0)
        overflow = fixture(wallet=100, material_wallet=MAX_I64)
        overflow["loadout"]["weapons_0"]["level"] = 2
        overflow["loadout"]["defence_0"]["level"] = 20
        host = AuditHost(overflow)
        before = host.snapshot()
        self.assertEqual(host.refund(("weapons_0", "defence_0"))["status"], "material_overflow")
        self.assertEqual(host.snapshot(), before)

    def test_fractional_research_and_income_source_isolation(self):
        source = fixture()
        source["resources"]["1"] = 0.5
        host = AuditHost(source)
        self.assertEqual(host.research_step(1.0, 1), {"status": "advanced", "step": 1.0, "paid_step": 0.5})
        self.assertEqual(wallet(host).small_decimal(), 0)
        self.assertEqual((host.snapshot()["research_elapsed"], host.snapshot()["research_paid_elapsed"]), (1.0, 0.5))
        self.assertEqual(host.research_step(1.0, 1), {"status": "advanced", "step": 1.0, "paid_step": 0.0})
        micro = fixture()
        micro["resources"]["1"] = 1e-12
        micro_host = AuditHost(micro)
        self.assertEqual(micro_host.research_step(1.0, 1), {"status": "advanced", "step": 1.0, "paid_step": 0.0})
        self.assertEqual(wallet(micro_host).small_decimal(), 0)
        short = AuditHost(fixture(wallet=100))
        short_before = short.snapshot()
        short_generation = short._generation
        self.assertEqual(short.research_step(1e-12, 1), {"status": "no_change"})
        self.assertEqual(short.snapshot(), short_before)
        self.assertEqual(short._generation, short_generation)
        equal = fixture()
        equal["resources"]["1"] = 1e-10
        equal_host = AuditHost(equal)
        equal_before = equal_host.snapshot()
        equal_generation = equal_host._generation
        self.assertEqual(equal_host.research_step(1.0, 1), {"status": "no_change"})
        self.assertEqual(equal_host.snapshot(), equal_before)
        self.assertEqual(equal_host._generation, equal_generation)
        source = fixture(wallet=100)
        source["drops"].append({"id": "1", "amount": 5, "production_base": 3, "hightech": False})
        host = AuditHost(source)
        self.assertEqual(host.collect_source(0)["status"], "committed")
        result = host.snapshot()
        self.assertEqual(wallet(host).small_decimal(), 105)
        self.assertEqual((result["run_resources"]["1"], result["furnaceIncomePeak"]), (5, 3))
        self.assertEqual(result["drops"], [])
        self.assertEqual(host.collect_source(0), {"status": "missing_source"})

    def test_one_native_descriptor_and_failure_paths(self):
        host = AuditHost(fixture())
        batch = host.native_prepare_aggregate(("weapons_0", "weapons_1", "defence_0"))
        self.assertEqual(batch["planned"], ("weapons_0", "defence_0"))
        self.assertEqual(batch["descriptor"], {"weapon_levels": {"weapons_0": 2}, "defence_levels": {"defence_0": 2}})
        before = host.snapshot()
        self.assertEqual(host.native_commit_aggregate(batch, kernel_accept=False)["status"], "handoff_rejected")
        self.assertEqual(host.snapshot(), before)
        tampered = dict(batch)
        tampered["descriptor"] = copy.deepcopy(batch["descriptor"])
        tampered["descriptor"]["weapon_levels"]["weapons_0"] = 3
        self.assertEqual(host.native_commit_aggregate(tampered)["status"], "descriptor_mismatch")
        self.assertEqual(host.snapshot(), before)
        self.assertEqual(host.native_commit_aggregate(batch), {"status": "committed", "planned": ("weapons_0", "defence_0"), "descriptor_updates": 1})
        self.assertEqual(host.native_commit_aggregate(batch), {"status": "stale"})
        late = AuditHost(fixture())
        prepared = late.native_prepare_aggregate(("weapons_0", "weapons_1", "defence_0"))
        self.assertEqual(late.native_commit_aggregate(prepared, fail_after_successes=1), {
            "status": "partial_handoff_stop", "changed": ("weapons_0",),
            "stopped_before": "defence_0", "descriptor_updates": 0,
        })
        current = late.snapshot()
        self.assertEqual((current["loadout"]["weapons_0"]["level"], current["loadout"]["defence_0"]["level"]), (2, 1))
        self.assertEqual(wallet(late).small_decimal(), 65)
        self.assertEqual([e["kind"] for e in current["events"]],
                         ["resources_changed", "upgrade", "upgrades_completed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
