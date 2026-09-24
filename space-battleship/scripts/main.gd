extends Node2D

const BG := Color("080e1b")
const PANEL := Color("101c2c")
const LINE := Color("26384b")
const INK := Color("e0ecf4")
const MUTED := Color("8195ac")
const CYAN := Color("71e5f4")
const ORANGE := Color("ffbc73")
const PURPLE := Color("b3a0ff")
const CREW_TAB_TYPES := {0:["equipment"],1:["hightech","production","smelting"],4:["jewel"]}
const CREW_TAB_TITLES := {0:"equipment.tab",1:"upgrade.research_tab",4:"gem.tab"}
var NAMES: Dictionary = {}
const PROJECTILE_TEXTURES := {
	"laser":preload("res://assets/weapons/laser-pulse.png"),
	"cannon":preload("res://assets/weapons/cannon-slug.png"),
	"missile":preload("res://assets/weapons/guided-missile.png")
}
const PROJECTILE_SIZES := {"laser":Vector2(64,24),"cannon":Vector2(40,21),"missile":Vector2(64,26)}
const PROJECTILE_SCALE := 0.65
const SLOT_TEXTURES := {
	"longLaser":preload("res://assets/weapons/icons/laser-emitter.png"),
	"laser":preload("res://assets/weapons/icons/laser-emitter.png"),
	"cannon":preload("res://assets/weapons/icons/cannon-turret.png"),
	"missile":preload("res://assets/weapons/icons/missile-pod.png")
}
const SHIP_TEXTURES := {
	"Frigate":preload("res://assets/ships/player/player-scout-3slot.png"),
	"Destroyer":preload("res://assets/ships/player/player-interceptor-4slot.png"),
	"Cruiser":preload("res://assets/ships/player/player-cruiser-5slot.png"),
	"Battleship":preload("res://assets/ships/player/player-battleship-6slot.png"),
	"Heavy_Battleship":preload("res://assets/ships/player/player-dreadnought-8slot.png")
}
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const ENEMY_SHIP_TEXTURES := [
	preload("res://assets/ships/enemy/enemy-scout-1slot.png"),
	preload("res://assets/ships/enemy/enemy-medium-1slot.png"),
	preload("res://assets/ships/enemy/enemy-medium-2slot.png"),
	preload("res://assets/ships/enemy/enemy-large-4slot.png"),
	preload("res://assets/ships/enemy/enemy-large-6slot.png"),
	preload("res://assets/ships/enemy/enemy-super-8slot.png")
]
const SHIP_VISUALS := preload("res://scripts/ship_visuals.gd")
# Tight artwork regions exclude transparent padding in the existing module icons.
var module_regions: Dictionary = {
	"cannon":Rect2(106,436,1064,369),
	"missile":Rect2(158,452,984,350),
	"laser":Rect2(101,407,1057,440),
	"longLaser":Rect2(101,407,1057,440)
}
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
var floats: Array[Dictionary] = []
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
var sound_on := false
var audio: AudioStreamPlayer
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
var battle_return_button: Button
var equipment_panel: Control
var crew_panel: Control
var planet_panel: Control
var equipment_page := 0
var equipment_tabs: TabContainer
var equipment_cooldowns: Dictionary = {}
var equipment_card_controls: Dictionary = {}
var hightech_buttons: Dictionary = {}
var hightech_descriptions: Dictionary = {}
var hightech_progress: Dictionary = {}
var scientist_generate_button: Button
var scientist_bulk_buttons: Dictionary = {}
var scientist_assignment_buttons: Dictionary = {}
var scientist_summary: Label
var scientist_cost_label: Label
var scientist_distribute_button: Button
var scientist_remove_buttons: Dictionary = {}
var charge_cards: Dictionary = {}
var charge_panel: Control
var charge_nav_backdrop: ColorRect
const HIGHTECH_CARD_SIZE := Vector2(324,510)
const CONSTRUCTION_SCRIPT := preload("res://scripts/hightech_construction.gd")
var hightech_page: Panel
var hightech_inventory: Label
var hightech_scroll: ScrollContainer
var hightech_scroll_offset := 0
var ui_rebuild_pending := false
var ui_rebuild_scheduled := false
var automation_args := OS.get_cmdline_user_args() if OS.has_feature("debug") else PackedStringArray()
var capture_frame := 0
var equipment_containers: Dictionary = {}
var equipment_panels: Dictionary = {}
var hightech_titles: Dictionary = {}
var hightech_container: HBoxContainer
var ship_controls: Dictionary = {}
var help_button: Button
var help_close_button: Button
var continue_button: Button
var advance_button: Button
var sound_button: Button
var guard_settings: MenuButton
var draw_surface: Node2D
var background_layer: Node2D
var chrome_layer: Node2D
var stars_layer: Node2D
var battle_layer: Node2D
var resource_layer: Node2D
var overlay_layer: Node2D
var jewel_panel: Panel

func _ready() -> void:
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
	game = BattleGame.new(db, not automation_args.has("--capture"))
	game.event.connect(on_event)
	create_draw_layers()
	ui = Control.new()
	if OS.has_feature("release"):
		ui.theme = Theme.new()
		ui.theme.default_font = font
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	for i in range(200):
		stars.append({"x":randf()*1440,"y":randf()*810,"z":randf_range(0.2,1.0)})
	audio = AudioStreamPlayer.new()
	audio.volume_db = -25
	add_child(audio)
	game.resume_progress()
	build_ui()
	if not game.offline_rewards.is_empty():
		var rewards: PackedStringArray = []
		for id in game.offline_rewards:
			rewards.append(UIText.t("main._ready.text_01", {"id":"%s" % (UIText.t("main._ready.text_02") if id == "jewel" else UIText.data_text("resources",str(id))), "id_2":"%s" % (("%.2f" % game.offline_rewards[id]) if id == "jewel" else number(game.offline_rewards[id]))}))
		toast(UIText.t("main.offline_rewards", {"rewards":"  ".join(rewards)}))
		message_time = 10.0
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
	if OS.has_feature("debug") and DisplayServer.get_name() != "headless" and not automation_args.has("--capture"):
		var preferences := ConfigFile.new()
		preferences.load("user://qa_settings.cfg")
		var saved_speed := int(preferences.get_value("control","speed",1))
		game.speed = saved_speed if saved_speed in [1,2,5] else 1
		call_deferred("show_qa_tools")

var balance_lab: Window

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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game != null:
		game.settle_drops()
		game.save_progress()

func _process(delta: float) -> void:
	# Freeze the live scene while the independent lab window owns focus.
	if is_instance_valid(balance_lab) and balance_lab.visible:return
	if ui_rebuild_pending and not get_viewport().gui_is_dragging():
		ui_rebuild_pending = false
		build_ui()
	var dt := minf(delta,0.1)
	clock += dt
	prune_resource_samples(Time.get_unix_time_from_system())
	if not game.paused:
		fx_time += dt
		wave_hint = maxf(0,wave_hint-dt)
		advance_turrets(dt)
		var remaining := dt*game.speed
		while remaining > 0:
			var step := minf(remaining, 1.0/60.0)
			game.tick(step)
			remaining -= step
		sync_beam_visuals()
		advance_projectile_visuals(dt)
		star_travel += dt * (-250.0*game.speed if game.state == BattleGame.State.RETREAT else game.ship_movement()*game.speed if game.state == BattleGame.State.TRAVEL else 2.0)
		# Blend the star-only travel effect instead of toggling 200 trails at once.
		star_streak = move_toward(star_streak,1.0 if game.state == BattleGame.State.TRAVEL else 0.0,dt*4.0)
		for p in particles:
			p.life -= dt
			p.pos += p.vel*dt
			p.vel *= 0.97
		particles = particles.filter(func(p):return p.life > 0)
		for f in floats:
			f.life -= dt
			if f.get("damage",false):f.pos.y -= dt*12
		floats = floats.filter(func(f):return f.life > 0)
		flush_damage_numbers()
	shake = maxf(0,shake-dt*18)
	message_time = maxf(0,message_time-dt)
	refresh_visible_cards(dt)
	refresh_navigation()
	refresh_draw_layers(dt)
	if automation_args.has("--capture"):
		capture_frame += 1
		if capture_frame == 45:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://preview" + ("-unlock" if automation_args.has("--capture-unlock") else "-all" if automation_args.has("--capture-all") else "-combat") + ".png")
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		show_balance_lab()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(balance_lab) and balance_lab.visible:return
	if event is InputEventMouseMotion:
		game.collect_near(event.position)
	if event is InputEventMouseButton and event.pressed:
		game.collect_near(get_global_mouse_position(), event.button_index == MOUSE_BUTTON_LEFT)
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

func on_event(kind: String, info: Dictionary) -> void:
	match kind:
		"crew_changed":
			if is_instance_valid(crew_panel):crew_panel.invalidate()
			if is_instance_valid(planet_panel):planet_panel.invalidate()
			var tabs_changed: Dictionary = {}
			for item in [info.previous,info.current]:
				var row: Dictionary=game.crew.assignments(game).get(str(item.get("assignmentType","")),{})
				for index in CREW_TAB_TYPES:
					if CREW_TAB_TYPES[index].has(str(row.get("targetType",""))):tabs_changed[index]=true
			for index in tabs_changed:refresh_crew_tab_badge(int(index))
		"planet_changed":
			if is_instance_valid(planet_panel):
				planet_panel.invalidate()
				if info.has("reward"):planet_panel.show_completion(str(info.get("id", "")), float(info.reward))
			if is_instance_valid(crew_panel):crew_panel.invalidate()
			if info.has("reward"):
				for category in ["weapons", "defence"]:
					for index in game.active_slot_count(category):refresh_equipment_cards(game.slot_id(category,index))
		"equipment_stats":
			if is_instance_valid(equipment_panel):equipment_panel.invalidate_stats(info)
		"jewels_changed":
			if is_instance_valid(jewel_panel):
				jewel_panel.inventory_changed()
			if not str(info.get("slot", "")).is_empty():
				refresh_equipment_cards(str(info.slot))
			for slot in info.get("slots",[]):refresh_equipment_cards(str(slot))
		"jewel_error":
			toast(str(info.message))
		"jewel_pickup":
			if is_instance_valid(jewel_panel):jewel_panel.pickup_feedback(info)
		"state":
			refresh_structure()
			refresh_navigation()
		"beam_started":
			var shot: Dictionary = info.shot
			beam_visuals.append({"shot":shot,"start":visual_muzzle(shot),"end":Vector2(shot.target.x,shot.target.y),"full":false})
			weapon_flash(visual_muzzle(shot),ORANGE if shot.hostile else CYAN,7.0,0.07)
		"beam_hit":
			var shot: Dictionary = info.shot
			weapon_flash(Vector2(shot.target.x,shot.target.y),ORANGE if shot.hostile else CYAN,7.0,0.08)
		"critical_impact":
			weapon_flash(info.pos,Color.WHITE,14.0,0.08)
			beam_ring(info.pos,ORANGE,0.12,11)
			weapon_sparks(info.pos,7,140,info.direction)
		"hit":
			queue_damage_number(info)
		"explode":
			var pos := Vector2(info.x,info.y)
			weapon_flash(pos,ORANGE,22.0,0.08)
			# Split the existing hull texture, using only an event-time visual snapshot.
			if info.has("size"):
				var texture: Texture2D = ENEMY_SHIP_TEXTURES[clampi(int(info.size)-1,0,ENEMY_SHIP_TEXTURES.size()-1)]
				var dimensions: Vector2 = SHIP_VISUALS.CANVAS*SHIP_VISUALS.enemy_scale_for(info)
				for piece in 6:
					if particles.size()>=WEAPON_PARTICLE_LIMIT:break
					var cell := Vector2(piece%3,piece/3)
					var local := (cell+Vector2(0.5,0.5))*dimensions/Vector2(3,2)-dimensions/2
					local.x = -local.x
					particles.append({"pos":pos+local,"vel":local.normalized()*randf_range(65,120),"color":ORANGE,"life":0.52,"duration":0.52,"fragment":true,"texture":texture,"region":Rect2(cell*texture.get_size()/Vector2(3,2),texture.get_size()/Vector2(3,2)),"extent":dimensions/Vector2(3,2),"spin":randf_range(-2.5,2.5)})
			weapon_sparks(pos,14 if info.boss else 9,150)
			for i in 9:
				if particles.size()<WEAPON_PARTICLE_LIMIT:
					particles.append({"pos":pos,"vel":Vector2.from_angle(float(i)*TAU/9)*float(45+i*7),"color":ORANGE,"life":0.55,"size":7.0,"spark":true})
			weapon_smoke(pos,Color("7e7780"),3,0.24,9)
			beep(90)
		"projectile_impact":
			weapon_impact(info.shot,info.pos)
		"fire":
			if info.has("shot"):
				weapon_launch(info.shot,float(info.get("spread",0)))
			beep(620 if info.type == 1 else 200)
		"collect":
			var active: Dictionary = {}
			for entry in floats:
				if entry.get("resource","")==info.id and fx_time-float(entry.born)<0.4:active = entry
			if active.is_empty():
				floats = floats.filter(func(f):return f.get("resource","")!=info.id)
				active = {"resource":info.id,"amount":0.0,"born":fx_time,"pos":Vector2(760,550+int(info.id)*18),"color":INK if info.id=="1" else PURPLE,"life":0.8}
				floats.append(active)
			active.amount += float(info.amount)
			active.text = UIText.t("main.on_event.text_01", {"amount":"%s" % (number(active.amount)), "id":"%s" % (UIText.data_text("resources",str(info.id)))})
		"encounter":
			wave_hint = 0.8
		"wave_clear":
			wave_hint = 1.1
		"upgrade":
			var levels := int(info.get("levels",1))
			toast(UIText.t("upgrade.completed",{"name":UIText.t("module.upgrade_name",{"slot":str(info.get("slot",""))}),"result":UIText.t("main.on_event.text_02") if levels == 1 else UIText.t("main.on_event.text_03", {"levels":"%s" % (str(int(levels)))})}))
			if bool(info.get("batch",false)):return
			refresh_equipment_cards(str(info.get("slot","")))
			if is_instance_valid(jewel_panel) and jewel_panel.visible and str(info.get("slot",""))==game.slot_id(jewel_panel.category,jewel_panel.equipment_index):
				jewel_panel.refresh()
		"upgrades_completed":
			if is_instance_valid(equipment_panel):equipment_panel.refresh_slots(info.slots)
			if is_instance_valid(jewel_panel) and jewel_panel.visible and info.slots.has(game.slot_id(jewel_panel.category,jewel_panel.equipment_index)):
				jewel_panel.refresh()
		"module_changed":
			if is_instance_valid(crew_panel):crew_panel.invalidate()
			if is_instance_valid(jewel_panel) and jewel_panel.visible:jewel_panel.refresh()
			refresh_equipment_cards(str(info.slot))
			refresh_ship_controls()
		"ship_changed":
			refresh_structure()
			if is_instance_valid(jewel_panel) and jewel_panel.visible:jewel_panel.refresh()
		"scientists_changed":
			refresh_scientists()
			for key in hightech_progress:
				refresh_hightech_progress(key)
		"hightech_complete":
			if game.hightech_level(str(info.key))==1 and is_instance_valid(crew_panel):crew_panel.invalidate()
			if hightech_progress.has(str(info.key)):
				hightech_progress[str(info.key)].construction.celebrate()
			toast(UIText.t("upgrade.research_complete", {"name":UIText.data_text("hightech",str(info.key))}))
			refresh_hightech_card(str(info.key))
			refresh_equipment_effects(str(info.key))
		"unlock":
			help_open = false
			refresh_structure()
			refresh_navigation()
		"retreat":
			toast(UIText.t("main.on_event.text_05", {"to":"%s" % (number(info.to))}))
		"save_error":
			toast(UIText.t("main.on_event.text_06"))

func number(value: float) -> String:
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
	var rate := game.resource_minute_total(id, now) / 60.0
	return UIText.t("inventory.rate",{"rate":NUMBER_FORMAT.rate(rate)})

func toggle_resource_display() -> void:
	resource_rate_mode = not resource_rate_mode
	resource_mode_button.text = UIText.t("main.build_ui.text_02") if resource_rate_mode else UIText.t("main.build_ui.text_03")
	resource_layer.queue_redraw()

func toast(value: String) -> void:
	message = value
	message_time = 3.5

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

func weapon_key(shot: Dictionary) -> String:
	return str(shot.key).replace("_mon", "").replace("-mon", "")

func weapon_strength(shot: Dictionary) -> float:
	return 1.0 + clampf(log(maxf(1,float(shot.damage)))/log(10.0)/30.0,0,0.5)

func decoration_budget(pos: Vector2, count: int) -> int:
	var nearby := 0
	for particle in particles:
		if particle.pos.distance_squared_to(pos)<6400:nearby += 1
	return mini(count,maxi(0,18-nearby))

func weapon_smoke(pos: Vector2, color: Color, count: int, duration: float, size: float) -> void:
	for i in mini(decoration_budget(pos,count),maxi(0,WEAPON_PARTICLE_LIMIT-particles.size())):
		particles.append({"pos":pos,"vel":Vector2(randf_range(-16,16),randf_range(-22,-6)),"color":color,"life":duration,"duration":duration,"size":size,"smoke":true})

func weapon_flash(pos: Vector2, color: Color, radius: float, duration: float) -> void:
	if particles.size()>=WEAPON_PARTICLE_LIMIT:
		for i in particles.size():
			if not particles[i].has("flash"):
				particles.remove_at(i)
				break
		if particles.size()>=WEAPON_PARTICLE_LIMIT:particles.remove_at(0)
	particles.append({"pos":pos,"vel":Vector2.ZERO,"color":color,"life":duration,"duration":duration,"size":radius,"flash":true})

func weapon_sparks(pos: Vector2, count: int, force: float, direction := Vector2.RIGHT) -> void:
	for i in mini(decoration_budget(pos,count),maxi(0,WEAPON_PARTICLE_LIMIT-particles.size())):
		particles.append({"pos":pos,"vel":direction.rotated(randf_range(-0.65,0.65))*randf_range(force*0.3,force),"color":ORANGE,"life":randf_range(0.12,0.22),"size":randf_range(5,11),"spark":true})

func turret_angle(index: int) -> float:
	if turret_ship!=str(game.profile.selectedShip) or not turret_visuals.has(index):return 0.0
	var pose: Dictionary = turret_visuals[index]
	return float(pose.angle) if is_same(pose.entry,game.slot_entry("weapons",index)) and pose.key==str(pose.entry.key) else 0.0

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
	var scale_value := SHIP_VISUALS.player_display_scale(db.ship(key))
	var local := SHIP_VISUALS.center(key,index)+Vector2(SHIP_VISUALS.module_width(key)/2,0).rotated(turret_angle(index))
	return Vector2(game.player.x,game.player.y)+local*scale_value

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
			var pivot := Vector2(game.player.x,game.player.y)+SHIP_VISUALS.center(str(game.profile.selectedShip),index)*SHIP_VISUALS.player_display_scale(db.ship(str(game.profile.selectedShip)))
			var limit := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_limit_degrees",85.0)))
			desired = clampf((Vector2(target.x,target.y)-pivot).angle(),-limit,limit)
		var speed := deg_to_rad(float(ProjectSettings.get_setting("visuals/turret_turn_degrees_per_second",240.0)))
		pose.angle = rotate_toward(float(pose.angle),desired,maxf(0,speed)*dt)

func visual_muzzle(shot: Dictionary) -> Vector2:
	var pos := Vector2(shot.x,shot.y)
	if shot.hostile:return pos
	var index := shot_mount(shot)
	if index>=0:return turret_muzzle(index)
	var source := Vector2(game.player.x,game.player.y)
	return source+(pos-source)*SHIP_VISUALS.player_display_multiplier()

func weapon_launch(shot: Dictionary, spread := 0.0) -> void:
	var key := weapon_key(shot)
	if key=="longLaser":return
	var mount := shot_mount(shot)
	if mount>=0:
		var pose := turret_pose(mount)
		if key!="missile" or not is_equal_approx(float(pose.get("fired_at",-1)),fx_time):
			pose.target = shot.target
			pose.fired_at = fx_time
		if key=="cannon":pose.recoil = 0.13
	var pos := visual_muzzle(shot)
	var trail := PackedVector2Array()
	trail.resize(14)
	trail.fill(pos)
	# One fixed trail buffer per shot, overwritten in place during flight.
	if projectile_visuals.size()<256:
		projectile_visuals.append({"shot":shot,"angle":turret_angle(mount) if mount>=0 else shot.direction.angle(),"mount":mount,"age":0.0,"origin":pos,"logical_origin":Vector2(shot.x,shot.y),"spread":spread,"trail":trail,"head":0,"samples":1,"trail_times":PackedFloat32Array([0,0,0,0,0,0,0,0,0,0,0,0,0,0])})
	var color := CYAN if key=="laser" else ORANGE
	weapon_flash(pos,color,10.0 if key=="cannon" else 7.0,0.07)
	if key in ["missile","cannon"]:
		weapon_smoke(pos,Color("8992a0"),1,0.14,4.0)

func advance_projectile_visuals(dt: float) -> void:
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
		visual.angle = lerp_angle(float(visual.angle),visual.shot.direction.angle(),1.0-exp(-dt*16.0))
		if dt>0:
			visual.head = (int(visual.head)+1)%14
			visual.trail_times[visual.head] = visual.age
			visual.trail[visual.head] = missile_visual_position(visual.shot,float(visual.spread),visual.origin,visual)
			visual.samples = mini(14,int(visual.samples)+1)

func missile_visual_position(shot: Dictionary, spread: float, origin: Vector2, visual: Dictionary = {}) -> Vector2:
	var pos := Vector2(shot.x,shot.y)
	var converge := 1.0
	if not shot.target.is_empty():
		converge = clampf(pos.distance_to(Vector2(shot.target.x,shot.target.y))/160.0,0,1)
	if visual.is_empty():visual = projectile_visual(shot)
	var logical_origin: Vector2 = visual.get("logical_origin",origin)
	var distance := pos.distance_to(logical_origin)
	var unfold := smoothstep(0.0,100.0,distance)
	var blend_distance := minf(160.0,logical_origin.distance_to(Vector2(shot.target.x,shot.target.y))) if not shot.target.is_empty() else 160.0
	var muzzle_shift := (origin-logical_origin)*(1.0-smoothstep(0.0,maxf(1,blend_distance),distance))
	return pos+muzzle_shift+Vector2(0,spread*unfold*converge)

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
	var key := weapon_key(shot)
	var color := CYAN if key=="laser" else ORANGE
	weapon_flash(pos,color,(18.0 if key=="missile" else 14.0)*IMPACT_SCALE,0.08)
	if shot.get("critical",false):
		on_event("critical_impact",{"pos":pos,"direction":shot.get("direction",Vector2.RIGHT)})
	weapon_sparks(pos,8 if key=="cannon" else 5,210 if key=="cannon" else 160,shot.get("direction",Vector2.RIGHT))
	if key=="missile":
		# Short radial blast streaks read as impact, never as an area-of-damage circle.
		for i in mini(6,decoration_budget(pos,6)):
			if particles.size()>=WEAPON_PARTICLE_LIMIT:break
			particles.append({"pos":pos,"vel":Vector2.from_angle(float(i)*TAU/6)*150,"color":ORANGE,"life":0.18,"size":10.0,"spark":true})
		weapon_smoke(pos,Color("7e7780"),2,0.18,7.0*IMPACT_SCALE)

func draw_projectile_fx(shot: Dictionary, pos: Vector2, offset: Vector2, core := true, visual: Dictionary = {}, trail_budget := -1) -> float:
	var key := weapon_key(shot)
	var angle: float = shot.direction.angle()
	if not visual.is_empty():
		angle = visual.angle
	if not visual.is_empty():
		var color := Color("ffc879") if key=="missile" else ORANGE if key=="cannon" else CYAN
		for i in range(1,mini(int(visual.samples),14 if key=="missile" else 4)):
			# The short fresh trail shares the bullet layer; only older exhaust sits behind hulls.
			if (i<=3)!=core:continue
			if i>4 and trail_budget==0:break
			var a: Vector2 = visual.trail[(int(visual.head)-i+14)%14]+offset
			var b: Vector2 = visual.trail[(int(visual.head)-i+1+14)%14]+offset
			var age: float = float(visual.age)-float(visual.trail_times[(int(visual.head)-i+14)%14])
			var fade := maxf(0,1.0-age/(0.14 if key=="missile" else 0.065))
			if fade<=0:break
			draw_surface.draw_line(a,b,Color(color,fade*0.8),(3.5 if key=="missile" else 2.2)*fade*TRAIL_SCALE,true)
	if not core:return angle
	if not visual.is_empty():
		var color := CYAN if key=="laser" else ORANGE
		if float(visual.age)<0.06:
			var fade := 1.0-float(visual.age)/0.06
			var muzzle: Vector2 = visual.origin+offset
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
			draw_surface.draw_circle(pos+heading*float(i),2.8,Color(CYAN,0.06))
		draw_surface.draw_line(pos-heading*10,pos+heading*10,CYAN,2.0,true)
		draw_surface.draw_line(pos-heading*8,pos+heading*8,Color.WHITE,0.8,true)
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
	return {"power":power,"width":lerpf(1.2,2.8,power)+pulse*0.6,"glow":0.025+power*0.035+pulse*0.22,"pulse":pulse}

func beam_ring(pos: Vector2, color: Color, duration: float, radius: float) -> void:
	if particles.size()>=WEAPON_PARTICLE_LIMIT or decoration_budget(pos,1)==0:return
	particles.append({"pos":pos,"vel":Vector2.ZERO,"color":color,"life":duration,"duration":duration,"size":radius,"ring":true})

func sync_beam_visuals() -> void:
	for visual in beam_visuals:
		var shot: Dictionary = visual.shot
		var color := ORANGE if shot.hostile else CYAN
		if not game.projectiles.has(shot) or not game.long_laser_valid(shot):
			particles.append({"pos":visual.start,"beam_end":visual.end if int(shot.ticks)>0 else visual.start,"vel":Vector2.ZERO,"color":color,"life":0.16,"duration":0.16,"size":4.0})
			burst(visual.start,color,6,65)
			weapon_flash(visual.end,color,3,0.06)
			continue
		visual.start = visual_muzzle(shot)
		visual.end = Vector2(shot.target.x,shot.target.y)
		if int(shot.ticks)>0 and not visual.full and float(beam_style(shot).power)>=1.0:
			visual.full = true
			weapon_flash(visual.end,color,4,0.06)
	beam_visuals = beam_visuals.filter(func(v):return game.projectiles.has(v.shot) and game.long_laser_valid(v.shot))

func burst(pos: Vector2, color: Color, count: int, force: float) -> void:
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
	battle_return_button = null
	if is_instance_valid(hightech_scroll):
		hightech_scroll_offset = hightech_scroll.scroll_horizontal
	hightech_scroll = null
	equipment_containers.clear()
	equipment_panels.clear()
	hightech_titles.clear()
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
	hightech_buttons.clear()
	hightech_descriptions.clear()
	hightech_progress.clear()
	scientist_remove_buttons.clear()
	scientist_bulk_buttons.clear()
	scientist_assignment_buttons.clear()
	scientist_generate_button = null
	scientist_summary = null
	scientist_cost_label = null
	scientist_distribute_button = null
	charge_cards.clear()
	help_button = button(UIText.t("main.build_ui.text_01"),Rect2(1262,25,140,38),func():help_open=not help_open;refresh_navigation())
	resource_mode_button = button(UIText.t("main.build_ui.text_02") if resource_rate_mode else UIText.t("main.build_ui.text_03"),Rect2(664,25,156,38),toggle_resource_display)
	resource_mode_button.tooltip_text = UIText.t("main.build_ui.text_04")
	continue_button = button(UIText.t("main.build_ui.text_05"),Rect2(600,535,240,48),func():game.acknowledge_unlocks(),true)
	help_close_button = button(UIText.t("main.build_ui.text_06"),Rect2(600,626,240,44),func():help_open=false;refresh_navigation(),true)
	loop_select = OptionButton.new()
	loop_select.allow_reselect = true
	loop_select.position = Vector2(1010,92)
	loop_select.size = Vector2(190,38)
	loop_select.add_item(UIText.t("main.build_ui.text_07"), 0)
	for level in range(1, db.levels.size()+1):
		if game.profile.cleared.has(level) or level == game.stage:
			loop_select.add_item(UIText.t("main.build_ui.text_08", {"level":"%s" % (str(int(level)))}), level)
			if level == int(game.profile.get("loopLevel", 0)):
				loop_select.select(loop_select.item_count-1)
	loop_select.set_item_disabled(0, true)
	loop_select.item_selected.connect(func(index):game.select_loop_level(loop_select.get_item_id(index));refresh_navigation())
	ui.add_child(loop_select)
	loop_select.get_popup().about_to_popup.connect(limit_warp_popup)
	loop_button = button(UIText.t("settings.guard",{"state":UIText.t("main.build_ui.text_10") if game.profile.loop else UIText.t("gem.setup.text_03")}),Rect2(1210,92,142,38),func():game.toggle_loop();refresh_navigation(),false,game.state == BattleGame.State.RETREAT)
	guard_settings = MenuButton.new()
	guard_settings.text = UIText.t("main.build_ui.text_12")
	guard_settings.position = Vector2(1356,92)
	guard_settings.size = Vector2(46,38)
	guard_settings.tooltip_text = UIText.t("main.build_ui.text_13")
	var death_menu := guard_settings.get_popup()
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
	advance_button = button(UIText.t("main.build_ui.text_23"),Rect2(780,302,200,46),func():game.advance_after_clear(),true)
	sound_button = button("",Rect2(1262,778,140,26),func():sound_on=not sound_on;refresh_navigation())
	refresh_navigation()
	jewel_panel = preload("res://scripts/jewel_panel.gd").new()
	ui.add_child(jewel_panel)
	jewel_panel.setup(self)
	jewel_panel.visibility_changed.connect(layout_battle_return)
	if equipment_tabs.current_tab==4:jewel_panel.open()
	battle_return_button = button(UIText.t("battle.return"),Rect2(500,25,140,38),return_to_battle)
	layout_battle_return()
	refresh_draw_layers(0)

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
			refresh_scientists()
			for key in hightech_progress:
				var controls: Dictionary = hightech_progress[key]
				var construction = controls.construction
				if construction.active_in_view():
					construction.advance(delta,game.paused)
					controls.sample = float(controls.get("sample",0.0))+delta
					if delta<=0 or not controls.get("in_view",false) or controls.get("paused")!=game.paused or controls.get("complete")!=(construction.completed>0) or (not game.paused and controls.sample>=0.1):
						refresh_hightech_card(key)
						controls.sample = 0.0
					controls.in_view = true
					controls.paused = game.paused
					controls.complete = construction.completed>0
				else:
					controls.in_view = false
		2:
			charge_panel.refresh_sample(delta)
		5:
			crew_panel.refresh_exploration_sample()
		6:
			planet_panel.refresh_sample(delta)

func refresh_hightech_card(key: String) -> void:
	if not hightech_progress.has(key):
		return
	var title: Label = hightech_titles[key]
	if ui_state_changed(title,[game.hightech_level(key),db.data.hightech[key]]):
		set_ui_value(title,"text",UIText.t("gem.name_level", {"item_name":"%s" % (UIText.data_text("hightech",key)), "level":"%s" % (str(int(game.hightech_level(key))))}))
		set_ui_value(title,"tooltip_text",title.text)
	var income := game.furnace_income_peak(-1,true) if key == BattleGame.JEWEL_FURNACE else 0.0
	if ui_state_changed(hightech_descriptions[key],[game.hightech_level(key),db.data.hightech[key],income]):
		var description := game.hightech_description(key)
		set_ui_value(hightech_descriptions[key],"text",description)
		set_ui_value(hightech_descriptions[key],"tooltip_text",description)
	refresh_hightech_progress(key)

func refresh_equipment_effects(tech: String) -> void:
	if tech not in [BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR]:
		return
	var category := "weapons" if tech == BattleGame.ENERGY_FOCUS else "defence"
	for index in game.profile.loadout[category].size():
		refresh_equipment_cards(game.slot_id(category,index))

func refresh_crew_tab_badge(index: int) -> void:
	if not is_instance_valid(equipment_tabs) or index>=equipment_tabs.get_tab_count():return
	var badge: Dictionary=game.crew.tab_badge(game,CREW_TAB_TYPES[index])
	var title: String=UIText.t(str(CREW_TAB_TITLES[index]))+("  "+str(badge.text) if not str(badge.text).is_empty() else "")
	if equipment_tabs.get_tab_title(index)!=title:equipment_tabs.set_tab_title(index,title)
	var bar: TabBar=equipment_tabs.get_tab_bar()
	if bar.get_tab_tooltip(index)!=badge.tooltip:bar.set_tab_tooltip(index,badge.tooltip)

func refresh_tab_visibility() -> void:
	if is_instance_valid(charge_panel):
		charge_panel.sync_modules()
	var pages: Array[bool] = []
	pages.append(not game.profile.unlocked.is_empty())
	pages.append(not hightech_buttons.is_empty())
	pages.append(db.data.get("charge",{}).keys().any(func(key):return game.charge_unlocked(key)))
	pages.append(unlocked_ship_keys().size()>1)
	pages.append(game.jewels_unlocked())
	pages.append(game.profile.get("crew",[]).any(func(item):return game.crew.unlocked(game,item.crewId)))
	pages.append(db.data.get("planet",{}).keys().any(func(id):return game.planet_unlocked(str(id))))
	for index in pages.size():
		if equipment_tabs.is_tab_hidden(index) == pages[index]:
			equipment_tabs.set_tab_hidden(index,not pages[index])
	for index in CREW_TAB_TYPES:refresh_crew_tab_badge(int(index))
	var selected := equipment_page
	if selected < 0 or selected >= pages.size() or not pages[selected]:
		selected = pages.find(true)
	equipment_page = selected
	set_ui_value(equipment_tabs,"current_tab",selected)

func refresh_structure() -> void:
	if not is_instance_valid(equipment_tabs):
		return
	if not ui_state_changed(equipment_tabs,[game.profile.loadout,game.profile.unlocked,game.profile.cleared,game.profile.selectedShip]):
		return
	equipment_panel.refresh()
	if is_instance_valid(crew_panel):crew_panel.invalidate()
	if is_instance_valid(planet_panel):planet_panel.invalidate()
	sync_hightech_slots()
	refresh_ship_controls()
	refresh_tab_visibility()
	refresh_visible_cards()

func sync_hightech_slots() -> void:
	if not is_instance_valid(hightech_container):
		return
	var slots := game.hightech_slots().filter(func(key):return not str(key).is_empty())
	for index in slots.size():
		var key := str(slots[index])
		var matching: Control = null
		for child in hightech_container.get_children().slice(index):
			if child.get_meta("tech_key", "") == key:
				matching = child
				break
		if matching == null:
			build_hightech_card(index,key)
			matching = hightech_container.get_child(-1)
		if matching.get_index() != index:
			hightech_container.move_child(matching,index)
	while hightech_container.get_child_count() > slots.size():
		var retired = hightech_container.get_child(-1)
		var key := str(retired.get_meta("tech_key"))
		for controls in [hightech_buttons,hightech_titles,hightech_descriptions,hightech_progress,scientist_remove_buttons,scientist_assignment_buttons]:
			controls.erase(key)
		hightech_container.remove_child(retired)
		retired.queue_free()

func refresh_ship_controls() -> void:
	if not ship_controls.is_empty():ship_controls.page.refresh()

func limit_warp_popup() -> void:
	var popup := loop_select.get_popup()
	var row_height := maxi(int(popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))), int(popup.get_theme_icon("radio_checked").get_height())) + popup.get_theme_constant("v_separation")
	popup.max_size.y = row_height * 10 + int(popup.get_theme_stylebox("panel").get_minimum_size().y)

func refresh_navigation() -> void:
	if not is_instance_valid(advance_button):
		return
	var unlocking := not game.pending_unlocks.is_empty()
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
		for control in [loop_select,loop_button,guard_settings,equipment_tabs,sound_button,battle_return_button]:
			if not is_instance_valid(control):continue
			set_ui_value(control,"visible",navigation_visible)
	var advance_visible := navigation_visible and game.state==BattleGame.State.LEVEL_CLEAR
	if ui_state_changed(advance_button,[advance_visible]):
		set_ui_value(advance_button,"visible",advance_visible)
	if ui_state_changed(loop_button,[game.profile.loop,game.state==BattleGame.State.RETREAT]):
		set_ui_value(loop_button,"text",UIText.t("settings.guard",{"state":UIText.t("main.build_ui.text_10") if game.profile.loop else UIText.t("gem.setup.text_03")}))
		set_ui_value(loop_button,"disabled",game.state==BattleGame.State.RETREAT)
	if ui_state_changed(sound_button,[sound_on]):
		set_ui_value(sound_button,"text",UIText.t("settings.sound",{"state":UIText.t("main.refresh_navigation.text_02") if sound_on else UIText.t("main.refresh_navigation.text_03")}))
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

func create_draw_layers() -> void:
	background_layer = Node2D.new()
	chrome_layer = Node2D.new()
	stars_layer = Node2D.new()
	var star_material := ShaderMaterial.new()
	star_material.shader=STARFIELD_SHADER
	stars_layer.material=star_material
	battle_layer = Node2D.new()
	resource_layer = Node2D.new()
	overlay_layer = Node2D.new()
	var layers := [background_layer,stars_layer,chrome_layer,battle_layer,resource_layer,overlay_layer]
	var painters := [draw_background,draw_stars,draw_chrome,draw_battle,draw_resources,draw_overlay]
	for index in layers.size():
		var layer: Node2D = layers[index]
		var painter: Callable = painters[index]
		add_child(layer)
		layer.draw.connect(func():draw_surface=layer;painter.call())

func refresh_draw_layers(dt: float) -> void:
	if not is_instance_valid(battle_layer):
		return
	sync_battle_visibility()
	if ui_state_changed(stars_layer,[star_travel,star_streak,game.speed]):
		stars_layer.queue_redraw()
	# Animation is isolated to the battlefield; stationary UI/backgrounds retain draw commands.
	if battle_layer.visible:
		var battle_changed := ui_state_changed(battle_layer,[game.state,game.paused,game.stage,game.player,game.profile.selectedShip,game.profile.loadout,game.stat("armour"),game.max_shield(),game.profile.unlocked,game.pending_unlocks])
		if battle_changed or (dt>0 and (not game.paused or shake>0 or not game.drops.is_empty())):
			battle_layer.queue_redraw()
	if ui_state_changed(resource_layer,[resource_display("1"),resource_display("2")]):
		resource_layer.queue_redraw()
	if ui_state_changed(overlay_layer,[help_open,game.pending_unlocks,message if message_time>0 and not help_open and game.pending_unlocks.is_empty() else ""]):
		overlay_layer.queue_redraw()

func sync_battle_visibility() -> void:
	if not is_instance_valid(battle_layer):return
	var covered := is_instance_valid(hightech_page) and hightech_page.is_visible_in_tree()
	if battle_layer.visible==covered:
		battle_layer.visible = not covered
		if not covered:battle_layer.queue_redraw()

func set_damage_mode(mode: int) -> void:
	damage_mode = mode
	show_damage_numbers = mode != 2
	damage_pending.clear()
	floats = floats.filter(func(f):return not f.get("damage",false))
	battle_layer.queue_redraw()

func queue_damage_number(info: Dictionary) -> void:
	var exact := "%.0f" % float(info.amount) if float(info.amount)==roundf(float(info.amount)) else str(info.amount)
	damage_history.append(UIText.t("battle.damage_record", {"target":UIText.t("battle.queue_damage_number.text_01") if info.player else UIText.t("battle.queue_damage_number.text_02", {"uid":"%s" % (info.uid)}), "critical":UIText.t("battle.queue_damage_number.text_03") if info.get("critical",false) else "", "damage":exact}))
	if damage_history.size()>40:damage_history.pop_front()
	if not show_damage_numbers:return
	var target := "player" if info.player else "enemy:%s" % info.uid
	var critical := bool(info.get("critical",false))
	var category := int(info.type) if damage_mode==1 else 0
	for entries in [floats,damage_pending]:
		for entry in entries:
			if entry.get("target","")==target and entry.critical==critical and entry.type==category and fx_time-entry.born<0.2 and not entry.get("retiring",false):
				entry.amount += float(info.amount)
				entry.text = NUMBER_FORMAT.damage(entry.amount)
				return
	var height := SHIP_VISUALS.CANVAS.y*SHIP_VISUALS.player_display_scale(db.ship(str(game.profile.selectedShip)))/2
	if not info.player:
		for enemy in game.enemies:
			if enemy.uid==info.uid:height = SHIP_VISUALS.CANVAS.y*SHIP_VISUALS.enemy_scale_for(enemy)/2
	var entry := {"target":target,"critical":critical,"type":category,"amount":float(info.amount),"text":NUMBER_FORMAT.damage(info.amount),"born":fx_time,"life":0.6,"damage":true,"color":Color("ffd477") if critical else Color("cbd0d7"),"size":19 if critical else 15,"origin":Vector2(info.x,info.y-height-16),"pos":Vector2.ZERO}
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
		var pos := damage_text_position(entry.origin,entry.text,"",entry.size)
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

func damage_text_position(origin: Vector2, value: String, excluded_target := "", size_value := 19) -> Vector2:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
	for row in 2:
		for shift in [0,-56,56,-140,140]:
			var pos := Vector2(clampf(origin.x-width/2+shift,40,1390-width),origin.y-row*40)
			var bounds := damage_text_rect(pos,value,size_value)
			if bounds.position.y<150:continue
			var blocked := false
			for entry in floats:
				if entry.get("damage",false) and entry.get("target","")!=excluded_target and bounds.grow(8).intersects(damage_text_rect(entry.pos,entry.text,entry.size)):blocked = true
			for enemy in game.enemies:
				var dimensions: Vector2 = SHIP_VISUALS.CANVAS*SHIP_VISUALS.enemy_scale_for(enemy)
				if enemy.hp>0 and bounds.intersects(Rect2(Vector2(enemy.x,enemy.y)-dimensions/2-Vector2(4,8),dimensions+Vector2(8,12))):blocked = true
			if not blocked:return pos
	return Vector2.INF

func text_at(value: String, pos: Vector2, size := 16, color := INK) -> void:
	draw_surface.draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func box(rect: Rect2, color := PANEL, border := LINE) -> void:
	draw_surface.draw_style_box(style(color,border),rect)

func bar(rect: Rect2, percent: float, color: Color) -> void:
	draw_surface.draw_rect(rect,Color("243144"))
	draw_surface.draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(percent,0,1),rect.size.y)),color)

func draw_background() -> void:
	draw_surface.draw_rect(Rect2(0,0,1440,810),BG)
	# Layered translucent disks produce a soft procedural nebula without assets.
	for j in range(22,0,-1):
		draw_surface.draw_circle(Vector2(1020,345),float(j)*18,Color(0.12,0.23,0.38,0.012))
		draw_surface.draw_circle(Vector2(625,530),float(j)*13,Color(0.21,0.12,0.34,0.008))

func draw_chrome() -> void:
	draw_surface.draw_line(Vector2(38,76),Vector2(1402,76),LINE)
	text_at("◈",Vector2(39,52),30,CYAN)
	text_at(UIText.t("main.draw_chrome.text_01"),Vector2(83,49),22)
	text_at(UIText.t("main.subtitle"),Vector2(210,47),12,MUTED)
	draw_surface.draw_rect(Rect2(0,615,1440,195),Color("0c1522"))
	draw_surface.draw_line(Vector2(38,615),Vector2(1402,615),LINE)
	text_at(UIText.t("main.draw_chrome.text_02"),Vector2(40,795),11,MUTED)

func draw_stars() -> void:
	if stars_mesh==null:
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for star in stars:
			var offset := vertices.size()
			for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				vertices.append(Vector3(star.x+uv.x*2,star.y+uv.y*2,0))
				uvs.append(uv)
				colors.append(Color(star.z,star.x/1440.0,star.y/810.0,1))
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
	draw_surface.draw_mesh(stars_mesh,null)

func draw_resources() -> void:
	text_at(str(UIText.data_text("resources",str("1"))),Vector2(850,34),11,MUTED)
	text_at(resource_display("1"),Vector2(850,58),22,INK)
	text_at(str(UIText.data_text("resources",str("2"))),Vector2(1040,34),11,MUTED)
	text_at(resource_display("2"),Vector2(1040,58),22,PURPLE)

func draw_overlay() -> void:
	if message_time > 0 and not help_open and game.pending_unlocks.is_empty():
		box(Rect2(470,91,465,38),Color("132637"),Color("315468"))
		text_at(message,Vector2(490,117),15,CYAN)
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
	var width := 500.0 if columns == 1 else 244.0
	for index in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[index]
		if enemy.hp <= 0:
			continue
		cards.append({"enemy":enemy, "rect":Rect2(470 + (index % columns) * 256, 211 + (index / columns) * 64, width, 54),
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

func draw_battle() -> void:
	var length := float(db.levels[game.stage-1].length)
	text_at(UIText.t("battle.stage", {"stage":"%s" % (str(int(game.stage)))}),Vector2(39,111),21)
	var boss_battle := game.state == BattleGame.State.COMBAT and game.is_boss_encounter()
	var boss_title := UIText.t("battle.draw_battle.text_02", {"targets":"%s" % (number(game.targets().size())), "enemies":"%s" % (number(game.enemies.size()))}) if boss_battle else UIText.t("battle.boss_info",{"name":game.boss_info()})
	text_at(fit_battle_text(boss_title, 570, 16),Vector2(175,111),16,ORANGE)
	text_at(UIText.t("battle.draw_battle.text_03", {"distance":"%s" % (number(game.distance)), "length":"%s" % (number(length))}),Vector2(40,142),13,MUTED)
	bar(Rect2(40,155,1362,3),game.distance/length,CYAN)
	for j in range(9):
		var xx := 40+1362*float(j+1)/10
		draw_surface.draw_circle(Vector2(xx,156),4,CYAN if game.group_index>j else LINE)
	var travel_status := UIText.t("battle.draw_battle.text_04") if game.state==BattleGame.State.RETREAT else UIText.t("battle.draw_battle.text_05") if game.state==BattleGame.State.COMBAT else UIText.t("battle.draw_battle.text_06")
	if game.guarding_here() and game.state == BattleGame.State.COMBAT and game.targets().is_empty():
		travel_status = UIText.t("battle.draw_battle.text_07", {"guard_elapsed":"%s" % (number(maxf(0,game.guard_interval()-game.guard_elapsed)))})
	text_at(travel_status,Vector2(40,197),12,CYAN)
	text_at(UIText.t("battle.draw_battle.text_08", {"group_index":"%s" % (number(game.group_index)), "value":"%s" % (number(9))}),Vector2(1266,197),13,MUTED)
	var offset := Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
	for slot in range(10):
		text_at(UIText.t("battle.slot_number",{"slot":"%02d" % slot}),Vector2(1370,202+slot*44),10,Color("34475c"))
		draw_surface.draw_line(Vector2(1330,198+slot*44),Vector2(1353,198+slot*44),Color("253345"))
	for drop in game.drops:
		if float(drop.age)<0.5 and not drop.get("hightech",false) and not drop.get("auto_gen",false):continue
		var pos := Vector2(drop.x,drop.y)
		var color := INK if drop.id=="1" else PURPLE
		var bob := sin(clock*3+float(drop.uid))*3
		var furnace: bool = drop.get("hightech", false)
		var core: bool = furnace and drop.has("jewel")
		var auto_gen: bool = drop.get("auto_gen", false)
		if auto_gen and drop.id=="2":
			draw_surface.draw_set_transform(pos+Vector2(0,bob),0.0,Vector2(0.25,0.25))
			draw_auto_uranium(Vector2.ZERO,float(drop.uid))
			draw_surface.draw_set_transform(Vector2.ZERO)
			text_at(UIText.data_text("resources","2"),pos+Vector2(-6,25+bob),11,Color("e9ddff"))
			if pos.distance_to(get_global_mouse_position())<40:
				text_at(UIText.t("battle.draw_battle.text_11",{"amount":number(drop.amount),"id":UIText.data_text("resources","2")}),pos+Vector2(-25,42+bob),12,PURPLE)
			continue
		if furnace:
			color = PURPLE if core else ORANGE
			box(Rect2(pos-Vector2(18,18),Vector2(36,36)),PANEL,color)
			text_at(UIText.t("battle.jewel_furnace_core" if core else "battle.draw_battle.text_09"),pos+Vector2(-25,-31),12,color)
		if auto_gen:
			draw_surface.draw_line(pos+Vector2(22,0),pos+Vector2(62,0),Color(color,0.25),2)
		elif not furnace:
			pass
		else:
			draw_surface.draw_arc(pos,24,-PI/2,-PI/2+TAU*clampf(1.0-float(drop.age)/10.0,0,1),24,Color(color,0.35),2)
		text_at("⬡" if drop.id=="1" else "◇",pos+Vector2(-10,7+bob),16,Color(color,0.65))
		if furnace or pos.distance_to(get_global_mouse_position())<40:
			var caption := UIText.t("battle.jewel_furnace_amount",{"amount":number(drop.amount)}) if core else UIText.t("battle.draw_battle.text_10") if drop.has("jewel") else UIText.t("battle.draw_battle.text_11", {"amount":"%s" % (number(drop.amount)), "id":"%s" % (UIText.data_text("resources",str(drop.id)))})
			text_at(caption,pos+Vector2(-19,26),12,color)
	draw_battle_particles(offset,false)
	var visual_index := projectile_visual_index()
	var flights: Array = []
	for p in game.projectiles:
		var pos := Vector2(p.x,p.y)+offset
		if p.get("beam", false):
			pos = visual_muzzle(p)+offset
			if game.long_laser_valid(p):
				var end := Vector2(p.target.x, p.target.y) + offset
				var color := ORANGE if p.hostile else CYAN
				if float(p.charge)>0 and float(p.elapsed)<float(p.charge):
					draw_surface.draw_line(pos,end,Color(color,0.12),1.0,true)
					continue
				var visual := beam_style(p)
				draw_surface.draw_line(pos,end,Color(color,visual.glow),visual.width*2.5,true)
			continue
		var flight_visual := projectile_visual(p,visual_index)
		if not flight_visual.is_empty():
			pos = missile_visual_position(p,float(flight_visual.spread),flight_visual.origin,flight_visual)+offset
		var trail_budget := decoration_budget(pos,1) if weapon_key(p)=="missile" and not flight_visual.is_empty() and int(flight_visual.samples)>5 else 1
		flights.append({"shot":p,"pos":pos,"visual":flight_visual,"budget":trail_budget})
		draw_projectile_fx(p,pos,offset,false,flight_visual,trail_budget)
	if game.player.armour>0 or game.state==BattleGame.State.RETREAT:
		draw_ship(Vector2(game.player.x,game.player.y)+offset,0.24,false,1,game.player.shield>0)
		var name_y := maxf(489,float(game.player.y)+SHIP_VISUALS.CANVAS.y*SHIP_VISUALS.player_display_scale(db.ship(str(game.profile.selectedShip)))/2+18)
		text_at(game.ship_name(),Vector2(246,name_y),16,INK)
		text_at(UIText.t("battle.draw_battle.text_12", {"selectedShip":"%s" % (UIText.data_text("ship",str(game.profile.selectedShip),"code")), "weapon_entries":"%02d" % (game.weapon_entries().size()), "defense_entries":"%02d" % (game.defense_entries().size())}),Vector2(215,name_y+26),11,MUTED)
	for enemy in game.enemies:
		if enemy.hp <= 0:
			continue
		var pos := Vector2(enemy.x,enemy.y)+offset
		var dimensions: Vector2 = SHIP_VISUALS.CANVAS * SHIP_VISUALS.enemy_scale_for(enemy)
		draw_surface.draw_set_transform(pos,0.0,Vector2(-1,1))
		draw_surface.draw_texture_rect(ENEMY_SHIP_TEXTURES[clampi(int(enemy.size)-1,0,ENEMY_SHIP_TEXTURES.size()-1)],Rect2(-dimensions/2,dimensions),false)
		draw_surface.draw_set_transform(Vector2.ZERO)
		var w := dimensions.x * 0.8
		bar(Rect2(pos.x-w/2,pos.y-dimensions.y/2,w,4),float(enemy.hp)/float(enemy.max_hp),ORANGE if int(enemy.armourType)==2 else CYAN)
		if boss_battle:
			var marker := pos + Vector2(dimensions.x/2+8,-10)
			box(Rect2(marker, Vector2(40, 20)), PANEL, LINE)
			text_at(UIText.t("battle.enemy_marker",{"slot":"%02d" % (int(enemy.slot)+1)}),marker+Vector2(5,15),12,INK)
	for card in boss_health_cards():
		var rect: Rect2 = card.rect
		var color: Color = ORANGE if int(card.enemy.armourType) == 2 else CYAN
		box(rect,Color("131e2c"),Color("34475c"))
		text_at(fit_battle_text(card.label,rect.size.x-24,14),rect.position+Vector2(12,18),14,color)
		text_at(card.health,rect.position+Vector2(12,36),13,INK)
		bar(Rect2(rect.position+Vector2(12,44),Vector2(rect.size.x-24,4)),card.ratio,color)
	# Visible bullets/flames must leave the top-mounted barrels above the hull.
	for flight in flights:
		var p: Dictionary = flight.shot
		var pos: Vector2 = flight.pos
		var angle := draw_projectile_fx(p,pos,offset,true,flight.visual,flight.budget)
		var key := str(p.key).replace("_mon", "").replace("-mon", "")
		if key=="laser":continue
		var size: Vector2 = PROJECTILE_SIZES[key] * PROJECTILE_SCALE * BODY_SCALE[key]
		draw_surface.draw_set_transform(pos, angle)
		draw_surface.draw_texture_rect(PROJECTILE_TEXTURES[key],Rect2(-size/2,size),false)
		draw_surface.draw_set_transform(Vector2.ZERO)
	# Muzzle charge and the burn point sit above hulls; the beam stays behind them.
	for shot in game.projectiles:
		if not shot.get("beam",false) or not game.long_laser_valid(shot):continue
		if float(shot.charge)>0 and float(shot.elapsed)<float(shot.charge):
			var pos := visual_muzzle(shot)+offset
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
			var end := Vector2(shot.target.x,shot.target.y)+offset
			var color := ORANGE if shot.hostile else CYAN
			var pos := visual_muzzle(shot)+offset
			draw_surface.draw_line(pos,end,Color(color,0.28+beam.power*0.12+beam.pulse*0.5),beam.width,true)
			draw_surface.draw_line(pos,end,Color(1,1,1,0.18+beam.pulse*0.7),beam.width*0.32,true)
			for stream in range(4):
				var phase := fposmod(float(shot.elapsed)*2.0+float(stream)*0.25,1.0)
				var flow: Vector2 = pos.lerp(end,phase)
				draw_surface.draw_line(flow,flow.lerp(end,0.035),Color(1,1,1,0.12+beam.pulse*0.5),beam.width*0.55,true)
			draw_surface.draw_circle(pos,beam.width*1.3,Color(color,0.45))
			draw_surface.draw_circle(end,4.0+beam.pulse*3.0,Color(color,0.3+beam.pulse*0.3))
			draw_surface.draw_circle(end,1.8+beam.pulse*1.8,Color.WHITE)
	draw_battle_particles(offset,true)
	for f in floats:
		if f.get("damage",false) and not show_damage_numbers:continue
		text_at(f.text,f.pos,int(f.get("size",18)),Color(f.color,clampf(float(f.life)/0.2,0,1)))
	if wave_hint>0:
		text_at(UIText.t("battle.draw_battle.text_13"),Vector2(670,235),18,Color(CYAN,minf(1,wave_hint*3)))
	text_at(UIText.t("battle.hp", {"current_hp":"%s" % (number(game.player.armour)), "max_hp":"%s" % (number(game.stat("armour")))}),Vector2(40,587),15,INK)
	bar(Rect2(40,598,273,5),float(game.player.armour)/game.stat("armour"),ORANGE)
	if game.profile.unlocked.has("shield"):
		text_at(UIText.t("battle.shield", {"current_shield":"%s" % (number(game.player.shield)), "max_shield":"%s" % (number(game.max_shield()))}),Vector2(343,587),15,CYAN)
		bar(Rect2(343,598,273,5),float(game.player.shield)/maxf(1,game.max_shield()),CYAN)
	text_at(UIText.t("battle.draw_battle.text_16", {"autoCollectDelay":"%s" % (number(float(db.defaults.autoCollectDelay))), "autoCollectReduce":"%s" % (number((1.0-float(db.config.autoCollectReduce))*100))}),Vector2(650 if boss_battle else 1010,596),12,MUTED)
	if game.state == BattleGame.State.LEVEL_CLEAR and game.pending_unlocks.is_empty():
		box(Rect2(430,280,580,95),Color("101c2b"),CYAN)
		text_at(UIText.t("battle.draw_battle.text_17", {"stage":"%s" % (str(int(game.stage)))}),Vector2(458,318),26,CYAN)
		var target := game.next_stage()
		text_at(UIText.t("battle.draw_battle.text_18", {"clear_timer":"%s" % (number(maxf(0,game.clear_timer)))}) if game.guarding_here() else UIText.t("battle.draw_battle.text_19", {"clear_timer":"%s" % (number(maxf(0,game.clear_timer))), "target":"%s" % (str(int(target)))}),Vector2(458,352),17,INK)
	if game.paused and game.pending_unlocks.is_empty():
		if boss_battle:
			box(Rect2(565,533,310,46),Color("142334"),CYAN)
			text_at(UIText.t("battle.draw_battle.text_20"),Vector2(661,553),20,CYAN)
			text_at(UIText.t("battle.draw_battle.text_21"),Vector2(648,571),14,MUTED)
		else:
			box(Rect2(565,296,310,92),Color("142334"),CYAN)
			text_at(UIText.t("battle.draw_battle.text_20"),Vector2(637,336),26,CYAN)
			text_at(UIText.t("battle.draw_battle.text_21"),Vector2(648,365),14,MUTED)

func draw_auto_uranium(pos: Vector2, uid: float) -> void:
	# The generated ore moves left. Keep its glow and wake behind the crystal.
	var pulse := 0.5+0.5*sin(fx_time*4.0+uid)
	var violet := Color("aa83ff")
	var ice := Color("e9ddff")
	for i in range(3):
		var wake := pos+Vector2(38.0+float(i)*24.0,6.0*sin(fx_time*5.0+uid+float(i)))
		draw_surface.draw_line(pos+Vector2(15,0),wake,Color(violet,0.34-float(i)*0.07),5.0-float(i),true)
		draw_surface.draw_circle(wake,3.0-float(i)*0.5,Color(ice,0.6-float(i)*0.12))
	draw_surface.draw_circle(pos,35.0+4.0*pulse,Color(violet,0.075+0.025*pulse))
	draw_surface.draw_circle(pos,26.0,Color(violet,0.13))
	draw_surface.draw_arc(pos,30.0,-PI*0.7,PI*0.45,36,Color(ice,0.42+0.22*pulse),1.6,true)
	draw_surface.draw_arc(pos,30.0,PI*0.5,PI*1.65,36,Color(violet,0.35),1.6,true)
	var hull := PackedVector2Array([pos+Vector2(-21,-6),pos+Vector2(-9,-23),pos+Vector2(11,-25),pos+Vector2(25,-5),pos+Vector2(14,21),pos+Vector2(-11,23),pos+Vector2(-24,8)])
	draw_surface.draw_colored_polygon(hull,Color("432c70"))
	draw_surface.draw_colored_polygon(PackedVector2Array([hull[0],hull[1],pos+Vector2(0,-8),pos+Vector2(-3,12),hull[6]]),Color("7952c2"))
	draw_surface.draw_colored_polygon(PackedVector2Array([hull[1],hull[2],hull[3],pos+Vector2(0,-8)]),Color("c3a4ff"))
	draw_surface.draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-8),hull[3],hull[4],pos+Vector2(-3,12)]),Color("9868e2"))
	for i in hull.size():
		draw_surface.draw_line(hull[i],hull[(i+1)%hull.size()],Color(ice,0.85),2.0,true)
	draw_surface.draw_line(pos+Vector2(-4,-11),pos+Vector2(6,3),Color(1,1,1,0.55+0.25*pulse),2.0,true)
	draw_surface.draw_circle(pos+Vector2(1,-2),4.0+1.5*pulse,Color(ice,0.65+0.25*pulse))

func draw_battle_particles(offset: Vector2, core: bool) -> void:
	for p in particles:
		if bool(p.has("flash") or p.has("spark") or p.has("fragment") or p.has("ring"))!=core:continue
		if p.has("fragment"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_set_transform(p.pos+offset,float(p.spin)*(1.0-fade),Vector2(-1,1))
			draw_surface.draw_texture_rect_region(p.texture,Rect2(-p.extent/2,p.extent),p.region,Color(1,0.8+fade*0.2,0.65+fade*0.35,fade))
			draw_surface.draw_set_transform(Vector2.ZERO)
		elif p.has("flash"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_circle(p.pos+offset,float(p.size)*0.55,Color(p.color,fade*0.45))
			draw_surface.draw_circle(p.pos+offset,float(p.size)*fade*0.4,Color(1,0.98,0.88,fade))
			for ray in 4:
				var direction := Vector2.from_angle(float(ray)*PI/2+0.35)
				draw_surface.draw_line(p.pos+offset,p.pos+offset+direction*float(p.size)*fade*1.5,Color(p.color,fade),2.0*fade,true)
		elif p.has("spark"):
			draw_surface.draw_line(p.pos+offset,p.pos-p.vel.normalized()*float(p.size)+offset,Color(p.color,clampf(float(p.life)*8,0,1)),2.2,true)
		elif p.has("smoke"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_circle(p.pos+offset,float(p.size)*(1.0+(1.0-fade)*1.6),Color(p.color,fade*0.22))
		elif p.has("ring"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_arc(p.pos+offset,float(p.size)*(1.0-fade)+2.0,0,TAU,24,Color(p.color,fade),2.0,true)
		elif p.has("beam_end"):
			var fade := clampf(float(p.life)/float(p.duration),0,1)
			draw_surface.draw_line(p.pos+offset,p.pos.lerp(p.beam_end,fade)+offset,Color(p.color,fade*0.65),float(p.size)*fade,true)
		else:
			draw_surface.draw_circle(p.pos+offset,float(p.size),Color(p.color,clampf(float(p.life)*2,0,1)))

func draw_ship(pos: Vector2, scale_value: float, hostile: bool, type: int, shield: bool) -> void:
	if not hostile and SHIP_TEXTURES.has(str(game.profile.selectedShip)):
		var ship_key := str(game.profile.selectedShip)
		scale_value = SHIP_VISUALS.player_display_scale(db.ship(ship_key))
		draw_surface.draw_set_transform(pos,0.0,Vector2.ONE*scale_value)
		draw_surface.draw_texture_rect(SHIP_TEXTURES[ship_key],Rect2(-SHIP_VISUALS.CANVAS/2,SHIP_VISUALS.CANVAS),false)
		var entries := game.weapon_entries()
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var key := str(entry.get("key", ""))
			if key.is_empty() or not SLOT_TEXTURES.has(key):
				continue
			if not module_regions.has(key):
				module_regions[key] = Rect2(SLOT_TEXTURES[key].get_image().get_used_rect())
			var region: Rect2 = module_regions[key]
			var width := SHIP_VISUALS.module_width(ship_key)
			var icon_size := region.size * (width / region.size.x)
			var angle := turret_angle(index)
			var recoil := 0.0
			if key=="cannon" and turret_visuals.has(index):
				recoil = 8.0*clampf(float(turret_visuals[index].recoil)/0.13,0,1)/scale_value
			# Rotate around the original socket; recoil follows the barrel's local axis.
			draw_surface.draw_set_transform(pos+SHIP_VISUALS.center(ship_key,index)*scale_value,angle,Vector2.ONE*scale_value)
			var mount := Vector2(-recoil,0)
			var backing := Rect2(mount-icon_size/2,icon_size).grow(4)
			draw_surface.draw_rect(backing,Color("09131f"))
			draw_surface.draw_rect(backing,Color("9bc5d9"),false,width*0.06)
			draw_surface.draw_texture_rect_region(SLOT_TEXTURES[key],Rect2(mount-icon_size/2,icon_size),region)
			if key=="cannon":
				draw_surface.draw_line(mount+Vector2(width*0.05,0),mount+Vector2(width*0.5,0),ORANGE,width*0.09,true)
			elif key in ["laser","longLaser"]:
				draw_surface.draw_circle(mount+Vector2(width*0.33,0),width*0.13,CYAN)
				draw_surface.draw_circle(mount+Vector2(width*0.33,0),width*0.06,Color.WHITE)
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
	draw_surface.draw_rect(Rect2(0,78,1440,696),Color(0.02,0.04,0.08,0.97))
	box(Rect2(310,143,820,551))
	text_at(UIText.t("main.draw_help.text_01"),Vector2(360,203),30,CYAN)
	var lines := [UIText.t("main.draw_help.text_02"), UIText.t("main.draw_help.text_03"), UIText.t("main.draw_help.text_04"), UIText.t("main.draw_help.text_05"), UIText.t("main.draw_help.text_06"), UIText.t("main.draw_help.text_07"), UIText.t("main.draw_help.text_08"), UIText.t("main.draw_help.text_09"), UIText.t("main.draw_help.text_10")]
	for i in range(lines.size()):
		text_at(lines[i],Vector2(360,250+i*39),16,MUTED if i>5 else INK)

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

func equipment_stat_text(entry: Dictionary) -> String:
	var key := str(entry.key)
	var lv := int(entry.level)
	var cap := db.max_equipment_level(key)
	var label := UIText.t("defense.shield") if key == "shield" else (UIText.t("defense.armour") if key == "armour" else UIText.t("weapon.damage"))
	return UIText.t("weapon.equipment_stat_text.text_04", {"label":"%s" % (label), "entry":"%s" % (number(game.jewel_equipment_stat(entry))), "cap":"%s" % (number(game.jewel_equipment_stat(entry,mini(lv+1,cap)))), "else":"%s" % (UIText.t("weapon.equipment_stat_text.text_05") if lv >= cap else "")})

func equipment_detail_text(entry: Dictionary) -> String:
	var key := str(entry.key)
	var lv := int(entry.level)
	var row := db.equip(key,lv)
	if key in ["shield","armour"]:
		return UIText.t("weapon.equipment_detail_text.text_01", {"dmgReduce":"%s" % (number(float(db.config.dmgReduce)*100)), "dmgReduce_2":"%s" % (number(float(db.config.dmgReduce)*100))})
	return UIText.t("weapon.equipment_detail_text.text_02", {"cd":"%s" % (number(float(row.cd))), "cd_2":"%s" % (number(float(db.equip(key,mini(lv+1,db.max_equipment_level(key))).cd)))})

func build_equipment_tabs() -> void:
	charge_nav_backdrop = ColorRect.new()
	charge_nav_backdrop.position = Vector2(38,84)
	charge_nav_backdrop.size = Vector2(1364,50)
	charge_nav_backdrop.color = BG
	charge_nav_backdrop.visible = false
	ui.add_child(charge_nav_backdrop)
	equipment_tabs = TabContainer.new()
	equipment_tabs.position = Vector2(38,620)
	equipment_tabs.size = Vector2(1364,156)
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
	build_charge_tab()
	build_ship_tab()
	var jewel_tab := Control.new()
	jewel_tab.name = "Jewels"
	equipment_tabs.add_child(jewel_tab)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(jewel_tab),UIText.t("gem.tab"))
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
	refresh_tab_visibility()
	equipment_tabs.tab_changed.connect(func(index):
		equipment_page=index
		if is_instance_valid(jewel_panel):
			if index==4:jewel_panel.open()
			else:set_ui_value(jewel_panel,"visible",false)
		layout_charge_page()
		sync_battle_visibility()
		refresh_visible_cards())
	layout_charge_page()

func return_to_battle() -> void:
	# Navigation only: preserve the battle and all existing feature controls.
	if is_instance_valid(jewel_panel):set_ui_value(jewel_panel,"visible",false)
	equipment_panel.set_view_mode("compact")
	var first := -1
	for index in equipment_tabs.get_tab_count():
		if not equipment_tabs.is_tab_hidden(index):
			first = index
			break
	equipment_page = first
	set_ui_value(equipment_tabs,"current_tab",first)
	layout_charge_page()

func layout_battle_return() -> void:
	if not is_instance_valid(battle_return_button):return
	set_ui_value(battle_return_button,"position",Vector2(500,25))
	set_ui_value(battle_return_button,"size",Vector2(140,38))
	set_ui_value(battle_return_button,"visible",not help_open and game.pending_unlocks.is_empty())
	ui.move_child(battle_return_button,-1)

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

func refresh_scientists() -> void:
	if not is_instance_valid(scientist_generate_button):
		return
	# Control-owned snapshots: resource income cannot invalidate AI deployment.
	if ui_state_changed(scientist_summary,[game.profile.scientists,game.profile.scientistAssignments,game.profile.unlocked,hightech_buttons.keys()]):
		var idle := game.idle_scientists()
		set_ui_value(scientist_summary,"text",UIText.t("research.ai_summary", {"total":number(game.profile.scientists),"assigned":number(game.profile.scientists-idle),"idle":number(idle)}))
		set_ui_value(hightech_inventory,"text",UIText.t("research.inventory",{"count":str(hightech_buttons.size())}))
		set_ui_value(scientist_distribute_button,"disabled",int(game.profile.scientists)<=0 or hightech_buttons.is_empty())
		for key in scientist_assignment_buttons:
			var disabled := idle<=0 or not game.hightech_unlocked(key)
			set_ui_value(hightech_buttons[key],"disabled",disabled)
			for action in scientist_assignment_buttons[key]:set_ui_value(action,"disabled",disabled)
			set_ui_value(scientist_remove_buttons[key],"disabled",game.assigned_scientists(key)<=0)
	if ui_state_changed(scientist_cost_label,[game.profile.scientists,db.config.scientistCost]):
		var cost := game.scientist_cost()
		var costs: Array[String] = []
		for id in cost:
			costs.append(UIText.t("upgrade.refresh_scientists.text_02", {"id":UIText.data_text("resources",str(id)),"id_2":number(cost[id])}))
		set_ui_value(scientist_generate_button,"tooltip_text"," / ".join(costs))
		set_ui_value(scientist_cost_label,"text",UIText.t("upgrade.scientist_cost",{"cost":" / ".join(costs)}))
		set_ui_value(scientist_cost_label,"tooltip_text",scientist_cost_label.text)
	if ui_state_changed(scientist_generate_button,[game.profile.scientists,game.profile.resources,game.profile.unlocked,db.config.scientistCost,hightech_buttons.keys()]):
		for amount in scientist_bulk_buttons:
			set_ui_value(scientist_bulk_buttons[amount],"disabled",not game.can_generate_scientist(amount))
		set_ui_value(scientist_generate_button,"disabled",not game.can_generate_scientist())

func refresh_hightech_progress(key: String) -> void:
	var controls: Dictionary = hightech_progress[key]
	var construction = controls.construction
	var workers := game.assigned_scientists(key)
	var rate := game.research_rate(key)
	var required := game.hightech_required(key)
	var points := float(game.profile.techPoints.get(key,0))
	if not ui_state_changed(controls.label,[workers,game.hightech_level(key),points,required,rate,game.paused,construction.completed>0]):
		return
	var fraction := clampf(points/required,0,1)
	construction.set_fraction(fraction)
	construction.set_workers(workers)
	set_ui_value(controls.label,"text",UIText.t("research.metrics",{"rate":number(rate),"points":number(points),"required":number(required)}))
	set_ui_value(controls.workers,"text",UIText.t("research.assigned",{"count":number(workers)}))
	var state := "research.foundation" if fraction<0.1 else "research.frame" if fraction<0.4 else "research.assembly" if fraction<0.75 else "research.validation"
	if game.paused:state = "research.paused"
	elif workers<=0:state = "research.idle"
	if construction.completed>0:state = "research.complete"
	set_ui_value(controls.state,"text",UIText.t(state))
	set_ui_value(controls.percent,"text",UIText.t("research.progress",{"percent":"100" if construction.completed>0 else "%.0f" % floorf(fraction*100)}))

func build_charge_tab() -> void:
	charge_panel = preload("res://scripts/charge_panel.gd").new()
	charge_panel.name = "Charge"
	equipment_tabs.add_child(charge_panel)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(charge_panel),UIText.t("upgrade.charge_tab"))
	charge_panel.setup(self)
	charge_cards = charge_panel.cards

func layout_charge_page() -> void:
	layout_battle_return()
	var expanded := equipment_tabs.current_tab in [1,2,3,4,5,6]
	set_ui_value(charge_nav_backdrop,"visible",expanded)
	if equipment_tabs.current_tab==4:
		equipment_panel.stop_transition()
		set_ui_value(equipment_tabs,"position",Vector2(38,96))
		set_ui_value(equipment_tabs,"size",Vector2(1364,679))
		return
	if equipment_tabs.current_tab == 0:
		equipment_panel.apply_view_layout(false)
		return
	equipment_panel.stop_transition()
	set_ui_value(equipment_tabs,"position",Vector2(38,84 if expanded else 620))
	set_ui_value(equipment_tabs,"size",Vector2(1364,692 if expanded else 156))

func charge_progress_bar(card: Control, pos: Vector2, width: float, color: Color) -> ColorRect:
	var progress := ColorRect.new()
	progress.position = pos
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.color = LINE
	progress.size = Vector2(width,6)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(0,6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(fill)
	card.add_child(progress)
	return progress

func refresh_charge_card(key: String) -> void:
	if is_instance_valid(charge_panel):
		charge_panel.refresh_card(key)

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
	add_child(dialog)
	dialog.confirmed.connect(func():
		if str(game.profile.selectedShip) == ship_key and game.slot_entry(category,index) == entry:
			if game.unequip_slot(category,index):
				refresh_structure()
		dialog.queue_free())
	dialog.canceled.connect(func():dialog.queue_free())
	dialog.popup_centered()

func build_hightech_tab() -> void:
	hightech_page = Panel.new()
	hightech_page.name = "Hightech"
	hightech_page.add_theme_stylebox_override("panel",style(Color("08121f"),LINE))
	equipment_tabs.add_child(hightech_page)
	equipment_tabs.set_tab_title(equipment_tabs.get_tab_idx_from_control(hightech_page),UIText.t("upgrade.research_tab"))
	equipment_label(hightech_page,UIText.t("research.heading"),Vector2(18,12),25,INK)
	equipment_label(hightech_page,UIText.t("research.subtitle"),Vector2(20,48),12,MUTED)
	scientist_summary = equipment_label(hightech_page,"",Vector2(400,17),17,CYAN)
	hightech_inventory = equipment_label(hightech_page,"",Vector2(20,91),12,MUTED)
	var actions := [1,10,-1]
	for i in actions.size():
		var amount: int = actions[i]
		var text_key := "upgrade.refresh_scientists.text_03" if amount==1 else "upgrade.build_hightech_tab.text_04" if amount==10 else "upgrade.build_hightech_tab.text_05"
		var action := button(UIText.t(text_key),Rect2(857+i*119,14,110,34),func():game.generate_scientist(amount),amount==1)
		action.reparent(hightech_page,false)
		action.add_theme_font_size_override("font_size",13)
		if amount==1:scientist_generate_button=action
		else:scientist_bulk_buttons[amount]=action
	scientist_distribute_button = button(UIText.t("upgrade.build_hightech_tab.text_02"),Rect2(1214,14,124,34),func():game.distribute_scientists())
	scientist_distribute_button.reparent(hightech_page,false)
	scientist_distribute_button.add_theme_font_size_override("font_size",13)
	scientist_distribute_button.tooltip_text = UIText.t("upgrade.build_hightech_tab.text_03")
	scientist_cost_label = equipment_card_label(hightech_page,"",Rect2(857,54,482,28),12,MUTED)
	var hint := equipment_card_label(hightech_page,UIText.t("research.navigation"),Rect2(500,89,837,24),12,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scroll := ScrollContainer.new()
	hightech_scroll = scroll
	scroll.position = Vector2(12,121)
	scroll.size = Vector2(1336,526)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hightech_page.add_child(scroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation",12)
	scroll.add_child(cards)
	hightech_container = cards
	var slots := game.hightech_slots().filter(func(key):return not str(key).is_empty())
	for index in range(slots.size()):build_hightech_card(index,str(slots[index]))
	refresh_scientists()
	scroll.set_deferred("scroll_horizontal",hightech_scroll_offset)

func build_hightech_card(_index: int, key: String) -> void:
	var card := Panel.new()
	card.set_meta("tech_key",key)
	card.custom_minimum_size = HIGHTECH_CARD_SIZE
	card.add_theme_stylebox_override("panel",style(Color("0e1d2d"),Color("2b445b")))
	card.add_theme_font_override("font",font)
	hightech_container.add_child(card)
	var construction := CONSTRUCTION_SCRIPT.new()
	construction.position = Vector2(14,74)
	construction.size = Vector2(296,304)
	card.add_child(construction)
	construction.setup(key)
	var title := equipment_card_label(card,"",Rect2(14,12,295,27),16,INK)
	title.text = UIText.t("gem.name_level",{"item_name":UIText.data_text("hightech",key),"level":str(int(game.hightech_level(key)))})
	title.size = Vector2(295,27)
	title.tooltip_text = title.text
	hightech_titles[key] = title
	var state := equipment_label(card,"",Vector2(14,46),12,construction.accent)
	var percent := equipment_card_label(card,"",Rect2(172,44,137,24),12,MUTED)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var description := equipment_card_label(card,game.hightech_description(key),Rect2(14,388,296,44),13,INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size = Vector2(296,44)
	description.tooltip_text = description.text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	hightech_descriptions[key] = description
	var metrics := equipment_card_label(card,"",Rect2(14,434,296,24),11,MUTED)
	var workers := equipment_card_label(card,"",Rect2(14,469,110,24),13,construction.accent)
	hightech_progress[key] = {"label":metrics,"construction":construction,"state":state,"percent":percent,"workers":workers}
	refresh_hightech_progress(key)
	var remove := button(UIText.t("upgrade.build_hightech_card.text_05"),Rect2(131,465,39,31),func():game.assign_scientist(key,-1),false,game.assigned_scientists(key)<=0)
	remove.reparent(card,false)
	remove.add_theme_font_size_override("font_size",12)
	scientist_remove_buttons[key] = remove
	var add := button(UIText.t("upgrade.build_hightech_card.text_04"),Rect2(177,465,39,31),func():game.assign_scientist(key,1),true,not game.can_research(key))
	add.reparent(card,false)
	add.add_theme_font_size_override("font_size",12)
	hightech_buttons[key] = add
	scientist_assignment_buttons[key]=[]
	for amount in [10,-1]:
		var action := button(UIText.t("upgrade.build_hightech_card.text_06") if amount==10 else UIText.t("weapon.build_equipment_card.text_19"),Rect2(223 if amount==10 else 269,465,39,31),func():game.assign_scientist(key,10 if amount==10 else game.idle_scientists()),false,not game.can_research(key))
		action.reparent(card,false)
		action.add_theme_font_size_override("font_size",11)
		scientist_assignment_buttons[key].append(action)

func draw_unlock() -> void:
	draw_surface.draw_rect(Rect2(0,78,1440,732),Color(0.02,0.04,0.08,0.93))
	box(Rect2(400,240,640,370),Color("142638"),CYAN)
	var row: Dictionary = db.data.unlock[game.pending_unlocks[0]]
	text_at(str(row.title),Vector2(457,303),32,CYAN)
	text_at(str(row.desc),Vector2(457,361),18,INK)
	if game.pending_unlocks.size() > 1:
		text_at(UIText.t("unlock.remaining", {"count":str(game.pending_unlocks.size())}),Vector2(457,476),18,MUTED)
	text_at(UIText.t("unlock.next" if game.pending_unlocks.size() > 1 else "main.draw_unlock.text_03"),Vector2(457,509),15,MUTED)
