"""Exploratory fixed-wallet generator v2; no result is an official MAX timing.

Input construction is intentionally separate from the MAX query. This module
does not pretend to construct the billion-level resource wallet.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import time

from ledger import CurrencyValue
from price import material, quote

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "generated_wallets"
VERSION = "p1-wallet-v2-exploratory"
TARGETS = (20, 3873, 4001, 10000, 50000)


def write_case(name: str, start: int, target: int, prices: list[int], prefix: list[int]) -> dict:
    half = prices[target + 1] // 2
    wallet = prefix[target] - prefix[start] + half
    materials = sum(map(material, range(start + 1, target + 1)))
    stored = CurrencyValue.from_integer(wallet).encode()
    profile = {
        "evolution": {"interval": 20, "material_cost_per_tier": 10, "material_id": "degenerate_matter"},
        "hyperspace": {"materials": {"degenerate_matter": materials}},
        "laser_level": start,
        "resources": {"1": stored, "2": 0},
    }
    blob = json.dumps(profile, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    filename = f"{name}.json"
    (OUT / filename).write_bytes(blob)
    return {
        "id": name,
        "file": filename,
        "start": start,
        "target": target,
        "expected_count": target - start,
        "first_unaffordable_price": str(prices[target + 1]),
        "remaining_after_expected_purchases": str(half),
        "wallet_decimal_digits": len(str(wallet)),
        "candidate_blocks": len(stored["blocks"]) if isinstance(stored, dict) else 0,
        "input_bytes": len(blob),
        "sha256": hashlib.sha256(blob).hexdigest(),
        "material_wallet": materials,
        "whole_game_save_bytes": None,
        "independent_full_price_oracle": "pending",
    }


def main() -> None:
    sys.set_int_max_str_digits(1_000_000)
    OUT.mkdir(exist_ok=True)
    start_time = time.perf_counter()
    prices = [0] * (TARGETS[-1] + 2)
    prefix = [0] * (TARGETS[-1] + 2)
    for level in range(2, TARGETS[-1] + 2):
        prices[level] = quote(50.0, 0.2, level)
        prefix[level] = prefix[level - 1] + prices[level]
    construction_ms = (time.perf_counter() - start_time) * 1000
    cases = []
    for target in TARGETS:
        cases.append(write_case(f"MAX-{target}", 1, target, prices, prefix))
        if target != 20:
            cases.append(write_case(f"MAX-HIGH-{target}", target - 10, target, prices, prefix))
    manifest = {
        "classification": "exploratory setup, not official P1 timing",
        "generator_version": VERSION,
        "price_basis": "price.py quote; main S09 branch with S11 decimal-factor overflow interpretation",
        "build_time_ms": construction_ms,
        "source_blob_game_data": "582d36199cb394127288e53eac16fb7eee57b4a6",
        "source_blob_evolution": "fbbc9b50d00dc889cc709c65fcd87db122b60f82",
        "cases": cases,
        "MAX-1000000000": "not constructed; exact wallet and full-save admissibility remain pending",
        "MAX-HIGH-1000000000": "not constructed; exact price and full-save admissibility remain pending",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"build_time_ms": construction_ms, "cases": [{k: c[k] for k in ("id", "input_bytes", "candidate_blocks", "sha256")} for c in cases]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
