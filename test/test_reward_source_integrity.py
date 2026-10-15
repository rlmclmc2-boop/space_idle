"""Reject edits to the original reward source groups and their stage/node map."""
import copy
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "space-battleship/tools"))
import hyperspace_entities as entities

data = root / "space-battleship/data"
main = json.loads((data / "game_data.json").read_text(encoding="utf8"))
sources = json.loads((data / "space_enemy_reward_sources.json").read_text(encoding="utf8"))
frozen = json.loads((data / "space_enemy_reward_early_frozen.json").read_text(encoding="utf8"))
schema = entities.load_schema()

def rejected(label, source_rows, mainline):
    try:
        entities.validate_sources(source_rows, mainline, schema, frozen)
    except ValueError:
        return
    raise AssertionError(label + " accepted")

entities.validate_sources(sources, main, schema, frozen)
changed = copy.deepcopy(main)
changed["groups"]["30011"]["description"] = "tampered"
rejected("group content", sources, changed)
changed = copy.deepcopy(main)
member = str(changed["groups"]["30011"]["slots"][1])
changed["enemies"][member]["drops"][0]["amount"] += 1
rejected("member content", sources, changed)
changed = copy.deepcopy(main)
changed["levels"][0]["rewardReferenceGroups"][0]["id"] = 30012
rejected("wrong node", sources, changed)
changed = copy.deepcopy(main)
changed["levels"][0]["rewardReferenceGroups"][0]["id"] = 30021
rejected("cross-stage reference", sources, changed)
changed_sources = copy.deepcopy(sources)
changed_sources["waves"][0]["group"] = 30012
rejected("source mapping order", changed_sources, main)
books = {name: (root / "space-battleship/config_excel" / name).read_bytes()
         for name in ("hyperspace_config.xlsx", "hyperspace_enemies.xlsx")}
outputs, _ = entities.read_bundle(books, main, data)
assert len(outputs["space_enemy_candidates.json"]["groups"]) == 40
print("REWARD_SOURCE_INTEGRITY 7 checks 0 failures")
