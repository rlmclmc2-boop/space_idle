extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func drone_source(g) -> Dictionary:
 return g.combat_weapon_entries().filter(func(entry):return entry.get("drone_id","")=="growth-white")[0]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1178,814);root.gui_embed_subwindows=true
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.paused=true;g.save_enabled=false;g.profile.cleared=range(1,10);g.profile.highestLevel=10;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.hyperspace.unlocked_drones=true;g.profile.selectedShip="Frigate"
 g.profile.loadout={"weapons":[{"key":"laser","level":42},{"key":"cannon","level":42},{"key":"missile","level":42}],"defence":[{"key":"armour","level":42},{"key":"shield","level":42}]}
 for id in g.profile.resources:g.profile.resources[id]=1e30
 var rng=RandomNumberGenerator.new();rng.seed=54
 var d=Rewards.create_drone(rng,g.hyperspace.config,"growth-white","white","laser",1,"1");d.affixes=[];d.hangings=[]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config) and g.hyperspace.set_equipped(g,[d.id]),"Equip plain body-level-one drone")
 g.refresh_drone_weapon_floor();g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.select_section(1);p.choose_drone(d.id)
 check(drone_source(g).level==42,"Initial combat source inherits 42")
 check(g.upgrade_equipment_batch("1") and drone_source(g).level==43,"Automatic handler's batch API advances actual drone growth")
 for index in 3:check(g.upgrade_slot("weapons",index,1),"Manual weapon upgrade through same public API")
 check(p.dirty,"Upgrade events invalidate visible drone weapon details")
 p.refresh()
 check(drone_source(g).level==44 and p.equipment_ui.slots[0].text.contains("武器等级 44") and p.details.text.contains(p.t("drone_independent_weapon",{"weapon":p.t("laser"),"level":"44"})),"Manual upgrades update both actual combat source and slot/details")
 # Reproduce a newly unlocked fourth slot while the player retains the three-slot hull.
 g.profile.cleared=range(1,16);g.profile.highestLevel=16;g.profile.droneWeaponFloor=42;g.rebuild_unlocks();g.pending_unlocks.clear()
 for i in 3:g.profile.loadout.weapons[i].level=[110,107,106][i]
 g.invalidate_stat_cache();g.refresh_drone_weapon_floor()
 check(g.lowest_unlocked_weapon_slot()==3 and g.lowest_unlocked_weapon_level()==1 and drone_source(g).level==42,"Unmaterialized unlocked W04 explains actual 42, not a display cache")
 check(g.crew.assign(g,"navigator","equipment_upgrade","equipment","1"),"Assign equipment crew using actual automatic path")
 g.paused=false;g.crew.advance(g,1.1);g.paused=true
 check(g.profile.loadout.weapons[0].level==111 and drone_source(g).level==42,"Crew upgrades enabled weapons while inactive W04 retains inherited floor")
 p.refresh_manual_status();p.dirty=true;p.refresh()
 check(p.equipment_ui.slots[0].text.contains("武器等级 42") and p.equipment_ui.slots[0].tooltip_text.contains("W04") and p.equipment_ui.slots[0].tooltip_text.contains(p.t("drone_growth_inactive_slot")),"Slot's true level and hover explain the actual inactive bottleneck")
 p.details_expanded=true;p.refresh_details()
 check(p.details.text.contains(p.drone_growth_basis_text()) and p.details.text.contains("W04"),"Expanded details share the same growth basis")
 var profile_before=JSON.stringify(g.profile);var state=g.rng.state;var generation=g.profile.hyperspace.inventory.generation
 p.refresh_details();scene.select_system(0);await process_frame;scene.select_system(9);await process_frame;p.dirty=true;p.refresh()
 check(JSON.stringify(g.profile)==profile_before and g.rng.state==state and g.profile.hyperspace.inventory.generation==generation and p.equipment_ui.slots[0].text.contains("武器等级 42"),"Reopening reads actual growth without modifying inventory, profile or RNG")
 var evidence=OS.get_environment("DRONE_GROWTH_EVIDENCE")
 if DisplayServer.get_name()!="headless" and not evidence.is_empty():
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(evidence)
 check(g.switch_ship("Destroyer"),"Enable the unlocked fourth slot through normal hull API")
 check(g.upgrade_slot("weapons",3,105) and drone_source(g).level==106,"Manual catch-up of W04 releases the same actual growth floor")
 p.refresh()
 var old_source=drone_source(g)
 g.paused=false;g.crew.advance(g,1.1);g.paused=true
 check(p.dirty,"Actual crew upgrade event invalidates visible drone weapon details")
 p.refresh()
 check(drone_source(g).level==107 and old_source.level==106 and p.equipment_ui.slots[0].text.contains("武器等级 107"),"Automatic crew advances future drone source after all enabled slots catch up; old source stays frozen")
 check(g.profile.hyperspace.inventory.drones[d.id].level==1,"Inherited weapon growth never changes drone body level")
 scene.queue_free();await process_frame
 print("Drone upgrade inheritance: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
