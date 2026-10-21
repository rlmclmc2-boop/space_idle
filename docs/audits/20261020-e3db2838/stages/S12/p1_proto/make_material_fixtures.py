"""Audit-only exact MAX material stop controls at level 19."""
import json
from pathlib import Path

from price import quote

OUT = Path(__file__).resolve().parent / "generated_wallets"


def main():
    assert (quote(50.0, 0.2, 20), quote(50.0, 0.2, 21)) == (1600, 1900)
    for available in (0, 9, 10):
        profile = {
            "evolution": {"interval": 20, "material_cost_per_tier": 10, "material_id": "degenerate_matter"},
            "hyperspace": {"materials": {"degenerate_matter": available}},
            "laser_level": 19,
            "resources": {"1": 2550, "2": 0},
            "events": [],
            "save_dirty": False,
        }
        expected = {
            "classification": "audit-only material stop control, not official P1 benchmark",
            "expected_count": 1 if available == 10 else 0,
            "first_unaffordable_price": "1900" if available == 10 else "1600",
            "remaining_after_expected_purchases": "950" if available == 10 else "2550",
            "remaining_material": 0 if available == 10 else available,
            "stop_reason": "insufficient_resource" if available == 10 else "insufficient_material",
        }
        (OUT / f"MAX-MATERIAL-{available}.json").write_text(json.dumps(profile, sort_keys=True, separators=(",", ":")), encoding="utf-8")
        (OUT / f"MAX-MATERIAL-{available}.manifest.json").write_text(json.dumps(expected, sort_keys=True, separators=(",", ":")), encoding="utf-8")
        print(json.dumps({"material": available, **expected}, sort_keys=True))


if __name__ == "__main__":
    main()
