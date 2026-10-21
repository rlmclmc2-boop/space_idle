"""One audit host for finite transaction protocols; never imported by the game.

Untrusted profile/quote data are copied and decoded at entry. A prepared ticket
binds host identity, generation and the whole profile. No method exposes the
owned mutable profile. Godot MAX-APPROX-v1 remains a separate query producer;
its untrusted serialized quote is not accepted as an authority by this model.
"""
from __future__ import annotations

import copy
from dataclasses import dataclass
import json
import math
from typing import Any

from ledger import CurrencyValue, MAX_I64
from transaction_model import (
    MATERIAL_ID, collect, commit_purchase, ordered_batch, plan_purchase, refund_all,
)


def _wire(profile: dict) -> str:
    return json.dumps(profile, sort_keys=True, separators=(",", ":"), allow_nan=False)


@dataclass(frozen=True)
class Ticket:
    owner: object
    generation: int
    source: str
    kind: str
    slot: str
    count: int
    declared_cost: int


class AuditHost:
    """Synchronous audit boundary with one publication per successful command."""

    def __init__(self, encoded_profile: dict):
        self._profile: dict = {}
        self._generation = 0
        self._pending_ticket: Ticket | None = None
        self._pending_native: dict | None = None
        self.load(encoded_profile)

    def load(self, encoded_profile: dict) -> str:
        # A failed import invalidates all old tickets and the old balance.
        self._generation += 1
        self._profile = {}
        self._pending_ticket = None
        self._pending_native = None
        try:
            candidate = copy.deepcopy(encoded_profile)
            CurrencyValue.decode(candidate["resources"]["1"])
            material = candidate["hyperspace"]["materials"][MATERIAL_ID]
            if type(material) is not int or not 0 <= material <= MAX_I64:
                return "invalid_material"
            _wire(candidate)
        except (KeyError, TypeError, ValueError, OverflowError):
            return "invalid_profile"
        self._profile = candidate
        return "loaded"

    def snapshot(self) -> dict:
        return copy.deepcopy(self._profile)

    def _publish(self, proposed: dict) -> None:
        self._profile = proposed
        self._generation += 1
        self._pending_ticket = None
        self._pending_native = None

    def prepare(self, slot: str, mode: str) -> tuple[str, Ticket | None]:
        if not self._profile:
            return "invalid_profile", None
        if mode not in ("x1", "x10"):
            # Extreme MAX must arrive via its separately validated query and
            # certificate; never route it through a small exact command.
            return "unsupported_mode", None
        count = 1 if mode == "x1" else 10
        entry = self._profile.get("loadout", {}).get(slot)
        if type(entry) is not dict or type(entry.get("level")) is not int:
            return "invalid_slot", None
        if not 1 <= entry["level"] <= MAX_I64 - count:
            return "unsupported_level_representation", None
        try:
            status, plan = plan_purchase(self._profile, slot, count)
            if plan is None:
                return status, None
            ticket = Ticket(self, self._generation, _wire(self._profile), "purchase", slot, count, plan.resource_cost)
            self._pending_ticket = ticket
            return "ready", ticket
        except (ValueError, TypeError, OverflowError, ArithmeticError):
            return "unsupported_quote", None

    def commit(self, ticket: Ticket) -> dict:
        if type(ticket) is not Ticket or ticket is not self._pending_ticket or ticket.owner is not self or ticket.generation != self._generation or not self._profile or ticket.source != _wire(self._profile):
            return {"status": "stale"}
        status, plan = plan_purchase(self._profile, ticket.slot, ticket.count)
        if status != "ready" or plan is None or plan.resource_cost != ticket.declared_cost:
            return {"status": "stale"}
        proposed = copy.deepcopy(self._profile)
        status2, proposal = plan_purchase(proposed, ticket.slot, ticket.count)
        if status2 != "ready" or proposal is None:
            return {"status": "stale"}
        receipt = commit_purchase(proposed, proposal)
        if receipt["status"] != "committed":
            return receipt
        self._publish(proposed)
        return receipt

    def batch(self, slots: tuple[str, ...]) -> dict:
        if not self._profile:
            return {"status": "invalid_profile"}
        proposed = copy.deepcopy(self._profile)
        result = ordered_batch(proposed, slots)
        if not result["changed"]:
            return {"status": "not_affordable", **result}
        self._publish(proposed)
        return {"status": "committed", **result}

    def refund(self, slots: tuple[str, ...]) -> dict:
        if not self._profile:
            return {"status": "invalid_profile"}
        proposed = copy.deepcopy(self._profile)
        try:
            result = refund_all(proposed, slots)
        except (KeyError, TypeError, ValueError, ArithmeticError, OverflowError):
            return {"status": "invalid_refund"}
        if result["status"] == "committed":
            self._publish(proposed)
        return result

    def collect_source(self, source_index: int) -> dict:
        if not self._profile or type(source_index) is not int or not 0 <= source_index < len(self._profile["drops"]):
            return {"status": "missing_source"}
        proposed = copy.deepcopy(self._profile)
        try:
            result = collect(proposed, proposed["drops"][source_index])
        except (KeyError, TypeError, ValueError, ArithmeticError, OverflowError):
            return {"status": "invalid_source"}
        if result["status"] == "committed":
            self._publish(proposed)
        return result

    def research_step(self, dt: float, rate: int = 1) -> dict:
        """Finite R-HALF duration model; float expense follows baseline order."""
        if not self._profile or not math.isfinite(dt) or dt <= 0 or type(rate) is not int or rate <= 0:
            return {"status": "invalid_research"}
        proposed = copy.deepcopy(self._profile)
        try:
            balance = CurrencyValue.decode(proposed["resources"]["1"])
            full_cost = CurrencyValue.from_float(float(rate) * dt)
            paid_step = dt
            if balance.compare(full_cost) < 0:
                # Only the small exhausted-balance branch needs a float.
                paid_step = min(dt, float(balance.small_decimal()) / float(rate))
            if paid_step <= 1e-10:
                # Baseline clears a sub-step depleted input and proceeds with
                # basic, unpaid research for the remaining requested time.
                paid_step = 0.0
            expense = CurrencyValue.from_float(float(rate) * paid_step)
            next_balance = balance.subtract(expense) if paid_step else CurrencyValue.from_integer(0)
            proposed["resources"]["1"] = next_balance.encode()
            proposed["research_elapsed"] = float(proposed.get("research_elapsed", 0.0)) + dt
            proposed["research_paid_elapsed"] = float(proposed.get("research_paid_elapsed", 0.0)) + paid_step
            proposed["save_dirty"] = True
        except (ValueError, TypeError, ArithmeticError, OverflowError):
            return {"status": "unsupported_research"}
        self._publish(proposed)
        return {"status": "advanced", "step": dt, "paid_step": paid_step}

    def native_prepare_aggregate(self, slots: tuple[str, ...]) -> dict:
        """One descriptor after sequential simulated purchases, not per slot."""
        if not self._profile:
            return {"status": "invalid_profile"}
        simulated = copy.deepcopy(self._profile)
        result = ordered_batch(simulated, slots)
        if not result["changed"]:
            return {"status": "skip"}
        result_batch = {"status": "prepared", "owner": self, "generation": self._generation,
                "source": _wire(self._profile), "slots": slots,
                "planned": tuple(result["changed"]), "descriptor": {
                    "weapon_levels": {s: simulated["loadout"][s]["level"] for s in result["changed"] if s.startswith("weapons_")},
                    "defence_levels": {s: simulated["loadout"][s]["level"] for s in result["changed"] if s.startswith("defence_")},
                }}
        self._pending_native = copy.deepcopy({key: value for key, value in result_batch.items() if key != "owner"})
        return result_batch

    def native_commit_aggregate(self, batch: dict, kernel_accept: bool = True,
                                fail_after_successes: int | None = None) -> dict:
        if batch.get("status") != "prepared" or batch.get("owner") is not self or batch.get("generation") != self._generation or not self._profile or batch.get("source") != _wire(self._profile):
            return {"status": "stale"}
        if self._pending_native is None or {key: value for key, value in batch.items() if key != "owner"} != self._pending_native:
            return {"status": "descriptor_mismatch"}
        simulated = copy.deepcopy(self._profile)
        result = ordered_batch(simulated, batch["slots"])
        expected = {
            "weapon_levels": {s: simulated["loadout"][s]["level"] for s in result["changed"] if s.startswith("weapons_")},
            "defence_levels": {s: simulated["loadout"][s]["level"] for s in result["changed"] if s.startswith("defence_")},
        }
        if tuple(result["changed"]) != batch["planned"] or expected != batch["descriptor"]:
            return {"status": "descriptor_mismatch"}
        if not kernel_accept:
            return {"status": "handoff_rejected"}
        if fail_after_successes is not None:
            if fail_after_successes != 1 or len(batch["planned"]) < 2:
                return {"status": "invalid_failure_injection"}
            # Model a native handoff failure observed after the first genuine
            # purchase. The aggregate descriptor is discarded, no later slot
            # runs, and only that already-successful slot remains visible.
            partial = copy.deepcopy(self._profile)
            first = batch["planned"][0]
            status, ticket = plan_purchase(partial, first, 1)
            if status != "ready" or ticket is None:
                return {"status": "stale"}
            if commit_purchase(partial, ticket)["status"] != "committed":
                return {"status": "stale"}
            partial["events"].append({"kind": "upgrades_completed", "slots": [first]})
            self._publish(partial)
            return {"status": "partial_handoff_stop", "changed": (first,),
                    "stopped_before": batch["planned"][1], "descriptor_updates": 0}
        self._publish(simulated)
        return {"status": "committed", "planned": batch["planned"], "descriptor_updates": 1}
