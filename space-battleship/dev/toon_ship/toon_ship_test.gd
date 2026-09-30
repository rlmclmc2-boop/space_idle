extends "res://scripts/main.gd"
## Development-only subclass. Production code, values, UI and assets are untouched.

const SHIP_VIEW := preload("res://dev/toon_ship/ship_view.gd")

@export_group("Toon ship prototype")
@export_range(0.0,1.0,0.01) var toon_shadow_threshold := 0.60
@export_range(2,5,1) var toon_steps := 3
@export_range(0.0,1.0,0.01) var rim_strength := 0.22
@export_range(1.0,12.0,0.1) var rim_power := 4.5
@export_range(0.0,0.3,0.01) var specular_strength := 0.04
# Reserved because precision outlines are deliberately excluded from this prototype.
@export_range(0.0,2.0,0.1) var outline_strength := 0.0
@export_range(0.0,3.0,0.1) var emission_strength := 1.0
@export_range(0.0,4.0,0.1) var engine_emission := 1.4
@export_range(0.0,0.6,0.01) var shield_opacity := 0.12
@export var toon_enabled := true
@export var rim_enabled := true
@export var shield_enabled := true

var effects_enabled := true
var ship_view
var prototype_enabled := true
var close_up := false
var demo_time := 0.0
var pulse_layer: Node2D
var reference_height := 0.0
var reference_offset := Vector2.ZERO
var requested_exit := false
var prototype_frames := 0
var capture_directory := ""
var parameters_signature := ""
var paused_presentation_signature := ""


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
	if str(game.profile.selectedShip)!="Heavy_Battleship":
		push_error("Run preview.py with the eight-slot Heavy_Battleship snapshot")
		get_tree().quit(1)
		return
	ship_view = SHIP_VIEW.new()
	ship_view.name = "ToonShipView"
	ship_view.size = BATTLE_VIEW_SIZE
	ship_view.z_index = 0
	battle_clip.add_child(ship_view)
	battle_clip.move_child(ship_view,battle_layer.get_index())
	ship_view.set_loadout(game.weapon_entries())
	pulse_layer = Node2D.new()
	pulse_layer.name = "PrototypePulse"
	pulse_layer.z_index = 2
	battle_clip.add_child(pulse_layer)

	_set_reference_dimensions()
	for arg in args:
		if arg.begins_with("--prototype-capture="):
			capture_directory = arg.trim_prefix("--prototype-capture=")
		if arg=="--prototype-exit": requested_exit = true
		if arg=="--prototype-close": close_up = true
		if arg=="--prototype-smooth": toon_enabled = false
		if arg=="--prototype-no-rim": rim_enabled = false
		if arg=="--prototype-no-shield": shield_enabled = false
		if arg=="--prototype-original": prototype_enabled = false
	_update_title()
	_sync_parameters()
	ship_view.set_pose(player_render_position()+reference_offset,reference_height,player_idle_angle(),player_render_position()+Vector2(0,-600),demo_time,shield_enabled,close_up)


func _set_reference_dimensions() -> void:
	# Match the existing hull's opaque footprint, not its transparent source canvas.
	var image := ship_hull_texture(str(game.profile.selectedShip)).get_image()
	var rect := image.get_used_rect()
	var factor: float = float(battle_visual.player_core_scale)*player_art_scale()
	reference_height = float(rect.size.y)*factor
	reference_offset = Vector2.ZERO # The modular hull origin is its own center, not the PNG canvas center.


func _sync_parameters() -> void:
	var settings := {"toon_shadow_threshold":toon_shadow_threshold,"toon_steps":toon_steps,
		"rim_strength":rim_strength,"rim_power":rim_power,"specular_strength":specular_strength,
		"outline_strength":outline_strength,"emission_strength":emission_strength,
		"engine_emission":engine_emission,"shield_opacity":shield_opacity}
	var signature := str(settings)+str(toon_enabled)+str(rim_enabled)
	if signature != parameters_signature:
		parameters_signature = signature
		ship_view.apply_parameters(settings,toon_enabled,rim_enabled)


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(ship_view): return
	prototype_frames += 1
	if not game.paused: demo_time += delta
	_sync_parameters()
	if game.weapon_entries().size()!=8:
		prototype_enabled = false
		ship_view.set_rendering(false)
		return
	ship_view.set_loadout(game.weapon_entries())
	var target := player_render_position()+Vector2(sin(demo_time*0.7)*180,-450)
	if not game.enemies.is_empty(): target = enemy_render_position(game.enemies[0])
	var pose_signature := str([parameters_signature,prototype_enabled,close_up,shield_enabled,battle_layer.visible,game.paused,player_render_position(),target,fx_time])
	if game.paused and pose_signature==paused_presentation_signature: return
	paused_presentation_signature = pose_signature
	var shake_offset := Vector2(sin(fx_time*83.0),cos(fx_time*97.0))*shake
	ship_view.set_pose(player_render_position()+reference_offset+shake_offset,reference_height,player_idle_angle(),target,demo_time,shield_enabled,close_up)
	var angles: Array = []
	for index in game.weapon_entries().size(): angles.append(turret_angle(index))
	ship_view.set_slot_angles(angles)
	for plume in ship_view.exhaust_nodes: plume.visible = effects_enabled
	var alive: bool = GrowthNumber.compare(game.player.armour,0)>0 or game.state==BattleGame.State.RETREAT
	ship_view.set_rendering(prototype_enabled and alive and battle_layer.visible,game.paused)
	pulse_layer.visible = ship_view.visible
	pulse_layer.queue_redraw()
	if capture_directory!="" and prototype_frames==150:
		_capture()


func draw_ship(pos: Vector2, scale_value: float, hostile: bool, type: int, shield_active: bool) -> void:
	if hostile or not prototype_enabled:
		super.draw_ship(pos,scale_value,hostile,type,shield_active)


func draw_engine_wake(pos: Vector2) -> void:
	if not prototype_enabled: super.draw_engine_wake(pos)


func turret_muzzle(index: int) -> Vector2:
	if prototype_enabled and is_instance_valid(ship_view):
		var point: Vector2 = ship_view.screen_muzzle_for_slot(index)
		if point!=Vector2.ZERO: return battle_logical_point(point)
	return super.turret_muzzle(index)


func player_mount_center(key: String, index: int) -> Vector2:
	if prototype_enabled and is_instance_valid(ship_view):
		for module in ship_view.modules:
			if int(module.slot)!=index: continue
			var point: Vector2 = ship_view.camera.unproject_position(module.mount.global_position)
			return (point-player_render_position()).rotated(PI/2-player_idle_angle())/player_art_scale()
	return super.player_mount_center(key,index)


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
		KEY_P: game.paused = not game.paused
		_: return
	_sync_parameters()
	_update_title()
	get_viewport().set_input_as_handled()


func _update_title() -> void:
	get_window().title = "模块战舰原型 | T Toon %s · R Rim %s · S 护盾 · B 原图 · C 近看 · V 特效 · P 暂停 | %s" % ["开" if toon_enabled else "关","开" if rim_enabled else "关","近看" if close_up else "实战尺寸"]


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


func player_render_position() -> Vector2:
	var point := super.player_render_position()
	if prototype_enabled and reference_height>0:
		# Reserve the existing HUD gap for the new hull's actual opaque bounds.
		point.y = minf(point.y,BATTLE_VIEW_SIZE.y-float(battle_visual.player_hud_gap)-reference_height*0.5)
	return point


func draw_battle() -> void:
	if effects_enabled: super.draw_battle()
