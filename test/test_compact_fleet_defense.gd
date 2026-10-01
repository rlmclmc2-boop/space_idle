extends SceneTree
const N := preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
var scene
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
	scene.refresh_draw_layers(0)
	scene.battle_layer.queue_redraw()
	scene.battle_hud_layer.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/compact-"+name+".png")
func fixture()->void:
	scene.game.profile.cleared=range(1,89)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.highestLevel=89
	scene.game.profile.onboarding.completed=true
	scene.game.pending_unlocks.clear()
	scene.game.switch_ship("Heavy_Battleship")
	for i in scene.game.weapon_entries().size():scene.game.slot_entry("weapons",i).merge({"key":["laser","cannon","missile"][i%3],"level":150},true)
	for i in scene.game.defense_entries().size():scene.game.slot_entry("defence",i).merge({"key":"armour" if i%2==0 else "shield","level":150},true)
	scene.game.invalidate_stat_cache()
	scene.game.reset_player()
	scene.game.start(89,false)
	scene.game.spawn_group()
	scene.game.pending_unlocks.clear()
	scene.game.paused=true
	scene.show_damage_numbers=false
	scene.refresh_structure()
	scene.current_hull="Heavy_Battleship"
	scene.ship_view.set_hull("Heavy_Battleship")
	scene.ship_view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	scene._set_reference_dimensions()
	scene.ship_view.set_pose(scene.player_render_position(),scene.reference_height,0,Vector2(280,120),0,false,false,0)
func run()->void:
	scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.music.stop()
	fixture()
	var original_hull_height:float=scene.reference_height
	root.size=Vector2i(1180,738)
	await capture("fleet-after")
	var view=scene.ship_view
	for dimensions in [Vector2i(1180,738),Vector2i(960,600)]:
		root.size=dimensions
		for hull in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
			view.set_hull(hull)
			scene.game.profile.selectedShip=hull
			scene._set_reference_dimensions()
			var anchor:Vector2=scene.player_render_position()
			var height:float=scene.reference_height
			for count in [0,3,7]:
				var entries:Array=[]
				for i in int(view.hull_config.hull_mount_budget)+count:entries.append({"key":["laser","missile","cannon","longLaser"][i%4],"level":1})
				check(view.set_loadout(entries,entries.size()),"Configured carrier capacity accepted "+hull+str(count))
				check(view.carriers.size()==count,"Active assignment owns count "+hull+str(count))
				var previous:Array=[]
				for step in 240:
					view.set_pose(anchor,height,0,Vector2(286,120),step*.1,false,false,.1)
					for carrier in view.carriers:
						var center:Vector2=view.camera.unproject_position(carrier.global_position)
						var radius:float=1.6*carrier.scale.x/view.WORLD_PER_PIXEL+3
						check(Rect2(Vector2.ONE*8,view.size-Vector2.ONE*16).encloses(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2)),"Carrier geometry remains in battlefield "+hull)
						check(absf(center.x-anchor.x)+radius<=view.FLEET_HALF_EXTENT.x+.01 and absf(center.y-anchor.y)+radius<=view.FLEET_HALF_EXTENT.y+.01,"Carrier count never expands fleet envelope "+hull)
					if step==0:
						for carrier in view.carriers:previous.append(carrier.global_position)
				if count>0:check(previous[0].distance_to(view.carriers[0].global_position)>0.5,"Carrier moves independently "+hull)
				if count>1:
					check(not (view.carriers[0].global_position-previous[0]).is_equal_approx(view.carriers[1].global_position-previous[1]),"Distinct carrier phases and speeds "+hull)
	fixture()
	view=scene.ship_view
	check(is_equal_approx(original_hull_height,scene.reference_height),"Carrier count and motion preserve flagship size")
	for step in 30:
		view.set_pose(scene.player_render_position(),scene.reference_height,0,Vector2(280,120),step*.1,false,false,.1)
		for module in view.modules:
			for ordinal in [0,1]:
				var pose:Dictionary=scene._prototype_launch_pose(int(module.slot),Vector2(280,120),ordinal)
				var muzzle:Vector2=view.screen_muzzle_for_slot(int(module.slot),ordinal)
				check(scene.battle_point(pose.position).distance_to(muzzle)<.01,"True release point follows actual moving weapon tube")
	root.size=Vector2i(1180,738)
	scene.game.profile.enhancementLevel=0
	scene.game.invalidate_stat_cache()
	scene.game.reset_player()
	check(scene.defense_temporary_caption(scene.defense_hud_layers(scene.game.enhancement_protection_status()).armour).is_empty(),"No enhancement adds no temporary caption")
	await capture("defense-none")
	scene.game.profile.enhancementLevel=30
	scene.game.invalidate_stat_cache()
	scene.game.reset_player()
	scene.game.paused=false
	scene.game.advance_jewel_repair(2)
	scene.game.paused=true
	var status:Dictionary=scene.game.enhancement_protection_status()
	var layers:Dictionary=scene.defense_hud_layers(status)
	check(N.compare(N.add(layers.armour.current,layers.shield.current),status.current)==0,"Typed rows conserve actual temporary pool")
	check(N.compare(layers.armour.current,0)>0 and N.compare(layers.shield.current,0)>0,"Both module owners project into corresponding bars")
	check(scene.defense_temporary_caption(layers.armour).contains(UIText.t("enhance.protection_state.neutral")),"Default Memory remains neutral")
	await capture("defense-neutral")
	scene.game.set_enhancement_branch("defence","memory_material",2,"B")
	scene.game.set_enhancement_branch("defence","adaptation",3,"B")
	scene.game.enhancement_branches.memory_incoming(scene.game,2)
	status=scene.game.enhancement_protection_status()
	layers=scene.defense_hud_layers(status)
	var expected_resistance:String=scene.NUMBER_FORMAT.compact(clampf(scene.game.enhancement_parameter("memory_b2_resistance")+scene.game.enhancement_parameter("adaptation_b3_resistance_bonus"),0,1)*100)+"%"
	check(scene.defense_temporary_caption(layers.armour).contains(expected_resistance),"Physical protection uses live Adaptation boosted resistance")
	await capture("defense-physical")
	scene.game.enhancement_branches.defenses.clear()
	scene.game.enhancement_branches.memory_incoming(scene.game,1)
	status=scene.game.enhancement_protection_status()
	check(scene.defense_temporary_caption(scene.defense_hud_layers(status).shield).contains(expected_resistance),"Energy protection also retains current resistance")
	await capture("defense-energy")
	scene.game.set_enhancement_branch("defence","adaptation",2,"B")
	scene.game.paused=false
	scene.game.enhancement_branches.advance_defense(scene.game,scene.game.enhancement_parameter("adaptation_b2_interval"))
	scene.game.paused=true
	status=scene.game.enhancement_protection_status()
	check(N.compare(status.cover_current,0)>0 and scene.defense_hud_footer(status).contains("护罩"),"Live cover enters existing defense footer")
	scene.game.queue_enhancement_deferred("shield",1.23456789e40)
	check(scene.defense_hud_footer(status).contains(scene.number(scene.game.enhancement_deferred_total())),"Global debt reuses global number format")
	check(not scene.defense_hud_layers(status).armour.has("debt"),"Cross-layer debt is never fabricated as layer HP")
	await capture("defense-cover-debt")
	for key in ["armour","shield"]:
		var body_text:String=UIText.t("battle.hp",{"current_hp":"8.9e+81","max_hp":"8.9e+81"}) if key=="armour" else UIText.t("battle.shield",{"current_shield":"8.9e+81","max_shield":"8.9e+81"})
		var caption:String=body_text+" · "+UIText.t("battle.defense.temporary",{"current":"8.9e+81","state":UIText.t("enhance.protection_state.dual",{"physical":"75%","energy":"75%"})})
		check(scene.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,scene.defense_caption_size(caption,17)).x<=516,"Scientific mixed resistance fits unchanged defense row")
	var footer:String=scene.defense_hud_footer(status)
	check(scene.font.get_string_size(footer,HORIZONTAL_ALIGNMENT_LEFT,-1,scene.defense_caption_size(footer,13)).x<=516,"Cover and scientific debt fit original area")
	var before:Array=scene.enhancement_defense_hud_state()
	scene.game.enhancement_deferred.clear()
	check(scene.enhancement_defense_hud_state()!=before and not scene.defense_hud_footer(status).contains("待承受"),"Clearing queue invalidates and removes debt")
	scene.game.enhancement_branches.advance_defense(scene.game,scene.game.enhancement_parameter("adaptation_b2_duration")+.1)
	# Stop generating new cover, then expire the current one.
	scene.game.set_enhancement_branch("defence","adaptation",2,"A")
	scene.game.enhancement_branches.reconcile(scene.game)
	check(not scene.defense_hud_footer(scene.game.enhancement_protection_status()).contains("护罩"),"Expired/replaced cover disappears")
	scene.game.reset_player()
	check(scene.game.enhancement_deferred_total()==0 and scene.game.enhancement_protection_current()==0 and not scene.defense_hud_footer(scene.game.enhancement_protection_status()).contains("护罩"),"Reset clears transient protection cover and debt")
	await capture("defense-reset")
	var replacement=scene.create_battle_game(false)
	check(replacement.enhancement_protection_current()==0 and replacement.enhancement_deferred_total()==0 and replacement.enhancement_protection_status().cover_current==0,"Reload starts with no stale transient defenses")
	root.size=Vector2i(960,600)
	await capture("narrow-after")
	scene.queue_free()
	await process_frame
	print("COMPACT FLEET DEFENSE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
