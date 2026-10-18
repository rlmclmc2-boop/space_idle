"""Audit retained native-input traces without launching Godot."""
from pathlib import Path
import gzip
import hashlib
import json

root = Path(__file__).resolve().parent / "evidence/geometry-timing"


def load(label):
    with gzip.open(root / (label + ".json.gz"), "rt", encoding="utf-8") as stream:
        return json.load(stream)


before, unfixed, fixed = [load(s) for s in ("main51", "candidate-unfixed", "candidate-fixed")]
assert len(before) == len(unfixed) == len(fixed) == 721
fields = ("step", "clock", "player", "height", "aim", "muzzles", "incoming", "attacks")
actor_fields = ("uid", "position", "width", "angle", "hull", "center", "port")
for a, b in zip(before, fixed):
    assert all(a[k] == b[k] for k in fields), a["step"]
    assert len(a["actors"]) == len(b["actors"]) == 15
    for x, y in zip(a["actors"], b["actors"]):
        assert all(x[k] == y[k] for k in actor_fields), (a["step"], x["uid"])


def notifications(rows, field):
    # Same native_execution_session advance rule: emit when a counter changes.
    return [{"step":i - 1, "counter":rows[i][field]}
            for i in range(241, 721) if rows[i][field] != rows[i - 1][field]]


old_defence = notifications(before, "incoming")
new_defence = notifications(fixed, "incoming")
old_weapons = notifications(before, "attacks")
new_weapons = notifications(fixed, "attacks")
assert old_defence == new_defence and len(old_defence) == 192
assert old_weapons == new_weapons and len(old_weapons) == 50
assert len(notifications(unfixed, "incoming")) == 160
events_before, events_after = [load(s) for s in ("main51-events", "candidate-fixed-events")]
observed_before = [e for e in events_before["equipment_stats"] if 240 <= e["step"] < 720]
observed_after = [e for e in events_after["equipment_stats"] if 240 <= e["step"] < 720]
assert observed_before == observed_after and len(observed_before) == 242
assert events_before["events"] == events_after["events"]
state_before, state_after = [r["state_after"] for r in (events_before, events_after)]
assert all(state_before[k] == state_after[k] for k in state_before if k not in ("canonical_kernel", "kernel_hash"))
kernel_before, kernel_after = [r["canonical_kernel"] for r in (state_before, state_after)]
# The engine-created RNG's historical random seed differs; its transferred
# state, used for subsequent draws, matches. No gameplay field is excluded.
seed_before = kernel_before["rng"].pop("seed")
seed_after = kernel_after["rng"].pop("seed")
assert kernel_before == kernel_after
summary = {
    "baseline":"51a7e1b9bc5784927e7d5b232a112194d990a41c",
    "unfixed_candidate":"9cbd3d86453e25db9f73609c704d5ae6f57b00de",
    "dll_sha256":"B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA",
    "mode":"headless fixed-step diagnostic; not a performance measurement",
    "logical_steps":720, "state_snapshots":721, "actors_per_snapshot":15,
    "compared_global_fields":list(fields), "compared_actor_fields":list(actor_fields),
    "fixed_all_compared_values_equal":True,
    "unfixed_first_muzzle_difference":next(i for i,(a,b) in enumerate(zip(before,unfixed)) if a["muzzles"] != b["muzzles"]),
    "unfixed_first_incoming_difference":next(i for i,(a,b) in enumerate(zip(before,unfixed)) if a["incoming"] != b["incoming"]),
    "sample_defence_notifications":{"main51":192,"unfixed":160,"fixed":192},
    "sample_weapon_notifications":{"main51":50,"fixed":50},
    "fixed_notification_steps_and_values_equal":True,
    "actual_equipment_stats_payload_step_counter_trace_equal":True,
    "actual_sample_equipment_stats":[len(observed_before),len(observed_after)],
    "all_720_step_event_counts_equal":True,
    "final_public_state_equal":True,
    "final_kernel_equal_except_historical_rng_seed":True,
    "historical_rng_seeds":[seed_before,seed_after],
    "transferred_rng_state":kernel_before["rng"]["state"],
    "final_incoming":[before[-1]["incoming"],fixed[-1]["incoming"]],
    "final_attacks":[before[-1]["attacks"],fixed[-1]["attacks"]],
    "trace_sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.glob("*.json.gz"))},
    "scope":"laser fixture reused; other four fixtures not rerun; all eight runtime enemy mappings independently checked",
}
(root / "audit.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
print("GEOMETRY_TIMING_PASS snapshots=721 actors=15 defence=192/192 weapons=50/50")
