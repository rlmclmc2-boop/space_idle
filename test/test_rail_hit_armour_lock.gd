extends SceneTree
class UI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
var checks:=0
var failures:=0
var events:Array=[]
var cases:Array=[]
var scene
var folder:String
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func fixture(count:int=2)->void:
	var g=scene.game
	g.profile.loadout.weapons[0]={"key":"cannon","level":150}
	g.db.equipment.cannon[0].dmg=100;g.db.equipment.cannon[0].dmgMulti=0
	g.db.data.enhance_config.base_critical_rate.value=0
	g.db.data.enhance_config.repeat_probability.value=0
	g.profile.enhancementLevel=50;g.profile.enhancementBranches=g.default_enhancement_branches()
	g.reset_player();g.start(1,false);g.spawn_group()
	var original:Dictionary=g.enemies[0].duplicate(true)
	g.enemies.clear()
	for n in count:
		var enemy:Dictionary=original.duplicate(true)
		enemy.uid=10000+n;enemy.hp=100000.0;enemy.max_hp=enemy.hp
		enemy.shield=0.0;enemy.max_shield=0.0;enemy.armourType=0;enemy.shieldType=0
		enemy.x=200.0+n*80.0;enemy.y=120.0;enemy.equipment=[];enemy.cooldowns=[];enemy.drops=[]
		g.enemies.append(enemy)
	g.cooldowns={"weapons_0":1000.0,"weapons_1":1000.0,"weapons_2":1000.0}
	g.refresh_missile_target_registry();scene.rail_events.clear();events.clear()
func primary()->void:
	var g=scene.game
	g.begin_enhancement_attack(0,g.enemies[0])
	g.jewel_fire(0,g.enemies[0],g.player_weapon_row(g.slot_entry("weapons",0)),g.player_weapon_offset(0))
func finish()->void:scene.game.finish_enhancement_attack(0)
func capture(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run()->void:
	folder=OS.get_environment("RAIL_ARMOUR_EVIDENCE")
	if folder.is_empty():folder=ProjectSettings.globalize_path("res://../rail-armour-evidence")
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://main.tscn").instantiate();scene.set_script(UI)
	scene.automation_args=["--capture"];scene.music_on=false;scene.sound_on=false
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.cleared=range(1,76);g.rebuild_unlocks();g.pending_unlocks.clear()
	g.event.connect(func(kind,info):
		if kind in ["fire","projectile_impact","hit","explode"]:
			events.append({"kind":kind,"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"fx_time":scene.fx_time,"serial":int(info.get("shot",{}).get("serial",-1)),"rail_visual_count":scene.rail_events.size()}))
	fixture()
	var target:Dictionary=g.enemies[0];var untouched:Dictionary=g.enemies[1]
	target.shield=50.0;target.max_shield=50.0
	var before:float=target.hp+target.shield
	g.cooldowns.weapons_0=0.001
	scene._process(1.0/60.0) # Actual production scheduler and draw clock.
	check(target.hp+target.shield<before,"Primary damage settles before launch returns")
	check(untouched.hp==100000.0,"Screen extension adds no penetration damage")
	check(events.map(func(e):return e.kind)==["fire","projectile_impact","hit"],"One primary follows canonical fire-impact-hit order")
	check(events.all(func(e):return e.frame==events[0].frame and e.physics_frame==events[0].physics_frame and e.fx_time==events[0].fx_time),"Actual damage and visual discharge share the same Godot frame and UI time")
	check(events[0].rail_visual_count>=1 and scene.rail_events.any(func(e):return e.kind=="hit"),"Visible discharge exists in damage frame")
	check(g.projectiles.is_empty(),"Primary is retired before any future collision tick")
	cases.append({"case":"shielded-primary-production-scheduler","events":events.duplicate(true),"before":before,"after":target.hp+target.shield})
	await capture("rail-hit-frame")
	var hp:float=target.hp
	for step in 12:scene._process(1.0/60.0)
	check(target.hp==hp and scene.rail_events.any(func(e):return e.kind=="fire"),"Afterglow remains visible without another hit")
	await capture("rail-afterglow")
	fixture();g.db.data.enhance_config.repeat_probability.value=1
	primary();g.queue_jewel_repeats(0,1.0);finish()
	check(not g.jewel_repeats.is_empty(),"Actual repeat plan queues a delayed second attack")
	var hits_before:int=events.filter(func(e):return e.kind=="hit").size()
	g.advance_jewel_repeats(float(g.enhancement_parameter("repeat_delay"))+0.001)
	check(events.filter(func(e):return e.kind=="hit").size()==hits_before+1,"Delayed repeat settles exactly one immediate primary")
	check(events.filter(func(e):return e.kind=="fire").size()==2 and g.projectiles.is_empty(),"Repeat has two discharges and no stale damaging projectiles")
	cases.append({"case":"actual-repeat","events":events.duplicate(true)})
	fixture();g.db.data.enhance_config.repeat_b3_probability.value=1
	check(g.set_enhancement_branch("weapons","repeat",3,"B"),"Legal secondary branch fixture")
	primary();g.launch_enhancement_secondary(0,g.enemies[0],g.player_weapon_row(g.slot_entry("weapons",0)),1.0);finish()
	check(events.filter(func(e):return e.kind=="fire").size()==2 and events.filter(func(e):return e.kind=="hit").size()==2,"Actual secondary keeps two independent single settlements")
	check(g.enemies[1].hp<100000.0,"Existing secondary still reaches a distinct target")
	fixture();check(g.set_enhancement_branch("weapons","repeat",1,"B"),"Legal chain branch fixture")
	primary();finish()
	check(g.enemies[0].hp<100000.0 and g.enemies[1].hp==100000.0,"Primary is immediate while existing chain retains flight")
	check(g.projectiles.size()==1 and g.projectiles[0].get("chain_hop",false),"Primary retirement preserves exactly one real chain carrier")
	for step in 30:g.tick_projectiles(1.0/60.0)
	check(g.enemies[1].hp<100000.0 and events.filter(func(e):return e.kind=="hit").size()==2,"Chain arrives once without duplicate primary or recursion")
	cases.append({"case":"actual-chain","events":events.duplicate(true)})
	fixture(1);g.group_index=g.db.levels[0].groups.size();g.enemies[0].hp=1
	g.projectiles.append({"sentinel":true})
	primary();finish()
	check(g.projectiles.is_empty() and events.filter(func(e):return e.kind=="explode").size()==1,"Final enemy cleanup is safe during immediate settlement")
	for step in 60:g.tick_projectiles(1.0/60.0)
	check(events.filter(func(e):return e.kind=="hit").size()==1,"Final hit cannot recur after clearing the live projectile array")
	cases.append({"case":"final-kill","events":events.duplicate(true)})
	fixture();g.fire(g.enemies[0],g.player,g.db.enemy_weapon("cannon-mon"),10.0,true,"cannon-mon")
	check(g.projectiles.size()==1 and events.filter(func(e):return e.kind=="hit").is_empty(),"Hostile cannon retains its original travelling collision")
	# Modern and legacy save boundaries are read-only fixtures in this isolated user dir.
	var fresh=BattleGame.new(ShipDatabase.new(),false)
	check(fresh.slot_entry("defence",0).key=="armour","New game fixes first defence slot to real armour key")
	var raw:Dictionary=g.portable_save_data();raw.resources={"1":4321.0,"2":987.0}
	raw.loadout.defence=[{"key":"shield","level":37},{"key":"armour","level":21}]
	raw.loadout.weapons[0].level=19
	for version in [2,3,BattleGame.SAVE_VERSION]:
		var copy:Dictionary=raw.duplicate(true);copy.version=version
		var restored=BattleGame.new(ShipDatabase.new(),false);restored.load_progress_data(copy)
		check(restored.slot_entry("defence",0)=={"key":"armour","level":37},"Save migration preserves first-slot investment v"+str(version))
		check(restored.slot_entry("defence",1)==raw.loadout.defence[1] and restored.slot_entry("weapons",0).level==19,"Save migration preserves other slots v"+str(version))
		check(restored.profile.resources==raw.resources,"Save migration does not spend/refund resources v"+str(version))
		check(not restored.equip_slot("defence",0,"shield") and not restored.unequip_slot("defence",0),"Model rejects first-slot replacement/removal")
		check(restored.equip_slot("defence",0,"armour") and restored.slot_entry("defence",0).level==37,"Idempotent armour selection keeps growth")
		var roundtrip=BattleGame.new(ShipDatabase.new(),false);roundtrip.load_progress_data(restored.portable_save_data())
		check(roundtrip.profile.loadout==restored.profile.loadout and roundtrip.profile.resources==raw.resources,"Portable export/import retains repaired loadout")
	var empty_save:Dictionary=raw.duplicate(true);empty_save.loadout.defence[0]={"key":"","level":42}
	var empty_restored=BattleGame.new(ShipDatabase.new(),false);empty_restored.load_progress_data(empty_save)
	check(empty_restored.slot_entry("defence",0)=={"key":"armour","level":42},"Empty first slot repairs without losing its growth")
	check(fresh.default_loadout(fresh.first_ship(),["shield","armour"]).defence[0].key=="armour","Unlock ordering cannot replace fixed default armour")
	var legacy:Dictionary=raw.duplicate(true);legacy.moduleVersion=0;legacy.levels={"armour":5,"shield":8,"cannon":4}
	var restored=BattleGame.new(ShipDatabase.new(),false);restored.load_progress_data(legacy)
	check(restored.slot_entry("defence",0).level==37 and restored.slot_entry("defence",1).level==21 and restored.slot_entry("weapons",0).level==19,"Older name-level map cannot downgrade explicit slot investment")
	restored.profile.resources={"1":1e20,"2":1e20}
	check(restored.upgrade_slot("defence",0) and restored.slot_entry("defence",0).level==38,"Fixed armour still upgrades using actual costs")
	check(restored.equip_slot("defence",1,"shield") and restored.unequip_slot("defence",1),"Other defence slots remain freely swappable")
	var draft:Dictionary=restored.default_loadout("Heavy_Battleship",restored.profile.unlocked)
	draft.defence[0].key="shield"
	check(not restored.valid_loadout("Heavy_Battleship",draft) and not restored.switch_ship("Heavy_Battleship",draft),"Hull draft cannot bypass fixed armour")
	check(restored.switch_ship("Heavy_Battleship") and restored.slot_entry("defence",0).key=="armour" and restored.slot_entry("defence",0).level==38,"Hull switch preserves fixed armour and level")
	restored.save_enabled=true;restored.save_progress()
	var restarted=BattleGame.new(ShipDatabase.new(),true);restarted.save_enabled=false
	check(restarted.slot_entry("defence",0).key=="armour" and restarted.slot_entry("defence",0).level==38,"Actual isolated disk restart preserves fixed armour")
	fixture();g.ensure_loadout();scene.refresh_structure();scene.select_system(0)
	await process_frame;await process_frame
	var panel=scene.equipment_panel;panel.refresh();panel.select_item("defence_0");panel.show_inspector();panel.refresh_detail({},true)
	var card=panel.cards.defence_0
	check(card.name_button.disabled and card.equipment_options==["armour"],"Inline first-slot menu is disabled and exposes only armour")
	check(panel.detail.slots.disabled and panel.detail.remove.disabled and panel.detail.equip.disabled,"Inspector replacement, removal and confirmation disabled")
	var before_key:Dictionary=g.slot_entry("defence",0).duplicate(true)
	panel.open_picker("defence_0");panel.change_card_equipment("defence_0","shield");panel.change_equipment("");panel.act("remove")
	check(not card.name_button.get_popup().visible and g.slot_entry("defence",0)==before_key,"All UI callback entrypoints preserve fixed armour")
	var children:int=scene.get_child_count();scene.confirm_unequip("defence",0)
	check(scene.get_child_count()==children,"Legacy removal entry opens no forbidden dialog")
	g.profile.resources={"1":1e20,"2":1e20};panel.refresh();panel.refresh_detail({},true)
	check(not card.upgrade_button.disabled and not panel.detail.upgrade.disabled,"Inline and inspector upgrade controls remain enabled")
	await capture("fixed-armour-slot")
	var report={"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"scope":"Controlled real scene and isolated save boundary fixtures; no progression replay","cases":cases}
	FileAccess.open(folder+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RAIL HIT / ARMOUR LOCK checks=",checks," failures=",failures," evidence=",folder)
	g.launch_provider=Callable();g.target_provider=Callable();scene.queue_free();await process_frame;current_scene=null
	quit(1 if failures else 0)
