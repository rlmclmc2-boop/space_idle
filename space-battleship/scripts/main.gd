extends Node2D

const BG := Color("080e1b")
const PANEL := Color("101c2c")
const LINE := Color("26384b")
const INK := Color("e0ecf4")
const MUTED := Color("8195ac")
const CYAN := Color("71e5f4")
const ORANGE := Color("ffbc73")
const PURPLE := Color("b3a0ff")
const RESOURCE_ART := preload("res://scripts/resource_art.gd")
const CREW_TAB_TYPES := {0:["equipment"],1:["hightech","production","smelting"],2:["reactor"],4:["jewel"],8:["galaxy"]}
const CREW_TAB_TITLES := {0:"equipment.tab",1:"upgrade.research_tab",2:"reactor.tab",4:"enhance.tab",8:"galaxy.tab"}
const BATTLE_INVERSE_STEPS := 20
const BATTLE_LINEAR_INVERSE_OFFSET := 110.0 / (1 << BATTLE_INVERSE_STEPS)
const RIGHT_UI_OFFSET := 608.0
const CHROME_HEIGHT := 78.0
const VIEW_CROP_LEFT := 20.0
const MUSIC_SETTINGS_PATH := "user://music_settings.cfg"
const EQUIPMENT_DISPLAY := preload("res://scripts/equipment_display.gd")
const BATTLE_ORIGIN := Vector2(20,160)
const BATTLE_VIEW_SIZE := Vector2(572,960)
# Defaults share the existing ProjectSettings visuals namespace; presentation only.
const BATTLE_VISUAL_DEFAULTS := {
	"player_ship_y":0.91, "player_hud_gap":14.0, "player_core_scale":0.65,
	"enemy_base_scale":0.34, "enemy_offset_y":12.0,
	"enemy_max_y":0.36, "enemy_player_min_gap":0.20, "enemy_entry_distance":50.0,
	"enemy_scale_variance":Vector2(0.90,1.08), "enemy_rotation_variance":4.0,
	"enemy_depth_scale_min":0.82, "enemy_depth_scale_max":1.12,
	"player_idle_x":5.0, "player_idle_y":3.0, "player_idle_rotation":0.7,
	"enemy_idle_x":8.0, "enemy_idle_y":7.0, "enemy_idle_rotation":1.3,
	"background_far_speed":3.0, "background_mid_speed":18.0,
	"background_near_speed":90.0, "background_object_density":0.9,
	"background_mid_opacity":0.16, "background_fog_opacity":0.22,
	"bullet_trail_scale":0.72, "laser_glow_scale":1.12, "missile_trail_scale":0.76,
	"muzzle_pulse_duration":0.12, "beam_hit_spark_scale":0.75,
	"damage_number_normal_duration":0.42, "damage_number_critical_duration":0.58,
	"hit_flash_duration":0.08, "destroy_effect_duration":0.52,
	"environment_event_enabled":true, "environment_event_interval":55.0,
	"boss_destroy_shake":3.0
}
var battle_visual: Dictionary = BATTLE_VISUAL_DEFAULTS.duplicate()
# At most one pose per occupied logical slot, replaced on entity identity change.
var enemy_poses: Dictionary = {}
# Display anchors for drops from destroyed enemies; removed after their drops leave.
var death_drop_positions: Dictionary = {}
var compact_armour: Array[PackedVector2Array] = []
var compact_bridges: Array[PackedVector2Array] = []
# All ten configured slots share one rear display line.
const NAV_RECT := Rect2(4,96,144,1160)
const WORK_RECT := Rect2(160,96,1204,1160)
const WORK_CONTENT_RECT := Rect2(168,150,1364,1200)
const WORK_CONTENT_SCALE := Vector2(0.875,0.875)
const RESOURCE_STRIP_PRESENTATION := preload("res://scripts/resource_strip_presentation.gd")
const SHELL_PRESENTATION := preload("res://scripts/shell_presentation.gd")
const SYSTEM_ICONS := ["▣","⬡","◉","◇","✦","♙","◎","◷","✧"]
const SYSTEM_TITLES := ["equipment.tab","upgrade.research_tab","reactor.tab","ship.tab","enhance.tab","crew.tab","planet.tab","chrono.tab","galaxy.tab","save.tab"]
var NAMES: Dictionary = {}
const PROJECTILE_SIZES := {"laser":Vector2(64,24),"cannon":Vector2(40,21),"missile":Vector2(64,26)}
const PROJECTILE_SCALE := 0.65
const SHIP_ART_CANVAS := Vector2(887, 1774)
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const SHIP_VISUALS := preload("res://scripts/ship_visuals.gd")
const RAILGUN_FX := preload("res://scripts/railgun_fx.gd")
var railgun_fx = RAILGUN_FX.new()
var railgun_audio: Dictionary = {}
var railgun_sound_times: Dictionary = {}
const WEAPON_VISUAL := preload("res://scripts/weapon_visual.gd")
var visual_config: Dictionary = {}
var visual_textures: Dictionary = {}
var visual_regions: Dictionary = {}
var hull_visible_bottoms: Dictionary = {}
var player_components: Array = []
var player_components_signature := ""
# Reuse presentation values only inside one synchronous draw callback. No state
# survives the draw, so movement, refits and event-time muzzle reads stay live.
var battle_draw_active := false
var battle_draw_player_position := Vector2.ZERO
var battle_draw_enemy_positions: Dictionary = {}
var db: ShipDatabase
var game: BattleGame
var font: Font
var ui: Control
var stars: Array[Dictionary] = []
var particles: Array[Dictionary] = []
# UI-only references and endpoint snapshots; never written into combat state.
var beam_visuals: Array[Dictionary] = []
var projectile_visuals: Array[Dictionary] = []
# UI-owned per-mount pose; never used by damage, aiming or projectile simulation.
var turret_visuals: Dictionary = {}
var turret_ship := ""
const WEAPON_PARTICLE_LIMIT := 700
const FAST_MODE_MIN_SPEED := 3.0
const FAST_MODE_GAME_STEP := 1.0 / 15.0
# Independent presentation controls; no combat parameter reads these values.
const BODY_SCALE := {"missile":Vector2(0.7,0.7),"cannon":Vector2(0.7,0.45)}
const FLAME_SCALE := 0.65
const TRAIL_SCALE := 0.55
const IMPACT_SCALE := 0.65
var show_damage_numbers := true
var damage_mode := 0 # 0 simplified, 1 all (damage types), 2 off
var damage_pending: Array[Dictionary] = []
var damage_history: Array[String] = []
var wave_hint := 0.0
var fx_time := 0.0
var accelerated_visual_mode := false
var floats: Array[Dictionary] = []
var pickup_effects: Array[Dictionary] = []
var resource_hover_feedback: Array[Dictionary] = []
var clock := 0.0
var star_travel := 0.0
var star_streak := 0.0
# Immutable star seeds own this geometry until the scene is freed.
var stars_mesh: ArrayMesh
const STARFIELD_SHADER := preload("res://scripts/starfield.gdshader")
var shake := 0.0
var message := ""
var message_time := 0.0
var help_open := false
var help_surface: StyleBoxFlat = preload("res://scripts/dialog_presentation.gd").surface()
var unlock_scroll: ScrollContainer
var unlock_title: Label
var unlock_description: Label
var sound_on := false
var audio: AudioStreamPlayer
var music_on := true
var music: AudioStreamPlayer
var last_sound := -1.0
var loop_button: Button
var loop_select: OptionButton
var resource_rate_mode := false
var resource_samples: Array[Dictionary]:
	get:
		return game.resource_samples
var resource_mode_button: Button
var upgrade_buttons: Dictionary = {}
var ten_upgrade_buttons: Dictionary = {}
var max_upgrade_buttons: Dictionary = {}
var EQUIPMENT_PAGES: Array = []
var equipment_panel: Control
var crew_panel: Control
var planet_panel: Control
var chrono_panel: Control
var galaxy_panel: Control
var background_unfocused := false
var equipment_page := 0
var equipment_tabs: TabContainer
var system_nav: Panel
var system_nav_buttons: Array[Button] = []
var workspace_frame: Panel
var workspace_title: Label
var fps_label: Label
var fps_refresh_elapsed := 0.0
var displayed_fps := -1
var battle_clip: Control
var battle_hud_layer: Node2D
var equipment_cooldowns: Dictionary = {}
var equipment_card_controls: Dictionary = {}
var reactor_panel: Control
var hightech_page: Control
var ui_rebuild_pending := false
var ui_rebuild_scheduled := false
var automation_args := OS.get_cmdline_user_args() if OS.has_feature("debug") else PackedStringArray()
var capture_frame := 0
var equipment_containers: Dictionary = {}
var equipment_panels: Dictionary = {}
var ship_controls: Dictionary = {}
var help_button: Button
var help_close_button: Button
var continue_button: Button
var advance_button: Button
var advance_countdown_label: Label
var advance_progress: ProgressBar
var sound_button: Button
var music_button: Button
var guard_settings: MenuButton
var draw_surface: Node2D
var background_layer: Node2D
var chrome_layer: Node2D
var stars_layer: Node2D
var battle_layer: Node2D
var drop_layer: Node2D
var resource_layer: Node2D
var overlay_layer: Node2D
var enhancement_panel: Panel
var beginner_guide: Control
var chrono_login_dialog: AcceptDialog
var save_panel: Control
var save_confirmation_text: Label
var save_interval_input: LineEdit
var save_interval_feedback: Label
var last_save_label: Label
var save_status_label: Label
var save_transfer := preload("res://scripts/save_transfer.gd").new()
var save_file_dialog: FileDialog
var save_import_confirmation: ConfirmationDialog
var save_transfer_feedback: Label
var pending_import: Dictionary = {}
var import_committing := false

func _ready() -> void:
	var from_save_import := get_tree().has_meta("save_import_backup")
	# Place the battlefield at the cropped viewport edge; keep the title strip anchored.
	position.x = -VIEW_CROP_LEFT
	for side in [-1.0,1.0]:
		compact_armour.append(PackedVector2Array([Vector2(290,side*315),Vector2(185,side*535),Vector2(-285,side*535),Vector2(-390,side*405),Vector2(-335,side*240),Vector2(90,side*240)]))
		compact_bridges.append(PackedVector2Array([Vector2(170,side*100),Vector2(110,side*380),Vector2(-270,side*380),Vector2(-370,side*120)]))
	var text_errors := UIText.reload_catalog()
	if not text_errors.is_empty():
		set_process(false)
		set_process_unhandled_input(false)
		var problem := AcceptDialog.new()
		problem.title = "UI text validation"
		problem.dialog_text = "\n".join(text_errors)
		add_child(problem)
		problem.popup_centered(Vector2i(900,420))
		return
	NAMES = {"armour":UIText.t("defense.armour_name"),"shield":UIText.t("defense.shield_name"),"laser":UIText.t("weapon.laser_name"),"missile":UIText.t("weapon.missile_name"),"cannon":UIText.t("weapon.cannon_name"),"longLaser":UIText.t("weapon.long_laser_name")}
	EQUIPMENT_PAGES = [{"title":UIText.t("weapon.tab"),"keys":["laser","cannon","missile","longLaser"]},{"title":UIText.t("defense.tab"),"keys":["armour","shield"]}]
	get_window().title = UIText.t("main.window_title")
	if OS.has_feature("release"):
		font = load("res://assets/fonts/NotoSansSC-Regular.tres")
		var symbols: FontFile = load("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
		symbols.allow_system_fallback = false
		font.fallbacks = [symbols]
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
		font = system_font
	db = ShipDatabase.new()
	var parsed_visuals = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	if not parsed_visuals is Dictionary:
		push_error("Invalid ship weapon visual profiles")
		return
	visual_config = parsed_visuals
	for key in battle_visual:
		battle_visual[key] = ProjectSettings.get_setting("visuals/"+key,battle_visual[key])
	game = create_battle_game(not automation_args.has("--capture"))
	railgun_fx.configure(db)
	if game.save_enabled:
		load_music_setting()
	game.event.connect(on_event)
	create_draw_layers()
	ui = Control.new()
	if OS.has_feature("release"):
		ui.theme = Theme.new()
		ui.theme.default_font = font
		ui.theme.default_font_size = 20
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.position = Vector2(RIGHT_UI_OFFSET,0)
	get_viewport().size_changed.connect(on_viewport_resized)
	for i in range(200):
		var depth_seed := randf_range(0.2,0.86) if i<174 else randf_range(0.97,1.0) if i<182 else randf_range(0.88,0.95)
		stars.append({"x":randf()*BattleGame.BATTLE_SIZE.x,"y":randf()*BattleGame.BATTLE_SIZE.y,"z":depth_seed})
	audio = AudioStreamPlayer.new()
	audio.volume_db = -25
	add_child(audio)
	for kind in ["charge","release","impact"]:
		var voice := AudioStreamPlayer.new()
		voice.stream = RAILGUN_FX.sound(kind)
		voice.volume_db = -25.0
		add_child(voice)
		railgun_audio[kind] = voice
	var music_stream := preload("res://assets/audio/bgm/deep_space_idle_01.ogg").duplicate() as AudioStreamOggVorbis
	music_stream.loop = true
	music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	music.stream = music_stream
	music.volume_db = -18
	add_child(music)
	if music_on:
		music.play()
	game.resume_progress()
	build_ui()
	if get_tree().has_meta("save_import_backup"):
		var backup: String=get_tree().get_meta("save_import_backup")
		get_tree().remove_meta("save_import_backup")
		call_deferred("save_transfer_message",UIText.t("save.import_success",{"backup":backup}))
	if automation_args.has("--capture"):
		game.start(1, false)
		game.distance = 99.8
		game.tick(0.02)
		game.tick(0.1)
		if automation_args.has("--capture-unlock"):
			game.clear_level()
		if automation_args.has("--capture-all"):
			game.profile.cleared = [1,2]
			game.rebuild_unlocks()
			game.start(3, false)
			game.profile.resources["1"] = 5000.0
			game.profile.resources["2"] = 100.0
		build_ui()
	get_window().min_size = Vector2i(960,540)
	if game.save_enabled:
		if not from_save_import:call_deferred("show_chrono_login_report")
	elif OS.has_feature("debug") and DisplayServer.get_name() != "headless" and not automation_args.has("--capture"):
		call_deferred("show_qa_tools")

func show_chrono_login_report() -> void:
	if is_instance_valid(chrono_login_dialog):
		return
	var qa_tools := get_tree().root.get_node_or_null("QATools")
	if qa_tools is Window and qa_tools.visible:
		qa_tools.hide()
	var amount := float(game.login_chrono_particles)
	var display := str(int(amount)) if is_equal_approx(amount,roundf(amount)) else str(amount)
	chrono_login_dialog = AcceptDialog.new()
	chrono_login_dialog.name = "ChronoLoginDialog"
	chrono_login_dialog.title = UIText.t("chrono.login_title")
	chrono_login_dialog.dialog_text = UIText.t("chrono.login_report",{"amount":display})
	chrono_login_dialog.ok_button_text = UIText.t("system.confirm")
	preload("res://scripts/dialog_presentation.gd").dialog(chrono_login_dialog)
	chrono_login_dialog.transient = true
	chrono_login_dialog.exclusive = true
	var close_report := func():
		chrono_login_dialog.queue_free()
		if OS.has_feature("debug") and DisplayServer.get_name() != "headless" and not automation_args.has("--capture"):
			call_deferred("show_qa_tools")
	chrono_login_dialog.confirmed.connect(close_report)
	chrono_login_dialog.canceled.connect(close_report)
	add_child(chrono_login_dialog)
	chrono_login_dialog.popup_centered(Vector2i(500,150))
	chrono_login_dialog.grab_focus()

var balance_lab: Window
var enemy_fleet_lab: Window

func show_enemy_fleet_lab() -> void:
	if not OS.has_feature("debug") or not ProjectSettings.get_setting("debug/enemy_fleet_lab/enabled",true):return
	get_viewport().gui_embed_subwindows = false
	if not is_instance_valid(enemy_fleet_lab):
		enemy_fleet_lab = Window.new()
		enemy_fleet_lab.transient = true
		enemy_fleet_lab.exclusive = true
		enemy_fleet_lab.set_script(load("res://scripts/enemy_fleet_panel.gd"))
		enemy_fleet_lab.database = game.db
		add_child(enemy_fleet_lab)
	enemy_fleet_lab.popup_centered()

func show_balance_lab() -> void:
	if not OS.has_feature("debug") or not ProjectSettings.get_setting("debug/balance_lab/enabled",true):return
	get_viewport().gui_embed_subwindows = false
	if not is_instance_valid(balance_lab):
		balance_lab = Window.new()
		balance_lab.transient = true
		balance_lab.exclusive = true
		balance_lab.set_script(load("res://scripts/balance_panel.gd"))
		add_child(balance_lab)
	balance_lab.set_process(true)
	balance_lab.popup_centered()

func show_qa_tools() -> void:
	if not OS.has_feature("debug"):
		return
	get_viewport().gui_embed_subwindows = false
	var panel := get_tree().root.get_node_or_null("QATools")
	if panel == null:
		panel = Window.new()
		panel.name = "QATools"
		panel.set_script(load("res://scripts/config_panel.gd"))
		get_tree().root.add_child(panel)
	panel.show()

func _notification(what: int) -> void:
	if game == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not background_unfocused:
		background_unfocused = true
		game.speed = game.default_speed()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and background_unfocused:
		background_unfocused = false
		game.speed = game.default_speed()
		if is_instance_valid(chrono_panel):chrono_panel.refresh()

func _process(delta: float) -> void:
	game.check_timed_save()
	if fast_mode_enabled():
		for voice in railgun_audio.values():
			if is_instance_valid(voice) and voice.playing:voice.stop()
	else:
		update_railgun_audio()
	# Freeze the live scene while the independent lab window owns focus.
	if is_instance_valid(balance_lab) and balance_lab.visible:return
	if ui_rebuild_pending and not get_viewport().gui_is_dragging():
		ui_rebuild_pending = false
		build_ui()
	sync_accelerated_visual_mode()
	var dt := maxf(0,delta) if background_unfocused else minf(delta,0.1)
	clock += dt
	prune_resource_samples(Time.get_unix_time_from_system())
	if not game.paused:
		fx_time += dt
		wave_hint = maxf(0,wave_hint-dt)
		advance_turrets(dt)
		var boosted := game.chrono_affordable_seconds(dt)
		advance_game_time(boosted * game.speed)
		if boosted < dt or (game.chrono_cost(game.speed) > 0 and game.profile.chronoParticles <= 0):
			game.speed = game.default_speed()
			advance_game_time((dt - boosted) * game.speed)
		if not accelerated_visual_mode:
			sync_beam_visuals()
			advance_projectile_visuals(dt)
		star_travel += dt * (-250.0*game.speed if game.state == BattleGame.State.RETREAT else game.ship_movement()*game.speed if game.state == BattleGame.State.TRAVEL else 2.0)
		# Blend the star-only travel effect instead of toggling 200 trails at once.
		star_streak = move_toward(star_streak,1.0 if game.state == BattleGame.State.TRAVEL else 0.0,dt*4.0)
		if not accelerated_visual_mode:
			for p in particles:
				p.life -= dt
				p.pos += p.vel*dt
				p.vel *= 0.97
			particles = particles.filter(func(p):return p.life > 0)
		for f in floats:
			f.life -= dt
			if f.get("damage",false):f.pos.y -= dt*12
		floats = floats.filter(func(f):return f.life > 0)
		for effect in pickup_effects:effect.life -= dt
		pickup_effects = pickup_effects.filter(func(effect):return effect.life>0)
		flush_damage_numbers()
	shake = maxf(0,shake-dt*18)
	message_time = maxf(0,message_time-dt)
	refresh_visible_cards(dt)
	refresh_navigation()
	refresh_draw_layers(dt)
	fps_refresh_elapsed += maxf(0.0,delta)
	if fps_refresh_elapsed >= 0.5:
		fps_refresh_elapsed = fmod(fps_refresh_elapsed,0.5)
		refresh_fps_label()
	if automation_args.has("--capture"):
		capture_frame += 1
		if capture_frame == 45:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://preview" + ("-unlock" if automation_args.has("--capture-unlock") else "-all" if automation_args.has("--capture-all") else "-combat") + ".png")
			get_tree().quit()

func advance_game_time(seconds: float) -> void:
	var remaining := seconds
	# Floating-point residue after a full step must not run another near-zero tick.
	while remaining > 0.000000001:
		var max_step := FAST_MODE_GAME_STEP if fast_mode_enabled() else 1.0/60.0
		var step := minf(remaining, max_step)
		game.tick(step)
		remaining -= step

func fast_mode_enabled() -> bool:
	return game != null and game.speed >= FAST_MODE_MIN_SPEED

func sync_accelerated_visual_mode() -> void:
	var enabled := fast_mode_enabled()
	if enabled == accelerated_visual_mode:
		return
	accelerated_visual_mode = enabled
	if not enabled:
		if is_instance_valid(battle_layer):battle_layer.queue_redraw()
		return
	particles.clear()
	beam_visuals.clear()
	projectile_visuals.clear()
	damage_pending.clear()
	floats = floats.filter(func(entry):return not entry.get("damage",false))
	shake = 0.0
	for voice in railgun_audio.values():
		if is_instance_valid(voice) and voice.playing:voice.stop()
	for pose in turret_visuals.values():
		pose.fired_at = -100.0
		pose.recoil = 0.0
	for uid in enemy_poses:
		var pose: Dictionary = enemy_poses[uid]
		for key in pose.keys():
			if str(key).begins_with("rail_fired_"):
				pose[key] = -100.0
	if is_instance_valid(battle_layer):battle_layer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		show_enemy_fleet_lab()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		show_balance_lab()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(balance_lab) and balance_lab.visible:return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collect_render_path(event.position,event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			show_qa_tools()
		if event.keycode in [KEY_SPACE, KEY_ESCAPE]:
			if not game.pending_unlocks.is_empty():
				game.acknowledge_unlocks()
			elif help_open:
				help_open = false
				refresh_navigation()
			else:
				game.paused = not game.paused

func _input(event: InputEvent) -> void:
	# Motion may end on a GUI control after crossing exposed battlefield space.
	if event is InputEventMouseMotion and is_instance_valid(battle_clip):
		collect_render_path(event.position-event.relative,event.position)

func resource_input_blocked() -> bool:
	if game.paused or help_open or not game.pending_unlocks.is_empty() or not battle_layer.visible:return true
	if is_instance_valid(balance_lab) and balance_lab.visible:return true
	if not get_window().has_focus():return true
	for window in get_viewport().get_embedded_subwindows():
		if window.exclusive or window.popup_window:return true
	return false

func clip_pickup_path(from: Vector2, to: Vector2, rect: Rect2) -> Array[Vector2]:
	var low := 0.0
	var high := 1.0
	var delta := to-from
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if from[axis]<rect.position[axis] or from[axis]>rect.end[axis]:return []
		else:
			var a: float=(rect.position[axis]-from[axis])/delta[axis]
			var b: float=(rect.end[axis]-from[axis])/delta[axis]
			low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
			if low>high:return []
	return [from+delta*low,from+delta*high]

func pickup_control_rects(control: Control, field: Rect2, clip: Rect2, result: Array[Rect2]) -> void:
	if not control.is_visible_in_tree():return
	var rect: Rect2=(control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)).intersection(clip)
	if control.mouse_filter!=Control.MOUSE_FILTER_IGNORE and rect.intersects(field):result.append(rect.intersection(field))
	if control.clip_contents:
		clip=rect
		if not clip.intersects(field):return
	for child in control.get_children():
		if child is Control:pickup_control_rects(child,field,clip,result)

func collect_render_path(from: Vector2, to: Vector2) -> void:
	if game.drops.is_empty() or resource_input_blocked():return
	var field: Rect2=battle_clip.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,battle_clip.size)
	var clipped := clip_pickup_path(from,to,field)
	if clipped.is_empty():return
	var covers: Array[Rect2]=[]
	for child in get_children():
		if child is Control:pickup_control_rects(child,field,field,covers)
	var paths: Array=[clipped]
	for cover in covers:
		var exposed: Array=[]
		for path in paths:
			var cut := clip_pickup_path(path[0],path[1],cover)
			if cut.is_empty():exposed.append(path)
			else:
				if path[0].distance_to(cut[0])>0.001:exposed.append([path[0],cut[0]])
				if path[1].distance_to(cut[1])>0.001:exposed.append([cut[1],path[1]])
		paths=exposed
		if paths.is_empty():return
	recover_death_drop_positions()
	var transform := battle_layer.get_global_transform_with_canvas()
	var inverse := transform.affine_inverse()
	for drop in game.drops.duplicate():
		var point := drop_render_position(drop)
		var screen_point: Vector2=transform*point
		if not field.has_point(screen_point) or covers.any(func(rect):return rect.has_point(screen_point)):continue
		for path in paths:
			var nearest := Geometry2D.get_closest_point_to_segment(point,inverse*path[0],inverse*path[1])
			if point.distance_to(nearest)<55:
				game.collect(drop,true)
				break

func invalidate_equipment_projections() -> void:
	if not is_instance_valid(equipment_panel):return
	# Coalesce repeated modifier events with equipment_stats in refresh_pending.
	for category in ["weapons","defence"]:
		equipment_panel.invalidate_stats({"category":category,"detail":true})

func on_event(kind: String, info: Dictionary) -> void:
	match kind:
		"galaxy_unlocked":
			if is_instance_valid(equipment_tabs):refresh_tab_visibility()
			if is_instance_valid(crew_panel):crew_panel.invalidate()
		"galaxy_changed":
			if is_instance_valid(galaxy_panel):galaxy_panel.refresh()
		"galaxy_income":
			if is_instance_valid(galaxy_panel):galaxy_panel.refresh()
		"crew_changed":
			var assignment_changed: bool = info.previous.get("assignmentType")!=info.current.get("assignmentType") or info.previous.get("targetId")!=info.current.get("targetId")
			if assignment_changed:
				if is_instance_valid(galaxy_panel):galaxy_panel.refresh()
				if is_instance_valid(crew_panel):crew_panel.invalidate()
				if is_instance_valid(planet_panel):planet_panel.invalidate()
			else:
				if is_instance_valid(crew_panel):
					if game.planet_crew_payout_active:
						# planet_changed refreshes the complete panel after this payout.
						crew_panel.dirty=true
					else:crew_panel.refresh_member(info.current)
				# Picker captions catch up once after a shared exploration payout.
				if is_instance_valid(planet_panel):planet_panel.dirty=true
			if not assignment_changed and info.previous.get("level")==info.current.get("level") and info.previous.get("upgradeMode")==info.current.get("upgradeMode"):return
			var tabs_changed: Dictionary = {}
			for item in [info.previous,info.current]:
				var row: Dictionary=game.crew.assignments(game).get(str(item.get("assignmentType","")),{})
				for index in CREW_TAB_TYPES:
					if CREW_TAB_TYPES[index].has(str(row.get("targetType",""))):tabs_changed[index]=true
			for index in tabs_changed:refresh_crew_tab_badge(int(index))
		"planet_reforged":
			# All reset systems and their unlocks change together.
			request_ui_rebuild()
		"planet_changed":
			refresh_planet_activation_badge()
			if is_instance_valid(planet_panel):
				planet_panel.invalidate()
				if info.has("reward"):planet_panel.show_completion(str(info.get("id", "")), float(info.reward))
			if is_instance_valid(crew_panel):crew_panel.invalidate()
			if is_instance_valid(enhancement_panel):enhancement_panel.invalidate()
			if info.has("reward") or info.has("activated"):
				# Shared modifiers change projections, not equipment structure or costs.
				invalidate_equipment_projections()
		"equipment_stats":
			if is_instance_valid(equipment_panel):equipment_panel.invalidate_stats(info)
		"enhancement_changed":
			if is_instance_valid(enhancement_panel):enhancement_panel.invalidate()
			invalidate_equipment_projections()
		"jewels_changed":
			if is_instance_valid(enhancement_panel):
				enhancement_panel.inventory_changed()
			if not str(info.get("slot", "")).is_empty():
				refresh_equipment_cards(str(info.slot))
			for slot in info.get("slots",[]):refresh_equipment_cards(str(slot))
		"jewel_error":
			toast(str(info.message))
		"jewel_pickup":
			if is_instance_valid(enhancement_panel):enhancement_panel.pickup_feedback(info)
			resource_pickup_feedback(info)
		"state":
			refresh_structure()
			refresh_navigation()
		"beam_started":
			if fast_mode_enabled():return
			var shot: Dictionary = info.shot
			beam_visuals.append({"shot":shot,"start":visual_muzzle(shot),"end":battle_logical_point(entity_render_position(shot.target)),"full":false})
			if not shot.hostile and int(shot.mount)>=0:turret_pose(int(shot.mount)).fired_at=fx_time
			weapon_flash(visual_muzzle(shot),weapon_visual_glow(weapon_key(shot),shot.hostile),7.0,0.07)
		"beam_hit":
			if fast_mode_enabled():return
			var shot: Dictionary = info.shot
			weapon_flash(battle_logical_point(entity_render_position(shot.target)),ORANGE if shot.hostile else CYAN,7.0,0.08)
		"critical_impact":
			if fast_mode_enabled():return
			weapon_flash(info.pos,Color.WHITE,14.0,0.08)
			beam_ring(info.pos,ORANGE,0.12,11)
			weapon_sparks(info.pos,7,140,info.direction)
		"hit":
			queue_damage_number(info)
		"explode":
			if info.has("slot"):
				death_drop_positions[int(info.uid)] = enemy_drop_anchor(info)
			if fast_mode_enabled():return
			var pos := visual_effect_point(Vector2(info.x,info.y))
			if info.get("boss",false):shake=maxf(shake,float(battle_visual.boss_destroy_shake))
			var destruction_time := maxf(0.3,float(battle_visual.destroy_effect_duration))
			weapon_flash(pos,ORANGE,22.0,float(battle_visual.hit_flash_duration))
			var destroy_visual := {"pos":pos,"vel":Vector2.ZERO,"color":ORANGE,"life":destruction_time,"duration":destruction_time,"destroy":true,"size":24.0}
			if particles.size()<WEAPON_PARTICLE_LIMIT:
				particles.append(destroy_visual)
			# Split the existing hull texture, using only an event-time visual snapshot.
			if info.has("size"):
				var texture: Texture2D = ship_hull_texture("enemy_"+str(clampi(int(info.size),1,6)))
				var dimensions := Vector2(30,60)
				for enemy in game.enemies:
					if enemy.get("uid",-1)==info.get("uid",-2):dimensions=Vector2(1,2)*enemy_render_width(enemy)
				destroy_visual.texture=texture
				destroy_visual.extent=dimensions
				for piece in 6:
					if particles.size()>=WEAPON_PARTICLE_LIMIT:break
					var cell := Vector2(piece%2,piece/2)
					var local := (cell+Vector2(0.5,0.5))*dimensions/Vector2(2,3)-dimensions/2
					local.x = -local.x
					particles.append({"pos":pos+local,"vel":local.normalized()*randf_range(65,120),"color":ORANGE,"life":destruction_time,"duration":destruction_time,"fragment":true,"texture":texture,"region":Rect2(cell*texture.get_size()/Vector2(2,3),texture.get_size()/Vector2(2,3)),"extent":dimensions/Vector2(2,3),"spin":randf_range(-2.5,2.5)})
			weapon_sparks(pos,14 if info.boss else 9,150)
			for i in 9:
				if particles.size()<WEAPON_PARTICLE_LIMIT:
					particles.append({"pos":pos,"vel":Vector2.from_angle(float(i)*TAU/9)*float(45+i*7),"color":ORANGE,"life":destruction_time,"size":7.0,"spark":true})
			weapon_smoke(pos,Color("7e7780"),3,0.24,9)
			beep(90)
		"projectile_impact":
			if fast_mode_enabled():return
			var visual := projectile_visual(info.shot)
			var impact: Vector2 = visual_effect_point(info.pos)
			if visual.has("fixed_step"):
				impact=straight_projectile_point(info.pos,visual)
			weapon_impact(info.shot,impact)
		"fire":
			if fast_mode_enabled():return
			if info.has("shot"):
				weapon_launch(info.shot,float(info.get("spread",0)))
			if info.has("shot") and weapon_key(info.shot)=="cannon":railgun_sound("release")
			else:beep(620 if info.type == 1 else 200)
		"collect":
			resource_pickup_feedback(info)
		"encounter":
			wave_hint = 0.8
		"wave_clear":
			wave_hint = 1.1
		"upgrade":
			var levels := int(info.get("levels",1))
			var slot: String = str(info.get("slot",""))
			var prefix := ("W" if slot.begins_with("weapons_") else "D")+str(int(slot.get_slice("_",1))+1).pad_zeros(2)
			var equipment_name: String = NAMES.get(str(info.get("key","")),UIText.t("equipment.vacant"))
			toast(UIText.t("upgrade.completed",{"name":UIText.t("module.upgrade_name",{"slot":prefix+" "+equipment_name}),"result":UIText.t("main.on_event.text_02") if levels == 1 else UIText.t("main.on_event.text_03", {"levels":"%s" % (str(int(levels)))})}))
			if bool(info.get("batch",false)):return
			refresh_equipment_cards(str(info.get("slot","")))
			if is_instance_valid(enhancement_panel):
				enhancement_panel.invalidate()
		"upgrades_completed":
			if is_instance_valid(equipment_panel):equipment_panel.refresh_slots(info.slots)
			if is_instance_valid(enhancement_panel):
				enhancement_panel.invalidate()
		"module_changed":
			if is_instance_valid(crew_panel):crew_panel.invalidate()
			if is_instance_valid(enhancement_panel) and enhancement_panel.visible:enhancement_panel.refresh()
			refresh_equipment_cards(str(info.slot))
			refresh_ship_controls()
		"ship_changed":
			refresh_structure()
			if is_instance_valid(enhancement_panel) and enhancement_panel.visible:enhancement_panel.refresh()
		"hightech_complete":
			if game.hightech_level(str(info.key))==1 and is_instance_valid(crew_panel):crew_panel.invalidate()
			toast(UIText.t("upgrade.research_complete", {"name":UIText.data_text("hightech",str(info.key))}))
			refresh_equipment_effects(str(info.key))
		"unlock":
			help_open = false
			refresh_structure()
			refresh_navigation()
		"retreat":
			toast(UIText.t("main.on_event.text_05", {"to":"%s" % (number(info.to))}))
		"save_error":
			var error: Error = info.get("error", ERR_FILE_CANT_WRITE)
			toast(UIText.t("save.failed", {"error":error_string(error)}))
			refresh_save_status()
		"save_success":
			toast(UIText.t("save.success"))
			refresh_save_status()

func number(value) -> String:
	# Quantities use K/M/B/T; stage identifiers and levels use exact integers.
	return NUMBER_FORMAT.compact(value)

func enemy_health(value: float) -> String:
	return number(value)

func cost_text(cost: Dictionary) -> String:
	var result := ""
	for id in cost:
		result += UIText.t("main.cost_text.text_01", {"id":"%s" % (number(cost[id])), "id_2":"%s" % (UIText.data_text("resources",str(id)))})
	return result.strip_edges()

func prune_resource_samples(now: float) -> void:
	game.prune_resource_samples(now)

func resource_display(id: String, now := -1.0) -> String:
	if not resource_rate_mode:
		return number(game.profile.resources[id])
	if now < 0:
		now = Time.get_unix_time_from_system()
	prune_resource_samples(now)
	var rate = GrowthNumber.divide(game.resource_minute_total(id,now),60.0)
	return UIText.t("inventory.rate",{"rate":NUMBER_FORMAT.rate(rate)})

func toggle_resource_display() -> void:
	resource_rate_mode = not resource_rate_mode
	resource_mode_button.text = UIText.t("main.build_ui.text_02") if resource_rate_mode else UIText.t("main.build_ui.text_03")
	resource_layer.queue_redraw()

func toast(value: String) -> void:
	message = value
	message_time = 3.5

func load_music_setting() -> void:
	var config := ConfigFile.new()
	if config.load(MUSIC_SETTINGS_PATH) != OK:
		return
	var saved: Variant = config.get_value("audio", "music_on", true)
	if saved is bool:
		music_on = saved

func show_save_page() -> void:
	select_system(equipment_tabs.get_tab_idx_from_control(save_panel))
	refresh_save_status()

func create_save_file_picker() -> FileDialog:
	var picker := FileDialog.new()
	picker.use_native_dialog = true
	return picker

func open_save_file(mode: String) -> void:
	if OS.has_feature("web") or import_committing:return
	pending_import.clear()
	if not is_instance_valid(save_file_dialog):
		save_file_dialog = create_save_file_picker()
		save_file_dialog.name = "SaveTransferFile"
		save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_file_dialog.exclusive = true
		save_file_dialog.add_filter("*.json",UIText.t("save.file_filter"))
		save_file_dialog.file_selected.connect(save_file_selected)
		save_file_dialog.canceled.connect(func():save_file_dialog.hide();pending_import.clear();show_save_page())
		add_child(save_file_dialog)
	save_file_dialog.set_meta("mode",mode)
	save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode=="export" else FileDialog.FILE_MODE_OPEN_FILE
	save_file_dialog.current_file = "space-battleship-progress.json" if mode=="export" else ""
	save_file_dialog.popup_centered(Vector2i(860,560))

func save_file_selected(path: String) -> void:
	save_file_dialog.hide()
	if save_file_dialog.get_meta("mode")=="export":
		var error: Error=save_transfer.export_progress(game,path)
		save_transfer_message(UIText.t("save.export_success",{"file":path.get_file()}) if error==OK else UIText.t("save.transfer_failed",{"error":error_string(error)}))
		return
	var prepared: Dictionary=save_transfer.prepare(path,db)
	if not prepared.error.is_empty():
		save_transfer_message(UIText.t("save.import_invalid_"+str(prepared.error)))
		return
	pending_import=prepared.data
	if not is_instance_valid(save_import_confirmation):
		save_import_confirmation=ConfirmationDialog.new()
		save_import_confirmation.name="ConfirmSaveImport"
		save_import_confirmation.title=UIText.t("save.import_title")
		save_import_confirmation.ok_button_text=UIText.t("save.import_replace")
		save_import_confirmation.exclusive=true
		preload("res://scripts/dialog_presentation.gd").dialog(save_import_confirmation)
		save_import_confirmation.confirmed.connect(confirm_save_import)
		save_import_confirmation.canceled.connect(func():save_import_confirmation.hide();pending_import.clear();show_save_page())
		add_child(save_import_confirmation)
		save_confirmation_text=Label.new()
		save_confirmation_text.name="ImportReplacementRisk"
		save_confirmation_text.custom_minimum_size=Vector2(600,220)
		save_confirmation_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		save_confirmation_text.add_theme_color_override("font_color",Color("916326"))
		save_import_confirmation.add_child(save_confirmation_text)
	save_confirmation_text.text=UIText.t("save.import_confirmation",{"file":path.get_file(),"stage":str(prepared.stage)})
	save_import_confirmation.popup_centered(Vector2i(680,340))

func save_transfer_message(message: String) -> void:
	show_save_page()
	save_transfer_feedback.text=message

func confirm_save_import() -> void:
	save_import_confirmation.hide()
	if import_committing or pending_import.is_empty():return
	import_committing=true
	var transaction: Dictionary=save_transfer.commit_import(game,pending_import)
	pending_import.clear()
	if transaction.error!=OK:
		import_committing=false
		save_transfer_message(UIText.t("save.transfer_failed",{"error":error_string(transaction.error)}))
		return
	# Explicit global replacement uses the same fresh load/cache/UI path as startup.
	var was_saving: bool=game.save_enabled
	game.save_enabled=false
	set_process(false)
	var scene_tree:=get_tree()
	var error:=scene_tree.reload_current_scene()
	if error!=OK:
		var rollback_error: Error=save_transfer.rollback(transaction)
		game.save_enabled=was_saving
		set_process(true)
		import_committing=false
		save_transfer_message(UIText.t("save.import_reload_failed",{"error":error_string(error),"backup":str(transaction.backup),"rollback":error_string(rollback_error)}))
		return
	save_transfer.finish(transaction)
	scene_tree.set_meta("save_import_backup",str(transaction.backup)+"/current-progress.json")

func apply_save_interval() -> void:
	if not game.set_save_interval(save_interval_input.text):
		save_interval_feedback.text = UIText.t("save.invalid_interval")
		return
	save_interval_input.text = str(game.save_interval_minutes)
	save_interval_feedback.text = UIText.t("save.interval_applied", {"minutes":str(game.save_interval_minutes)})

func manual_save() -> void:
	game.save_progress()

func refresh_save_status() -> void:
	if not is_instance_valid(last_save_label) or not save_panel.is_visible_in_tree():return
	save_panel.refresh_actions()
	var display := UIText.t("save.never")
	if game.last_successful_save_at > 0:
		var bias := int(Time.get_time_zone_from_system().get("bias",0))
		display = Time.get_datetime_string_from_unix_time(int(game.last_successful_save_at)+bias*60,true)
	set_ui_value(last_save_label,"text",UIText.t("save.last_success", {"time":display}))
	set_ui_value(save_status_label,"text",UIText.t("save.failed", {"error":error_string(game.last_save_error)}) if game.last_save_error != OK else "")
	set_ui_value(save_status_label,"visible",game.last_save_error != OK)

func save_music_setting() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_on", music_on)
	config.save(MUSIC_SETTINGS_PATH)

func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		music.play()
	else:
		music.stop()
	if game.save_enabled:
		save_music_setting()
	refresh_navigation()

func railgun_component_charge(component, enemy: Dictionary = {}) -> float:
	if accelerated_visual_mode:return 0.0
	if str(component.profile.get("visual_class",""))!="gun" or game.state!=BattleGame.State.COMBAT:return 0.0
	if enemy.is_empty() and not game.has_alive_enemy():return 0.0
	var progress := 0.0
	for slot in component.slots:
		var remaining := INF
		if enemy.is_empty():
			if str(game.slot_entry("weapons",slot).get("key",""))!="cannon":continue
			progress=maxf(progress,player_railgun_charge(slot))
			continue
		else:
			if slot>=enemy.cooldowns.size() or str(enemy.equipment[slot].name).replace("_mon", "").replace("-mon", "")!="cannon":continue
			remaining=float(enemy.cooldowns[slot])
		progress=maxf(progress,railgun_fx.charge(remaining,maxf(0.01,game.speed)))
	return progress

func player_railgun_charge(slot: int) -> float:
	var entry: Dictionary=game.slot_entry("weapons",slot)
	var remaining := float(game.cooldowns.get(game.slot_id("weapons",slot),INF))
	var base: Dictionary=db.equip("cannon",int(entry.get("level",1)))
	return railgun_fx.player_charge(remaining,game.enhancement_branches.cooldown_multiplier(game,entry),float(base.cd))

func railgun_sound(kind: String) -> void:
	if not sound_on or game.paused or not railgun_audio.has(kind):return
	if fx_time-float(railgun_sound_times.get(kind,-100.0))<0.055:return
	railgun_sound_times[kind]=fx_time
	railgun_audio[kind].play()

func update_railgun_audio() -> void:
	if railgun_audio.is_empty():return
	if not sound_on or game.paused or (is_instance_valid(balance_lab) and balance_lab.visible):
		for voice in railgun_audio.values():
			if voice.playing:voice.stop()
		return
	var progress := 0.0
	for component in player_weapon_components():progress=maxf(progress,railgun_component_charge(component))
	for enemy in game.enemies:
		if float(enemy.hp)<=0:continue
		for component in enemy_weapon_components(enemy):progress=maxf(progress,railgun_component_charge(component,enemy)*0.8)
	var voice: AudioStreamPlayer = railgun_audio.charge
	if progress<=0.0:
		if voice.playing:voice.stop()
		return
	voice.pitch_scale=lerpf(0.8,2.1,progress*progress)
	voice.volume_db=lerpf(-42.0,-28.0,progress)
	if not voice.playing:voice.play()

func beep(frequency: float) -> void:
	if not sound_on or clock-last_sound < 0.09:
		return
	last_sound = clock
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	for i in range(1100):
		var sample := sin(float(i)*frequency*TAU/22050.0)*50.0*(1.0-float(i)/1100.0)
		bytes.append(int(sample)&255)
	wav.data = bytes
	audio.stream = wav
	audio.play()

# Exact equipment-table IDs, plus missile_mon's existing legacy fallback contract.
const ENEMY_VISUAL_ALIASES := {"laser_mon":"laser","cannon-mon":"cannon","missile-mon":"missile","longLaser-mon":"longLaser","missile_mon":"missile"}

func weapon_visual_key(key:String)->String:
	return str(ENEMY_VISUAL_ALIASES.get(key,key))

func weapon_key(shot: Dictionary) -> String:
	return weapon_visual_key(str(shot.key))

func weapon_visual_tier(shot: Dictionary) -> int:
	if bool(shot.get("hostile",false)) and game.is_boss_encounter():return 2
	return 1 if weapon_key(shot) in ["cannon","missile"] else 0

func weapon_strength(shot: Dictionary) -> float:
	return 1.0 + clampf(GrowthNumber.logarithm(GrowthNumber.maximum(1,shot.damage))/30.0,0,0.5)

func decoration_budget(pos: Vector2, count: int) -> int:
	var nearby := 0
	for particle in particles:
		if particle.pos.distance_squared_to(pos)<6400:nearby += 1
	return mini(count,maxi(0,18-nearby))

func weapon_smoke(pos: Vector2, color: Color, count: int, duration: float, size: float) -> void:
	if fast_mode_enabled():return
	for i in mini(decoration_budget(pos,count),maxi(0,WEAPON_PARTICLE_LIMIT-particles.size())):
		particles.append({"pos":pos,"vel":Vector2(randf_range(-16,16),randf_range(-22,-6)),"color":color,"life":duration,"duration":duration,"size":size,"smoke":true})

func weapon_flash(pos: Vector2, color: Color, radius: float, duration: float) -> void:
	if fast_mode_enabled():return
	if particles.size()>=WEAPON_PARTICLE_LIMIT:
		for i in particles.size():
			if not particles[i].has("flash"):
				particles.remove_at(i)
				break
		if particles.size()>=WEAPON_PARTICLE_LIMIT:particles.remove_at(0)
	particles.append({"pos":pos,"vel":Vector2.ZERO,"color":color,"life":duration,"duration":duration,"size":radius,"flash":true})

func weapon_sparks(pos: Vector2, count: int, force: float, direction := Vector2.RIGHT) -> void:
	if fast_mode_enabled():return
	for i in mini(decoration_budget(pos,count),maxi(0,WEAPON_PARTICLE_LIMIT-particles.size())):
		particles.append({"pos":pos,"vel":direction.rotated(randf_range(-0.65,0.65))*randf_range(force*0.3,force),"color":ORANGE,"life":randf_range(0.12,0.22),"size":randf_range(5,11),"spark":true})

func turret_angle(index: int) -> float:
	if turret_ship!=str(game.profile.selectedShip) or not turret_visuals.has(index):return 0.0
	var pose: Dictionary = turret_visuals[index]
	return float(pose.angle) if is_same(pose.entry,game.slot_entry("weapons",index)) and pose.key==str(pose.entry.key) else 0.0

func ship_visual_entry(ship_key: String) -> Dictionary:
	return visual_config.get("ships",{}).get(ship_key,{})

func weapon_visual_profile(key: String) -> Dictionary:
	return visual_config.get("weapons",{}).get(weapon_visual_key(key),{})

func weapon_visual_glow(key: String, hostile: bool) -> Color:
	var faction := "enemy" if hostile else "ally"
	var skin: Dictionary = weapon_visual_profile(key).get("faction_skin",{}).get(faction,{})
	return Color(str(skin.get("muzzle_glow","ffbc73" if hostile else "71e5f4")))

func visual_texture(path: String) -> Texture2D:
	if path.is_empty():return null
	if not visual_textures.has(path):visual_textures[path]=load(path)
	return visual_textures[path]

func visual_region(path: String) -> Rect2:
	if not visual_regions.has(path):visual_regions[path]=Rect2(visual_texture(path).get_image().get_used_rect())
	return visual_regions[path]

func ship_hull_texture(ship_key: String) -> Texture2D:
	return visual_texture(str(ship_visual_entry(ship_key).get("texture","")))

func slot_hardpoint_index(ship_key: String, index: int) -> int:
	var ship := ship_visual_entry(ship_key)
	var mapping: Array = ship.get("slot_map",[])
	var points: Array = ship.get("hardpoints",[])
	if points.is_empty():return -1
	return clampi(int(mapping[index]) if index<mapping.size() else posmod(index,points.size()),0,points.size()-1)

func hardpoint_for_slot(ship_key: String, index: int) -> Dictionary:
	var point := slot_hardpoint_index(ship_key,index)
	return ship_visual_entry(ship_key).get("hardpoints",[])[point] if point>=0 else {}

func weapon_visual_role(index: int) -> String:
	var component = player_component_for_slot(index)
	return component.mode() if component!=null else "embedded"

func weapon_visual_angle(index: int) -> float:
	var role := weapon_visual_role(index)
	var limit := deg_to_rad(float(hardpoint_for_slot(str(game.profile.selectedShip),index).get("rotation_limit",0)))
	return clampf(turret_angle(index),-limit,limit)*(1.0 if role=="main" else 0.2 if role=="secondary" else 0.0)

func player_weapon_components() -> Array:
	if battle_draw_active:return player_components
	var ship_key := str(game.profile.selectedShip)
	var entries := game.weapon_entries()
	var signature := ship_key
	for entry in entries:signature += "|"+str(entry.get("key",""))
	if signature==player_components_signature:return player_components
	player_components_signature=signature
	player_components=compose_weapon_components(ship_key,entries,"ally")
	return player_components

func compose_weapon_components(ship_key: String, entries: Array, faction: String) -> Array:
	var components: Array = []
	var ship := ship_visual_entry(ship_key)
	var points: Array = ship.get("hardpoints",[])
	for point_index in points.size():
		var point: Dictionary = points[point_index]
		var bound: Array[int] = []
		var owner := -1
		for index in entries.size():
			if slot_hardpoint_index(ship_key,index)!=point_index:continue
			bound.append(index)
			var profile := weapon_visual_profile(str(entries[index].get("key","")))
			if profile.is_empty() or not point.get("allowed_weapon_visual_class",[]).has(profile.get("visual_class","")):continue
			if owner<0 or (str(weapon_visual_profile(str(entries[owner].get("key",""))).get("visual_class",""))=="missile" and str(profile.get("visual_class",""))!="missile"):
				owner=index
		if owner>=0:components.append(WEAPON_VISUAL.new(point,weapon_visual_profile(str(entries[owner].key)),bound,owner,faction))
	return components

func enemy_weapon_components(enemy: Dictionary) -> Array:
	var pose := enemy_pose(enemy)
	var ship_key := "enemy_"+str(clampi(int(enemy.size),1,6))
	var entries: Array = []
	var signature := ship_key
	for equipment in enemy.equipment:
		var key := str(equipment.get("name",""))
		entries.append({"key":key})
		signature += "|"+key
	if str(pose.get("components_signature",""))!=signature:
		pose.components_signature=signature
		pose.components=compose_weapon_components(ship_key,entries,"enemy")
	return pose.components

func turret_pose(index: int) -> Dictionary:
	if turret_ship!=str(game.profile.selectedShip):
		turret_visuals.clear()
		turret_ship = str(game.profile.selectedShip)
	var entry := game.slot_entry("weapons",index)
	if not turret_visuals.has(index) or not is_same(turret_visuals[index].entry,entry) or turret_visuals[index].key!=str(entry.key):
		turret_visuals[index] = {"entry":entry,"key":str(entry.key),"angle":0.0,"target":{},"recoil":0.0}
	return turret_visuals[index]

func turret_muzzle(index: int) -> Vector2:
	var key := str(game.profile.selectedShip)
	var scale_value := player_art_scale()
	var component = player_component_for_slot(index)
	var owner: int = component.owner_slot if component!=null else index
	var profile: Dictionary = component.profile if component!=null else weapon_visual_profile(str(game.slot_entry("weapons",index).get("key","")))
	var muzzle: Array = profile.get("muzzle",[[0.25,0]])
	var class_scale := float({"small":0.72,"medium":0.9,"large":1.1}.get(str(component.hardpoint.get("visual_size_class","medium")),0.9)) if component!=null else 0.9
	var reach := SHIP_VISUALS.module_width(key)*class_scale*float(muzzle[0][0])
	var local := player_mount_center(key,index)+Vector2(reach,0).rotated(weapon_visual_angle(owner))
	return battle_logical_point(player_render_position()+local.rotated(-PI/2+player_idle_angle())*scale_value)

func player_component_for_slot(index: int):
	for component in player_weapon_components():
		if component.slots.has(index):return component
	return null

func shot_mount(shot: Dictionary) -> int:
	if shot.hostile:return -1
	if shot.has("mount"):return int(shot.mount)
	var closest := -1
	var distance := INF
	for index in game.weapon_entries().size():
		if str(game.slot_entry("weapons",index).key)!=weapon_key(shot):continue
		var muzzle := Vector2(game.player.x,game.player.y)+game.player_weapon_offset(index)
		var candidate := muzzle.distance_squared_to(Vector2(shot.x,shot.y))
		if candidate<distance:
			distance = candidate
			closest = index
	return closest

func enemy_render_angle(enemy:Dictionary)->float:
	var pose:=enemy_pose(enemy)
	return float(pose.rotation)+deg_to_rad(float(battle_visual.enemy_idle_rotation))*sin(fx_time*0.83+float(pose.phase))

func enemy_component_pose(enemy:Dictionary,component)->Dictionary:
	var point:Dictionary=component.hardpoint
	var width:=enemy_render_width(enemy)
	var hull_angle:=enemy_render_angle(enemy)
	var normalized:Array=point.pos
	var origin:=Vector2(float(normalized[0])*width,float(normalized[1])*width*2.0).rotated(PI+hull_angle)
	var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
	var module_width:=width*0.42*class_scale
	var angle:=PI/2+hull_angle+enemy_weapon_angle(enemy,component.owner_slot)+deg_to_rad(float(point.get("base_rotation",0)))
	var muzzle:Array=component.profile.get("muzzle",[[0.22,0]])
	var port:=Vector2(float(muzzle[0][0]),float(muzzle[0][1]))*module_width
	return {"origin":origin,"angle":angle,"width":module_width,"port":port,"muzzle":origin+port.rotated(angle)}

func enemy_port_offset(enemy: Dictionary, index: int) -> Vector2:
	var component=enemy_component_for_slot(enemy,index)
	if component!=null:return enemy_component_pose(enemy,component).muzzle
	# Unknown external configurations keep the previous logical mount fallback.
	var point:=hardpoint_for_slot("enemy_"+str(clampi(int(enemy.size),1,6)),index)
	if point.is_empty():return Vector2.ZERO
	var width:=enemy_render_width(enemy)
	var angle:=float(enemy_pose(enemy).rotation)
	var origin:=Vector2(float(point.pos[0])*width,float(point.pos[1])*width*2.0).rotated(PI+angle)
	var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
	return origin+Vector2(width*0.42*class_scale*0.22,0).rotated(PI/2+angle)

func enemy_weapon_angle(enemy: Dictionary, index: int) -> float:
	var component = enemy_component_for_slot(enemy,index)
	if component==null:return 0.0
	var role: String = component.mode()
	if role!="main" and role!="secondary":return 0.0
	var pose_angle := enemy_render_angle(enemy)
	var desired := wrapf((player_render_position()-enemy_render_position(enemy)).angle()-PI/2-pose_angle,-PI,PI)
	var limit := deg_to_rad(float(component.hardpoint.get("rotation_limit",0)))
	return clampf(desired,-limit,limit)*(1.0 if role=="main" else 0.2)

func enemy_component_for_slot(enemy: Dictionary, index: int):
	for component in enemy_weapon_components(enemy):
		if component.slots.has(index):return component
	return null

func enemy_shot_mount(enemy: Dictionary, shot: Dictionary) -> int:
	if is_same(enemy,shot.get("source",{})) and shot.has("mount"):return int(shot.mount)
	var origin := Vector2(float(shot.x),float(shot.y))
	var best := 0
	var distance := INF
	for index in enemy.equipment.size():
		var logical := Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,index)
		var candidate := logical.distance_squared_to(origin)
		if candidate<distance:
			distance = candidate
			best = index
	return best

func advance_turrets(dt: float) -> void:
	if game.paused:return
	var entries := game.weapon_entries()
	for index in turret_visuals.keys():
		if int(index)>=entries.size() or str(entries[index].key).is_empty():turret_visuals.erase(index)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if str(entry.key).is_empty():continue
		var pose := turret_pose(index)
		pose.recoil = maxf(0,float(pose.recoil)-dt)
		var target: Dictionary = pose.target
		# A live main beam owns its mount's aim; repeats cannot pull it off target.
		for shot in game.projectiles:
			if shot.get("beam",false) and not shot.hostile and int(shot.mount)==index and not shot.get("repeated",false) and game.long_laser_valid(shot):
				target = shot.target
				break
		if game.state!=BattleGame.State.COMBAT:
			target = {}
		elif target.is_empty() or not game.enemies.has(target) or float(target.get("hp",0))<=0:
			var candidates := game.targets(int(db.equip(str(entry.key),int(entry.level)).dmgtype))
			target = candidates[0] if not candidates.is_empty() else {}
		pose.target = target
		var desired := 0.0
		if not target.is_empty():
			var pivot := player_render_position()+player_mount_center(str(game.profile.selectedShip),index).rotated(-PI/2+player_idle_angle())*player_art_scale()
			var limit := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_limit_degrees",85.0)))
			desired = clampf(wrapf((entity_render_position(target)-pivot).angle()+PI/2-player_idle_angle(),-PI,PI),-limit,limit)
		var speed := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_turn_degrees_per_second",240.0)))
		pose.angle = rotate_toward(float(pose.angle),desired,maxf(0,speed)*dt)

func visual_muzzle(shot: Dictionary) -> Vector2:
	var pos := Vector2(shot.x,shot.y)
	if shot.hostile:
		var nearest: Dictionary = {}
		var distance := INF
		for enemy in game.enemies:
			if is_same(enemy,shot.get("source",{})):
				return battle_logical_point(enemy_render_position(enemy)+enemy_port_offset(enemy,enemy_shot_mount(enemy,shot)))
			for index in enemy.equipment.size():
				var candidate := pos.distance_squared_to(Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,index))
				if candidate<distance:
					distance=candidate
					nearest=enemy
		if not nearest.is_empty():return battle_logical_point(enemy_render_position(nearest)+enemy_port_offset(nearest,enemy_shot_mount(nearest,shot)))
		return pos
	var index := shot_mount(shot)
	if index>=0:return turret_muzzle(index)
	var source := Vector2(game.player.x,game.player.y)
	return source+(pos-source)*player_art_scale()/SHIP_VISUALS.scale_for(db.ship(str(game.profile.selectedShip)))

func player_base_art_scale_for(ship_key: String) -> float:
	var entry := ship_visual_entry(ship_key)
	return float(entry.get("display_scale",minf(SHIP_VISUALS.scale_for(db.ship(ship_key)),0.18)))*SHIP_VISUALS.player_display_multiplier()

func player_base_art_scale() -> float:
	return player_base_art_scale_for(str(game.profile.selectedShip))

func player_art_scale_for(ship_key: String) -> float:
	return player_base_art_scale_for(ship_key)*float(db.config.get("playerVisualScale"+ship_key,1.0))

func player_art_scale() -> float:
	return player_art_scale_for(str(game.profile.selectedShip))

func player_idle_angle() -> float:
	return deg_to_rad(float(battle_visual.player_idle_rotation))*sin(fx_time*TAU/6.3)

func player_visible_tail() -> float:
	var ship_key := str(game.profile.selectedShip)
	var texture_path := str(ship_visual_entry(ship_key).get("texture",""))
	if texture_path.is_empty():return SHIP_ART_CANVAS.y*float(battle_visual.player_core_scale)*player_art_scale()*0.5
	if not hull_visible_bottoms.has(texture_path):
		var image := visual_texture(texture_path).get_image()
		image.convert(Image.FORMAT_RGBA8)
		var pixels := image.get_data()
		var width := image.get_width()
		var bottom := image.get_height()
		for y in range(image.get_height()-1,-1,-1):
			var found := false
			for x in range(0,width,2):
				if pixels[(y*width+x)*4+3]>8:
					bottom=y+1
					found=true
					break
			if found:break
		hull_visible_bottoms[texture_path]=bottom
	return (float(hull_visible_bottoms[texture_path])-SHIP_ART_CANVAS.y*0.5)*float(battle_visual.player_core_scale)*player_art_scale()

func player_render_position() -> Vector2:
	if battle_draw_active:return battle_draw_player_position
	var half_height := SHIP_ART_CANVAS.y*float(battle_visual.player_core_scale)*player_art_scale()*0.5
	var reference_half_height := SHIP_ART_CANVAS.y*float(battle_visual.player_core_scale)*0.18*1.15*0.5
	var hud_top := 1132.0-BATTLE_ORIGIN.y
	var y := BATTLE_VIEW_SIZE.y*float(battle_visual.player_ship_y)+maxf(0.0,reference_half_height-half_height)
	y = minf(y,hud_top-float(battle_visual.player_hud_gap)-player_visible_tail()-absf(float(battle_visual.player_idle_y)))
	return Vector2(game.player.x,y)+Vector2(sin(fx_time*TAU/5.7)*float(battle_visual.player_idle_x),sin(fx_time*TAU/4.3)*float(battle_visual.player_idle_y))

func player_mount_center(key: String, index: int) -> Vector2:
	# Convert normalized hull coordinates to the original x-forward mount frame.
	var point := hardpoint_for_slot(key,index)
	if point.is_empty():return Vector2.ZERO
	var normalized: Array = point.pos
	var core := SHIP_ART_CANVAS*float(battle_visual.player_core_scale)
	return Vector2(-float(normalized[1])*core.y,float(normalized[0])*core.x)

func enemy_config_visual_scale(size: int) -> float:
	return float(db.config.get("enemyVisualScaleSize"+str(clampi(size,1,6)),1.0))

func enemy_formation_anchor(slot: int, large: bool, size: int) -> Vector2:
	var scale_offset := maxf(0.0,enemy_config_visual_scale(size)-1.0)*35.0
	return Vector2(BattleGame.enemy_slot_position(slot).x,(130.0 if large else 120.0)+scale_offset)

func enemy_pose(enemy: Dictionary) -> Dictionary:
	var slot := int(enemy.slot)
	if enemy_poses.has(slot) and is_same(enemy_poses[slot].entity,enemy):return enemy_poses[slot]
	# Local deterministic generator never consumes the combat RNG stream.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(enemy.get("uid",slot))*7919+slot*104729
	var phase := rng.randf()*TAU
	var offset := Vector2(0,rng.randf_range(-battle_visual.enemy_offset_y,battle_visual.enemy_offset_y))
	var large := game.is_boss_encounter() or game.enemies.any(func(item):return int(item.size)>=4)
	var anchor := enemy_formation_anchor(slot,large,int(enemy.size))
	anchor.x += float(enemy.x)-BattleGame.enemy_slot_position(slot).x
	# Preserve left-to-right slot order. Hull overlap is allowed for this line.
	var target := anchor+offset
	target.x = clampf(target.x,54.0,BATTLE_VIEW_SIZE.x-54.0)
	var pose := {"entity":enemy,"logical_position":Vector2(enemy.x,enemy.y),"target":target,"phase":phase,"born":fx_time,
		"variance":rng.randf_range(battle_visual.enemy_scale_variance.x,battle_visual.enemy_scale_variance.y),
		"rotation":deg_to_rad(rng.randf_range(-battle_visual.enemy_rotation_variance,battle_visual.enemy_rotation_variance)),
		"duration":rng.randf_range(0.65,1.15),"entry_x":rng.randf_range(-2,2)}
	enemy_poses[slot] = pose
	return pose

func enemy_depth(enemy: Dictionary) -> float:
	return clampf((enemy_render_position(enemy).y-90.0)/maxf(1.0,enemy_frontline_y_limit(enemy)-90.0),0,1)

func enemy_render_width(enemy: Dictionary) -> float:
	var tier := 1.85 if game.is_boss_encounter() else 1.5 if int(enemy.size)>=4 else 1.0+float(int(enemy.size)-1)*0.08
	var width_limit := 78.0 if game.is_boss_encounter() else 66.0 if int(enemy.size)>=4 else 54.0
	var base := minf(width_limit/(float(battle_visual.enemy_depth_scale_max)*float(battle_visual.enemy_scale_variance.y)),SHIP_VISUALS.CANVAS.y*1.2*player_base_art_scale()*float(battle_visual.enemy_base_scale)*tier)
	return base*enemy_config_visual_scale(int(enemy.size))*lerpf(battle_visual.enemy_depth_scale_min,battle_visual.enemy_depth_scale_max,enemy_depth(enemy))*float(enemy_pose(enemy).variance)

func enemy_frontline_y_limit(enemy: Dictionary) -> float:
	# Measure empty firing space between hull envelopes, not entity centres.
	# Conservative rotation bounds avoid a dependency on enemy_depth/width.
	var player_half_height := (SHIP_ART_CANVAS.y*float(battle_visual.player_core_scale)/2.0+SHIP_ART_CANVAS.x*float(battle_visual.player_core_scale)/2.0*absf(sin(deg_to_rad(float(battle_visual.player_idle_rotation)))))*player_art_scale()
	var player_front := BATTLE_VIEW_SIZE.y*float(battle_visual.player_ship_y)-absf(float(battle_visual.player_idle_y))-player_half_height
	var enemy_half_height := (78.0 if game.is_boss_encounter() else 66.0 if int(enemy.size)>=4 else 54.0)*1.06*enemy_config_visual_scale(int(enemy.size))
	return minf(BATTLE_VIEW_SIZE.y*float(battle_visual.enemy_max_y),player_front-BATTLE_VIEW_SIZE.y*float(battle_visual.enemy_player_min_gap)-enemy_half_height)

func enemy_render_position(enemy: Dictionary) -> Vector2:
	var cached: Dictionary = battle_draw_enemy_positions.get(int(enemy.slot),{}) if battle_draw_active else {}
	if not cached.is_empty() and is_same(cached.entity,enemy):return cached.position
	var pose := enemy_pose(enemy)
	var age := maxf(0,fx_time-float(pose.born))
	var enter := 1.0-pow(1.0-clampf(age/float(pose.duration),0,1),3)
	var target: Vector2 = pose.target+Vector2(enemy.x,enemy.y)-pose.logical_position
	target.x=clampf(target.x,54,BATTLE_VIEW_SIZE.x-54)
	var hover := Vector2(sin(fx_time*1.13+float(pose.phase))*float(battle_visual.enemy_idle_x),sin(fx_time*0.91+float(pose.phase))*float(battle_visual.enemy_idle_y))
	# Shared approach distance keeps each column separated even during entry.
	var position := target+Vector2(float(pose.entry_x)*(1.0-enter),-float(battle_visual.enemy_entry_distance)*(1.0-enter))+hover*enter
	var half_height := (78.0 if game.is_boss_encounter() else 66.0 if int(enemy.size)>=4 else 54.0)*1.06
	# Clamp the final animated position, so hover, entry and ship changes cannot
	# cross the front line. Logical entity coordinates remain untouched.
	position.y=clampf(position.y,half_height+8.0,floorf(enemy_frontline_y_limit(enemy)))
	if battle_draw_active:battle_draw_enemy_positions[int(enemy.slot)]={"entity":enemy,"position":position}
	return position

func entity_render_position(entity: Dictionary) -> Vector2:
	if is_same(entity,game.player):return player_render_position()
	if entity.has("slot"):return enemy_render_position(entity)
	return battle_point(Vector2(entity.x,entity.y))

func visual_effect_point(point: Vector2) -> Vector2:
	# Event-time snapshot in the existing FX coordinate space; no entity mutation.
	if point.distance_squared_to(Vector2(game.player.x,game.player.y))<1.0:return battle_logical_point(player_render_position())
	for enemy in game.enemies:
		if point.distance_squared_to(Vector2(enemy.x,enemy.y))<1.0:return battle_logical_point(enemy_render_position(enemy))
	return point

func battle_point(point: Vector2) -> Vector2:
	# Presentation only: open the engagement corridor without stretching hulls or FX.
	return Vector2(point.x,point.y+smoothstep(220.0,420.0,point.y)*220.0)

func enemy_drop_anchor(enemy: Dictionary) -> Vector2:
	return enemy_render_position(enemy)+Vector2(0,enemy_render_width(enemy)+12.0)

func drop_render_position(drop: Dictionary) -> Vector2:
	var source_uid := int(drop.get("source_uid",-1))
	if death_drop_positions.has(source_uid):return death_drop_positions[source_uid]
	if source_uid>=0:
		for enemy in game.enemies:
			if int(enemy.uid)==source_uid and float(enemy.hp)<=0:return enemy_drop_anchor(enemy)
	return battle_point(Vector2(drop.x,drop.y))

func recover_death_drop_positions() -> void:
	# A killed enemy remains in the encounter. Rebuild a lost display snapshot
	# before drawing or hit testing its drops; gameplay coordinates stay intact.
	for drop in game.drops:
		var source_uid := int(drop.get("source_uid",-1))
		if source_uid<0 or death_drop_positions.has(source_uid):continue
		for enemy in game.enemies:
			if int(enemy.uid)==source_uid and float(enemy.hp)<=0:
				death_drop_positions[source_uid] = enemy_drop_anchor(enemy)
				break

func drop_pickup_positions() -> Dictionary:
	recover_death_drop_positions()
	var positions := {}
	for drop in game.drops:
		positions[int(drop.uid)] = battle_logical_point(drop_render_position(drop))
	return positions

func battle_logical_point(point: Vector2) -> Vector2:
	# In these affine regions all original comparisons take the same branch.
	# Preserve the finite-bisection midpoint bias, rather than replacing it
	# with the mathematical inverse and moving missile collision coordinates.
	if point.y>=-512.0 and point.y<=220.0:
		return Vector2(point.x,point.y-BATTLE_LINEAR_INVERSE_OFFSET)
	if point.y>=640.0 and point.y<=2048.0:
		return Vector2(point.x,point.y-220.0+BATTLE_LINEAR_INVERSE_OFFSET)
	var low := point.y-220.0
	var high := point.y
	for iteration in BATTLE_INVERSE_STEPS:
		var middle := (low+high)*0.5
		if battle_point(Vector2(0,middle)).y<point.y:low=middle
		else:high=middle
	return Vector2(point.x,(low+high)*0.5)

func weapon_launch(shot: Dictionary, spread := 0.0) -> void:
	if fast_mode_enabled():return
	var key := weapon_key(shot)
	if key=="longLaser":return
	var mount := shot_mount(shot)
	if mount>=0:
		var pose := turret_pose(mount)
		if key!="missile" or not is_equal_approx(float(pose.get("fired_at",-1)),fx_time):
			pose.target = shot.target
			pose.fired_at = fx_time
		if key=="cannon":pose.recoil = 0.13
	if key=="cannon" and bool(shot.hostile):
		var nearest: Dictionary = {}
		var nearest_distance := INF
		for enemy in game.enemies:
			if enemy.equipment.is_empty():continue
			var slot := enemy_shot_mount(enemy,shot)
			var distance := (Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,slot)).distance_squared_to(Vector2(shot.x,shot.y))
			if distance<nearest_distance:
				nearest_distance=distance
				nearest={"enemy":enemy,"slot":slot}
		if not nearest.is_empty():enemy_pose(nearest.enemy)["rail_fired_"+str(nearest.slot)]=fx_time
	var pos := visual_muzzle(shot)
	var trail := PackedVector2Array()
	trail.resize(14)
	trail.fill(pos)
	# One fixed trail buffer per shot, overwritten in place during flight.
	if projectile_visuals.size()<256:
		projectile_visuals.append({"shot":shot,"angle":-PI/2+player_idle_angle()+weapon_visual_angle(mount) if mount>=0 else shot.direction.angle(),"mount":mount,"age":0.0,"origin":pos,"logical_origin":Vector2(shot.x,shot.y),"spread":spread,"trail":trail,"head":0,"samples":1,"trail_times":PackedFloat32Array([0,0,0,0,0,0,0,0,0,0,0,0,0,0])})
		if key in ["laser","cannon"] and not shot.target.is_empty():
			var visual: Dictionary=projectile_visuals.back()
			var distance := Vector2(shot.x,shot.y).distance_to(Vector2(shot.target.x,shot.target.y))
			visual.fixed_origin=battle_point(pos)
			visual.fixed_step=(entity_render_position(shot.target)-visual.fixed_origin)/maxf(distance,0.001)
			visual.fixed_direction=shot.direction
			visual.angle=Vector2(visual.fixed_step).angle()
	var tier := weapon_visual_tier(shot)
	if key=="cannon":
		weapon_flash(pos,Color("d8f8ff"),5.0*clampf(railgun_fx.muzzle_flash,0.0,1.5),0.035)
		return
	var fire_vfx := str(weapon_visual_profile(key).get("fire_vfx","flash"))
	var color := Color("fff0d5") if tier==2 else weapon_visual_glow(key,shot.hostile)
	var muzzle_radius := 13.0 if tier==2 else 11.0 if fire_vfx=="hatch" else 10.0 if fire_vfx=="flash" else 7.0
	weapon_flash(pos,color,muzzle_radius,0.07+float(tier)*0.015)
	if fire_vfx in ["hatch","flash"]:
		weapon_smoke(pos,Color("8992a0"),1,0.14,4.0)

func advance_projectile_visuals(dt: float) -> void:
	if fast_mode_enabled():
		projectile_visuals.clear()
		return
	var active_shots := {}
	for shot in game.projectiles:
		if shot.has("serial"):active_shots[shot.serial] = shot
	for i in range(projectile_visuals.size()-1,-1,-1):
		var visual: Dictionary = projectile_visuals[i]
		var alive: bool = is_same(active_shots.get(visual.shot.serial),visual.shot) if visual.shot.has("serial") else game.projectiles.has(visual.shot)
		if not alive:
			projectile_visuals.remove_at(i)
			continue
		visual.age += dt
		var next_position := missile_visual_position(visual.shot,float(visual.spread),visual.origin,visual)
		var movement := battle_point(next_position)-battle_point(visual.trail[int(visual.head)])
		var desired_angle: float = movement.angle() if movement.length_squared()>0.001 else visual.shot.direction.angle()
		visual.angle = lerp_angle(float(visual.angle),desired_angle,1.0-exp(-dt*16.0))
		if dt>0:
			visual.head = (int(visual.head)+1)%14
			visual.trail_times[visual.head] = visual.age
			visual.trail[visual.head] = next_position
			visual.samples = mini(14,int(visual.samples)+1)

func straight_projectile_point(logical_point: Vector2, visual: Dictionary) -> Vector2:
	var distance := (logical_point-Vector2(visual.logical_origin)).dot(visual.fixed_direction)
	return battle_logical_point(Vector2(visual.fixed_origin)+Vector2(visual.fixed_step)*distance)

func missile_visual_position(shot: Dictionary, spread: float, origin: Vector2, visual: Dictionary = {}) -> Vector2:
	var pos := Vector2(shot.x,shot.y)
	if visual.is_empty():visual = projectile_visual(shot)
	if visual.has("fixed_step"):return straight_projectile_point(pos,visual)
	var converge := 1.0
	if not shot.target.is_empty():
		converge = clampf(pos.distance_to(Vector2(shot.target.x,shot.target.y))/160.0,0,1)
	var logical_origin: Vector2 = visual.get("logical_origin",origin)
	var distance := pos.distance_to(logical_origin)
	var unfold := smoothstep(0.0,100.0,distance)
	var blend_distance := minf(160.0,logical_origin.distance_to(Vector2(shot.target.x,shot.target.y))) if not shot.target.is_empty() else 160.0
	var muzzle_shift := (origin-logical_origin)*(1.0-smoothstep(0.0,maxf(1,blend_distance),distance))
	var target_shift := Vector2.ZERO
	if not shot.target.is_empty():
		target_shift = (battle_logical_point(entity_render_position(shot.target))-Vector2(shot.target.x,shot.target.y))*(1.0-converge)
	return pos+muzzle_shift+target_shift+Vector2(spread*unfold*converge,0)

func projectile_visual(shot: Dictionary, index: Dictionary = {}) -> Dictionary:
	if shot.has("serial") and not index.is_empty():return index.get(shot.serial,{})
	for visual in projectile_visuals:
		if is_same(visual.shot,shot):return visual
	return {}

func projectile_visual_index() -> Dictionary:
	# Frame-local serial index; no references survive the draw.
	var index := {}
	for visual in projectile_visuals:
		if visual.shot.has("serial"):index[visual.shot.serial] = visual
	return index

func weapon_impact(shot: Dictionary, pos: Vector2) -> void:
	if fast_mode_enabled():return
	var key := weapon_key(shot)
	if key=="cannon":
		if particles.size()<WEAPON_PARTICLE_LIMIT:
			particles.append({"pos":pos,"vel":Vector2.ZERO,"color":Color("9eeaff"),"life":0.18,"duration":0.18,"rail_contact":true,"direction":shot.get("direction",Vector2.RIGHT)})
		if shot.get("critical",false):beam_ring(pos,Color("9eeaff"),0.09,5.0)
		railgun_sound("impact")
		return
	var tier := weapon_visual_tier(shot)
	var color := Color("fff0d5") if tier==2 else CYAN if key=="laser" else ORANGE
	var radius := 20.0 if tier==2 else 18.0 if key=="missile" else 16.0 if key=="cannon" else 11.0
	weapon_flash(pos,color,radius*IMPACT_SCALE,float(battle_visual.hit_flash_duration))
	if shot.get("critical",false):
		on_event("critical_impact",{"pos":pos,"direction":shot.get("direction",Vector2.RIGHT)})
	elif tier==2:
		beam_ring(pos,color,0.13,13.0)
	weapon_sparks(pos,4 if tier==2 else 3 if tier==1 else 2,210 if key=="cannon" else 160,shot.get("direction",Vector2.RIGHT))
	if key=="missile":
		# Short radial blast streaks read as impact, never as an area-of-damage circle.
		for i in mini(4,decoration_budget(pos,4)):
			if particles.size()>=WEAPON_PARTICLE_LIMIT:break
			particles.append({"pos":pos,"vel":Vector2.from_angle(float(i)*TAU/6)*150,"color":ORANGE,"life":0.18,"size":10.0,"spark":true})
		weapon_smoke(pos,Color("7e7780"),2,0.18,7.0*IMPACT_SCALE)

func draw_projectile_fx(shot: Dictionary, pos: Vector2, offset: Vector2, core := true, visual: Dictionary = {}, trail_budget := -1) -> float:
	var key := weapon_key(shot)
	var angle: float = shot.direction.angle()
	if not visual.is_empty():
		angle = visual.angle
	if key=="cannon":
		if core:
			var distance := pos.distance_to(battle_point(visual.get("origin",Vector2(shot.x,shot.y)))+offset)
			var render_speed := float(shot.get("speed",800.0))*Vector2(visual.get("fixed_step",Vector2.ONE.normalized())).length()*maxf(1.0,game.speed)
			railgun_fx.draw_flight(draw_surface,pos,Vector2.from_angle(angle),distance,render_speed)
		return angle
	if not visual.is_empty():
		var color := Color("ffc879") if key=="missile" else ORANGE if key=="cannon" else CYAN
		var trail_end := mini(int(visual.samples),14 if key=="missile" else 4)
		if core:trail_end=mini(trail_end,4)
		var head := int(visual.head)
		var shot_age := float(visual.age)
		var trail_scale := float(battle_visual.missile_trail_scale) if key=="missile" else float(battle_visual.bullet_trail_scale)
		for i in range(1 if core else 4,trail_end):
			# The short fresh trail shares the bullet layer; only older exhaust sits behind hulls.
			if i>4 and trail_budget==0:break
			var trail_index := (head-i+14)%14
			var a: Vector2 = battle_point(visual.trail[trail_index])+offset
			var b: Vector2 = battle_point(visual.trail[(trail_index+1)%14])+offset
			var age: float = shot_age-float(visual.trail_times[trail_index])
			var fade := maxf(0,1.0-age/(0.18 if key=="missile" else 0.075))
			if fade<=0:break
			draw_surface.draw_line(a,b,Color(color,fade*0.8),(3.5 if key=="missile" else 2.2)*fade*trail_scale,true)
	if not core:return angle
	if not visual.is_empty():
		var color := CYAN if key=="laser" else ORANGE
		if float(visual.age)<0.06:
			var fade := 1.0-float(visual.age)/0.06
			var muzzle: Vector2 = battle_point(visual.origin)+offset
			draw_surface.draw_line(muzzle,muzzle+Vector2.from_angle(angle)*(23.0 if key=="cannon" else 12.0)*fade,Color(color,fade),(5.0 if key=="cannon" else 3.0)*fade,true)
	var heading := Vector2.from_angle(angle)
	if key=="missile":
		var flame := (28.0+5.0*sin(float(visual.get("age",0))*65))*FLAME_SCALE
		var base := pos-heading*12
		var side := heading.orthogonal()*4.5*FLAME_SCALE
		draw_surface.draw_colored_polygon(PackedVector2Array([base+side,base-heading*flame,base-side]),Color(1,0.55,0.12,0.95))
		draw_surface.draw_colored_polygon(PackedVector2Array([base+side*0.5,base-heading*flame*0.75,base-side*0.5]),Color(1,0.97,0.8))
	elif key=="laser":
		# Round, layered halo avoids the rectangular texture/glow boundary.
		for i in range(-9,10,2):
			draw_surface.draw_circle(pos+heading*float(i),2.8*float(battle_visual.laser_glow_scale),Color(CYAN,0.08))
		draw_surface.draw_line(pos-heading*10,pos+heading*10,CYAN,2.0,true)
		draw_surface.draw_line(pos-heading*8,pos+heading*8,Color.WHITE,1.0,true)
	else:
		draw_surface.draw_line(pos-heading*15,pos,Color(ORANGE,0.75),2.0,true)
		draw_surface.draw_circle(pos+heading*5,3.0,Color(1,0.65,0.2,0.6))
		draw_surface.draw_line(pos+heading*2,pos+heading*9,Color(1,0.97,0.8),2.5,true)
	return angle

func beam_style(shot: Dictionary) -> Dictionary:
	var weapon: Dictionary = game.db.enemy_weapon(shot.entry.name) if shot.hostile else game.db.equip(shot.entry.key,int(shot.entry.level))
	var multiplier := game.long_laser_multiplier(weapon,maxf(0,float(shot.elapsed)-maxf(0,float(shot.charge))))
	var power := clampf((multiplier-1.0)/(float(weapon.para2)-1.0),0,1) if float(weapon.para2)>1 else 1.0
	var first_hit := float(shot.charge) if float(shot.charge)>=0 else float(shot.weapon.cd)
	var since_tick := float(shot.elapsed)-(first_hit+(int(shot.ticks)-1)*float(shot.weapon.cd))
	var pulse := maxf(0,1.0-since_tick/minf(0.12,float(shot.weapon.cd)*0.6)) if int(shot.ticks)>0 else 0.0
	return {"power":power,"width":lerpf(1.2,2.8,power)+pulse*0.6,"glow":0.05+power*0.045+pulse*0.2,"pulse":pulse}

func beam_ring(pos: Vector2, color: Color, duration: float, radius: float) -> void:
	if fast_mode_enabled():return
	if particles.size()>=WEAPON_PARTICLE_LIMIT or decoration_budget(pos,1)==0:return
	particles.append({"pos":pos,"vel":Vector2.ZERO,"color":color,"life":duration,"duration":duration,"size":radius,"ring":true})

func sync_beam_visuals() -> void:
	if fast_mode_enabled():
		beam_visuals.clear()
		return
	for visual in beam_visuals:
		var shot: Dictionary = visual.shot
		var color := ORANGE if shot.hostile else CYAN
		if not game.projectiles.has(shot) or not game.long_laser_valid(shot):
			particles.append({"pos":visual.start,"beam_end":visual.end if int(shot.ticks)>0 else visual.start,"vel":Vector2.ZERO,"color":color,"life":0.16,"duration":0.16,"size":4.0})
			burst(visual.start,color,6,65)
			weapon_flash(visual.end,color,3,0.06)
			continue
		visual.start = visual_muzzle(shot)
		visual.end = battle_logical_point(entity_render_position(shot.target))
		if int(shot.ticks)>0 and not visual.full and float(beam_style(shot).power)>=1.0:
			visual.full = true
			weapon_flash(visual.end,color,4,0.06)
	beam_visuals = beam_visuals.filter(func(v):return game.projectiles.has(v.shot) and game.long_laser_valid(v.shot))

func burst(pos: Vector2, color: Color, count: int, force: float) -> void:
	if fast_mode_enabled():return
	for i in range(mini(decoration_budget(pos,count),maxi(0,WEAPON_PARTICLE_LIMIT-particles.size()))):
		particles.append({"pos":pos,"vel":Vector2.from_angle(randf()*TAU)*randf_range(force*0.2,force),"color":color,"life":randf_range(0.2,0.8),"size":randf_range(1,3)})

func style(color: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	return s

func button(label: String, rect: Rect2, action: Callable, primary := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",BG if primary else INK)
	b.add_theme_color_override("font_hover_color",BG if primary else CYAN)
	b.add_theme_color_override("font_disabled_color",Color("516379"))
	b.add_theme_stylebox_override("normal",style(CYAN if primary else PANEL,CYAN if primary else LINE))
	b.add_theme_stylebox_override("hover",style(Color("a5f5ff") if primary else Color("1c3044"),CYAN))
	b.add_theme_stylebox_override("pressed",style(Color("65bbc9"),CYAN))
	b.add_theme_stylebox_override("disabled",style(Color("111923"),Color("1e2b3a")))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),CYAN))
	b.disabled = disabled
	b.pressed.connect(action)
	ui.add_child(b)
	return b

func request_ui_rebuild() -> void:
	ui_rebuild_pending = true
	if not ui_rebuild_scheduled:
		ui_rebuild_scheduled = true
		call_deferred("flush_ui_rebuild")

func flush_ui_rebuild() -> void:
	ui_rebuild_scheduled = false
	if ui_rebuild_pending and not get_viewport().gui_is_dragging():
		build_ui()

func build_ui() -> void:
	# Explicit UI rebuilds still preserve active drags in other feature pages.
	if get_viewport().gui_is_dragging():
		ui_rebuild_pending = true
		return
	ui_rebuild_pending = false
	system_nav_buttons.clear()
	system_nav = null
	workspace_frame = null
	workspace_title = null
	fps_label = null
	hightech_page = null
	equipment_containers.clear()
	equipment_panels.clear()
	ship_controls.clear()
	for child in ui.get_children():
		if child is CanvasItem:
			child.hide()
		ui.remove_child(child)
		child.queue_free()
	loop_button = null
	upgrade_buttons.clear()
	ten_upgrade_buttons.clear()
	max_upgrade_buttons.clear()
	equipment_cooldowns.clear()
	equipment_card_controls.clear()
	build_workspace_shell()
	fps_label = equipment_card_label(ui,"",Rect2(-373,24,250,30),13,CYAN)
	fps_label.name = "CurrentFps"
	refresh_fps_label(true)
	help_button = button(UIText.t("main.build_ui.text_01"),Rect2(1190,20,150,40),func():help_open=not help_open;refresh_navigation())
	resource_mode_button = button(UIText.t("main.build_ui.text_02") if resource_rate_mode else UIText.t("main.build_ui.text_03"),Rect2(-112,20,148,40),toggle_resource_display)
	music_button = button("",Rect2(500,20,130,40),toggle_music)
	resource_mode_button.tooltip_text = UIText.t("main.build_ui.text_04")
	continue_button = button(UIText.t("main.build_ui.text_05"),Rect2(600,535,240,48),func():game.acknowledge_unlocks(),true)
	help_close_button = button(UIText.t("main.build_ui.text_06"),Rect2(600,626,240,44),func():help_open=false;refresh_navigation(),true)
	continue_button.z_index = 2
	help_close_button.z_index = 2
	preload("res://scripts/dialog_presentation.gd").button_skin(help_close_button,true)
	unlock_scroll = ScrollContainer.new()
	unlock_scroll.z_index = 2
	unlock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	unlock_scroll.size = Vector2(526,180)
	ui.add_child(unlock_scroll)
	var unlock_content := VBoxContainer.new()
	unlock_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_content.add_theme_constant_override("separation",24)
	unlock_scroll.add_child(unlock_content)
	unlock_title = Label.new()
	unlock_description = Label.new()
	for label in [unlock_title,unlock_description]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unlock_content.add_child(label)
	unlock_title.add_theme_font_size_override("font_size",32)
	unlock_title.add_theme_color_override("font_color",CYAN)
	unlock_description.add_theme_font_size_override("font_size",18)
	unlock_description.add_theme_color_override("font_color",INK)
	layout_overlay_controls()
	loop_select = OptionButton.new()
	loop_select.allow_reselect = true
	loop_select.position = Vector2(680,20)
	loop_select.size = Vector2(170,40)
	loop_select.add_item(UIText.t("main.build_ui.text_07"), 0)
	for level in range(1, db.levels.size()+1):
		if game.profile.cleared.has(level) or level == game.stage:
			loop_select.add_item(UIText.t("main.build_ui.text_08", {"level":"%s" % (str(int(level)))}), level)
			if level == int(game.profile.get("loopLevel", 0)):
				loop_select.select(loop_select.item_count-1)
	loop_select.set_item_disabled(0, true)
	loop_select.item_selected.connect(func(index):game.select_loop_level(loop_select.get_item_id(index));refresh_navigation())
	ui.add_child(loop_select)
	preload("res://scripts/dialog_presentation.gd").option(loop_select,false)
	loop_select.get_popup().about_to_popup.connect(limit_warp_popup)
	loop_button = button(UIText.t("settings.guard",{"state":UIText.t("main.build_ui.text_10") if game.profile.loop else UIText.t("gem.setup.text_03")}),Rect2(860,20,130,40),func():game.toggle_loop();refresh_navigation(),false,game.state == BattleGame.State.RETREAT)
	guard_settings = MenuButton.new()
	guard_settings.text = UIText.t("main.build_ui.text_12")
	guard_settings.position = Vector2(1000,20)
	guard_settings.size = Vector2(48,40)
	guard_settings.tooltip_text = UIText.t("main.build_ui.text_13")
	var death_menu := guard_settings.get_popup()
	preload("res://scripts/dialog_presentation.gd").popup(death_menu)
	var death_options := [UIText.t("main.build_ui.text_14"), UIText.t("main.build_ui.text_15"), UIText.t("main.build_ui.text_16")]
	for mode in range(death_options.size()):
		death_menu.add_radio_check_item(death_options[mode], mode)
		death_menu.set_item_checked(mode, mode == int(game.profile.get("guardDeath", 0)))
	death_menu.add_separator(UIText.t("main.build_ui.text_17"))
	death_menu.add_item(UIText.t("main.build_ui.text_18"),20)
	for mode in 3:
		death_menu.add_radio_check_item([UIText.t("main.build_ui.text_19"), UIText.t("main.build_ui.text_20"), UIText.t("gem.setup.text_03")][mode],10+mode)
		death_menu.set_item_checked(death_menu.get_item_index(10+mode),damage_mode==mode)
	death_menu.id_pressed.connect(func(mode):
		if mode==20:
			var details := AcceptDialog.new()
			preload("res://scripts/dialog_presentation.gd").dialog(details)
			details.ok_button_text = UIText.t("system.confirm")
			details.title = UIText.t("main.build_ui.text_21")
			var detail_text := RichTextLabel.new()
			detail_text.custom_minimum_size = Vector2(520,480)
			detail_text.selection_enabled = true
			detail_text.text = "\n".join(damage_history) if not damage_history.is_empty() else UIText.t("main.build_ui.text_22")
			details.add_child(detail_text)
			details.confirmed.connect(details.queue_free)
			details.canceled.connect(details.queue_free)
			ui.add_child(details)
			details.popup_centered(Vector2i(560,600))
		elif mode>=10:
			set_damage_mode(mode-10)
			for option in 3:death_menu.set_item_checked(death_menu.get_item_index(10+option),damage_mode==option)
		else:
			game.set_guard_death(mode)
			refresh_navigation())
	ui.add_child(guard_settings)
	build_equipment_tabs()
	layout_reactor_page()
	var advance_center := BATTLE_ORIGIN+BATTLE_VIEW_SIZE*0.5-ui.position
	advance_button = button(UIText.t("main.build_ui.text_23"),Rect2(advance_center-Vector2(120,24),Vector2(240,48)),func():game.advance_after_clear(),true)
	advance_countdown_label = equipment_card_label(ui,"",Rect2(advance_center+Vector2(-120,-68),Vector2(240,32)),20,CYAN)
	advance_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advance_progress = ProgressBar.new()
	advance_progress.position = advance_center+Vector2(-120,38)
	advance_progress.size = Vector2(240,16)
	advance_progress.max_value = BattleGame.CLEAR_ADVANCE_DELAY
	advance_progress.show_percentage = false
	advance_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	advance_progress.add_theme_stylebox_override("background",style(PANEL,LINE))
	advance_progress.add_theme_stylebox_override("fill",style(CYAN,CYAN))
	ui.add_child(advance_progress)
	sound_button = button("",Rect2(1060,20,118,40),func():sound_on=not sound_on;refresh_navigation())
	for header_button in [help_button,resource_mode_button,music_button,loop_select,loop_button,guard_settings,sound_button]:
		SHELL_PRESENTATION.skin_header(header_button)
	refresh_navigation()
	enhancement_panel = preload("res://scripts/enhancement_panel.gd").new()
	ui.add_child(enhancement_panel)
	enhancement_panel.setup(self)
	layout_enhancement_workspace()
	if equipment_tabs.current_tab==4:enhancement_panel.open()
	refresh_system_nav()
	advance_button.move_to_front()
	advance_countdown_label.move_to_front()
	advance_progress.move_to_front()
	apply_readable_fonts(ui)
	beginner_guide = preload("res://scripts/beginner_guide.gd").new()
	ui.add_child(beginner_guide)
	beginner_guide.setup(self)
	refresh_draw_layers(0)

func apply_readable_fonts(node: Node) -> void:
	# The workspace has an additional 0.875 scale on top of the window scale.
	# Keep text legible at the default 1440x900 window without changing layout.
	if node is Control:
		var control := node as Control
		if control is Label or control is Button or control is LineEdit or control is TextEdit:
			var minimum := 21 if (equipment_tabs.is_ancestor_of(control) or enhancement_panel.is_ancestor_of(control)) else 19
			if control.has_meta("hightech_compact_text"):minimum=18
			if control.get_theme_font_size("font_size") < minimum:
				control.add_theme_font_size_override("font_size",minimum)
		elif control is RichTextLabel:
			var minimum := 21 if (equipment_tabs.is_ancestor_of(control) or enhancement_panel.is_ancestor_of(control)) else 19
			if control.get_theme_font_size("normal_font_size") < minimum:
				control.add_theme_font_size_override("normal_font_size",minimum)
	if not node.child_entered_tree.is_connected(apply_readable_fonts):
		node.child_entered_tree.connect(apply_readable_fonts)
	for child in node.get_children():
		apply_readable_fonts(child)

func build_workspace_shell() -> void:
	system_nav = Panel.new()
	system_nav.name = "SystemNavigation"
	system_nav.position = NAV_RECT.position
	system_nav.size = NAV_RECT.size
	system_nav.add_theme_stylebox_override("panel",SHELL_PRESENTATION.surface(SHELL_PRESENTATION.STRUCTURE))
	ui.add_child(system_nav)
	var navigation_scroll := ScrollContainer.new()
	navigation_scroll.name = "SystemNavigationScroll"
	navigation_scroll.position = Vector2(6,12)
	navigation_scroll.size = Vector2(132,1136)
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	system_nav.add_child(navigation_scroll)
	var navigation_list := VBoxContainer.new()
	navigation_list.name = "SystemNavigationList"
	navigation_list.add_theme_constant_override("separation",14)
	navigation_scroll.add_child(navigation_list)
	workspace_frame = Panel.new()
	workspace_frame.name = "SystemWorkspace"
	workspace_frame.position = WORK_RECT.position
	workspace_frame.size = WORK_RECT.size
	workspace_frame.add_theme_stylebox_override("panel",SHELL_PRESENTATION.surface(Color("0c1522")))
	ui.add_child(workspace_frame)
	workspace_title = equipment_card_label(ui,"",Rect2(180,108,1100,36),24,INK)
	workspace_title.name = "SystemWorkspaceTitle"
	workspace_title.add_theme_color_override("font_color",SHELL_PRESENTATION.PAPER)
	for index in SYSTEM_TITLES.size():
		var navigation := Button.new()
		navigation.name = "SystemNav%d" % index
		navigation.custom_minimum_size = Vector2(124,68)
		navigation.add_theme_font_override("font",font)
		SHELL_PRESENTATION.setup_navigation(navigation,index)
		navigation.pressed.connect(select_system.bind(index))
		navigation_list.add_child(navigation)
		system_nav_buttons.append(navigation)
		if index == 6:
			var dot := Control.new()
			dot.name = "ActivationBadge"
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			navigation.add_child(dot)
			dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			dot.offset_left = -18
			dot.offset_right = -8
			dot.offset_top = 8
			dot.offset_bottom = 18
			dot.draw.connect(func():dot.draw_circle(Vector2(5, 5), 5, Color("f05261")))
			dot.visible = false

func select_system(index: int) -> void:
	if index<0 or index>=equipment_tabs.get_tab_count() or equipment_tabs.is_tab_hidden(index):return
	set_ui_value(equipment_tabs,"current_tab",index)
	refresh_system_nav()

func refresh_planet_activation_badge() -> void:
	if system_nav_buttons.size() <= 6:return
	var dot := system_nav_buttons[6].get_node_or_null("ActivationBadge")
	if is_instance_valid(dot):set_ui_value(dot, "visible", game.planet_buildings.has_ready(game))

func refresh_system_nav() -> void:
	if not is_instance_valid(equipment_tabs) or not is_instance_valid(workspace_title):return
	refresh_planet_activation_badge()
	var selected := equipment_tabs.current_tab
	for index in system_nav_buttons.size():
		var navigation := system_nav_buttons[index]
		var available := index<equipment_tabs.get_tab_count() and not equipment_tabs.is_tab_hidden(index)
		set_ui_value(navigation,"visible",available)
		if not available:continue
		var caption := UIText.t(SYSTEM_TITLES[index])
		set_ui_value(navigation,"text",caption)
		set_ui_value(navigation,"tooltip_text",equipment_tabs.get_tab_bar().get_tab_tooltip(index))
		if not navigation.has_meta("selected") or bool(navigation.get_meta("selected"))!=(index==selected):
			navigation.set_meta("selected",index==selected)
			SHELL_PRESENTATION.skin_navigation(navigation,index==selected)
	set_ui_value(workspace_title,"text",UIText.t(SYSTEM_TITLES[selected]) if selected>=0 else "")

func layout_enhancement_workspace() -> void:
	if not is_instance_valid(enhancement_panel):return
	enhancement_panel.position = WORK_CONTENT_RECT.position+Vector2(4,8)
	enhancement_panel.scale = WORK_CONTENT_SCALE

func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
	if control.get(property) != value:
		control.set(property,value)

func ui_state_changed(control: Node, state: Array) -> bool:
	# UI-only dependency snapshot, owned by its control; discarded with that control.
	if control.has_meta("refresh_state") and control.get_meta("refresh_state") == state:
		return false
	control.set_meta("refresh_state",state.duplicate(true))
	return true

func refresh_visible_cards(delta := 0.0) -> void:
	if not is_instance_valid(equipment_tabs) or not equipment_tabs.is_visible_in_tree():
		return
	match equipment_tabs.current_tab:
		0:
			equipment_panel.refresh_pending()
		1:
			# The workshop owns visible sampling and animation. Do not double-tick it.
			if delta<=0 and is_instance_valid(hightech_page):hightech_page.invalidate()
		2:
			reactor_panel.refresh_pending(delta)
		5:
			crew_panel.refresh_exploration_sample()
		6:
			planet_panel.refresh_sample(delta)
		7:
			chrono_panel.refresh()
		8:
			galaxy_panel.refresh_sample(delta)

func refresh_equipment_effects(tech: String) -> void:
	if tech not in [BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR]:
		return
	var category := "weapons" if tech == BattleGame.ENERGY_FOCUS else "defence"
	var slots: Array = []
	for index in game.profile.loadout[category].size():
		slots.append(game.slot_id(category,index))
	if is_instance_valid(equipment_panel):equipment_panel.refresh_slots(slots)

func refresh_crew_tab_badge(index: int) -> void:
	if not is_instance_valid(equipment_tabs) or index>=equipment_tabs.get_tab_count():return
	var badge: Dictionary=game.crew.tab_badge(game,CREW_TAB_TYPES[index])
	var title: String=UIText.t(str(CREW_TAB_TITLES[index]))+("  "+str(badge.text) if not str(badge.text).is_empty() else "")
	if equipment_tabs.get_tab_title(index)!=title:equipment_tabs.set_tab_title(index,title)
	var bar: TabBar=equipment_tabs.get_tab_bar()
	if bar.get_tab_tooltip(index)!=badge.tooltip:bar.set_tab_tooltip(index,badge.tooltip)

func refresh_tab_visibility() -> void:
	var pages: Array[bool] = []
	pages.append(not game.profile.unlocked.is_empty())
	pages.append(db.data.get("hightech",{}).keys().any(func(key):return game.hightech_unlocked(str(key))))
	pages.append(game.reactor_unlocked())
	pages.append(unlocked_ship_keys().size()>1)
	pages.append(game.enhancement_unlocked())
	pages.append(game.profile.get("crew",[]).any(func(item):return game.crew.unlocked(game,item.crewId)))
	pages.append(db.data.get("planet",{}).keys().any(func(id):return game.planet_unlocked(str(id))))
	pages.append(true)
	pages.append(game.galaxy.available())
	pages.append(true) # Save is always the final page, independent of unlocks.
	for index in pages.size():
		if equipment_tabs.is_tab_hidden(index) == pages[index]:
			equipment_tabs.set_tab_hidden(index,not pages[index])
	for index in CREW_TAB_TYPES:refresh_crew_tab_badge(int(index))
	var selected := equipment_page
	if selected < 0 or selected >= pages.size() or not pages[selected]:
		selected = pages.find(true)
	equipment_page = selected
	set_ui_value(equipment_tabs,"current_tab",selected)
	refresh_system_nav()

func refresh_structure() -> void:
	if not is_instance_valid(equipment_tabs):
		return
	if not ui_state_changed(equipment_tabs,[game.profile.loadout,game.profile.unlocked,game.profile.cleared,game.profile.selectedShip]):
		return
	equipment_panel.refresh()
	if is_instance_valid(crew_panel):crew_panel.invalidate()
	if is_instance_valid(planet_panel):planet_panel.invalidate()
	if is_instance_valid(hightech_page):hightech_page.invalidate(true)
	refresh_ship_controls()
	refresh_tab_visibility()
	refresh_visible_cards()

func refresh_ship_controls() -> void:
	if not ship_controls.is_empty():ship_controls.page.refresh()

func limit_warp_popup() -> void:
	var popup := loop_select.get_popup()
	var row_height := maxi(int(popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))), int(popup.get_theme_icon("radio_checked").get_height())) + popup.get_theme_constant("v_separation")
	popup.max_size.y = row_height * 10 + int(popup.get_theme_stylebox("panel").get_minimum_size().y)

func overlay_modal_area() -> Rect2:
	var viewport := get_viewport_rect()
	var left := system_nav.get_global_rect().position.x-4.0 if is_instance_valid(system_nav) else 0.0
	if viewport.size.x-left < 852.0:
		left = 0.0
	return Rect2(Vector2(left,CHROME_HEIGHT),viewport.size-Vector2(left,CHROME_HEIGHT))

func overlay_panel_rect(desired_size: Vector2, area: Rect2 = Rect2()) -> Rect2:
	if not area.has_area():area = overlay_modal_area()
	var available := area.size-Vector2(48,48)
	var scale_value := minf(1.0,minf(available.x/desired_size.x,available.y/desired_size.y))
	var panel_size := desired_size*maxf(0.0,scale_value)
	return Rect2(area.get_center()-panel_size*0.5,panel_size)

func unlock_panel_rect() -> Rect2:
	return overlay_panel_rect(Vector2(640,370),Rect2(BATTLE_ORIGIN,BATTLE_VIEW_SIZE))

func layout_overlay_controls() -> void:
	if not is_instance_valid(continue_button) or not is_instance_valid(help_close_button):
		return
	var help_panel := overlay_panel_rect(Vector2(820,551))
	var help_scale := help_panel.size.x/820.0
	help_close_button.position = help_panel.position-ui.position+Vector2(290,483)*help_scale
	help_close_button.scale = Vector2.ONE*help_scale
	var unlock_panel := unlock_panel_rect()
	var unlock_scale := unlock_panel.size.x/640.0
	continue_button.position = unlock_panel.position-ui.position+Vector2(200,295)*unlock_scale
	continue_button.scale = Vector2.ONE*unlock_scale
	unlock_scroll.position = unlock_panel.position-ui.position+Vector2(57,28)*unlock_scale
	unlock_scroll.scale = Vector2.ONE*unlock_scale

func refresh_unlock_content() -> void:
	if not is_instance_valid(unlock_scroll):return
	var key := str(game.pending_unlocks[0]) if not game.pending_unlocks.is_empty() else ""
	var row: Dictionary = db.data.unlock.get(key,{})
	if not ui_state_changed(unlock_scroll,[key,row.get("title",""),row.get("desc","")]):return
	set_ui_value(unlock_scroll,"visible",not key.is_empty())
	set_ui_value(unlock_title,"text",str(row.get("title","")))
	set_ui_value(unlock_description,"text",str(row.get("desc","")))
	unlock_scroll.scroll_vertical = 0

func on_viewport_resized() -> void:
	if is_instance_valid(background_layer):background_layer.queue_redraw()
	if is_instance_valid(chrome_layer):chrome_layer.queue_redraw()
	if is_instance_valid(overlay_layer):overlay_layer.queue_redraw()
	layout_overlay_controls()

func refresh_navigation() -> void:
	if not is_instance_valid(advance_button):
		return
	var unlocking := not game.pending_unlocks.is_empty()
	refresh_unlock_content()
	# These explicit groups share visibility dependencies, not just a parent.
	# Their local snapshots expire with their controls on explicit UI rebuild.
	if ui_state_changed(help_button,[unlocking]):
		set_ui_value(help_button,"visible",not unlocking)
		set_ui_value(resource_mode_button,"visible",not unlocking)
		set_ui_value(continue_button,"visible",unlocking)
	var help_visible := help_open and not unlocking
	if ui_state_changed(help_close_button,[help_visible]):
		set_ui_value(help_close_button,"visible",help_visible)
	var navigation_visible := not help_open and not unlocking
	if ui_state_changed(guard_settings,[navigation_visible]):
		for control in [loop_select,loop_button,guard_settings,sound_button,music_button]:
			if not is_instance_valid(control):continue
			set_ui_value(control,"visible",navigation_visible)
	var workspace_visible := not help_visible
	if ui_state_changed(workspace_frame,[workspace_visible]):
		for control in [system_nav,workspace_frame,equipment_tabs,workspace_title]:
			if is_instance_valid(control):set_ui_value(control,"visible",workspace_visible)
		if is_instance_valid(enhancement_panel):set_ui_value(enhancement_panel,"visible",workspace_visible and equipment_tabs.current_tab==4)
	var advance_visible := navigation_visible and game.state==BattleGame.State.LEVEL_CLEAR and game.first_clear
	if ui_state_changed(advance_button,[advance_visible]):
		set_ui_value(advance_button,"visible",advance_visible)
	var countdown_visible := advance_visible and not game.guarding_here()
	if advance_countdown_label.visible != countdown_visible:
		set_ui_value(advance_countdown_label,"visible",countdown_visible)
	if advance_progress.visible != countdown_visible:
		set_ui_value(advance_progress,"visible",countdown_visible)
	if countdown_visible:
		var remaining := clampf(game.clear_timer,0.0,BattleGame.CLEAR_ADVANCE_DELAY)
		var seconds := ceili(remaining)
		if ui_state_changed(advance_countdown_label,[seconds]):
			set_ui_value(advance_countdown_label,"text",UIText.t("battle.clear_countdown",{"seconds":str(seconds)}))
		var progress := BattleGame.CLEAR_ADVANCE_DELAY-remaining
		if advance_progress.value != progress:
			set_ui_value(advance_progress,"value",progress)
	if ui_state_changed(loop_button,[game.profile.loop,game.state==BattleGame.State.RETREAT]):
		set_ui_value(loop_button,"text",UIText.t("settings.guard",{"state":UIText.t("main.build_ui.text_10") if game.profile.loop else UIText.t("gem.setup.text_03")}))
		set_ui_value(loop_button,"disabled",game.state==BattleGame.State.RETREAT)
	if ui_state_changed(sound_button,[sound_on]):
		set_ui_value(sound_button,"text",UIText.t("settings.sound",{"state":UIText.t("main.refresh_navigation.text_02") if sound_on else UIText.t("main.refresh_navigation.text_03")}))
	if ui_state_changed(music_button,[music_on]):
		set_ui_value(music_button,"text",UIText.t("settings.music",{"state":UIText.t("main.refresh_navigation.text_02") if music_on else UIText.t("main.refresh_navigation.text_03")}))
	var selection := int(game.profile.get("loopLevel",0))
	if ui_state_changed(loop_select,[game.profile.cleared,game.stage]):
		var ids: Array[int] = [0]
		for level in range(1,db.levels.size()+1):
			if game.profile.cleared.has(level) or level == game.stage:
				ids.append(level)
		while loop_select.item_count > ids.size():
			loop_select.remove_item(loop_select.item_count-1)
		for index in ids.size():
			var label := UIText.t("main.build_ui.text_07") if index==0 else UIText.t("main.build_ui.text_08", {"level":"%s" % (str(int(ids[index])))})
			if index >= loop_select.item_count:
				loop_select.add_item(label,ids[index])
			elif loop_select.get_item_id(index) != ids[index]:
				loop_select.set_item_id(index,ids[index])
				loop_select.set_item_text(index,label)
		if not loop_select.is_item_disabled(0):
			loop_select.set_item_disabled(0,true)
	if selection != game.stage and not game.profile.cleared.has(selection):
		selection = 0
	if loop_select.get_selected_id() != selection:
		loop_select.select(loop_select.get_item_index(selection))
	var menu := guard_settings.get_popup()
	if ui_state_changed(menu,[game.profile.get("guardDeath",0)]):
		for mode in 3:
			var checked := mode==int(game.profile.get("guardDeath",0))
			if menu.is_item_checked(mode) != checked:
				menu.set_item_checked(mode,checked)

func create_battle_game(persist: bool) -> BattleGame:
	return BattleGame.new(db,persist)

func create_draw_layers() -> void:
	background_layer = Node2D.new()
	chrome_layer = Node2D.new()
	stars_layer = Node2D.new()
	var star_material := ShaderMaterial.new()
	star_material.shader=STARFIELD_SHADER
	stars_layer.material=star_material
	battle_clip = Control.new()
	battle_clip.position = BATTLE_ORIGIN
	battle_clip.size = BATTLE_VIEW_SIZE
	battle_clip.clip_contents = true
	battle_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_layer = Node2D.new()
	drop_layer = Node2D.new()
	drop_layer.name = "BattleResources"
	battle_hud_layer = Node2D.new()
	battle_hud_layer.position = Vector2.ZERO
	resource_layer = Node2D.new()
	overlay_layer = Node2D.new()
	overlay_layer.z_index = 1
	var layers := [background_layer,stars_layer,chrome_layer,drop_layer,battle_layer,battle_hud_layer,resource_layer,overlay_layer]
	var painters := [draw_background,draw_stars,draw_chrome,draw_battle_resources,draw_battle,draw_vertical_battle_hud,draw_resources,draw_overlay]
	for index in layers.size():
		var layer: Node2D = layers[index]
		var painter: Callable = painters[index]
		if layer==stars_layer:
			add_child(battle_clip)
			battle_clip.add_child(layer)
		elif layer==battle_layer or layer==drop_layer:
			battle_clip.add_child(layer)
		else:
			add_child(layer)
			if layer==resource_layer:layer.position.x=RIGHT_UI_OFFSET
			if layer==chrome_layer:layer.position.x=VIEW_CROP_LEFT
		layer.draw.connect(func():draw_surface=layer;painter.call())

func refresh_draw_layers(dt: float) -> void:
	if not is_instance_valid(battle_layer):
		return
	sync_battle_visibility()
	for slot in 10:
		if enemy_poses.has(slot) and not game.enemies.has(enemy_poses[slot].entity):enemy_poses.erase(slot)
	for enemy in game.enemies:enemy_pose(enemy)
	for source_uid in death_drop_positions.keys():
		if not game.drops.any(func(drop):return int(drop.get("source_uid",-1))==int(source_uid)):
			death_drop_positions.erase(source_uid)
	recover_death_drop_positions()
	if ui_state_changed(stars_layer,[star_travel,star_streak,game.speed,fx_time]):
		stars_layer.queue_redraw()
	# Animation is isolated to the battlefield; stationary UI/backgrounds retain draw commands.
	if battle_layer.visible:
		var battle_changed := ui_state_changed(battle_layer,[game.state,game.paused,game.stage,game.player,game.profile.selectedShip,game.profile.loadout,game.stat("armour"),game.max_shield(),game.profile.unlocked,game.pending_unlocks])
		if battle_changed or (dt>0 and (not game.paused or shake>0 or not game.drops.is_empty())):
			battle_layer.queue_redraw()
	if drop_layer.visible!=battle_layer.visible:drop_layer.visible=battle_layer.visible
	if drop_layer.visible:
		var drops_changed := ui_state_changed(drop_layer,[game.drops,death_drop_positions])
		if drops_changed or (dt>0 and not game.paused and not game.drops.is_empty()):
			drop_layer.queue_redraw()
	# The HUD reads encounter identity and player health, never enemy cooldowns
	# or equipment. Do not deep-copy the whole enemy fleet on every frame.
	if ui_state_changed(battle_hud_layer,[game.stage,game.state,game.distance,game.group_index,game.player.armour,game.player.shield,game.stat("armour"),game.max_shield(),game.profile.unlocked,game.paused,game.pending_unlocks.is_empty(),game.is_boss_encounter(),enhancement_defense_hud_state()]):
		battle_hud_layer.queue_redraw()
	if ui_state_changed(resource_layer,[resource_display("1"),resource_display("2")]):
		resource_layer.queue_redraw()
	# Derived foreground feedback, refreshed even while the simulation is paused.
	resource_hover_feedback = resource_hover_notices()
	if ui_state_changed(overlay_layer,[help_open,game.pending_unlocks,battle_notices(),pickup_effects,resource_hover_feedback]):
		overlay_layer.queue_redraw()

func refresh_fps_label(force := false) -> void:
	if not is_instance_valid(fps_label):return
	var current_fps := roundi(Engine.get_frames_per_second())
	if not force and current_fps == displayed_fps:return
	displayed_fps = current_fps
	set_ui_value(fps_label,"text",UIText.t("hud.fps",{"fps":str(current_fps)}))

func sync_battle_visibility() -> void:
	if not is_instance_valid(battle_layer):return
	if not battle_layer.visible:
		battle_layer.visible = true
		battle_layer.queue_redraw()

func set_damage_mode(mode: int) -> void:
	damage_mode = mode
	show_damage_numbers = mode != 2
	damage_pending.clear()
	floats = floats.filter(func(f):return not f.get("damage",false))
	battle_layer.queue_redraw()

func damage_feedback_text(amount, absorbed = 0, exact := false) -> String:
	var damage_text := GrowthNumber.text(amount) if exact else NUMBER_FORMAT.damage(amount)
	if GrowthNumber.compare(absorbed,0)<=0:return damage_text
	var absorbed_text := GrowthNumber.text(absorbed) if exact and GrowthNumber.compare(absorbed,1)>=0 else NUMBER_FORMAT.damage(absorbed)
	if GrowthNumber.compare(amount,0)<=0:
		return UIText.t("battle.damage_absorbed",{"absorbed":absorbed_text})
	return UIText.t("battle.damage_with_absorption",{"damage":damage_text,"absorbed":absorbed_text})

func queue_damage_number(info: Dictionary) -> void:
	if fast_mode_enabled():return
	var absorbed = info.get("absorbed",0)
	var exact := damage_feedback_text(info.amount,absorbed,true)
	damage_history.append(UIText.t("battle.damage_record", {"target":UIText.t("battle.queue_damage_number.text_01") if info.player else UIText.t("battle.queue_damage_number.text_02", {"uid":"%s" % (info.uid)}), "critical":UIText.t("battle.queue_damage_number.text_03") if info.get("critical",false) else "", "damage":exact}))
	if damage_history.size()>40:damage_history.pop_front()
	if not show_damage_numbers:return
	var target := "player" if info.player else "enemy:%s" % info.uid
	var critical := bool(info.get("critical",false))
	var category := int(info.type) if damage_mode==1 else 0
	for entries in [floats,damage_pending]:
		for entry in entries:
			if entry.get("target","")==target and entry.critical==critical and entry.type==category and fx_time-entry.born<0.2 and not entry.get("retiring",false):
				entry.amount = GrowthNumber.add(entry.amount,info.amount)
				entry.absorbed = GrowthNumber.add(entry.get("absorbed",0),absorbed)
				entry.text = damage_feedback_text(entry.amount,entry.absorbed)
				if entry.pos!=Vector2.ZERO:
					var adjusted := damage_text_position(entry.origin,entry.text,entry.size,entry)
					if adjusted!=Vector2.INF:
						entry.pos=adjusted
					else:
						entry.life=minf(float(entry.life),0.08)
						entry.retiring=true
				return
	var height := SHIP_ART_CANVAS.y*player_art_scale()*float(battle_visual.player_core_scale)/2
	var anchor := player_render_position()
	if not info.player:
		for enemy in game.enemies:
			if enemy.uid==info.uid:
				height = enemy_render_width(enemy)
				anchor = enemy_render_position(enemy)
	var duration := float(battle_visual.damage_number_critical_duration) if critical else float(battle_visual.damage_number_normal_duration)
	var entry := {"target":target,"critical":critical,"type":category,"amount":info.amount,"absorbed":absorbed,"text":damage_feedback_text(info.amount,absorbed),"born":fx_time,"life":duration,"damage":true,"color":Color("ffd477") if critical else Color("cbd0d7"),"size":19 if critical else 15,"origin":battle_logical_point(anchor-Vector2(0,height+16)),"pos":Vector2.ZERO}
	damage_pending.append(entry)
	flush_damage_numbers()

func flush_damage_numbers() -> void:
	for entry in damage_pending.duplicate():
		if fx_time-entry.born>0.3:
			damage_pending.erase(entry)
			continue
		var active := floats.filter(func(f):return f.get("target","")==entry.target)
		if active.size()>=2:
			active[0].life = minf(active[0].life,0.08)
			active[0].retiring = true
			continue
		var pos := damage_text_position(entry.origin,entry.text,entry.size)
		if pos==Vector2.INF:
			# No safe local space: keep a bounded, short-lived visual backlog.
			if fx_time-entry.born>0.2:damage_pending.erase(entry)
			continue
		entry.pos = pos
		floats.append(entry)
		damage_pending.erase(entry)

func damage_text_rect(pos: Vector2, value: String, size_value := 19) -> Rect2:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
	return Rect2(pos-Vector2(maxf(0,92-width)/2,font.get_ascent(size_value)),Vector2(maxf(92,width),font.get_height(size_value))).grow(4)

func damage_text_position(origin: Vector2, value: String, size_value := 19, excluded_entry: Dictionary = {}) -> Vector2:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
	var enemy_bounds: Array[Rect2] = []
	for enemy in game.enemies:
		if enemy.hp<=0:continue
		var half_width := enemy_render_width(enemy)
		var center := enemy_render_position(enemy)
		var hover_margin := Vector2(float(battle_visual.enemy_idle_x),float(battle_visual.enemy_idle_y))
		var envelope := Vector2(half_width*0.6,half_width*1.15)+hover_margin
		enemy_bounds.append(Rect2(center-envelope,envelope*2.0))
	for row in 2:
		for shift in [0,-56,56,-140,140]:
			var pos := Vector2(clampf(origin.x-width/2+shift,8,BattleGame.BATTLE_SIZE.x-8-width),origin.y-row*40)
			var bounds := damage_text_rect(battle_point(pos),value,size_value)
			if bounds.position.y<8:continue
			var blocked := false
			for entry in floats:
				if entry.get("damage",false) and not is_same(entry,excluded_entry) and bounds.grow(8).intersects(damage_text_rect(battle_point(entry.pos),entry.text,entry.size)):blocked = true
			for obstacle in enemy_bounds:
				if bounds.intersects(obstacle):blocked = true
			if not blocked:return pos
	return Vector2.INF

func text_at(value: String, pos: Vector2, size := 16, color := INK) -> void:
	draw_surface.draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(size,17),color)

func box(rect: Rect2, color := PANEL, border := LINE) -> void:
	draw_surface.draw_style_box(style(color,border),rect)

func bar(rect: Rect2, percent: float, color: Color) -> void:
	draw_surface.draw_rect(rect,Color("243144"))
	draw_surface.draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(percent,0,1),rect.size.y)),color)

func draw_background() -> void:
	var viewport := get_viewport_rect()
	draw_surface.draw_rect(viewport,BG)
	draw_surface.draw_rect(Rect2(20,96,572,maxf(0.0,viewport.end.y-120.0)),Color("0d1927"))
	draw_surface.draw_rect(Rect2(BATTLE_ORIGIN,BATTLE_VIEW_SIZE),Color("0b1725"))
	# Deep-space scenery is batched with the animated stars below the combat layer.
	for i in 11:
		var p := Vector2(45+float(i%2)*510,240+float(i)*75)
		draw_surface.draw_line(p,p+Vector2(0,17),Color(LINE,0.5),1)
	# Layered translucent disks produce a soft procedural nebula without assets.
	for j in range(22,0,-1):
		draw_surface.draw_circle(Vector2(1020,345),float(j)*18,Color(0.12,0.23,0.38,0.012))
		draw_surface.draw_circle(Vector2(625,530),float(j)*13,Color(0.21,0.12,0.34,0.008))

func draw_chrome() -> void:
	var viewport := get_viewport_rect()
	draw_surface.draw_rect(Rect2(0,0,viewport.size.x,CHROME_HEIGHT),SHELL_PRESENTATION.STRUCTURE)
	draw_surface.draw_line(Vector2(0,CHROME_HEIGHT-1),Vector2(viewport.end.x,CHROME_HEIGHT-1),SHELL_PRESENTATION.NAVY,3)
	text_at("◈",Vector2(24,53),30,SHELL_PRESENTATION.TEAL)
	text_at(UIText.t("main.draw_chrome.text_01"),Vector2(69,49),22,SHELL_PRESENTATION.PAPER)
	draw_surface.draw_line(Vector2(599,96),Vector2(599,viewport.end.y-24),LINE,2)

func draw_vertical_battle_hud() -> void:
	var length := float(db.levels[game.stage-1].length)
	box(Rect2(30,100,552,98),Color("101f2e"),LINE)
	text_at(UIText.t("battle.stage",{"stage":str(int(game.stage))}),Vector2(44,129),20,INK)
	var state_key := "hud.state.retreat" if game.state==BattleGame.State.RETREAT else "hud.state.combat" if game.state==BattleGame.State.COMBAT else "hud.state.clear" if game.state==BattleGame.State.LEVEL_CLEAR else "hud.state.travel"
	if game.paused and game.pending_unlocks.is_empty():state_key="hud.state.paused"
	text_at(UIText.t(state_key),Vector2(180,128),13,CYAN)
	text_at(UIText.t("battle.draw_battle.text_08",{"group_index":str(game.group_index),"value":str(db.levels[game.stage-1].groups.size())}),Vector2(446,129),14,MUTED)
	bar(Rect2(44,190,524,4),game.distance/length,CYAN)
	var neutral_caption := neutral_protection_hud_text()
	if not neutral_caption.is_empty():
		var protection_state := enhancement_protection_state_text()
		text_at(neutral_caption,Vector2(44,155 if not protection_state.is_empty() else 166),17,SHELL_PRESENTATION.PAPER)
		if not protection_state.is_empty():text_at(protection_state,Vector2(44,176),15,MUTED)
		bar(Rect2(44,180 if not protection_state.is_empty() else 174,524,4),GrowthNumber.ratio(game.enhancement_protection_current(),GrowthNumber.maximum(1,game.enhancement_protection_capacity())),Color("b5c1bc"))
	if game.state==BattleGame.State.COMBAT and game.is_boss_encounter():
		text_at(UIText.t("battle.draw_battle.text_02"),Vector2(268,129),14,ORANGE)
	box(Rect2(30,1132,552,114),Color("101f2e"),LINE)
	text_at(UIText.t("battle.hp",{"current_hp":number(game.player.armour),"max_hp":number(game.stat("armour"))}),Vector2(44,1162),15,INK)
	bar(Rect2(44,1174,524,7),GrowthNumber.ratio(game.player.armour,GrowthNumber.maximum(1,game.stat("armour"))),ORANGE)
	if game.profile.unlocked.has("shield"):
		text_at(UIText.t("battle.shield",{"current_shield":number(game.player.shield),"max_shield":number(game.max_shield())}),Vector2(44,1207),15,CYAN)
		bar(Rect2(44,1219,524,7),GrowthNumber.ratio(game.player.shield,GrowthNumber.maximum(1,game.max_shield())),CYAN)

func enhancement_defense_hud_state() -> Array:
	# Small read-only runtime projection. Include ownership and debt so a pool
	# changing layer at equal total, cover expiry and queue clearing redraw the HUD.
	return [game.enhancement_protection_status(),game.enhancement_deferred_total(),game.defense_entries().map(func(entry):return str(entry.get("key","")))]

func neutral_protection_hud_text(status: Dictionary = {}) -> String:
	var current = game.enhancement_protection_current() if status.is_empty() else status.current
	var capacity = game.enhancement_protection_capacity() if status.is_empty() else status.capacity
	if GrowthNumber.compare(current,0)<=0 and GrowthNumber.compare(capacity,0)<=0:return ""
	return UIText.t("enhance.protection_hud.runtime" if game.has_method("enhancement_protection_status") else "enhance.protection_hud",{"current":number(current),"capacity":number(capacity)})

func enhancement_protection_state_text(status: Dictionary = {}) -> String:
	if not game.has_method("enhancement_protection_status"):return ""
	if status.is_empty():status = game.call("enhancement_protection_status")
	var mode := str(status.get("mode","neutral"))
	var key := "enhance.protection_state."+mode
	var duration := ceili(float(status.get("remaining",0))*10)/10.0
	if mode=="neutral" and float(status.get("lockout",0))>0:
		key = "enhance.protection_state.lockout"
		duration = ceili(float(status.lockout)*10)/10.0
	var arguments := {}
	if mode in ["physical","energy"]:arguments.resistance=NUMBER_FORMAT.percentage(float(status.get("resistance",0))*100)
	if mode in ["physical","energy"] or key=="enhance.protection_state.lockout":arguments.duration=NUMBER_FORMAT.precise(duration)
	var caption := mixed_protection_state_text(status) if mode=="mixed" else UIText.t(key,arguments)
	if GrowthNumber.compare(status.get("cover_current",0),0)>0:
		caption += " · "+UIText.t("enhance.protection_state.cover",{"amount":number(status.cover_current),"duration":NUMBER_FORMAT.precise(ceili(float(status.cover_remaining)*10)/10.0)})
	return caption

func mixed_protection_state_text(status: Dictionary) -> String:
	var strengths := {"physical":[],"energy":[]}
	var has_neutral := false
	for component in status.get("components",[]):
		if GrowthNumber.compare(component.current,0)<=0:continue
		var mode := str(component.get("mode","neutral"))
		if strengths.has(mode):strengths[mode].append(float(component.resistance)*100)
		else:has_neutral=true
	var types := {}
	for mode in strengths:
		if strengths[mode].is_empty():continue
		var minimum: float=strengths[mode].min()
		var maximum: float=strengths[mode].max()
		types[mode]=UIText.t("enhance.protection_state.range",{"minimum":NUMBER_FORMAT.percentage(minimum),"maximum":NUMBER_FORMAT.percentage(maximum)}) if minimum!=maximum else UIText.t("enhance.protection_state.range_equal",{"value":NUMBER_FORMAT.percentage(minimum)})
	var caption := ""
	if types.has("physical") and types.has("energy"):
		caption=UIText.t("enhance.protection_state.dual",{"physical":types.physical,"energy":types.energy})
	elif types.has("physical") or types.has("energy"):
		var mode := "physical" if types.has("physical") else "energy"
		caption=UIText.t("enhance.protection_state.mixed_"+mode,{"range":types[mode]})
	else:return UIText.t("enhance.protection_state.neutral")
	return UIText.t("enhance.protection_state.partial",{"types":caption}) if has_neutral else caption

func enhancement_protection_details() -> String:
	if not game.has_method("enhancement_protection_status"):return neutral_protection_hud_text()
	var status: Dictionary = game.call("enhancement_protection_status")
	var lines: Array[String] = [neutral_protection_hud_text(),enhancement_protection_state_text()]
	for component in status.get("components",[]):
		if GrowthNumber.compare(component.current,0)<=0 and float(component.lockout)<=0:continue
		var mode := str(component.get("mode","neutral"))
		var key := "enhance.protection_state.lockout" if float(component.lockout)>0 else "enhance.protection_state."+mode
		var duration: float = component.lockout if float(component.lockout)>0 else component.remaining
		var arguments := {}
		if mode in ["physical","energy"] and float(component.lockout)<=0:arguments.resistance=NUMBER_FORMAT.percentage(float(component.resistance)*100)
		if mode in ["physical","energy"] or float(component.lockout)>0:arguments.duration=NUMBER_FORMAT.precise(ceili(duration*10)/10.0)
		var state := UIText.t(key,arguments)
		lines.append(UIText.t("enhance.protection_component",{"index":int(component.index)+1,"current":number(component.current),"capacity":number(component.capacity),"state":state}))
	return "\n".join(lines)

func draw_stars() -> void:
	if stars_mesh==null:
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		# Alpha is a metadata flag, valid even with packed normalized vertex colors.
		for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			vertices.append(Vector3(uv.x*572,uv.y*960,0))
			uvs.append(uv)
			colors.append(Color(0,0,0,0))
		indices.append_array(PackedInt32Array([0,1,2,0,2,3]))
		for star in stars:
			var offset := vertices.size()
			for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				vertices.append(Vector3(star.x+uv.x*2,star.y+uv.y*2,0))
				uvs.append(uv)
				colors.append(Color(star.z,star.x/BattleGame.BATTLE_SIZE.x,star.y/BattleGame.BATTLE_SIZE.y,1))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_TEX_UV]=uvs
		arrays[Mesh.ARRAY_INDEX]=indices
		stars_mesh=ArrayMesh.new()
		stars_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# Reuse all 200 quads. The explicit uniforms preserve pause and the original
	# wrap/direction/speed/trail ramp without 200-400 individual draw commands.
	var mat: ShaderMaterial=stars_layer.material
	mat.set_shader_parameter("travel",star_travel)
	mat.set_shader_parameter("streak",star_streak)
	mat.set_shader_parameter("speed",float(game.speed))
	mat.set_shader_parameter("flight_time",fx_time)
	mat.set_shader_parameter("far_speed",battle_visual.background_far_speed)
	mat.set_shader_parameter("mid_speed",battle_visual.background_mid_speed)
	mat.set_shader_parameter("near_speed",battle_visual.background_near_speed)
	mat.set_shader_parameter("density",clampf(battle_visual.background_object_density,0,1))
	mat.set_shader_parameter("mid_opacity",clampf(battle_visual.background_mid_opacity,0,1))
	mat.set_shader_parameter("fog_opacity",clampf(battle_visual.background_fog_opacity,0,1))
	draw_surface.draw_mesh(stars_mesh,null)

func draw_resources() -> void:
	RESOURCE_STRIP_PRESENTATION.draw_resource(draw_surface,0,str(UIText.data_text("resources","1")),resource_display("1"))
	RESOURCE_STRIP_PRESENTATION.draw_resource(draw_surface,1,str(UIText.data_text("resources","2")),resource_display("2"))

func battle_notices() -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if help_open or not game.pending_unlocks.is_empty():return notices
	if message_time>0:notices.append({"text":message.replace("\n"," · "),"color":MUTED,"alpha":1.0})
	var resource_text: PackedStringArray = []
	var resource_ids: Array[String] = []
	var resource_alpha := 0.0
	var resource_color := INK
	for entry in floats:
		if entry.has("resource") and float(entry.life)>0:
			resource_text.append(str(entry.text))
			resource_ids.append(str(entry.resource))
			resource_alpha=maxf(resource_alpha,clampf(float(entry.life)/0.2,0,1))
			resource_color=entry.color if resource_text.size()==1 else CYAN
	if not resource_text.is_empty():notices.append({"text":" · ".join(resource_text),"resources":resource_ids,"color":resource_color,"alpha":resource_alpha})
	return notices

func resource_pickup_feedback(info: Dictionary) -> void:
	var id := "jewel" if info.has("jewel") else str(info.id)
	var active: Dictionary = {}
	for entry in floats:
		if entry.get("resource","")==id and float(entry.life)>0 and fx_time-float(entry.born)<0.4:active = entry
	if active.is_empty():
		floats = floats.filter(func(f):return f.get("resource","")!=id)
		active = {"resource":id,"amount":0.0,"born":fx_time,"color":RESOURCE_ART.accent(id),"life":0.8}
		floats.append(active)
	active.amount = GrowthNumber.add(active.amount,info.amount)
	var caption := UIText.t("main._ready.text_02") if id=="jewel" else UIText.data_text("resources",id)
	active.text = UIText.t("main.on_event.text_01",{"amount":number(active.amount),"id":caption})
	queue_pickup_effect(info,active.color)

func battle_notice_rect(index: int) -> Rect2:
	return Rect2(Vector2(40,138+index*23),Vector2(532,22))

func queue_pickup_effect(drop: Dictionary, color: Color) -> void:
	if not drop.has("x") or not drop.has("y") or pickup_effects.size()>=24:return
	var start := BATTLE_ORIGIN+drop_render_position(drop)
	if not Rect2(BATTLE_ORIGIN,BATTLE_VIEW_SIZE).has_point(start):return
	var destination := battle_notice_rect(0).get_center()
	if drop.has("id"):
		var notices := battle_notices()
		for index in notices.size():
			if str(drop.id) in notices[index].get("resources",[]):
				destination=battle_notice_rect(index).get_center()
				break
	pickup_effects.append({"start":start,"end":destination,"life":0.42,"duration":0.42,"color":color,"resource":"jewel" if drop.has("jewel") else str(drop.get("id","1"))})

func draw_overlay() -> void:
	for entry in resource_hover_feedback:
		text_at(fit_battle_text(str(entry.text),170,17),entry.position,17,entry.color)
	for effect in pickup_effects:
		var progress := 1.0-float(effect.life)/float(effect.duration)
		var point: Vector2 = effect.start.lerp(effect.end,1.0-pow(1.0-progress,3))
		var tail: Vector2 = effect.start.lerp(effect.end,1.0-pow(1.0-maxf(0,progress-0.09),3))
		draw_surface.draw_line(tail,point,Color(effect.color,0.55*(1.0-progress)),3.0,true)
		RESOURCE_ART.draw_icon(draw_surface,str(effect.resource),point,lerpf(22.0,14.0,progress),1.0-progress)
	var notices := battle_notices()
	for index in notices.size():
		var notice := battle_notice_rect(index)
		var entry: Dictionary = notices[index]
		box(notice,Color(0.045,0.075,0.11,0.9*float(entry.alpha)),Color(0.16,0.23,0.29,0.4*float(entry.alpha)))
		var resource_ids: Array = entry.get("resources",[])
		var icon_width := resource_ids.size()*20.0
		for icon_index in resource_ids.size():
			RESOURCE_ART.draw_icon(draw_surface,str(resource_ids[icon_index]),notice.position+Vector2(12+icon_index*20,11),20.0,float(entry.alpha))
		text_at(fit_battle_text(str(entry.text),notice.size.x-20.0-icon_width,14),notice.position+Vector2(10+icon_width,16),14,Color(entry.color,float(entry.alpha)))
	if help_open:
		draw_help()
	if not game.pending_unlocks.is_empty():
		draw_unlock()

func boss_health_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if game.state != BattleGame.State.COMBAT or not game.is_boss_encounter():
		return cards
	# Keep each enemy's position for the whole encounter, including after deaths.
	var columns := 1 if game.enemies.size() <= 5 else 2
	var battle_area := battle_clip.get_global_rect().intersection(get_viewport_rect())
	var gap := 10.0
	var width := minf(500.0,battle_area.size.x-24.0) if columns == 1 else (battle_area.size.x-24.0-gap)/2.0
	var left := battle_area.position.x+(battle_area.size.x-width*columns-gap*(columns-1))*0.5
	for index in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[index]
		if enemy.hp <= 0:
			continue
		cards.append({"enemy":enemy, "rect":Rect2(left+(index%columns)*(width+gap),battle_area.position.y+51.0+(index/columns)*64.0,width,54),
			"label":UIText.t("main.boss_health_cards.text_01", {"slot":"%02d" % (int(enemy.slot)+1), "des":"%s" % (UIText.data_text("enemies",str(enemy.id),"des"))}),
			"health":UIText.t("main.boss_health_cards.text_02", {"hp":"%s" % (enemy_health(float(enemy.hp))), "max_hp":"%s" % (enemy_health(float(enemy.max_hp)))}),
			"ratio":clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0, 1)})
	return cards

func fit_battle_text(value: String, width: float, size: int) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return value
	while not value.is_empty() and font.get_string_size(value + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		value = value.left(value.length()-1)
	return value + "…"

func draw_environment_event(offset: Vector2) -> void:
	if not bool(battle_visual.environment_event_enabled):return
	var interval := maxf(10.0,float(battle_visual.environment_event_interval))
	var cycle := int(floorf(fx_time/interval))
	if cycle<1:return
	var age := fposmod(fx_time,interval)
	if age>1.2:return
	var phase := age/1.2
	var from_left := cycle%2==0
	var x := lerpf(-60.0,190.0,phase) if from_left else lerpf(632.0,382.0,phase)
	var y := 115.0+fposmod(float(cycle)*73.0,260.0)+phase*70.0
	var point := Vector2(x,y)+offset
	var trail := Vector2(-42.0,-12.0) if from_left else Vector2(42.0,-12.0)
	var fade := sin(phase*PI)
	draw_surface.draw_line(point+trail,point,Color(CYAN,0.10*fade),5.0,true)
	draw_surface.draw_line(point+trail*0.55,point,Color(1.0,0.91,0.77,0.42*fade),1.0,true)
	draw_surface.draw_circle(point,2.0,Color.WHITE,0.55*fade)

func resource_hover_notices() -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if game.drops.is_empty() or not battle_layer.visible or help_open or not game.pending_unlocks.is_empty():return notices
	var mouse_pos := drop_layer.to_local(get_global_mouse_position())
	if not Rect2(Vector2.ZERO,BATTLE_VIEW_SIZE).has_point(mouse_pos):return notices
	for drop in game.drops:
		if float(drop.age)<0.5 and not drop.get("hightech",false) and not drop.get("auto_gen",false):continue
		var pos := drop_render_position(drop)
		if pos.distance_to(mouse_pos)<40:
			var id := "jewel" if drop.has("jewel") else str(drop.id)
			var caption := UIText.t("battle.draw_battle.text_10") if drop.has("jewel") else UIText.t("battle.draw_battle.text_11", {"amount":"%s" % (number(drop.amount)), "id":"%s" % (UIText.data_text("resources",str(drop.id)))})
			var caption_pos := Vector2(clampf(pos.x-85.0,12.0,BATTLE_VIEW_SIZE.x-182.0),clampf(pos.y+36.0,30.0,BATTLE_VIEW_SIZE.y-20.0))
			notices.append({"text":caption,"position":BATTLE_ORIGIN+caption_pos,"color":RESOURCE_ART.accent(id)})
	return notices

func draw_battle_resources() -> void:
	for drop in game.drops:
		if float(drop.age)<0.5 and not drop.get("hightech",false) and not drop.get("auto_gen",false):continue
		RESOURCE_ART.draw_drop(draw_surface,drop,drop_render_position(drop),clock)

func draw_battle() -> void:
	player_weapon_components()
	battle_draw_player_position=player_render_position()
	battle_draw_active=true
	var boss_battle := game.state == BattleGame.State.COMBAT and game.is_boss_encounter()
	var offset := Vector2(sin(fx_time*83.0),cos(fx_time*97.0))*shake
	if not accelerated_visual_mode:draw_environment_event(offset)
	if not accelerated_visual_mode:draw_battle_particles(offset,false)
	var visual_index := projectile_visual_index()
	var flights: Array = []
	var visible_projectiles: Array = [] if accelerated_visual_mode else game.projectiles
	for p in visible_projectiles:
		var pos := battle_point(Vector2(p.x,p.y))+offset
		if p.get("beam", false):
			if game.long_laser_valid(p) and draw_beam_override(p,offset,false):continue
			pos = battle_point(visual_muzzle(p))+offset
			if game.long_laser_valid(p):
				var end := entity_render_position(p.target) + offset
				var color := ORANGE if p.hostile else CYAN
				if float(p.charge)>0 and float(p.elapsed)<float(p.charge):
					draw_surface.draw_line(pos,end,Color(color,0.12),1.0,true)
					continue
				var visual := beam_style(p)
				draw_surface.draw_line(pos,end,Color(color,visual.glow),visual.width*2.5*float(battle_visual.laser_glow_scale),true)
			continue
		var flight_visual := projectile_visual(p,visual_index)
		if not flight_visual.is_empty():
			pos = battle_point(missile_visual_position(p,float(flight_visual.spread),flight_visual.origin,flight_visual))+offset
		var trail_budget := decoration_budget(pos,1) if weapon_key(p)=="missile" and not flight_visual.is_empty() and int(flight_visual.samples)>5 else 1
		flights.append({"shot":p,"pos":pos,"visual":flight_visual,"budget":trail_budget})
		draw_projectile_fx(p,pos,offset,false,flight_visual,trail_budget)
	if GrowthNumber.compare(game.player.armour,0)>0 or game.state==BattleGame.State.RETREAT:
		draw_ship(player_render_position()+offset,0.24,false,1,not accelerated_visual_mode and GrowthNumber.compare(game.player.shield,0)>0)
		if not accelerated_visual_mode:draw_engine_wake(player_render_position()+offset)
	for enemy in game.enemies:
		if enemy.hp <= 0:
			continue
		draw_enemy_hull_and_status(enemy,offset,boss_battle)
	# Visible bullets/flames must leave the top-mounted barrels above the hull.
	for flight in flights:
		var p: Dictionary = flight.shot
		var pos: Vector2 = flight.pos
		var angle := draw_projectile_fx(p,pos,offset,true,flight.visual,flight.budget)
		var key := str(p.key).replace("_mon", "").replace("-mon", "")
		if key in ["laser","cannon"]:continue
		if draw_projectile_body_override(p,pos,angle):continue
		var texture := visual_texture(str(weapon_visual_profile(key).get("projectile_vfx","")))
		if texture==null:continue
		var size: Vector2 = PROJECTILE_SIZES.get(key,Vector2(48,24)) * PROJECTILE_SCALE * BODY_SCALE.get(key,Vector2.ONE)
		draw_surface.draw_set_transform(pos, angle)
		draw_surface.draw_texture_rect(texture,Rect2(-size/2,size),false)
		draw_surface.draw_set_transform(Vector2.ZERO)
	# Muzzle charge and the burn point sit above hulls; the beam stays behind them.
	for shot in visible_projectiles:
		if not shot.get("beam",false) or not game.long_laser_valid(shot):continue
		if draw_beam_override(shot,offset):continue
		if float(shot.charge)>0 and float(shot.elapsed)<float(shot.charge):
			var pos := battle_point(visual_muzzle(shot))+offset
			var color := ORANGE if shot.hostile else CYAN
			var progress := clampf(float(shot.elapsed)/float(shot.charge),0,1)
			var radius := lerpf(28.0,8.0,progress)
			draw_surface.draw_circle(pos,4.0+progress*8.0,Color(color,0.2+progress*0.4))
			draw_surface.draw_circle(pos,2.0+progress*3.0,Color.WHITE)
			draw_surface.draw_arc(pos,radius,-PI/2,-PI/2+TAU*progress,32,color,2.0,true)
			for ray in range(6):
				var direction := Vector2.from_angle(float(ray)*TAU/6+float(shot.elapsed)*3)
				draw_surface.draw_line(pos+direction*radius,pos+direction*(radius+7.0),Color(color,0.35+progress*0.5),1.5,true)
		elif int(shot.ticks)>0:
			var beam := beam_style(shot)
			var end := entity_render_position(shot.target)+offset
			var color := ORANGE if shot.hostile else CYAN
			var pos := battle_point(visual_muzzle(shot))+offset
			draw_surface.draw_line(pos,end,Color(color,0.28+beam.power*0.12+beam.pulse*0.5),beam.width*float(battle_visual.laser_glow_scale),true)
			draw_surface.draw_line(pos,end,Color(1,1,1,0.5+beam.pulse*0.4),beam.width*0.38,true)
			for stream in range(4):
				var phase := fposmod(float(shot.elapsed)*2.0+float(stream)*0.25,1.0)
				var flow: Vector2 = pos.lerp(end,phase)
				draw_surface.draw_line(flow,flow.lerp(end,0.035),Color(1,1,1,0.12+beam.pulse*0.5),beam.width*0.55,true)
			draw_surface.draw_circle(pos,beam.width*1.3,Color(color,0.45))
			draw_surface.draw_circle(end,4.0+beam.pulse*3.0,Color(color,0.3+beam.pulse*0.3))
			draw_surface.draw_circle(end,1.8+beam.pulse*1.8,Color.WHITE)
			var spark_size: float = float(battle_visual.beam_hit_spark_scale)*(3.0+float(beam.pulse)*4.0)
			for spark in 2:
				var direction := Vector2.from_angle(float(shot.elapsed)*13.0+float(spark)*PI)
				draw_surface.draw_line(end+direction*2.0,end+direction*spark_size,Color(color,0.3+beam.pulse*0.55),1.0,true)
	if not accelerated_visual_mode:draw_battle_particles(offset,true)
	for f in floats:
		if accelerated_visual_mode:continue
		if not f.get("damage",false) or not show_damage_numbers:continue
		text_at(str(f.text),battle_point(f.pos),int(f.get("size",18)),Color(f.color,clampf(float(f.life)/0.2,0,1)))
	battle_draw_active=false
	battle_draw_enemy_positions.clear()

func draw_enemy_hull_and_status(enemy: Dictionary, offset: Vector2, boss_battle: bool) -> void:
	var pos := enemy_render_position(enemy)+offset
	var dimensions := Vector2(enemy_render_width(enemy),enemy_render_width(enemy)*2.0)
	var pose := enemy_pose(enemy)
	var depth := enemy_depth(enemy)
	var angle := float(pose.rotation)+deg_to_rad(float(battle_visual.enemy_idle_rotation))*sin(fx_time*0.83+float(pose.phase))
	var light := lerpf(0.63,1.0,depth)
	draw_enemy_weapon_components(enemy,pos,angle,dimensions.x,true)
	draw_surface.draw_set_transform(pos,PI+angle,Vector2.ONE)
	draw_surface.draw_circle(Vector2(-dimensions.x*0.32,0),dimensions.y*0.22,Color(0.3,0.6,0.85,lerpf(0.025,0.10,depth)))
	draw_surface.draw_texture_rect(ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),Rect2(-dimensions/2,dimensions),false,Color(light,light,light,lerpf(0.8,1.0,depth)))
	draw_surface.draw_set_transform(Vector2.ZERO)
	draw_enemy_weapon_components(enemy,pos,angle,dimensions.x,false)
	var w := dimensions.y * 0.8
	bar(Rect2(pos.x-w/2,pos.y-dimensions.x/2-6,w,4),float(enemy.hp)/float(enemy.max_hp),ORANGE if int(enemy.armourType)==2 else CYAN)
	if boss_battle:
		var marker := pos + Vector2(dimensions.y/2+4,-10)
		marker.x=minf(marker.x,BATTLE_VIEW_SIZE.x-44)
		box(Rect2(marker, Vector2(40, 20)), PANEL, LINE)
		text_at(UIText.t("battle.enemy_marker",{"slot":"%02d" % (int(enemy.slot)+1)}),marker+Vector2(5,15),12,INK)

func draw_projectile_body_override(_shot: Dictionary, _pos: Vector2, _angle: float) -> bool:
	# Optional presentation override; default retains the existing projectile sprite.
	return false

func draw_beam_override(_shot: Dictionary, _offset: Vector2, _core: bool = true) -> bool:
	# Optional presentation override; default preserves the original draw commands.
	return false

func draw_battle_particles(offset: Vector2, core: bool) -> void:
	for p in particles:
		if bool(p.has("flash") or p.has("spark") or p.has("fragment") or p.has("ring") or p.has("destroy") or p.has("rail_contact"))!=core:continue
		if p.has("rail_contact"):
			railgun_fx.draw_contact(draw_surface,battle_point(p.pos)+offset,float(p.duration)-float(p.life),p.direction)
			continue
		if p.has("fragment"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			if fade>0.86:continue
			draw_surface.draw_set_transform(battle_point(p.pos)+offset,float(p.spin)*(1.0-fade),Vector2(-1,1))
			draw_surface.draw_texture_rect_region(p.texture,Rect2(-p.extent/2,p.extent),p.region,Color(1,0.8+fade*0.2,0.65+fade*0.35,fade))
			draw_surface.draw_set_transform(Vector2.ZERO)
		elif p.has("flash"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_circle(battle_point(p.pos)+offset,float(p.size)*0.55,Color(p.color,fade*0.45))
			draw_surface.draw_circle(battle_point(p.pos)+offset,float(p.size)*fade*0.4,Color(1,0.98,0.88,fade))
			for ray in 4:
				var direction := Vector2.from_angle(float(ray)*PI/2+0.35)
				draw_surface.draw_line(battle_point(p.pos)+offset,battle_point(p.pos)+offset+direction*float(p.size)*fade*1.5,Color(p.color,fade),2.0*fade,true)
		elif p.has("destroy"):
			var progress := 1.0-clampf(float(p.life)/float(p.duration),0,1)
			var point := battle_point(p.pos)+offset
			if p.has("texture") and progress<0.23:
				draw_surface.draw_set_transform(point,PI/2,Vector2.ONE)
				draw_surface.draw_texture_rect(p.texture,Rect2(-p.extent/2,p.extent),false,Color(1.0,1.0,0.82,1.0-progress/0.23))
				draw_surface.draw_set_transform(Vector2.ZERO)
			for burst_index in 2:
				var local_pulse := maxf(0.0,1.0-absf(progress-(0.27+float(burst_index)*0.14))/0.13)
				if local_pulse>0.0:
					var local_point := point+Vector2(-11.0 if burst_index==0 else 10.0,-5.0 if burst_index==0 else 7.0)
					draw_surface.draw_circle(local_point,8.0*local_pulse,Color(1.0,0.72,0.35,0.48*local_pulse))
			var core_pulse := maxf(0.0,1.0-absf(progress-0.58)/0.21)
			draw_surface.draw_circle(point,float(p.size)*(0.25+progress*0.65),Color(ORANGE,0.24*(1.0-progress)))
			draw_surface.draw_arc(point,float(p.size)*(0.4+progress*1.1),0,TAU,20,Color(ORANGE,0.45*(1.0-progress)),1.5,true)
			if core_pulse>0.0:
				draw_surface.draw_circle(point,float(p.size)*0.7*core_pulse,Color.WHITE,0.65*core_pulse)
		elif p.has("spark"):
			draw_surface.draw_line(battle_point(p.pos)+offset,battle_point(p.pos)-p.vel.normalized()*float(p.size)+offset,Color(p.color,clampf(float(p.life)*8,0,1)),2.2,true)
		elif p.has("smoke"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_circle(battle_point(p.pos)+offset,float(p.size)*(1.0+(1.0-fade)*1.6),Color(p.color,fade*0.22))
		elif p.has("ring"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_arc(battle_point(p.pos)+offset,float(p.size)*(1.0-fade)+2.0,0,TAU,24,Color(p.color,fade),2.0,true)
		elif p.has("beam_end"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_line(battle_point(p.pos)+offset,battle_point(p.pos.lerp(p.beam_end,fade))+offset,Color(p.color,fade*0.65),float(p.size)*fade,true)
		else:
			draw_surface.draw_circle(battle_point(p.pos)+offset,float(p.size),Color(p.color,clampf(float(p.life)*2,0,1)))

func draw_compact_hull(ship_key: String, shield: bool) -> void:
	var core := SHIP_ART_CANVAS*float(battle_visual.player_core_scale)
	draw_surface.draw_texture_rect(ship_hull_texture(ship_key),Rect2(-core/2,core),false)
	if shield:draw_surface.draw_arc(Vector2.ZERO,550,0,TAU,48,Color(0.3,0.8,1,0.09),5,true)

func draw_weapon_component(component, origin: Vector2, angle: float, width: float, scale_value: float, launch_pulse: float, recoil: float, rail_charge := 0.0) -> void:
	var profile: Dictionary = component.profile
	var skin: Dictionary = component.skin()
	var mode: String = component.mode()
	var base := Color(str(skin.get("base","10283a")))
	var tint := Color(str(skin.get("tint","ffffff")))
	var is_rail := str(profile.get("visual_class",""))=="gun"
	var glow := Color("9eeaff") if is_rail else Color(str(skin.get("muzzle_glow","71e5f4")))
	draw_surface.draw_set_transform(origin,angle,Vector2.ONE*scale_value)
	if mode=="main" or mode=="secondary":
		var presence := 1.0 if mode=="main" else 0.62
		var body_width := width*presence
		draw_surface.draw_circle(Vector2.ZERO,body_width*0.38,base)
		draw_surface.draw_arc(Vector2.ZERO,body_width*0.38,0,TAU,20,Color(glow,0.12 if is_rail else 0.42 if mode=="main" else 0.17),body_width*0.035,true)
		var sprite_path := str(profile.get("rotating_sprite",""))
		var texture := visual_texture(sprite_path)
		if texture!=null:
			var region := visual_region(sprite_path)
			var icon_size := region.size*(body_width/region.size.x)
			draw_surface.draw_texture_rect_region(texture,Rect2(-icon_size/2-Vector2(recoil,0),icon_size),region,tint)
		if not is_rail:
			draw_surface.draw_circle(Vector2(body_width*0.35,0),body_width*0.1,glow)
	elif mode=="bay":
		var hatch := Rect2(-width*0.27,-width*0.21,width*0.54,width*0.42)
		draw_surface.draw_rect(hatch,base)
		draw_surface.draw_rect(hatch,Color(glow,0.52),false,width*0.035)
		draw_surface.draw_line(Vector2(-width*0.12,-width*0.13),Vector2(width*0.14,-width*0.13),tint,width*0.055,true)
	else:
		draw_surface.draw_rect(Rect2(-width*0.21,-width*0.12,width*0.42,width*0.24),base)
		if not is_rail:draw_surface.draw_line(Vector2(-width*0.03,0),Vector2(width*0.18,0),glow,width*0.09,true)
	if is_rail:
		railgun_fx.draw_rails(draw_surface,width,rail_charge,launch_pulse*launch_pulse,fx_time,component.owner_slot+int(origin.x),scale_value)
	if launch_pulse>0 and not is_rail:
		var muzzle: Array = profile.get("muzzle",[[0.25,0]])
		var point := Vector2(float(muzzle[0][0])*width,float(muzzle[0][1])*width)
		draw_surface.draw_circle(point,width*(0.08+0.1*launch_pulse),Color(glow,launch_pulse*0.65))
	draw_surface.draw_set_transform(Vector2.ZERO)

func draw_player_weapon_components(ship_key: String, pos: Vector2, scale_value: float, hull_angle: float, under_hull: bool) -> void:
	for component in player_weapon_components():
		if (int(component.hardpoint.get("z",1))<=0)!=under_hull:continue
		var owner: int = component.owner_slot
		var class_scale := float({"small":0.72,"medium":0.9,"large":1.1}.get(str(component.hardpoint.get("visual_size_class","medium")),0.9))
		var width := SHIP_VISUALS.module_width(ship_key)*class_scale
		var point := player_mount_center(ship_key,owner)
		var angle := hull_angle+weapon_visual_angle(owner)+deg_to_rad(float(component.hardpoint.get("base_rotation",0)))
		var pulse := 0.0
		var recoil := 0.0
		for slot in component.slots:
			if not turret_visuals.has(slot):continue
			var pose: Dictionary = turret_visuals[slot]
			var fired_at := float(pose.get("fired_at",-100.0))
			if fx_time>=fired_at:pulse=maxf(pulse,clampf(1.0-(fx_time-fired_at)/maxf(0.04,float(battle_visual.muzzle_pulse_duration)),0,1))
			recoil=maxf(recoil,8.0*clampf(float(pose.get("recoil",0.0))/0.13,0,1)/scale_value)
		draw_weapon_component(component,pos+point.rotated(hull_angle)*scale_value,angle,width,scale_value,pulse,recoil if component.mode()=="main" else 0.0,railgun_component_charge(component))

func draw_enemy_weapon_components(enemy: Dictionary, pos: Vector2, _hull_angle: float, _hull_width: float, under_hull: bool) -> void:
	for component in enemy_weapon_components(enemy):
		if (int(component.hardpoint.get("z",1))<=0)!=under_hull:continue
		var pose:=enemy_component_pose(enemy,component)
		draw_surface.draw_set_transform(pos+Vector2(pose.origin),float(pose.angle))
		var width:float=pose.width
		var port:Vector2=pose.port
		var tint:=Color("b29b86")
		# Compact warm armor and an explicit aperture, including embedded/bay mounts.
		# Geometry terminates at the same local port sampled by projectile launches.
		if component.mode()=="bay":
			draw_surface.draw_rect(Rect2(-width*0.26,-width*0.21,width*0.52,width*0.42),Color("292f34"))
			draw_surface.draw_line(Vector2(-width*0.13,-width*0.12),port,tint,maxf(1.0,width*0.10),true)
		else:
			var thickness:=width*(0.18 if component.mode()=="embedded" else 0.29)
			draw_surface.draw_rect(Rect2(-width*0.22,-thickness*0.5,width*0.40,thickness),Color("485159"))
			draw_surface.draw_line(Vector2(-width*0.10,0),port,tint,maxf(1.0,width*0.12),true)
		draw_surface.draw_circle(port,maxf(0.65,width*0.06),Color("e2a36b"))
		draw_surface.draw_set_transform(Vector2.ZERO)

func draw_engine_wake(position: Vector2) -> void:
	var tail := position.y+player_visible_tail()
	for i in 3:
		var drift := fposmod(fx_time*(51.0+float(i)*7.0)+float(i)*13.0,29.0)
		var point := Vector2(position.x+(float(i)-1.0)*19.0+sin(fx_time*2.0+float(i))*3.0,tail+7.0+drift)
		var fade := 0.13*(1.0-drift/29.0)
		draw_surface.draw_line(point,point+Vector2(0,5.0),Color(CYAN,fade),1.0,true)

func draw_ship(pos: Vector2, scale_value: float, hostile: bool, type: int, shield: bool) -> void:
	if not hostile and not ship_visual_entry(str(game.profile.selectedShip)).is_empty():
		var ship_key := str(game.profile.selectedShip)
		scale_value = player_art_scale()
		var hull_angle := -PI/2+player_idle_angle()
		draw_player_weapon_components(ship_key,pos,scale_value,hull_angle,true)
		draw_surface.draw_set_transform(pos,player_idle_angle(),Vector2.ONE*scale_value)
		draw_compact_hull(ship_key,shield)
		draw_surface.draw_set_transform(Vector2.ZERO)
		draw_player_weapon_components(ship_key,pos,scale_value,hull_angle,false)
		draw_surface.draw_set_transform(Vector2.ZERO)
		return
	draw_surface.draw_set_transform(pos,PI if hostile else 0.0,Vector2.ONE*scale_value)
	var accent := ORANGE if hostile and type==2 else Color("bf9cf2") if hostile else CYAN
	var body := Color("5e5264") if hostile else Color("698698")
	if shield:
		for r in range(3):
			draw_surface.draw_arc(Vector2.ZERO,97+r*3,-1.5,1.5,48,Color(CYAN,0.15-float(r)*0.04),2)
	var flame := 37.0+sin(clock*24)*7
	draw_surface.draw_colored_polygon(PackedVector2Array([Vector2(-70,-12),Vector2(-70-flame,0),Vector2(-70,12)]),Color(accent,0.22))
	draw_surface.draw_colored_polygon(PackedVector2Array([Vector2(-65,-5),Vector2(-86-sin(clock*30)*5,0),Vector2(-65,5)]),accent)
	var hull := PackedVector2Array([Vector2(91,0),Vector2(25,-19),Vector2(-5,-39),Vector2(-51,-45),Vector2(-35,-17),Vector2(-70,-14),Vector2(-64,0),Vector2(-70,14),Vector2(-35,17),Vector2(-51,45),Vector2(-5,39),Vector2(25,19)])
	draw_surface.draw_colored_polygon(hull,body)
	draw_surface.draw_polyline(hull+PackedVector2Array([hull[0]]),Color("a7c7d6") if not hostile else Color("b592a6"),1.1,true)
	draw_surface.draw_colored_polygon(PackedVector2Array([Vector2(91,0),Vector2(-49,-5),Vector2(-60,0),Vector2(-49,5)]),Color("d0dde0") if not hostile else Color("a99ba5"))
	draw_surface.draw_colored_polygon(PackedVector2Array([Vector2(40,-4),Vector2(17,-14),Vector2(-3,-14),Vector2(2,-5)]),accent)
	draw_surface.draw_line(Vector2(-32,-30),Vector2(3,-23),accent,3,true)
	draw_surface.draw_line(Vector2(-32,30),Vector2(3,23),accent,3,true)
	draw_surface.draw_rect(Rect2(-18,-5,33,10),Color("293b4c"))
	draw_surface.draw_rect(Rect2(-70,-11,7,22),accent)
	draw_surface.draw_set_transform(Vector2.ZERO)

func draw_help() -> void:
	draw_surface.draw_rect(overlay_modal_area(),Color(0.02,0.04,0.08,0.97))
	var panel := overlay_panel_rect(Vector2(820,551))
	var scale_value := panel.size.x/820.0
	draw_surface.draw_set_transform(panel.position,0,Vector2.ONE*scale_value)
	draw_surface.draw_style_box(help_surface,Rect2(Vector2.ZERO,Vector2(820,551)))
	text_at(UIText.t("main.draw_help.text_01"),Vector2(50,60),30,SHELL_PRESENTATION.NAVY)
	var lines := [UIText.t("main.draw_help.text_02"), UIText.t("main.draw_help.text_03"), UIText.t("main.draw_help.text_04"), UIText.t("main.draw_help.text_05"), UIText.t("main.draw_help.text_06"), UIText.t("main.draw_help.text_07"), UIText.t("main.draw_help.text_08"), UIText.t("main.draw_help.text_09"), UIText.t("main.draw_help.text_10")]
	for i in range(lines.size()):
		text_at(lines[i],Vector2(50,107+i*39),18,SHELL_PRESENTATION.NAVY)
	draw_surface.draw_set_transform(Vector2.ZERO)

func equipment_label(parent: Control, value: String, pos: Vector2, font_size := 13, color := INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func equipment_card_label(parent: Control, value: String, rect: Rect2, font_size := 13, color := INK) -> Label:
	var label := equipment_label(parent,value,rect.position,font_size,color)
	label.size = rect.size
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = value
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label

func equipment_skin(kind: String) -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = load("res://assets/ui/equipment/%s.svg" % kind)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(side,12)
	return skin

func skin_equipment_button(action: Button, primary := false) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		action.add_theme_stylebox_override(state,equipment_skin("disabled" if state == "disabled" else ("hover" if state in ["hover","pressed"] else ("primary" if primary else "secondary"))))
	action.add_theme_color_override("font_color",Color("effbff"))
	action.add_theme_color_override("font_hover_color",Color.WHITE)
	action.add_theme_color_override("font_disabled_color",Color("728795"))

func equipment_display_snapshot(entry: Dictionary, level := -1) -> Dictionary:
	return EQUIPMENT_DISPLAY.snapshot(game,entry,level)

func equipment_expected_details(entry: Dictionary, values: Dictionary = {}, exact := false) -> String:
	if not BattleGame.WEAPON_KEYS.has(str(entry.get("key",""))):return ""
	if values.is_empty():values=equipment_display_snapshot(entry)
	return UIText.t("weapon.expected_damage_details",{"base":NUMBER_FORMAT.precise(values.base) if exact else number(values.base),"trigger":NUMBER_FORMAT.percentage(values.trigger*100.0),"bonus":NUMBER_FORMAT.percentage(values.bonus_probability*100.0),"multiplier":NUMBER_FORMAT.percentage(GrowthNumber.multiply(values.critical_multiplier,100.0)),"expected":NUMBER_FORMAT.precise(values.expected) if exact else number(values.expected)})

func equipment_stat_text(entry: Dictionary, current: Dictionary = {}, next: Dictionary = {}) -> String:
	var key := str(entry.key)
	var lv := int(entry.level)
	var cap := db.max_equipment_level(key)
	if current.is_empty():current=equipment_display_snapshot(entry)
	if next.is_empty():next=equipment_display_snapshot(entry,mini(lv+1,cap))
	var label := UIText.t("defense.shield") if key == "shield" else (UIText.t("defense.armour") if key == "armour" else UIText.t("weapon.expected_damage"))
	return UIText.t("weapon.equipment_stat_text.text_04", {"label":"%s" % (label), "entry":"%s" % (number(current.expected)), "cap":"%s" % (number(next.expected)), "else":"%s" % (UIText.t("weapon.equipment_stat_text.text_05") if lv >= cap else "")})

func equipment_detail_text(entry: Dictionary) -> String:
	var key := str(entry.key)
	var lv := int(entry.level)
	var row := db.equip(key,lv)
	if key in ["shield","armour"]:
		return UIText.t("weapon.equipment_detail_text.text_01", {"dmgReduce":"%s" % (number(float(db.config.dmgReduce)*100)), "dmgReduce_2":"%s" % (number(float(db.config.dmgReduce)*100))})
	return UIText.t("weapon.equipment_detail_text.text_02", {"cd":"%s" % (number(float(row.cd))), "cd_2":"%s" % (number(float(db.equip(key,mini(lv+1,db.max_equipment_level(key))).cd)))})

func build_equipment_tabs() -> void:
	equipment_tabs = TabContainer.new()
	equipment_tabs.position = WORK_CONTENT_RECT.position
	equipment_tabs.size = WORK_CONTENT_RECT.size
	equipment_tabs.scale = WORK_CONTENT_SCALE
	equipment_tabs.tabs_visible = false
	equipment_tabs.add_theme_font_override("font",font)
	equipment_tabs.add_theme_font_size_override("font_size",16)
	equipment_tabs.add_theme_stylebox_override("panel",style(Color("0c1522"),LINE))
	equipment_tabs.add_theme_stylebox_override("tab_selected",style(PANEL,CYAN))
	equipment_tabs.add_theme_stylebox_override("tab_unselected",style(BG,LINE))
	for state in ["tab_selected","tab_unselected"]:
		var tab_style := equipment_tabs.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		tab_style.content_margin_left = 18
		tab_style.content_margin_right = 18
		tab_style.content_margin_top = 4
		tab_style.content_margin_bottom = 4
		equipment_tabs.add_theme_stylebox_override(state,tab_style)
	ui.add_child(equipment_tabs)
	equipment_panel = preload("res://scripts/equipment_tab.gd").new()
	equipment_panel.name = "Equipment"
	equipment_tabs.add_child(equipment_panel)
	equipment_tabs.set_tab_title(0,UIText.t("equipment.tab"))
	equipment_panel.setup(self)
	build_hightech_tab()
	build_reactor_tab()
	build_ship_tab()
	var enhancement_tab := Control.new()
	enhancement_tab.name = "Enhancement"
	equipment_tabs.add_child(enhancement_tab)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(enhancement_tab),UIText.t("enhance.tab"))
	crew_panel = preload("res://scripts/crew_panel.gd").new()
	crew_panel.name = "Crew"
	equipment_tabs.add_child(crew_panel)
	equipment_tabs.set_tab_title(5,UIText.t("crew.tab"))
	crew_panel.setup(self)
	planet_panel = preload("res://scripts/planet_panel.gd").new()
	planet_panel.name = "Planets"
	equipment_tabs.add_child(planet_panel)
	equipment_tabs.set_tab_title(6,UIText.t("planet.tab"))
	planet_panel.setup(self)
	chrono_panel = preload("res://scripts/chrono_panel.gd").new()
	chrono_panel.name = "Chrono"
	equipment_tabs.add_child(chrono_panel)
	equipment_tabs.set_tab_title(7,UIText.t("chrono.tab"))
	chrono_panel.setup(self)
	galaxy_panel=preload("res://scripts/galaxy_panel.gd").new()
	galaxy_panel.name="Galaxy"
	equipment_tabs.add_child(galaxy_panel)
	equipment_tabs.set_tab_title(8,UIText.t("galaxy.tab"))
	galaxy_panel.setup(self)
	# Append after every gameplay page so unlocks never place a tab below Save.
	save_panel = preload("res://scripts/save_panel.gd").new()
	save_panel.name = "Save"
	equipment_tabs.add_child(save_panel)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(save_panel),UIText.t("save.tab"))
	save_panel.setup(self)
	refresh_tab_visibility()
	equipment_tabs.tab_changed.connect(func(index):
		equipment_page=index
		if is_instance_valid(enhancement_panel):
			if index==4:enhancement_panel.open()
			else:set_ui_value(enhancement_panel,"visible",false)
		layout_reactor_page()
		refresh_system_nav()
		sync_battle_visibility()
		refresh_visible_cards())
	layout_reactor_page()

func return_to_first_system() -> void:
	# Closing enhancement returns to the first available system.
	if is_instance_valid(enhancement_panel):set_ui_value(enhancement_panel,"visible",false)
	var first := -1
	for index in equipment_tabs.get_tab_count():
		if not equipment_tabs.is_tab_hidden(index):
			first = index
			break
	equipment_page = first
	set_ui_value(equipment_tabs,"current_tab",first)
	layout_reactor_page()

func refresh_equipment_cards(only_slot := "") -> void:
	if is_instance_valid(equipment_panel):
		equipment_panel.refresh(only_slot)

func unlocked_ship_keys() -> Array:
	var result: Array = []
	for key in db.ships:
		if game.ship_unlocked(str(key)):
			result.append(str(key))
	return result

func build_ship_tab() -> void:
	var page := preload("res://scripts/ship_panel.gd").new()
	page.name = "Ship"
	equipment_tabs.add_child(page)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(page),UIText.t("ship.tab"))
	ship_controls = {"page":page}
	page.setup(self)

func build_reactor_tab() -> void:
	reactor_panel = preload("res://scripts/reactor_panel.gd").new()
	reactor_panel.name = "Reactor"
	equipment_tabs.add_child(reactor_panel)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(reactor_panel),UIText.t("reactor.tab"))
	reactor_panel.setup(self)

func layout_reactor_page() -> void:
	set_ui_value(equipment_tabs,"position",WORK_CONTENT_RECT.position)
	set_ui_value(equipment_tabs,"size",WORK_CONTENT_RECT.size)

func confirm_unequip(category: String, index: int) -> void:
	var entry := game.slot_entry(category,index).duplicate()
	if entry.is_empty() or str(entry.key).is_empty():
		return
	var ship_key := str(game.profile.selectedShip)
	var dialog := ConfirmationDialog.new()
	dialog.title = UIText.t("main.confirm_unequip.text_01")
	dialog.dialog_text = UIText.t("main.confirm_unequip.text_02", {"key":"%s" % (NAMES[str(entry.key)]), "level":"%d" % (int(entry.level))})
	dialog.ok_button_text = UIText.t("main.confirm_unequip.text_03")
	dialog.cancel_button_text = UIText.t("main.confirm_unequip.text_04")
	preload("res://scripts/dialog_presentation.gd").dialog(dialog)
	add_child(dialog)
	dialog.confirmed.connect(func():
		if str(game.profile.selectedShip) == ship_key and game.slot_entry(category,index) == entry:
			if game.unequip_slot(category,index):
				refresh_structure()
		dialog.queue_free())
	dialog.canceled.connect(func():dialog.queue_free())
	dialog.popup_centered()

func build_hightech_tab() -> void:
	hightech_page = preload("res://scripts/hightech_workshop.gd").new()
	hightech_page.name = "Hightech"
	equipment_tabs.add_child(hightech_page)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(hightech_page),UIText.t("upgrade.research_tab"))
	hightech_page.setup(game)

func draw_unlock() -> void:
	var panel := unlock_panel_rect()
	var scale_value := panel.size.x/640.0
	draw_surface.draw_set_transform(panel.position,0,Vector2.ONE*scale_value)
	box(Rect2(Vector2.ZERO,Vector2(640,370)),Color("142638"),CYAN)
	if game.pending_unlocks.size() > 1:
		text_at(UIText.t("unlock.remaining", {"count":str(game.pending_unlocks.size())}),Vector2(57,236),18,MUTED)
	text_at(UIText.t("unlock.next" if game.pending_unlocks.size() > 1 else "main.draw_unlock.text_03"),Vector2(57,269),15,MUTED)
	draw_surface.draw_set_transform(Vector2.ZERO)
