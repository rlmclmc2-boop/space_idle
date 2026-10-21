"""Rebuild exploratory MAX-3873 wallet from every Godot-produced S09 price."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from ledger import CurrencyValue
from price import material, oracle

OUT = Path(__file__).resolve().parent / "generated_wallets"


def main() -> None:
    source = (OUT / "godot_prices_3873.json").read_bytes()
    values = json.loads(source)
    assert len(values) == 3873
    assert all(type(v) is str and v.isdecimal() and (v == "0" or not v.startswith("0")) for v in values)
    assert int(values[-2]) == oracle(50.0, 0.2, 3873)
    assert int(values[-1]) == oracle(50.0, 0.2, 3874)
    costs = list(map(int, values))
    wallet = sum(costs[:-1]) + costs[-1] // 2
    stored = CurrencyValue.from_integer(wallet).encode()
    profile = {
        "evolution": {"interval": 20, "material_cost_per_tier": 10, "material_id": "degenerate_matter"},
        "hyperspace": {"materials": {"degenerate_matter": sum(map(material, range(2, 3874)))}},
        "laser_level": 1,
        "resources": {"1": stored, "2": 0},
    }
    blob = json.dumps(profile, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    (OUT / "MAX-3873-GODOT.json").write_bytes(blob)
    report = {
        "classification": "exploratory input, not official P1 timing",
        "price_list_sha256": hashlib.sha256(source).hexdigest(),
        "price_list_bytes": len(source),
        "price_count": len(costs),
        "finite_reference": "main database.gd binary64 branch compared inside export_prices_3873.gd; 3871/3871 exact",
        "overflow_reference": "independent price.py Decimal oracle at levels 3873 and 3874; 2/2 exact",
        "wallet_sha256": hashlib.sha256(blob).hexdigest(),
        "wallet_bytes": len(blob),
        "wallet_blocks": len(stored["blocks"]),
        "expected_count": 3872,
        "first_unaffordable_price": str(costs[-1]),
        "remaining_after_expected_purchases": str(costs[-1] // 2),
        "material_wallet": profile["hyperspace"]["materials"]["degenerate_matter"],
    }
    (OUT / "MAX-3873-GODOT.manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
