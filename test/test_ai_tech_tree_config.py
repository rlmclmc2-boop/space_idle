"""Validate the authored runtime technology table and its prerequisite graph."""
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
rows = json.loads((ROOT / "space-battleship/data/ai_tech_tree.json").read_text(encoding="utf-8"))
assert len(rows) == 8
assert len({row["name"] for row in rows.values()}) == len(rows)
for key, row in rows.items():
    assert key and row["name"] and row["description"]
    assert row["tier"] in {"basic", "core", "ultimate", "independent"}
    assert math.isfinite(row["base_seconds"]) and row["base_seconds"] > 0
    assert math.isfinite(row["growth"]) and row["growth"] > 1
    assert math.isfinite(row["factor"]) and row["factor"] > 0
    for prerequisite, condition in row.get("requirements", {}).items():
        assert prerequisite in rows and prerequisite != key
        assert condition == "10*k+1" or isinstance(condition, int) and condition > 0
assert rows["equipment_finishing"]["requirements"] == {
    "weapon_accuracy": "10*k+1", "equipment_reinforcement": "10*k+1"
}
assert rows["uranium_extraction"]["requirements"] == {"resource_refining": "10*k+1"}
assert rows["unification"]["requirements"] == {"equipment_finishing": 10, "uranium_extraction": 10}
print("AI_TECH_CONFIG=PASS rows=8")
