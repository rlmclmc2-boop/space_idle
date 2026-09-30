extends "res://scripts/battlefield.gd"
## Isolated fixtures and inspection controls; never used by main.tscn.

func _ready() -> void:
	# Existing capture boot is the project's no-save path. Remove its auto-quit after boot.
	var args := OS.get_cmdline_user_args()
	automation_args = PackedStringArray(["--capture"])
	super._ready()
	automation_args = PackedStringArray()
	music.stop()
	if args.has("--prototype-saved-loadout"):
		game.load_progress()
		game.resume_progress()
		build_ui()
	for arg in args:
		if arg.begins_with("--prototype-fixture="):
			fixture_name = arg.trim_prefix("--prototype-fixture=")
			_apply_fixture(fixture_name)
	_set_reference_dimensions()
	for arg in args:
		if arg.begins_with("--prototype-capture="):
			capture_directory = arg.trim_prefix("--prototype-capture=")
		if arg=="--prototype-exit": requested_exit = true
		if arg=="--prototype-close": close_up = true
		if arg=="--prototype-smooth": toon_enabled = false
		if arg=="--prototype-old-missile": missile_vfx_enabled = false
		if arg=="--prototype-old-beam": continuous_beam_enabled = false
		if arg=="--prototype-old-rail": rail_vfx_enabled = false
		if arg=="--prototype-old-pulse": pulse_vfx_enabled = false
		if arg=="--prototype-no-rim": rim_enabled = false
		if arg=="--prototype-no-shield": shield_enabled = false
		if arg=="--prototype-original": prototype_enabled = false
	_update_title()
	_sync_parameters()
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,player_idle_angle(),player_render_position()+Vector2(0,-600),demo_time,shield_enabled,close_up)


func set_effects(enabled: bool) -> void:
	effects_enabled = enabled
	shield_enabled = enabled
	# The battle renderer skips its transient layer during silhouette inspection.
	battle_layer.queue_redraw()
	pulse_layer.visible = false
	for plume in ship_view.exhaust_nodes: plume.visible = enabled
	ship_view.shield.visible = enabled
	ship_view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if game.paused else SubViewport.UPDATE_ALWAYS


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_T: toon_enabled = not toon_enabled
		KEY_R: rim_enabled = not rim_enabled
		KEY_S:
			shield_enabled = not shield_enabled
			paused_presentation_signature = ""
		KEY_B:
			prototype_enabled = not prototype_enabled
			battle_layer.queue_redraw()
		KEY_C: close_up = not close_up
		KEY_V: set_effects(not effects_enabled)
		KEY_O:
			protect_silhouette = not protect_silhouette
			battle_clip.move_child(ship_view,battle_layer.get_index()+1 if protect_silhouette else battle_layer.get_index())
		KEY_P: game.paused = not game.paused
		_: return
	_sync_parameters()
	_update_title()
	get_viewport().set_input_as_handled()


func _update_title() -> void:
	get_window().title = "五舰混合原型 | %s | %s | C 近看 · V 特效 · O 遮挡保护 · P 暂停" % [str(game.profile.selectedShip),"合成满载夹具（非玩家存档）" if not fixture_name.is_empty() else "隔离预览"]


func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_directory)
	get_viewport().get_texture().get_image().save_png(capture_directory.path_join("battle.png"))
	ship_view.viewport.get_texture().get_image().save_png(capture_directory.path_join("ship-alpha.png"))
	var facts := {"godot":Engine.get_version_info().string,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"ship_reference_pixels":reference_height,"battle_size":BATTLE_VIEW_SIZE,"save_enabled":game.save_enabled,
		"toon":toon_enabled,"rim":rim_enabled,"close_up":close_up,"outline":false,
		"turret_y":ship_view.turret.rotation.y if ship_view.turret!=null else 0.0,"weapon_mounted":ship_view.weapon!=null,"mesh_materials":ship_view.material_entries.size(),
		"engine_count":ship_view.exhaust_nodes.size(),"fps":Engine.get_frames_per_second()}
	var file := FileAccess.open(capture_directory.path_join("facts.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(facts,"\t"))
	print("TOON_PROTOTYPE ",JSON.stringify(facts))
	if requested_exit: get_tree().quit()


func _apply_fixture(key: String) -> void:
	# Explicit in-memory synthetic fixture, never represented as a player save.
	if db.ship(key).is_empty():
		push_error("Unknown synthetic fixture hull: "+key)
		get_tree().quit(1)
		return
	game.profile.selectedShip = key
	game.profile.loadout = game.empty_loadout(key)
	var pattern := ["laser","missile","cannon","longLaser","missile","longLaser","cannon","missile"]
	# Preserve the earlier heavy repeated-weapon review as its dedicated fixture.
	if key == "Heavy_Battleship": pattern = ["laser","missile","missile","missile","missile","longLaser","cannon","longLaser"]
	if OS.get_cmdline_user_args().has("--prototype-pulse-fixture"):pattern.fill("laser")
	if OS.get_cmdline_user_args().has("--prototype-rail-fixture"):pattern.fill("cannon")
	if OS.get_cmdline_user_args().has("--prototype-rail-single"):
		pattern.fill("");pattern[0]="cannon"
	if OS.get_cmdline_user_args().has("--prototype-missile-fixture"):pattern.fill("missile")
	if OS.get_cmdline_user_args().has("--prototype-beam-fixture"):pattern.fill("longLaser")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prototype-single-weapon="):
			pattern.fill("");pattern[0]=arg.trim_prefix("--prototype-single-weapon=")
	if OS.get_cmdline_user_args().has("--prototype-offcenter-source"):
		pattern.fill("");pattern[0]="laser";pattern[1]="missile"
	for index in game.profile.loadout.weapons.size():
		game.profile.loadout.weapons[index].key = pattern[index]
	game.profile.loadout.defence[0].key = "armour"
	game.invalidate_stat_cache()
	game.reset_player()
	game.projectiles.clear()
	projectile_visuals.clear()
	beam_visuals.clear()
	turret_visuals.clear()
	game.paused = true
	build_ui()

func _process(delta:float)->void:
	super._process(delta)
	if capture_directory!="" and prototype_frames==150:_capture()
