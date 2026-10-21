"""Audit-only semantic model; independent oracle for future Godot adapter.

It models narrow money, int64 material, read-only plan/stale commit and the
original ordered partial batch. It is not imported by the game and does not
certify Godot, save transfer or a native DLL.
"""
from __future__ import annotations

import copy
from dataclasses import dataclass
import json
from typing import Any

from ledger import CurrencyValue, MAX_I64
from price import material, quote

SAVE_LIMIT = 16 * 1024 * 1024
MATERIAL_ID = "degenerate_matter"


def fixture(wallet: int = 130, material_wallet: int = 0) -> dict:
    return {
        "resources": {"1": wallet, "2": 0},
        "hyperspace": {"materials": {MATERIAL_ID: material_wallet}},
        "loadout": {
            "weapons_0": {"key": "laser", "level": 1},
            "weapons_1": {"key": "missile", "level": 19},
            "defence_0": {"key": "armour", "level": 1},
        },
        "evolution": {"interval": 20, "material_cost_per_tier": 10},
        "resourceSamples": [],
        "drops": [],
        "run_resources": {"1": 0},
        "furnaceIncomePeak": 0,
        "events": [],
        "save_dirty": False,
    }


def _authority_view(profile: dict) -> dict:
    return {key: profile[key] for key in ("resources", "hyperspace", "loadout", "evolution")}


def _authority_signature(profile: dict) -> str:
    return json.dumps(_authority_view(profile), sort_keys=True, separators=(",", ":"))


def _fits(profile: dict) -> bool:
    return len(json.dumps(profile, ensure_ascii=False, separators=(",", ":")).encode()) <= SAVE_LIMIT


@dataclass(frozen=True)
class Plan:
    owner: dict
    signature: str
    slot: str
    before_level: int
    count: int
    resource_cost: int
    material_cost: int
    next_wallet: CurrencyValue
    next_material: int


def plan_purchase(profile: dict, slot: str, count: int) -> tuple[str, Plan | None]:
    if slot not in profile["loadout"] or type(count) is not int or count < 1:
        return "invalid", None
    entry = profile["loadout"][slot]
    before = entry["level"]
    interval = profile["evolution"]["interval"]
    per_tier = profile["evolution"]["material_cost_per_tier"]
    if type(before) is not int or before < 1 or type(interval) is not int or interval <= 0:
        return "invalid", None
    money_cost = 0
    matter_cost = 0
    try:
        for level in range(before + 1, before + count + 1):
            money_cost += quote(50.0, 0.2, level)
            matter_cost += material(level, interval, per_tier)
        wallet = CurrencyValue.decode(profile["resources"]["1"])
        price_value = CurrencyValue.from_integer(money_cost)
        current_material = profile["hyperspace"]["materials"][MATERIAL_ID]
        if type(current_material) is not int or not 0 <= current_material <= MAX_I64:
            return "invalid", None
        # Main quote inserts resource cost before evolution material.
        if wallet.compare(price_value) < 0:
            return "insufficient_resource", None
        if current_material < matter_cost:
            return "insufficient_material", None
        next_wallet = wallet.subtract(price_value)
    except (ValueError, ArithmeticError, OverflowError):
        return "invalid", None
    proposed = copy.deepcopy(profile)
    proposed["resources"]["1"] = next_wallet.encode()
    proposed["hyperspace"]["materials"][MATERIAL_ID] = current_material - matter_cost
    proposed["loadout"][slot]["level"] = before + count
    if not _fits(proposed):
        return "save_size", None
    return "ready", Plan(profile, _authority_signature(profile), slot, before, count, money_cost, matter_cost, next_wallet, current_material - matter_cost)


def commit_purchase(profile: dict, plan: Plan) -> dict:
    if profile is not plan.owner or _authority_signature(profile) != plan.signature:
        return {"status": "stale"}
    slot = plan.slot
    profile["resources"]["1"] = plan.next_wallet.encode()
    profile["hyperspace"]["materials"][MATERIAL_ID] = plan.next_material
    profile["loadout"][slot]["level"] = plan.before_level + plan.count
    profile["events"].append({"kind": "resources_changed", "ids": ["1"]})
    if plan.material_cost:
        profile["events"].append({"kind": "hyperspace_changed", "reason": "equipment_evolution"})
    profile["events"].append({"kind": "upgrade", "slot": slot, "key": profile["loadout"][slot]["key"], "levels": plan.count, "resource_cost": plan.resource_cost, "material_cost": plan.material_cost})
    profile["save_dirty"] = True
    return {"status": "committed", "slot": slot, "levels": plan.count}


def ordered_batch(profile: dict, slots: tuple[str, ...] = ("weapons_0", "weapons_1", "defence_0")) -> dict:
    changed = []
    rejected = []
    for slot in slots:
        status, proposal = plan_purchase(profile, slot, 1)
        if proposal is None:
            rejected.append({"slot": slot, "reason": status})
            continue
        receipt = commit_purchase(profile, proposal)
        if receipt["status"] == "committed":
            changed.append(slot)
        else:
            rejected.append({"slot": slot, "reason": receipt["status"]})
    if changed:
        profile["events"].append({"kind": "upgrades_completed", "slots": changed.copy()})
    return {"changed": changed, "rejected": rejected}


def refund_all(profile: dict, slots: tuple[str, ...]) -> dict:
    total_resource = 0
    total_material = 0
    for slot in slots:
        entry = profile["loadout"][slot]
        for level in range(2, entry["level"] + 1):
            total_resource += quote(50.0, 0.2, level)
            total_material += material(level, profile["evolution"]["interval"], profile["evolution"]["material_cost_per_tier"])
    before_material = profile["hyperspace"]["materials"][MATERIAL_ID]
    if before_material + total_material > MAX_I64:
        return {"status": "material_overflow"}
    try:
        new_wallet = CurrencyValue.decode(profile["resources"]["1"]).add(CurrencyValue.from_integer(total_resource))
    except ValueError:
        return {"status": "invalid_wallet"}
    proposed = copy.deepcopy(profile)
    proposed["resources"]["1"] = new_wallet.encode()
    proposed["hyperspace"]["materials"][MATERIAL_ID] += total_material
    if not _fits(proposed):
        return {"status": "save_size"}
    profile["resources"]["1"] = new_wallet.encode()
    profile["hyperspace"]["materials"][MATERIAL_ID] = before_material + total_material
    profile["events"].append({"kind": "resources_changed", "ids": ["1"]})
    if total_material:
        profile["events"].append({"kind": "hyperspace_changed", "reason": "equipment_refund"})
    profile["save_dirty"] = True
    return {"status": "committed", "resource_credit": total_resource, "material_credit": total_material}


def collect(profile: dict, source: dict, now: float = 1000.0) -> dict:
    if source not in profile["drops"]:
        return {"status": "missing_source"}
    if source.get("id") != "1" or source.get("hightech"):
        return {"status": "invalid_source"}
    amount = source["amount"]
    production_base = source["production_base"]
    if type(amount) is not int or type(production_base) is not int or amount < 0 or production_base < 0:
        return {"status": "invalid_source"}
    try:
        wallet = CurrencyValue.decode(profile["resources"]["1"]).add(CurrencyValue.from_integer(amount))
    except ValueError:
        return {"status": "invalid_wallet"}
    sample = {"time": now, "production_time": 1000.0, "id": "1", "amount": amount, "production_base": production_base, "origin": "drop"}
    proposed = copy.deepcopy(profile)
    proposed["resources"]["1"] = wallet.encode()
    proposed["resourceSamples"].append(sample)
    proposed["run_resources"]["1"] += amount
    proposed["furnaceIncomePeak"] += production_base
    proposed["drops"].remove(source)
    if not _fits(proposed):
        return {"status": "save_size"}
    profile["resources"]["1"] = wallet.encode()
    profile["resourceSamples"].append(sample)
    profile["run_resources"]["1"] += amount
    profile["furnaceIncomePeak"] += production_base
    profile["drops"].remove(source)
    profile["events"].append({"kind": "collect", "id": "1", "amount": amount, "manual": True})
    profile["save_dirty"] = True
    return {"status": "committed"}
