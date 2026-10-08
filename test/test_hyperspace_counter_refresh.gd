extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.onboarding.completed=true
 g.profile.highestLevel=61;g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear()
 for key in g.profile.resources:g.profile.resources[key]=1e30
 g.profile.jewelFragments=1e30;g.invalidate_stat_cache()
 var rng=RandomNumberGenerator.new();rng.seed=5
 var d=Rewards.create_drone(rng,g.hyperspace.config,"refresh:drone","blue","laser",6,"1")
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.inventory.generation+=1
 scene.refresh_structure();scene.refresh_tab_visibility();scene.equipment_tabs.current_tab=9
 await process_frame
 var p=scene.hyperspace_panel;p.select_section(1);p.selected_id=d.id;p.refresh_details();p.dirty=false
 var details:String=p.details.text;var node_id:int=p.details.get_instance_id();var events:Array=[]
 g.event.connect(func(kind,payload):
  if kind=="equipment_stats":events.append(payload.duplicate(true)))
 var attacks:int=g.profile.enhancementAttacks;var hits:int=g.profile.enhancementHits
 g.record_enhancement_attack();g.record_enhancement_hit()
 check(not p.dirty and p.details.text==details,"attack/hit counters do not dirty drone base details")
 check(g.profile.enhancementAttacks==attacks+1 and g.profile.enhancementHits==hits+1,"ordinary combat counters still advance")
 check(events.size()==2 and events[0].category=="weapons" and events[1].category=="defence" and events.all(func(e):return e.counter_only),"counter events remain available to ordinary equipment consumers")
 check(scene.equipment_panel.dirty or not scene.equipment_panel.stats_dirty.is_empty(),"ordinary equipment consumer retains pending counter projection")
 # Untagged equipment_stats remains authoritative for real modifier changes.
 check(g.set_reactor_allocation("weapons",1.0) and p.dirty,"reactor modifier still invalidates drone detail")
 p.refresh()
 check(p.details.text!=details,"reactor changes displayed drone base damage")
 p.dirty=false
 var amount:int=g.upgrade_enhancement(1)
 check(amount==1 and p.dirty,"real enhancement purchase still invalidates")
 p.refresh();p.dirty=false
 p.on_event("equipment_stats",{"category":"weapons"})
 check(p.dirty,"galaxy and other untagged modifier events still invalidate")
 p.refresh();p.dirty=false
 p.hide();g.record_enhancement_attack();check(not p.dirty,"hidden panel remains clean for counter-only event")
 g.event.emit("equipment_stats",{"category":"weapons"});check(p.dirty,"hidden panel retains real invalidation")
 p.show();p.refresh();check(not p.dirty and p.details.get_instance_id()==node_id,"reveal catches up without replacing detail controls")
 scene.queue_free();await process_frame
 print("HYPERSPACE_COUNTER_REFRESH %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
