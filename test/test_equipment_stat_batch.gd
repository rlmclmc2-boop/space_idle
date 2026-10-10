extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 var snapshot_reads:=0
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func equipment_display_snapshot(entry:Dictionary,level:=-1)->Dictionary:
  snapshot_reads+=1
  return super.equipment_display_snapshot(entry,level)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")];g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.selectedShip="Heavy_Battleship";g.profile.enhancementLevel=30
 g.profile.loadout.weapons=[]
 for i in range(8):g.profile.loadout.weapons.append({"key":"missile","level":150})
 g.profile.loadout.defence=[{"key":"shield","level":150},{"key":"armour","level":150},{"key":"shield","level":150},{"key":"armour","level":150}]
 g.invalidate_stat_cache();g.reset_player();scene.refresh_structure();scene.select_system(0);await process_frame
 var panel=scene.equipment_panel
 for counters in [0,1,2,99,100,9999,1000000]:
  g.profile.enhancementAttacks=counters;g.profile.enhancementHits=counters;g.invalidate_stat_cache()
  var reference={}
  for id in panel.items:
   var item=panel.items[id];reference[id]=scene.equipment_display_snapshot(g.module_entry(item.category,item.index))
  scene.snapshot_reads=0;panel.invalidate_stats({"category":"weapons"});panel.invalidate_stats({"category":"defence"});panel.refresh_stats()
  check(scene.snapshot_reads==3,"eight missiles plus paired defence use three fresh projections")
  for id in reference:check(panel.items[id].projection==reference[id],"exact fresh independent oracle at counter "+str(counters))
 # Every refresh has new inputs; no stale result after a same-identity level change.
 g.profile.loadout.weapons[0].level=151;g.invalidate_stat_cache();panel.invalidate_stats({"category":"weapons"});panel.refresh_stats()
 check(panel.items[g.slot_id("weapons",0)].projection==scene.equipment_display_snapshot(g.module_entry("weapons",0)),"refit/level boundary stays fresh")
 for key in ["missile","cannon","shield","armour","laser","longLaser"]:
  var entry={"key":key,"level":150};var groups={};scene.snapshot_reads=0
  var first=panel.stat_projection(entry,groups);var second=panel.stat_projection(entry.duplicate(),groups)
  check(first==second,"identical full projection "+key)
  check(scene.snapshot_reads==(2 if key in ["laser","longLaser"] else 1),"source-dependent paths excluded "+key)
  first.expected=-1
  check(second.expected!=-1,"independent card ownership "+key)
 for extra in [{"drone_id":"test"},{"future_modifier":2}]:
  var entry={"key":"missile","level":150};entry.merge(extra);var groups={};scene.snapshot_reads=0
  panel.stat_projection(entry,groups);panel.stat_projection(entry,groups)
  check(scene.snapshot_reads==2 and groups.is_empty(),"extended entries keep original path")
 print("EQUIPMENT_STAT_BATCH ",checks," checks ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
