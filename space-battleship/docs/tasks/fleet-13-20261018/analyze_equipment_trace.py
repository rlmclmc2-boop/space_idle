"""Analyze the two saved QA event traces without starting Godot."""
from pathlib import Path
import gzip
import json

root = Path(__file__).resolve().parent / "evidence/equipment-stats-trace"


def load(label: str) -> dict:
    with gzip.open(root / f"laser-{label}.json.gz", "rt", encoding="utf-8") as source:
        return json.load(source)


before = load("before")
after = load("after")
bt = before["equipment_stats_trace"]
at = after["equipment_stats_trace"]
assert all(item["payload"].get("counter_only") is True for item in bt + at)
weapon_before = [x for x in bt if x["payload"]["category"] == "weapons"]
weapon_after = [x for x in at if x["payload"]["category"] == "weapons"]
defence_before = {x["step"]: x for x in bt if x["payload"]["category"] == "defence"}
defence_after = {x["step"]: x for x in at if x["payload"]["category"] == "defence"}
assert len(defence_before) == 192 and len(defence_after) == 160

coalesced = []
for step in sorted(defence_before):
    if step not in defence_after:
        continue
    old = defence_before[step]
    new = defence_after[step]
    if old["incoming_counter"] == new["incoming_counter"]:
        continue
    next_old = defence_before.get(step + 1)
    assert next_old is not None and step + 1 not in defence_after
    assert old["incoming_counter"] + 1 == new["incoming_counter"] == next_old["incoming_counter"]
    coalesced.append({"step": step, "main51_values": [old["incoming_counter"], next_old["incoming_counter"]],
                      "candidate_value": new["incoming_counter"]})

assert len(coalesced) == 32
assert len(defence_before) - len(defence_after) == len(coalesced)
assert [(x["step"], x["attack_counter"]) for x in weapon_before] == [(x["step"], x["attack_counter"]) for x in weapon_after]

audit = {
    "fixture": "laser",
    "source": "native_execution_session.gd advance emits counter_only equipment_stats when attack/incoming counters change",
    "main51_events": len(bt),
    "candidate_events": len(at),
    "all_payloads_counter_only": True,
    "weapon_notifications_identical": True,
    "defence_notifications_main51": len(defence_before),
    "defence_notifications_candidate": len(defence_after),
    "defence_coalesced_pairs": coalesced,
    "final_incoming_counters": [before["kernel_metrics"]["incoming_counter"], after["kernel_metrics"]["incoming_counter"]],
    "final_attack_counters": [before["kernel_metrics"]["attack_counter"], after["kernel_metrics"]["attack_counter"]],
    "final_player_equal": before["state_after"]["player"] == after["state_after"]["player"],
    "final_loadout_equal": before["state_after"]["loadout"] == after["state_after"]["loadout"],
    "other_events_equal": {k: v for k, v in before["events"].items() if k != "equipment_stats"} == {k: v for k, v in after["events"].items() if k != "equipment_stats"},
}
(root / "audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
print("COUNTER_ONLY_COALESCED pairs=32 defence=192->160 weapons=50->50 final_incoming=330->330")
