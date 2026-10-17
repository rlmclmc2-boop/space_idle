extends SceneTree

# 实际 main 场景连续录制；环境变量只选择既定战点与同投入武器。
class UI extends "res://scripts/battlefield.gd":
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
	func create_battle_game(_persist:bool)->BattleGame:
		var result=preload("res://scripts/presented_battle_game.gd").new(db,false)
		result.stat_cache_enabled=true
		result.invalidate_stat_cache()
		db=result.db
		result.native_execution_auto=false
		result.launch_provider=_prototype_launch_pose
		result.drone_launch_provider=_prototype_drone_launch_pose
		result.target_provider=_prototype_target_point
		battle_read_model.setup(self)
		result.target_spatial_source=battle_read_model
		result.rail_geometry_provider=_rail_geometry
		result.rail_target_point_provider=entity_render_position
		result.enable_compiled_combat_rules()
		return result

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var stage:=int(OS.get_environment("QA_STAGE"))
	var point:=int(OS.get_environment("QA_POINT"))
	var weapon:=OS.get_environment("QA_WEAPON")
	var level:=int(OS.get_environment("QA_LEVEL"))
	var reactor:=int(OS.get_environment("QA_REACTOR"))
	var tech:=int(OS.get_environment("QA_TECH"))
	var capture_dir:=OS.get_environment("QA_CAPTURE_DIR")
	var capture_tag:=OS.get_environment("QA_CAPTURE_TAG")
	assert(stage in [6,7] and point>=1 and point<=9 and weapon in ["laser","longLaser"] and level>0 and not capture_dir.is_empty())
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(UI)
	scene.automation_args=["--capture"]
	scene.music_on=false
	root.add_child(scene)
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	var game=scene.game
	game.save_enabled=false
	game.speed=1
	game.rng.seed=1701
	game.profile.onboarding.completed=true
	scene.beginner_guide.hide()
	game.profile.cleared=range(1,stage)
	game.rebuild_unlocks()
	game.pending_unlocks.clear()
	game.profile.loadout.weapons[0]={"key":weapon,"level":level}
	game.profile.loadout.defence[0]={"key":"shield","level":level}
	game.profile.aiTechLevels={"weapon_accuracy":tech,"equipment_reinforcement":tech}
	game.profile.reactorLevel=reactor
	var cap=game.reactor_capacity()
	game.profile.reactorAllocation={"weapons":int(cap/2),"defence":cap-int(cap/2)}
	game.invalidate_stat_cache()
	game.reset_player()
	assert(game.start(stage,false))
	game.group_index=point-1
	game.spawn_group()
	scene.set_process(true)
	var frames:=0
	var key:="stage%d-point%d-%s" % [stage,point,weapon]
	if not capture_tag.is_empty():key+="-"+capture_tag
	while frames<1200:
		await RenderingServer.frame_post_draw
		frames+=1
		if frames in [90,180]:
			var image=scene.get_viewport().get_texture().get_image()
			image.save_png(capture_dir.path_join(key+"-frame%d.png" % frames))
		if game.state!=BattleGame.State.COMBAT and frames>60:break
	print("QA_VISUAL_CAPTURE ",JSON.stringify({"stage":stage,"point":point,"weapon":weapon,"level":level,"frames":frames,"state":game.state,"window":str(DisplayServer.window_get_size()),"render":str(scene.get_viewport().get_visible_rect().size),"native":game.native_execution!=null,"save":game.save_enabled}))
	scene.set_process(false)
	scene.queue_free()
	await process_frame
	quit()
