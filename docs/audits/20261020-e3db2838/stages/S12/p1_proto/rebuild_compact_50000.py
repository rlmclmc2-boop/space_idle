"""Independent exact-integer reduction of exploratory Godot compact quotes."""
import hashlib
import json
from pathlib import Path

from ledger import CurrencyValue
from price import material, oracle

OUT = Path(__file__).resolve().parent / "generated_wallets"


def main():
    raw = (OUT / "godot_prices_50000_compact.json").read_bytes()
    compact = json.loads(raw)
    prior = json.loads((OUT / "godot_prices_3873.json").read_bytes())
    assert len(compact) == 50_000

    def exact(entry):
        if isinstance(entry, str):
            return int(entry)
        assert isinstance(entry, list) and len(entry) == 2
        leading, power = entry
        assert type(leading) is int and type(power) is int and 10 <= leading <= 100 and power >= 0
        return leading * 10**power

    assert all(exact(entry) == int(reference) for entry, reference in zip(compact[:len(prior)], prior))
    assert exact(compact[9998]) == oracle(50.0, 0.2, 10_000)
    assert exact(compact[49998]) == oracle(50.0, 0.2, 50_000)
    costs = [exact(entry) for entry in compact]
    wallet = sum(costs[:-1]) + costs[-1] // 2
    stored = CurrencyValue.from_integer(wallet).encode()
    profile = {
        "evolution": {"interval": 20, "material_cost_per_tier": 10, "material_id": "degenerate_matter"},
        "hyperspace": {"materials": {"degenerate_matter": sum(map(material, range(2, 50_001))) }},
        "laser_level": 1,
        "resources": {"1": stored, "2": 0},
    }
    blob = json.dumps(profile, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    (OUT / "MAX-50000-GODOT-EXPLORATORY.json").write_bytes(blob)
    report = {
        "classification": "exploratory input, not frozen official P1 benchmark",
        "compact_price_list_sha256": hashlib.sha256(raw).hexdigest(),
        "compact_price_list_bytes": len(raw),
        "price_count": len(costs),
        "quote_cross_checks": "all first 3873 match frozen Godot export; levels 10000 and 50000 match independent Decimal oracle",
        "wallet_sha256": hashlib.sha256(blob).hexdigest(),
        "wallet_bytes": len(blob),
        "wallet_blocks": len(stored["blocks"]),
        "expected_count": 49_999,
        "first_unaffordable_price": str(costs[-1]),
        "remaining_after_expected_purchases": str(costs[-1] // 2),
        "material_wallet": profile["hyperspace"]["materials"]["degenerate_matter"],
    }
    (OUT / "MAX-50000-GODOT-EXPLORATORY.manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in ("first_unaffordable_price", "remaining_after_expected_purchases")}))


if __name__ == "__main__":
    main()
