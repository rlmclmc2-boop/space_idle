extends SceneTree

# Ordinary-speed stage 2 presentation sample. No health, damage or timing edits.
func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	var scene:Node=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.size=Vector2i(1373,883)
	root.add_child(scene)
	scene.game.save_enabled=false
	scene.game.profile.onboarding.completed=true
	scene.game.profile.onboarding.dismissed=true
	scene.game.profile.highestLevel=maxi(2,int(scene.game.profile.highestLevel))
	seed(24017)
	assert(scene.game.start(2,false))
	# Capture the real stage 2 third point used in the frozen readability review.
	scene.game.group_index=2
	scene.game.spawn_group()
	var out:=OS.get_environment("BATTLE_EVIDENCE_DIR")
	assert(not out.is_empty())
	for frame in 120:
		await process_frame
		if frame==20:
			var keys:Dictionary={}
			for enemy in scene.game.enemies:
				var key:String=scene.enemy_ship_key(enemy)
				keys[key]=int(keys.get(key,0))+1
			var metrics:Dictionary=scene.game.combat_presentation.retained_metrics() if scene.game.combat_presentation!=null else {}
			print("BATTLE_KEYS ",keys," native=",scene.game.native_execution!=null," combat_presentation=",scene.game.combat_presentation!=null," speed=",scene.game.speed," presentation_metrics=",metrics)
		if frame in [20,60,100]:
			var hostile_count:=0
			for shot in scene.game.projectiles:
				if bool(shot.get("hostile",false)):hostile_count+=1
			if DisplayServer.get_name()=="headless":
				print("BATTLE_CAPTURE frame=",frame," no_framebuffer enemy_count=",scene.game.enemies.size()," hostile_shots=",hostile_count)
			else:
				await RenderingServer.frame_post_draw
				var texture:=root.get_texture()
				var path:=out.path_join("stage2-%03d.png" % frame)
				var error:=texture.get_image().save_png(path)
				print("BATTLE_CAPTURE frame=",frame," enemy_count=",scene.game.enemies.size()," hostile_shots=",hostile_count," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," result=",error)
	quit()
