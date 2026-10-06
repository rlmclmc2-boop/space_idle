extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Config=preload("res://scripts/hyperspace_config.gd")
const FIXTURE:Dictionary={
 "source_snapshot": "/workspace/evidence-input/parent-pre-reforge-core-prefix/unpacked/hyperspace-parent-p1/diagnostics/parent-p1-fresh60/save_periodic_1800.json",
 "source_sha256": "3348bad0f79d5c5fe0ae11e528bee0030eb5fa2bb7d418500bfaee80b77eb403",
 "source_library_identity": {
  "transfer_id": "materialize-1",
  "file_id": "file_0000000078c48206921bc72b7903a192",
  "library_file_id": "libfile_9ae9b53186348191ba8223eaddbbc83b",
  "file_name": "parent-v6-live-evidence.zip",
  "suggested_path": "parent-v6-live-evidence.zip",
  "current_version_number": 20,
  "xattrs": [
   {
    "name": "user.library-file-version",
    "value": "20"
   }
  ],
  "workspace_path": null,
  "method": "GET",
  "headers": {},
  "mime_type": "application/zip",
  "size_bytes": 28801877
 },
 "actual_seed": 20261004,
 "source_x1": 1800.01666666536,
 "initial_random_state": "2727989612440780721",
 "actual_claim_schedule": [
  {
   "claimed_x1": 3036.61666667772,
   "request": {
    "round_id": 1,
    "run_id": 5,
    "route": "delta",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "677194716653549748",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:5",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "longLaser"
    },
    "hanging_rewards": {},
    "materials": {
     "zero_point_energy": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 3036.60000001105,
   "member": "hyperspace-parent-p1/diagnostics/parent-p1-fresh60/actions.jsonl"
  },
  {
   "claimed_x1": 3189.66666667967,
   "request": {
    "round_id": 1,
    "run_id": 6,
    "route": "alpha",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "7311466840492614045",
     "hanging_slots": 1,
     "hangings": [],
     "id": "space:1:6",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "laser"
    },
    "hanging_rewards": {},
    "materials": {
     "degenerate_matter": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 3189.650000013,
   "member": "hyperspace-parent-p1/diagnostics/parent-p1-fresh60/actions.jsonl"
  },
  {
   "claimed_x1": 13905.3666665485,
   "request": {
    "round_id": 1,
    "run_id": 9,
    "route": "gamma",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "-4807361108019410953",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:9",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "cannon"
    },
    "hanging_rewards": {},
    "materials": {
     "antiproton": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 13905.3499998818,
   "member": "hyperspace-parent-p1/diagnostics/parent-p1-fresh60/actions.jsonl"
  },
  {
   "claimed_x1": 24810.1999997231,
   "request": {
    "round_id": 1,
    "run_id": 12,
    "route": "beta",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "-6663608183160360026",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:12",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "missile"
    },
    "hanging_rewards": {},
    "materials": {
     "glueball": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 24810.1833330564,
   "member": "hyperspace-parent-p1/diagnostics/parent-p1-fresh60/actions.jsonl"
  },
  {
   "claimed_x1": 45562.4833355472,
   "request": {
    "round_id": 1,
    "run_id": 13,
    "route": "gamma",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "7794358040680059116",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:13",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "cannon"
    },
    "hanging_rewards": {},
    "materials": {
     "antiproton": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 45562.4833355472,
   "member": "/workspace/evidence-input/parent-natural-v6/hyperspace-parent-vfx/diagnostics/stage-parent-vfx-stage22-next7200-cached/actions.jsonl"
  },
  {
   "claimed_x1": 56394.8000044207,
   "request": {
    "round_id": 1,
    "run_id": 14,
    "route": "beta",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [
      {
       "key": "armour_capacity",
       "locked": false,
       "tier": 5,
       "value": 0.117
      }
     ],
     "blue_source_bonus": true,
     "forge_revision": 0,
     "forge_rng_state": "80864437933874082",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:14",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "blue",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "missile"
    },
    "hanging_rewards": {},
    "materials": {
     "glueball": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 56394.8000044207,
   "member": "/workspace/evidence-input/parent-natural-v6/hyperspace-parent-vfx/diagnostics/stage-parent-vfx-stage24-next14400-cached/actions.jsonl"
  },
  {
   "claimed_x1": 67162.4833392377,
   "request": {
    "round_id": 1,
    "run_id": 15,
    "route": "gamma",
    "level": 5
   },
   "planet_id": "1",
   "original_reward": {
    "drone": {
     "affixes": [],
     "blue_source_bonus": false,
     "forge_revision": 0,
     "forge_rng_state": "49991716156259672",
     "hanging_slots": 0,
     "hangings": [],
     "id": "space:1:15",
     "legendary": false,
     "legendary_effect": {},
     "level": 5,
     "omen": false,
     "origin_quality": "white",
     "planet_id": "1",
     "preserved_hanging_slots": 0,
     "ultimate": false,
     "ultimate_affix": {},
     "weapon": "cannon"
    },
    "hanging_rewards": {},
    "materials": {
     "antiproton": 1
    },
    "ultimate_cores": 0
   },
   "completed_x1": 67162.4833392377,
   "member": "/workspace/evidence-input/parent-natural-v6/hyperspace-parent-rational-v16/diagnostics/parent-rational-stage31-3600/actions.jsonl"
  }
 ],
 "scope": "Actual historical seven receipt requests/claim clocks; directed reward-function replay is conditional on this historical schedule, not a new native campaign clear/firstcore time acceptance."
}
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var fixture:Dictionary=FIXTURE.duplicate(true)
 var c:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_config.json"))
 var baseline:Dictionary=c.duplicate(true);baseline.quality_weights.ultimate_core=0.01
 check(Config.valid(c),"Formal candidate validates")
 check(c.quality_weights=={"white":0.5,"blue":0.26,"gold":0.15,"legendary":0.08,"ultimate_core":0.10},"Only raw core weight increases; ordinary relative proportions retained")
 check(c.tier_weights.size()==5 and c.tier_weights.keys().all(func(k):return float(c.tier_weights[k])==float({"1":1,"2":5,"3":15,"4":45,"5":135}[k])),"All affix tier weights unchanged numerically")
 check(c.policies.core_reward=="exclusive","Original exclusive reward rule retained")
 var old_state:Dictionary={"random_state":fixture.initial_random_state}
 var new_state:Dictionary=old_state.duplicate(true)
 var rows:Array=[];var first_core:Dictionary={};var cores:int=0
 for index in fixture.actual_claim_schedule.size():
  var draw:Dictionary=fixture.actual_claim_schedule[index]
  var old:Dictionary=Rewards.generate(old_state,baseline,draw.request,draw.planet_id)
  var next:Dictionary=Rewards.generate(new_state,c,draw.request,draw.planet_id)
  check(old.error.is_empty() and next.error.is_empty(),"Real historical request generates valid rewards")
  check(old.reward==draw.original_reward,"Baseline reproduces actual historical earned reward exactly")
  check(old.reward.materials==next.reward.materials,"Core candidate does not change ordinary earned materials")
  var core:bool=int(next.reward.ultimate_cores)==1
  check(not core or next.reward.drone.is_empty(),"Core replaces one drone under original exclusive rule")
  if core:
   cores+=1
   if first_core.is_empty():first_core={"successful_draw_index":index+1,"historical_claim_x1":draw.claimed_x1,"scope":"Fixed actual-seed reward replay conditional on the seven historical earned requests; NOT native first-core campaign time."}
  rows.append({"draw":index+1,"request":draw.request,"historical_claim_x1":draw.claimed_x1,"baseline_quality":old.reward.drone.get("origin_quality","core"),"candidate_quality":next.reward.drone.get("origin_quality","core"),"candidate_reward":next.reward,"rng_before":new_state.random_state,"rng_after":next.random_state})
  old_state.random_state=old.random_state;new_state.random_state=next.random_state
 var p:float=0.10/1.09
 var result:Dictionary={"checks":checks,"failures":failures,"candidate_probability":p,"mean_successful_draws":1.0/p,"median_successful_draws":8,"main_campaign_seed":fixture.actual_seed,"exploration_rng_note":"Fresh exploration RNG randomizes independently of main seed; captured saved exploration RNG makes this replay deterministic. Reforge creates a fresh randomized exploration stream. Main seed alone does not predict core time.","actual_initial_rng":fixture.initial_random_state,"candidate_core_rewards_in_seven":cores,"baseline_core_rewards_in_seven":0,"first_core":first_core,"replay":rows,"opportunity_cost":"Exclusive core replaces its receipt drone; ordinary drone probability99%→90.825688%, ~8.174312 percentage points fewer ordinary drones. Other qualities retain relative raw proportions. Core outcome consumes fewer RNG draws than a drone, so subsequent outcomes can diverge; no old business timing acceptance carries over.","scope":fixture.scope,"native_campaign_and_ultimate_use_acceptance":"Pending integrated candidate, not claimed by this directed test."}
 FileAccess.open(OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")+"/coreweight-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("CORE_WEIGHT ",checks," checks ",failures," failures; first_core ",JSON.stringify(first_core));quit(2 if failures else 0)
