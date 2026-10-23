extends SceneTree
const Region=preload("res://scripts/galaxy_region.gd")
var checks:=0
var failures:=0
class Refused extends RefCounted:
 var advance_blocked:=false
 var galaxy_refit_blocked:=false
 var calls:=0
 func handoff_to_legacy(_g,_why)->bool:calls+=1;return false
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func fresh(db):
 var row:Dictionary=db.data.galaxy.galaxy_1.duplicate(true)
 row.merge({"map_w":20,"map_h":20,"start_w":2,"start_h":2,"building_slot_count":4,"explore_work_total":100.0,"explore_power_base":1.0,"explore_power_per_crew":1.0,"build_interval":2.0,"construction_time":2.0,"upgrade_power_base":1.0,"upgrade_power_per_crew":1.0,"upgrade_cost_lv2":4.0,"upgrade_cost_lv3":4.0,"upgrade_cost_lv4":4.0,"upgrade_cost_lv5":4.0,"concurrent_upgrade_count":2},true)
 var r=Region.new();r.setup(row,db.data.galaxy_build,8);r._state.status="exploring";return r
func _initialize()->void:
 var db=ShipDatabase.new()
 for mode in ["empty","working","finishing","upgrade-start","upgrade-finish"]:
  for dt in [0.001,0.5,1.99,2.0,4.0,20.0]:
   var r=fresh(db)
   if mode in ["working","finishing"]:
    r._slots[0].status="constructing";r._slots[0].level=1;r._slots[0].construction=2.0
    r._slots[0].work=0.0 if mode=="working" else r.work_cost()
   if mode.begins_with("upgrade"):
    r._state.status="developing";r._state.explore_work=100.0
    for slot in r._slots:slot.status="active";slot.level=1;slot.work=r.work_cost()
    if mode=="upgrade-finish":
     for i in 2:r._slots[i].status="upgrading";r._slots[i].upgrade_progress=3.0
   r.changed();r.refresh_counts()
   var before=r.save_data().duplicate(true);var rng=r.random.state;var map_rng=r.map_random.state
   var due:bool=r.revision_due(dt,1)
   check(before==r.save_data() and rng==r.random.state and map_rng==r.map_random.state,"preflight pure "+mode)
   var projected=r.predict_advance(dt,1)
   check(before==r.save_data() and rng==r.random.state and map_rng==r.map_random.state,"building prediction leaves live state untouched "+mode)
   var revision:int=r.building_revision;r.advance(dt,1)
   check(projected.state==r._state and projected.building_revision==r.building_revision and projected.random.state==r.random.state,"prediction matches actual state and random continuation "+mode)
   check(due==(r.building_revision!=revision),"boundary prediction "+mode+" "+str(dt))
 # Final work completion is not full progress: construction participates
 # in node_progress(). Cover transition to upgrading with time left in dt.
 for dt in [1.0,30.5,31.0]:
  var r=fresh(db);r.row.construction_time=30.0
  for slot in r._slots:slot.status="active";slot.level=1;slot.work=r.work_cost();slot.construction=0.0
  var last:Dictionary=r._slots.back();last.status="constructing";last.work=r.work_cost()-1.0;last.construction=30.0
  r._state.status="exploring";r._state.explore_work=float(r.row.explore_work_total)-1.0;r.changed();r.refresh_counts()
  var revision:int=r.building_revision;var due:bool=r.revision_due(dt,1)
  r.advance(dt,1)
  check(due==(r.building_revision!=revision),"last work / construction / upgrade boundary "+str(dt))
  check(float(r._state.explore_work)==float(r.row.explore_work_total),"last work reaches recorded total "+str(dt))
  if dt==1.0:
   check(r._state.status=="exploring" and r.progress()<1.0 and last.construction>0 and r._slots.all(func(slot):return slot.status!="upgrading"),"remaining construction prevents early developing and upgrade selection")
  else:
   check(r._state.status=="developing" and last.status in ["active","upgrading"],"completion enters developing only after first revision "+str(dt))
   if dt>30.5:check(r._slots.any(func(slot):return slot.status=="upgrading"),"remaining substep can begin upgrades after preflighted completion")
 var g=BattleGame.new(db,false);g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
 check(g.assign_crew("navigator","galaxy_explore","galaxy_1"),"ordinary galaxy assignment")
 var saved:Dictionary=g.galaxy.save_data();var city:Dictionary=saved.galaxies.galaxy_1
 var chosen:=""
 for row in g.galaxy.regions.galaxy_1.builds.values():
  if row.effect_type=="equipment_value":chosen=row.key;break
 city.slots[0].type=chosen;city.slots[0].planned_type=chosen;city.slots[0].status="constructing";city.slots[0].level=1
 city.slots[0].work=g.galaxy.regions.galaxy_1.work_cost();city.slots[0].construction=0.01
 city.blueprint.nodes[0].type=chosen;city.blueprint.nodes[0].planned_type=chosen
 city.explore_work=g.galaxy.regions.galaxy_1.work_cost()
 check(g.galaxy.install_snapshot(saved,g.db),"boundary fixture installs real combat contribution")
 var region=g.galaxy.regions.galaxy_1
 g.galaxy.set_pending_context("galaxy_1",1);g.galaxy.add_pending("galaxy_1",9.99-g.galaxy.pending("galaxy_1"))
 var refusal=Refused.new();g.native_execution=refusal
 var state=region.save_data().duplicate(true);var clock=g.production_time();var resources=g.economy.resources();var rng=g.rng.state
 g.tick(1.0/60.0)
 check(not g.step_progress.reason.is_empty() and g.paused,"failed transfer blocks before shared phase")
 check(region.save_data()==state and g.galaxy.pending("galaxy_1")==9.99,"failed transfer retains region and pending time")
 check(g.production_time()==clock and g.economy.resources()==resources and g.rng.state==rng,"failed transfer has no clock income combat RNG side effects")
 g.paused=false;g.galaxy.add_pending("galaxy_1",10.0-g.galaxy.pending("galaxy_1"))
 check(not g.galaxy_runtime.flush_pending(g,"galaxy_1") and g.galaxy.pending("galaxy_1")==10.0 and region.save_data()==state,"direct flush failure retains all work")
 # The one online cadence preflights combined pending and new work.
 g.paused=false;refusal.advance_blocked=false
 g.galaxy.add_pending("galaxy_1",9.0-g.galaxy.pending("galaxy_1"));g.galaxy_runtime.reset()
 check(not g.galaxy_runtime.prepare_advance(g,1.0) and g.galaxy.pending("galaxy_1")==9.0 and region.save_data()==state,"combined pending/new batch preflight is pure")
 g.native_execution=null
 FileAccess.open("res://.runtime/galaxy-boundary-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
 print("GALAXY_BOUNDARY_CHECKS ",checks," failures ",failures)
 quit(1 if failures else 0)
