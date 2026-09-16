extends Node2D

const BG := Color("080e1b")
const PANEL := Color("101c2c")
const LINE := Color("26384b")
const INK := Color("e0ecf4")
const MUTED := Color("8195ac")
const CYAN := Color("71e5f4")
const ORANGE := Color("ffbc73")
const PURPLE := Color("b3a0ff")
const NAMES := {"armour":"复合装甲","shield":"偏转护盾","laser":"脉冲激光","missile":"追踪导弹","cannon":"磁轨火炮"}
const PROJECTILE_TEXTURES := {
	"laser":preload("res://assets/weapons/laser-pulse.png"),
	"cannon":preload("res://assets/weapons/cannon-slug.png"),
	"missile":preload("res://assets/weapons/guided-missile.png")
}
const PROJECTILE_SIZES := {"laser":Vector2(64,24),"cannon":Vector2(40,21),"missile":Vector2(64,26)}
const PROJECTILE_SCALE := 0.65
const SLOT_TEXTURES := {
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
var module_regions: Dictionary = {}
var db: ShipDatabase
var game: BattleGame
var font: SystemFont
var ui: Control
var stars: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var clock := 0.0
var star_travel := 0.0
var star_streak := 0.0
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
const EQUIPMENT_PAGES := [{"title":"武器","keys":["laser","cannon","missile"]},{"title":"防御","keys":["armour","shield"]}]
var equipment_page := 0
var equipment_tabs: TabContainer
var equipment_cooldowns: Dictionary = {}
var equipment_card_controls: Dictionary = {}
var ship_candidate := ""
var ship_candidate_loadout: Dictionary = {}
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
const HIGHTECH_SLOT_SCRIPT := preload("res://scripts/hightech_slot.gd")
const HIGHTECH_CARD_SIZE := Vector2(443,112)
var hightech_scroll: ScrollContainer
var hightech_scroll_offset := 0
var ui_rebuild_pending := false
var ui_rebuild_scheduled := false
var automation_args := OS.get_cmdline_user_args()
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
var hightech_sync_pending := false

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	db = ShipDatabase.new()
	game = BattleGame.new(db, not automation_args.has("--capture"))
	game.event.connect(on_event)
	create_draw_layers()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	for i in range(200):
		stars.append({"x":randf()*1440,"y":randf()*810,"z":randf_range(0.2,1.0)})
	audio = AudioStreamPlayer.new()
	audio.volume_db = -25
	add_child(audio)
	game.start(int(game.profile.guardStage) if game.profile.loop else int(game.profile.highestLevel), bool(game.profile.loop))
	if game.profile.loop:
		game.resume_guard()
	build_ui()
	if not game.offline_rewards.is_empty():
		var rewards: PackedStringArray = []
		for id in game.offline_rewards:
			rewards.append("%s +%s" % [db.data.resources[id], number(game.offline_rewards[id])])
		toast("离线收益：" + "  ".join(rewards))
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
	if DisplayServer.get_name() != "headless" and not automation_args.has("--capture"):
		var preferences := ConfigFile.new()
		preferences.load("user://qa_settings.cfg")
		var saved_speed := int(preferences.get_value("control","speed",1))
		game.speed = saved_speed if saved_speed in [1,2,5] else 1
		call_deferred("show_qa_tools")

func show_qa_tools() -> void:
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
	if hightech_sync_pending and not get_viewport().gui_is_dragging():
		sync_hightech_slots()
	if ui_rebuild_pending and not get_viewport().gui_is_dragging():
		ui_rebuild_pending = false
		build_ui()
	var dt := minf(delta,0.1)
	clock += dt
	prune_resource_samples(Time.get_unix_time_from_system())
	if not game.paused:
		var remaining := dt*game.speed
		while remaining > 0:
			var step := minf(remaining, 1.0/60.0)
			game.tick(step)
			remaining -= step
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
			f.pos.y -= dt*28
		floats = floats.filter(func(f):return f.life > 0)
	shake = maxf(0,shake-dt*18)
	message_time = maxf(0,message_time-dt)
	refresh_visible_cards()
	refresh_navigation()
	refresh_draw_layers(dt)
	if is_instance_valid(hightech_scroll) and hightech_scroll.is_visible_in_tree() and get_viewport().gui_is_dragging():
		var mouse := hightech_scroll.get_local_mouse_position()
		if mouse.y >= 0 and mouse.y <= hightech_scroll.size.y:
			if mouse.x >= hightech_scroll.size.x-36 and mouse.x <= hightech_scroll.size.x:
				hightech_scroll.scroll_horizontal += int(600*delta)+1
			elif mouse.x >= 0 and mouse.x < 36:
				hightech_scroll.scroll_horizontal -= int(600*delta)+1
	if automation_args.has("--capture"):
		capture_frame += 1
		if capture_frame == 45:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://preview" + ("-unlock" if automation_args.has("--capture-unlock") else "-all" if automation_args.has("--capture-all") else "-combat") + ".png")
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		game.collect_near(get_global_mouse_position())
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
		"jewels_changed":
			if is_instance_valid(jewel_panel):
				jewel_panel.refresh()
			if not str(info.get("slot", "")).is_empty():
				refresh_equipment_cards(str(info.slot))
		"jewel_error":
			toast(str(info.message))
		"jewel_pickup":
			toast("拾取 " + str(db.jewel(str(info.jewel)).get("name", info.jewel)) + "碎片")
		"state":
			refresh_structure()
			refresh_navigation()
		"hit":
			var color := ORANGE if info.player else (CYAN if info.type == 1 else ORANGE)
			var target := "player" if info.player else "enemy:%s" % info.uid
			var active: Dictionary = {}
			for entry in floats:
				if entry.get("target","") == target and entry.life > 0:
					active = entry
					break
			if active.is_empty():
				active = {"pos":Vector2(info.x,info.y-36),"amount":0.0,"color":color,"life":0.9,"damage":true,"target":target}
				floats.append(active)
			active.amount += float(info.amount)
			active.text = "−%s" % number(active.amount)
			active.pos = damage_text_position(active.pos,active.text,target)
			burst(Vector2(info.x,info.y),color,7,70)
			if info.player:
				shake = 3
		"explode":
			burst(Vector2(info.x,info.y),ORANGE,65 if info.boss else 26,200)
			shake = 6 if info.boss else 2
			beep(90)
		"fire":
			burst(Vector2(info.x,info.y),CYAN if info.type == 1 else ORANGE,4,40)
			beep(620 if info.type == 1 else 200)
		"collect":
			var color := INK if info.id == "1" else PURPLE
			var label := "+%s %s%s" % [number(info.amount),db.data.resources[info.id],"" if info.manual else " · 自动"]
			floats.append({"pos":Vector2(info.x,info.y-12),"text":label,"color":color,"life":1.5})
			var origin := Vector2(info.x,info.y)
			for i in range(9):
				particles.append({"pos":origin+Vector2(randf_range(-12,12),randf_range(-12,12)),"vel":(Vector2(890,42)-origin)*randf_range(1.0,1.4),"color":color,"life":0.65,"size":2.5})
		"encounter":
			toast("发现旗舰 · 武器自动锁定" if info.boss else "接触敌方编队 · 巡航暂停")
		"wave_clear":
			toast("空域已肃清 · 恢复巡航")
		"upgrade":
			var levels := int(info.get("levels",1))
			toast(NAMES[info.key] + ("升级完成" if levels == 1 else "连续升级%s级完成" % number(levels)))
			refresh_equipment_cards(str(info.get("slot","")))
		"scientists_changed":
			refresh_scientists()
			for key in hightech_progress:
				refresh_hightech_progress(key)
		"hightech_complete":
			toast(str(info.key) + "研发完成")
			refresh_hightech_card(str(info.key))
			refresh_equipment_effects(str(info.key))
		"unlock":
			help_open = false
			refresh_structure()
			refresh_navigation()
		"retreat":
			toast("生命归零 · 后退至 %s 距离，恢复后继续" % number(info.to))
		"save_error":
			toast("存档写入失败，请检查磁盘权限")

func number(value: float) -> String:
	# All in-game quantity text must use this shared K/M/B/T formatter.
	return NUMBER_FORMAT.compact(value)

func enemy_health(value: float) -> String:
	return number(value)

func cost_text(cost: Dictionary) -> String:
	var result := ""
	for id in cost:
		result += "%s %s  " % [number(cost[id]),db.data.resources[id]]
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
	return NUMBER_FORMAT.rate(rate) + "/秒"

func toggle_resource_display() -> void:
	resource_rate_mode = not resource_rate_mode
	resource_mode_button.text = "资源：每秒" if resource_rate_mode else "资源：总量"
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

func burst(pos: Vector2, color: Color, count: int, force: float) -> void:
	for i in range(count):
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
	# Combat and research events must not remove a card while it is being dragged.
	if get_viewport().gui_is_dragging():
		ui_rebuild_pending = true
		return
	ui_rebuild_pending = false
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
	help_button = button("?  操作指南",Rect2(1262,25,140,38),func():help_open=not help_open;refresh_navigation())
	resource_mode_button = button("资源：每秒" if resource_rate_mode else "资源：总量",Rect2(664,25,156,38),toggle_resource_display)
	resource_mode_button.tooltip_text = "切换总量 / 最近60秒实际拾取量÷60（现实时间）"
	continue_button = button("继续",Rect2(600,535,240,48),func():game.acknowledge_unlocks(),true)
	help_close_button = button("知道了",Rect2(600,626,240,44),func():help_open=false;refresh_navigation(),true)
	loop_select = OptionButton.new()
	loop_select.position = Vector2(1010,92)
	loop_select.size = Vector2(190,38)
	loop_select.add_item("跃迁至关卡", 0)
	for level in range(1, db.levels.size()+1):
		if game.profile.cleared.has(level):
			loop_select.add_item("跃迁 · 第 %s 关" % number(level), level)
			if level == int(game.profile.get("loopLevel", 0)):
				loop_select.select(loop_select.item_count-1)
	loop_select.set_item_disabled(0, true)
	loop_select.item_selected.connect(func(index):game.select_loop_level(loop_select.get_item_id(index));refresh_navigation())
	ui.add_child(loop_select)
	loop_button = button("驻守：" + ("开启" if game.profile.loop else "关闭"),Rect2(1210,92,142,38),func():game.toggle_loop();refresh_navigation(),false,game.state == BattleGame.State.RETREAT)
	guard_settings = MenuButton.new()
	guard_settings.text = "设置"
	guard_settings.position = Vector2(1356,92)
	guard_settings.size = Vector2(46,38)
	guard_settings.tooltip_text = "驻守死亡处理"
	var death_menu := guard_settings.get_popup()
	var death_options := ["后退并取消驻守", "后退后返回原点继续驻守", "后退并保持驻守（不返回）"]
	for mode in range(death_options.size()):
		death_menu.add_radio_check_item(death_options[mode], mode)
		death_menu.set_item_checked(mode, mode == int(game.profile.get("guardDeath", 0)))
	death_menu.id_pressed.connect(func(mode):game.set_guard_death(mode);refresh_navigation())
	ui.add_child(guard_settings)
	build_equipment_tabs()
	advance_button = button("立即过关",Rect2(780,302,200,46),func():game.advance_after_clear(),true)
	sound_button = button("",Rect2(1262,778,140,26),func():sound_on=not sound_on;refresh_navigation())
	refresh_navigation()
	jewel_panel = preload("res://scripts/jewel_panel.gd").new()
	ui.add_child(jewel_panel)
	jewel_panel.setup(self)
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

func refresh_visible_cards() -> void:
	if not is_instance_valid(equipment_tabs) or not equipment_tabs.is_visible_in_tree():
		return
	match equipment_tabs.current_tab:
		0,1:
			var category := "weapons" if equipment_tabs.current_tab == 0 else "defence"
			for index in game.profile.loadout[category].size():
				var slot := game.slot_id(category,index)
				refresh_equipment_cards(slot)
				if equipment_cooldowns.has(slot):
					var entry := game.slot_entry(category,index)
					var cd := float(db.equip(str(entry.key),int(entry.level)).cd)
					var fill: ColorRect = equipment_cooldowns[slot]
					set_ui_value(fill,"size",Vector2(fill.get_parent().size.x*clampf(1.0-float(game.cooldowns.get(slot,0))/maxf(cd,0.001),0,1),fill.size.y))
		2:
			refresh_scientists()
			for key in hightech_progress:
				refresh_hightech_card(key)
		3:
			for key in charge_cards:
				refresh_charge_card(key)

func refresh_hightech_card(key: String) -> void:
	if not hightech_progress.has(key):
		return
	var title: Label = hightech_titles[key]
	if ui_state_changed(title,[game.hightech_level(key),db.data.hightech[key]]):
		set_ui_value(title,"text","%s Lv.%s" % [key,number(game.hightech_level(key))])
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

func refresh_tab_visibility() -> void:
	var pages: Array[bool] = []
	for entries in [game.weapon_entries(),game.defense_entries()]:
		pages.append(entries.any(func(entry):return game.profile.unlocked.has(str(entry.get("key","")))))
	pages.append(not hightech_buttons.is_empty())
	pages.append(db.data.get("charge",{}).keys().any(func(key):return game.charge_unlocked(key)))
	pages.append(unlocked_ship_keys().size()>1)
	pages.append(game.jewels_unlocked())
	for index in pages.size():
		if equipment_tabs.is_tab_hidden(index) == pages[index]:
			equipment_tabs.set_tab_hidden(index,not pages[index])
	var selected := equipment_page
	if selected < 0 or selected >= pages.size() or not pages[selected]:
		selected = pages.find(true)
	set_ui_value(equipment_tabs,"current_tab",selected)

func remove_equipment_card(slot: String) -> void:
	for buttons in [upgrade_buttons,ten_upgrade_buttons,max_upgrade_buttons]:
		for key in buttons.keys():
			if str(buttons[key].get_meta("slot")) == slot:
				buttons.erase(key)
	equipment_card_controls.erase(slot)
	equipment_cooldowns.erase(slot)
	var card: Panel = equipment_panels[slot]
	card.get_parent().remove_child(card)
	card.queue_free()
	equipment_panels.erase(slot)

func refresh_structure() -> void:
	if not is_instance_valid(equipment_tabs):
		return
	if not ui_state_changed(equipment_tabs,[game.profile.loadout,game.profile.unlocked,game.profile.cleared,game.profile.selectedShip]):
		return
	for slot in equipment_panels.keys():
		var category := str(slot).get_slice("_",0)
		var index := int(str(slot).get_slice("_",1))
		if index >= game.profile.loadout[category].size() or equipment_panels[slot].get_meta("equipment_key") != str(game.slot_entry(category,index).key):
			remove_equipment_card(slot)
	for category in ["weapons","defence"]:
		for index in game.profile.loadout[category].size():
			var slot := game.slot_id(category,index)
			if not equipment_panels.has(slot):
				build_equipment_card(category,index)
				equipment_containers[category].move_child(equipment_panels[slot],index)
			var selector: OptionButton = equipment_panels[slot].get_meta("selector")
			if selector.visible and ui_state_changed(selector,[game.profile.unlocked,game.profile.loadout,game.equipment_limit()]):
				selector.clear()
				selector.add_item("空槽")
				var keys: Array = EQUIPMENT_PAGES[0 if category == "weapons" else 1].keys
				for key in keys:
					if game.profile.unlocked.has(key):
						var limit_reached := game.equipment_count(key)>=game.equipment_limit()
						selector.add_item(NAMES[key]+("（已达上限）" if limit_reached else ""),keys.find(key)+1)
						selector.set_item_disabled(selector.item_count-1,limit_reached)
	sync_hightech_slots()
	if not ship_controls.is_empty() and ship_candidate==str(game.profile.selectedShip) and ship_controls.page.get_meta("runtime_loadout",{}) != game.profile.loadout:
		var old_sizes := [ship_candidate_loadout.weapons.size(),ship_candidate_loadout.defence.size()]
		ship_candidate_loadout = game.profile.loadout.duplicate(true)
		ship_controls.page.set_meta("runtime_loadout",game.profile.loadout.duplicate(true))
		if old_sizes != [ship_candidate_loadout.weapons.size(),ship_candidate_loadout.defence.size()]:
			rebuild_ship_slots()
	refresh_ship_controls()
	refresh_tab_visibility()
	refresh_visible_cards()

func sync_hightech_slots() -> void:
	if not is_instance_valid(hightech_container):
		return
	if get_viewport().gui_is_dragging():
		hightech_sync_pending = true
		return
	hightech_sync_pending = false
	var slots := game.hightech_slots()
	for index in slots.size():
		var key := str(slots[index])
		var matching: Control = null
		for child in hightech_container.get_children().slice(index+1):
			if child.get("tech_key") == key:
				matching = child
				break
		if matching == null:
			build_hightech_card(index,key)
			matching = hightech_container.get_child(-1)
		if matching.get_index() != index+1:
			hightech_container.move_child(matching,index+1)
		matching.slot_index = index
	while hightech_container.get_child_count() > slots.size()+1:
		var retired = hightech_container.get_child(-1)
		var key := str(retired.tech_key)
		for controls in [hightech_buttons,hightech_titles,hightech_descriptions,hightech_progress,scientist_remove_buttons,scientist_assignment_buttons]:
			controls.erase(key)
		hightech_container.remove_child(retired)
		retired.queue_free()

func refresh_ship_controls() -> void:
	if ship_controls.is_empty():
		return
	var current := str(game.profile.selectedShip)
	var picker: OptionButton = ship_controls.picker
	var keys := unlocked_ship_keys()
	if ui_state_changed(picker,[keys]):
		picker.clear()
		for key in keys:
			var row: Dictionary = db.ship(key)
			picker.add_item(str(row.des))
			picker.set_item_metadata(picker.item_count-1,key)
			picker.set_item_tooltip(picker.item_count-1,"武器槽 %s · 防御槽 %s · 移动 %s" % [number(row.weaponSlots),number(row.defenseSlots),number(row.movement)])
	if picker.selected != keys.find(ship_candidate):
		picker.select(keys.find(ship_candidate))
	set_ui_value(ship_controls.status,"text","当前：%s · 空槽可保留，装备需在此页签选定" % game.ship_name() if ship_candidate==current else "%s · 新舰装备等级从 Lv.1 开始" % ("配置有效" if game.valid_loadout(ship_candidate,ship_candidate_loadout) else "请检查装备数量/解锁状态"))
	set_ui_value(ship_controls.confirm,"disabled",ship_candidate==current or not game.valid_loadout(ship_candidate,ship_candidate_loadout))
	for slot in ship_controls.selectors:
		var selector: OptionButton = ship_controls.selectors[slot]
		var category := str(slot).get_slice("_",0)
		var index := int(str(slot).get_slice("_",1))
		var selected := str(ship_candidate_loadout[category][index].key)
		var options: Array = EQUIPMENT_PAGES[0 if category=="weapons" else 1].keys
		options = options.filter(func(key):return game.profile.unlocked.has(key))
		if ui_state_changed(selector,[options]):
			selector.clear()
			selector.add_item("空槽")
			for key in options:
				selector.add_item(NAMES[key])
				selector.set_item_metadata(selector.item_count-1,key)
		var selection := options.find(selected)+1
		if selector.selected != selection:
			selector.select(selection)
		for i in options.size():
			var disabled := candidate_equipment_count(options[i],category,index)>=int(db.ship(ship_candidate).get("sameEquipmentLimit",1))
			if selector.is_item_disabled(i+1) != disabled:
				selector.set_item_disabled(i+1,disabled)
		set_ui_value(ship_controls.notes[slot],"text","可保留为空" if selected.is_empty() else "更换时配置 · Lv.1")

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
		for control in [loop_select,loop_button,guard_settings,equipment_tabs,sound_button]:
			set_ui_value(control,"visible",navigation_visible)
	var advance_visible := navigation_visible and game.state==BattleGame.State.LEVEL_CLEAR
	if ui_state_changed(advance_button,[advance_visible]):
		set_ui_value(advance_button,"visible",advance_visible)
	if ui_state_changed(loop_button,[game.profile.loop,game.state==BattleGame.State.RETREAT]):
		set_ui_value(loop_button,"text","驻守："+("开启" if game.profile.loop else "关闭"))
		set_ui_value(loop_button,"disabled",game.state==BattleGame.State.RETREAT)
	if ui_state_changed(sound_button,[sound_on]):
		set_ui_value(sound_button,"text","音效："+("开" if sound_on else "关"))
	var selection := int(game.profile.get("loopLevel",0))
	if ui_state_changed(loop_select,[game.profile.cleared]):
		var ids: Array[int] = [0]
		for level in range(1,db.levels.size()+1):
			if game.profile.cleared.has(level):
				ids.append(level)
		while loop_select.item_count > ids.size():
			loop_select.remove_item(loop_select.item_count-1)
		for index in ids.size():
			var label := "跃迁至关卡" if index==0 else "跃迁 · 第 %s 关" % number(ids[index])
			if index >= loop_select.item_count:
				loop_select.add_item(label,ids[index])
			elif loop_select.get_item_id(index) != ids[index]:
				loop_select.set_item_id(index,ids[index])
				loop_select.set_item_text(index,label)
		if not loop_select.is_item_disabled(0):
			loop_select.set_item_disabled(0,true)
	if not game.profile.cleared.has(selection):
		selection = 0
	if loop_select.get_selected_id() != selection:
		loop_select.select(loop_select.get_item_index(selection))
	var menu := guard_settings.get_popup()
	if ui_state_changed(menu,[game.profile.get("guardDeath",0)]):
		for mode in menu.item_count:
			var checked := mode==int(game.profile.get("guardDeath",0))
			if menu.is_item_checked(mode) != checked:
				menu.set_item_checked(mode,checked)

func create_draw_layers() -> void:
	background_layer = Node2D.new()
	chrome_layer = Node2D.new()
	stars_layer = Node2D.new()
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
	if ui_state_changed(stars_layer,[star_travel,star_streak,game.speed]):
		stars_layer.queue_redraw()
	# Animation is isolated to the battlefield; stationary UI/backgrounds retain draw commands.
	var battle_changed := ui_state_changed(battle_layer,[game.state,game.paused,game.stage,game.player,game.profile.selectedShip,game.profile.loadout,game.stat("armour"),game.max_shield(),game.profile.unlocked,game.pending_unlocks])
	if battle_changed or (dt>0 and (not game.paused or shake>0 or not game.drops.is_empty())):
		battle_layer.queue_redraw()
	if ui_state_changed(resource_layer,[resource_display("1"),resource_display("2")]):
		resource_layer.queue_redraw()
	if ui_state_changed(overlay_layer,[help_open,game.pending_unlocks,message if message_time>0 and not help_open and game.pending_unlocks.is_empty() else ""]):
		overlay_layer.queue_redraw()

func damage_text_rect(pos: Vector2, value: String) -> Rect2:
	return Rect2(pos-Vector2(0,font.get_ascent(18)),Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x,font.get_height(18))).grow(3)

func damage_text_position(origin: Vector2, value: String, excluded_target := "") -> Vector2:
	var pos := origin
	# All damage labels rise at the same speed, so separated bounds stay separated.
	while true:
		var bounds := damage_text_rect(pos,value)
		var blocked := false
		for entry in floats:
			if entry.get("damage",false) and entry.life > 0 and entry.get("target","") != excluded_target:
				var occupied := damage_text_rect(entry.pos,entry.text)
				if bounds.intersects(occupied):
					pos.y -= bounds.end.y-occupied.position.y+1
					if pos.y < 150:
						pos.x = occupied.end.x+4
						pos.y = origin.y
					blocked = true
					break
		if not blocked:
			return pos
	return pos

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
	text_at("太空战舰",Vector2(83,49),22)
	text_at("DEEP SPACE / EXPEDITION",Vector2(210,47),12,MUTED)
	draw_surface.draw_rect(Rect2(0,615,1440,195),Color("0c1522"))
	draw_surface.draw_line(Vector2(38,615),Vector2(1402,615),LINE)
	text_at("原型 0.2    /    本地自动保存",Vector2(40,795),11,MUTED)

func draw_stars() -> void:
	for s in stars:
		var x := fposmod(float(s.x)-star_travel*float(s.z)*4,1440)
		var a := 0.2+float(s.z)*0.5
		draw_surface.draw_circle(Vector2(x,s.y),float(s.z)*1.35,Color(0.7,0.83,1,a))
		if star_streak > 0:
			draw_surface.draw_line(Vector2(x,s.y),Vector2(x+float(s.z)*9*game.speed*star_streak,s.y),Color(0.5,0.8,1,a*0.3*star_streak))

func draw_resources() -> void:
	text_at(str(db.data.resources["1"]),Vector2(850,34),11,MUTED)
	text_at(resource_display("1"),Vector2(850,58),22,INK)
	text_at(str(db.data.resources["2"]),Vector2(1040,34),11,MUTED)
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
			"label":"#%02d  %s" % [int(enemy.slot)+1, str(enemy.des)],
			"health":"%s / %s" % [enemy_health(float(enemy.hp)), enemy_health(float(enemy.max_hp))],
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
	text_at("第 %s 关" % number(game.stage),Vector2(39,111),21)
	var boss_battle := game.state == BattleGame.State.COMBAT and game.is_boss_encounter()
	var boss_title := "BOSS战 · 当前存活 %s / %s 艘" % [number(game.targets().size()),number(game.enemies.size())] if boss_battle else "BOSS：" + game.boss_info()
	text_at(fit_battle_text(boss_title, 570, 16),Vector2(175,111),16,ORANGE)
	text_at("%s / %s" % [number(game.distance),number(length)],Vector2(40,142),13,MUTED)
	bar(Rect2(40,155,1362,3),game.distance/length,CYAN)
	for j in range(9):
		var xx := 40+1362*float(j+1)/10
		draw_surface.draw_circle(Vector2(xx,156),4,CYAN if game.group_index>j else LINE)
	var travel_status := "后退中 / RETREAT" if game.state==BattleGame.State.RETREAT else "自动交战 / AUTO ENGAGE" if game.state==BattleGame.State.COMBAT else "自动巡航 / CRUISING"
	if game.guarding_here() and game.state == BattleGame.State.COMBAT and game.targets().is_empty():
		travel_status = "驻守 · %s 秒后刷新" % number(maxf(0,game.guard_interval()-game.guard_elapsed))
	text_at(travel_status,Vector2(40,197),12,CYAN)
	text_at("遭遇 %s / %s" % [number(game.group_index),number(9)],Vector2(1266,197),13,MUTED)
	var offset := Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
	for slot in range(10):
		text_at("%02d" % slot,Vector2(1370,202+slot*44),10,Color("34475c"))
		draw_surface.draw_line(Vector2(1330,198+slot*44),Vector2(1353,198+slot*44),Color("253345"))
	if game.player.armour>0 or game.state==BattleGame.State.RETREAT:
		draw_ship(Vector2(game.player.x,game.player.y)+offset,0.24,false,1,game.player.shield>0)
		text_at(game.ship_name(),Vector2(246,489),16,INK)
		text_at("%s / %02dW-%02dD" % [game.profile.selectedShip,game.weapon_entries().size(),game.defense_entries().size()],Vector2(215,515),11,MUTED)
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
		if not boss_battle:
			var health_position := Vector2(pos.x+dimensions.x/2+8,pos.y+4)
			if health_position.x > 1240:
				health_position = Vector2(pos.x-w/2,pos.y-dimensions.y/2-6)
			text_at("%s / %s" % [enemy_health(float(enemy.hp)),enemy_health(float(enemy.max_hp))],health_position,12,INK)
		else:
			var marker := pos + Vector2(dimensions.x/2+8,-10)
			box(Rect2(marker, Vector2(40, 20)), PANEL, LINE)
			text_at("#%02d" % (int(enemy.slot)+1),marker+Vector2(5,15),12,INK)
	for card in boss_health_cards():
		var rect: Rect2 = card.rect
		var color: Color = ORANGE if int(card.enemy.armourType) == 2 else CYAN
		box(rect,Color("131e2c"),Color("34475c"))
		text_at(fit_battle_text(card.label,rect.size.x-24,14),rect.position+Vector2(12,18),14,color)
		text_at(card.health,rect.position+Vector2(12,36),13,INK)
		bar(Rect2(rect.position+Vector2(12,44),Vector2(rect.size.x-24,4)),card.ratio,color)
	for p in game.projectiles:
		var pos := Vector2(p.x,p.y)+offset
		var direction: Vector2 = p.direction
		var key := str(p.key).replace("_mon", "").replace("-mon", "")
		var size: Vector2 = PROJECTILE_SIZES[key] * PROJECTILE_SCALE
		draw_surface.draw_set_transform(pos, direction.angle())
		draw_surface.draw_texture_rect(PROJECTILE_TEXTURES[key],Rect2(-size/2,size),false)
		draw_surface.draw_set_transform(Vector2.ZERO)
	for drop in game.drops:
		var pos := Vector2(drop.x,drop.y)
		var color := INK if drop.id=="1" else PURPLE
		var bob := sin(clock*3+float(drop.uid))*3
		var furnace: bool = drop.get("hightech", false)
		var auto_gen: bool = drop.get("auto_gen", false)
		if furnace:
			color = ORANGE
			box(Rect2(pos-Vector2(18,18),Vector2(36,36)),PANEL,ORANGE)
			text_at("点击领取",pos+Vector2(-25,-31),12,ORANGE)
		if auto_gen:
			draw_surface.draw_line(pos+Vector2(22,0),pos+Vector2(62,0),Color(color,0.25),2)
		elif not furnace:
			draw_surface.draw_arc(pos,24,-PI/2,-PI/2+TAU*clampf(1.0-float(drop.age)/float(db.defaults.autoCollectDelay),0,1),24,Color(color,0.35),2)
		else:
			draw_surface.draw_arc(pos,24,-PI/2,-PI/2+TAU*clampf(1.0-float(drop.age)/10.0,0,1),24,Color(color,0.35),2)
		text_at("⬡" if drop.id=="1" else "◇",pos+Vector2(-10,7+bob),26,color)
		text_at("%s碎片 · 点击拾取" % db.jewel(str(drop.jewel)).get("name",drop.jewel) if drop.has("jewel") else "%s %s" % [number(drop.amount),db.data.resources[drop.id]],pos+Vector2(-19,41),12,color)
	for p in particles:
		draw_surface.draw_circle(p.pos+offset,float(p.size),Color(p.color,clampf(float(p.life)*2,0,1)))
	for f in floats:
		text_at(f.text,f.pos,18,Color(f.color,clampf(float(f.life)*2,0,1)))
	text_at("生命 %s / %s" % [number(game.player.armour),number(game.stat("armour"))],Vector2(40,587),15,INK)
	bar(Rect2(40,598,273,5),float(game.player.armour)/game.stat("armour"),ORANGE)
	if game.profile.unlocked.has("shield"):
		text_at("护盾 %s / %s" % [number(game.player.shield),number(game.max_shield())],Vector2(343,587),15,CYAN)
		bar(Rect2(343,598,273,5),float(game.player.shield)/maxf(1,game.max_shield()),CYAN)
	text_at("悬停拾取 100%%  /  %s 秒后自动拾取 %s%%" % [number(float(db.defaults.autoCollectDelay)),number((1.0-float(db.config.autoCollectReduce))*100)],Vector2(650 if boss_battle else 1010,596),12,MUTED)
	if game.state == BattleGame.State.LEVEL_CLEAR and game.pending_unlocks.is_empty():
		box(Rect2(430,280,580,95),Color("101c2b"),CYAN)
		text_at("第 %s 关通关" % number(game.stage),Vector2(458,318),26,CYAN)
		var target := game.next_stage()
		text_at("%s 秒后刷新驻守敌群" % number(maxf(0,game.clear_timer)) if game.guarding_here() else "%s 秒后进入第 %s 关" % [number(maxf(0,game.clear_timer)),number(target)],Vector2(458,352),17,INK)
	if game.paused and game.pending_unlocks.is_empty():
		if boss_battle:
			box(Rect2(565,533,310,46),Color("142334"),CYAN)
			text_at("航行已暂停",Vector2(661,553),20,CYAN)
			text_at("按空格或点击继续",Vector2(648,571),14,MUTED)
		else:
			box(Rect2(565,296,310,92),Color("142334"),CYAN)
			text_at("航行已暂停",Vector2(637,336),26,CYAN)
			text_at("按空格或点击继续",Vector2(648,365),14,MUTED)

func draw_ship(pos: Vector2, scale_value: float, hostile: bool, type: int, shield: bool) -> void:
	if not hostile and SHIP_TEXTURES.has(str(game.profile.selectedShip)):
		var ship_key := str(game.profile.selectedShip)
		scale_value = SHIP_VISUALS.scale_for(db.ship(ship_key))
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
			draw_surface.draw_texture_rect_region(SLOT_TEXTURES[key],Rect2(SHIP_VISUALS.center(ship_key,index)-icon_size/2,icon_size),region)
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
	text_at("操作指南",Vector2(360,203),30,CYAN)
	var lines := ["01   战舰自动前进、锁定并攻击敌人。", "02   点击下方装备的升级按钮，立即强化对应装备。", "03   驻守设置可选择死亡后取消、返回原点或退后就地驻守。", "04   未解锁装备不显示；获得新装备时会弹窗通知。", "05   驻守在清敌后按航行间隔刷新；跃迁可前往已通关关卡。", "06   鼠标悬停残骸获得全额资源，超时自动拾取有损耗。", "空格 / Esc：暂停或继续；QA 工具可切换 ×1 / ×2 / ×5", "升级武器不会恢复生命；升级防御装备仅增加提升的容量。", "资源与装备自动保存；生命归零不会扣除已获得资源。"]
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

func build_equipment_tabs() -> void:
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
	for page_index in range(EQUIPMENT_PAGES.size()):
		var scroll := ScrollContainer.new()
		scroll.name = EQUIPMENT_PAGES[page_index].title
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		equipment_tabs.add_child(scroll)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation",8)
		scroll.add_child(cards)
		var category := "weapons" if page_index == 0 else "defence"
		equipment_containers[category] = cards
		for index in game.profile.loadout[category].size():
			build_equipment_card(category,index)
	build_hightech_tab()
	build_charge_tab()
	build_ship_tab()
	var jewel_tab := Control.new()
	jewel_tab.name = "宝石"
	equipment_tabs.add_child(jewel_tab)
	var open_jewels := button("打开宝石工坊 · 背包 / 合成 / 分解", Rect2(22,20,460,45), func():jewel_panel.open())
	open_jewels.reparent(jewel_tab,false)
	equipment_card_label(jewel_tab,"装备镶嵌请点击武器或防御卡上的「镶嵌」",Rect2(505,24,780,38),16,MUTED)
	refresh_tab_visibility()
	equipment_tabs.tab_changed.connect(func(index):equipment_page=index;refresh_visible_cards())

func build_equipment_card(category: String, slot_index: int) -> void:
	var page: Dictionary = EQUIPMENT_PAGES[0 if category == "weapons" else 1]
	var cards: HBoxContainer = equipment_containers[category]
	var entry: Dictionary = game.profile.loadout[category][slot_index]
	var key := str(entry.get("key", ""))
	var defence: bool = category == "defence"
	var slot_key := game.slot_id("defence" if defence else "weapons",slot_index)
	var lv := int(entry.get("level",1))
	var maxed := lv >= db.max_equipment_level(key)
	var next := db.equip(key,mini(lv+1,db.max_equipment_level(key))) if not key.is_empty() else {}
	var bulk: bool = BattleGame.EQUIPMENT.has(key)
	var card := Panel.new()
	equipment_panels[slot_key] = card
	card.set_meta("equipment_key",key)
	card.custom_minimum_size = Vector2(440,112)
	card.add_theme_stylebox_override("panel",style(PANEL,LINE))
	cards.add_child(card)
	equipment_card_label(card,"%s槽 %s" % ["防御" if defence else "武器",number(slot_index+1)],Rect2(248,8,180,20),12,CYAN)
	if not key.is_empty() and SLOT_TEXTURES.has(key):
		var icon := TextureRect.new()
		icon.texture = SLOT_TEXTURES[key]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(12,8)
		icon.size = Vector2(34,26)
		card.add_child(icon)
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.position = Vector2(248,42)
	selector.size = Vector2(180,32)
	selector.disabled = not key.is_empty()
	selector.visible = key.is_empty()
	selector.add_theme_font_override("font",font)
	selector.add_theme_font_size_override("font_size",12)
	selector.add_item("空槽")
	for option_key in page.keys:
		if game.profile.unlocked.has(option_key):
			selector.add_item(NAMES[option_key],page.keys.find(option_key)+1)
			var limit_reached := game.equipment_count(option_key) >= game.equipment_limit()
			selector.set_item_disabled(selector.item_count-1,limit_reached)
			if limit_reached:
				selector.set_item_text(selector.item_count-1,NAMES[option_key]+"（已达上限）")
			if option_key == key:
				selector.select(selector.item_count-1)
	card.set_meta("selector",selector)
	selector.item_selected.connect(func(option):
		var selected := ""
		if option > 0:
			selected = str(page.keys[selector.get_item_id(option)-1])
		if selected.is_empty():
			return
		if game.equip_slot("defence" if defence else "weapons",slot_index,selected):
			refresh_structure()
	)
	card.add_child(selector)
	if not key.is_empty():
		equipment_card_controls[slot_key] = {"panel":card}
		equipment_card_controls[slot_key].title = equipment_card_label(card,"%s · Lv.%s" % [NAMES[key],number(lv)],Rect2(54 if SLOT_TEXTURES.has(key) else 12,8,130 if SLOT_TEXTURES.has(key) else 172,26),15)
		equipment_card_label(card,"已装配 · 换舰时可调整",Rect2(12,72,216 if defence else 144,20),11,MUTED)
	if key.is_empty():
		equipment_card_label(card,"空置槽位",Rect2(12,10,216,26),16)
		equipment_card_label(card,"选择右侧装备即可安装",Rect2(12,42,216,22),13,MUTED)
		equipment_card_label(card,"安装后仅可在换舰时调整",Rect2(12,76,216,20),11,MUTED)
		return
	var socket_action := button("镶嵌",Rect2(190,8,50,26),func():jewel_panel.open(category,slot_index))
	socket_action.reparent(card,false)
	socket_action.add_theme_font_size_override("font_size",11)
	socket_action.visible = game.jewels_unlocked()
	equipment_card_controls[slot_key].socket = socket_action
	var cd := float(db.equip(key,lv).get("cd",0))
	if not defence and cd > 0:
		equipment_card_label(card,"CD %s秒" % number(cd),Rect2(160,72,68,20),11,CYAN)
	equipment_card_controls[slot_key].stat = equipment_card_label(card,("容量" if defence else "伤害")+" %s" % number(game.equipment_stat(key,lv))+(" → %s" % number(game.equipment_stat(key,int(next.level))) if not maxed else " · 满级"),Rect2(12,42,216,24),14,CYAN)
	var single_cost := game.slot_upgrade_cost("defence" if defence else "weapons",slot_index)
	var ten_cost := game.slot_upgrade_cost("defence" if defence else "weapons",slot_index,10)
	equipment_card_controls[slot_key].cost = equipment_card_label(card,"已达最高等级" if maxed else "单次：%s" % cost_text(single_cost),Rect2(248,36,180,26),12,MUTED)
	var upgrade := button("已满级" if maxed else "升级",Rect2(248,70,56,32),func():game.upgrade_slot("defence" if defence else "weapons",slot_index),true,not game.can_upgrade_slot("defence" if defence else "weapons",slot_index))
	upgrade.tooltip_text = "已达最高等级" if maxed else "升1级，消耗："+cost_text(single_cost)
	upgrade.reparent(card,false)
	upgrade.add_theme_font_size_override("font_size",12)
	upgrade.set_meta("slot",slot_key)
	upgrade_buttons[key if not upgrade_buttons.has(key) else slot_key] = upgrade
	if bulk:
		var ten := button("10连",Rect2(310,70,56,32),func():game.upgrade_slot("defence" if defence else "weapons",slot_index,10),false,not game.can_upgrade_slot("defence" if defence else "weapons",slot_index,10))
		ten.reparent(card,false)
		ten.add_theme_font_size_override("font_size",12)
		ten.set_meta("slot",slot_key)
		ten.tooltip_text = "一次升10级，总消耗：" + cost_text(ten_cost)
		ten_upgrade_buttons[key if not ten_upgrade_buttons.has(key) else slot_key] = ten
		var max_button := button("MAX",Rect2(372,70,56,32),func():
			var amount := game.max_upgrade_amount_slot(category,slot_index)
			if amount > 0:
				game.upgrade_slot(category,slot_index,amount),false,not game.can_upgrade_slot(category,slot_index))
		max_button.reparent(card,false)
		max_button.add_theme_font_size_override("font_size",12)
		max_button.set_meta("slot",slot_key)
		max_button.tooltip_text = "按当前资源升级至可负担的最高等级"
		max_upgrade_buttons[key if not max_upgrade_buttons.has(key) else slot_key] = max_button
	if not defence:
		var cooldown := ColorRect.new()
		cooldown.position = Vector2(12,98)
		cooldown.size = Vector2(216,4)
		cooldown.color = LINE
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cooldown)
		var fill := ColorRect.new()
		fill.size = Vector2(216,4)
		fill.color = CYAN
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.add_child(fill)
		equipment_cooldowns[slot_key] = fill
	var tech := BattleGame.DENSE_ARMOUR if defence else BattleGame.ENERGY_FOCUS
	ui_state_changed(equipment_card_controls[slot_key].title,[lv,game.hightech_level(tech),game.charge_multiplier("防御充能" if defence else "攻击充能")])
	for action in card.get_children():
		if action is Button and action.has_meta("slot"):
			ui_state_changed(action,[lv,game.profile.resources])
			action.set_meta("display_level",lv)

func refresh_equipment_cards(only_slot := "") -> void:
	# Upgrades change values, not the control tree or selected/scrolling pages.
	for slot in equipment_card_controls:
		if not only_slot.is_empty() and slot != only_slot:
			continue
		var category := str(slot).get_slice("_",0)
		var index := int(str(slot).get_slice("_",1))
		var entry := game.slot_entry(category,index)
		var key := str(entry.key)
		var level := int(entry.level)
		var maxed := level >= db.max_equipment_level(key)
		var controls: Dictionary = equipment_card_controls[slot]
		var tech := BattleGame.DENSE_ARMOUR if category == "defence" else BattleGame.ENERGY_FOCUS
		var effect := game.charge_multiplier("防御充能" if category == "defence" else "攻击充能")
		set_ui_value(controls.socket,"visible",game.jewels_unlocked())
		if not ui_state_changed(controls.title,[level,game.hightech_level(tech),effect,game.jewel_equipment_stat(entry),entry.get("sockets",[])]):
			continue
		set_ui_value(controls.title,"text","%s · Lv.%s" % [NAMES[key],number(level)])
		set_ui_value(controls.stat,"text",("容量" if category == "defence" else "伤害")+" %s" % number(game.jewel_equipment_stat(entry))+(" → %s" % number(game.jewel_equipment_stat(entry,level+1)) if not maxed else " · 满级"))
		set_ui_value(controls.cost,"text","已达最高等级" if maxed else "单次：%s" % cost_text(game.slot_upgrade_cost(category,index)))
		for label in [controls.title,controls.stat,controls.cost]:
			set_ui_value(label,"tooltip_text",label.text)
	for buttons in [upgrade_buttons,ten_upgrade_buttons,max_upgrade_buttons]:
		for button_key in buttons:
			var action: Button = buttons[button_key]
			var slot := str(action.get_meta("slot"))
			if not only_slot.is_empty() and slot != only_slot:
				continue
			var category := slot.get_slice("_",0)
			var index := int(slot.get_slice("_",1))
			var amount := 10 if buttons == ten_upgrade_buttons else 1
			if not ui_state_changed(action,[game.slot_entry(category,index).level,game.profile.resources]):
				continue
			set_ui_value(action,"disabled",not game.can_upgrade_slot(category,index,amount))
			var entry := game.slot_entry(category,index)
			if action.get_meta("display_level",-1) == int(entry.level):
				continue
			action.set_meta("display_level",int(entry.level))
			if buttons != max_upgrade_buttons:
				set_ui_value(action,"tooltip_text",("一次升10级，总消耗：" if amount == 10 else "升1级，消耗：") + cost_text(game.slot_upgrade_cost(category,index,amount)))
			if buttons == upgrade_buttons:
				set_ui_value(action,"text","已满级" if int(entry.level) >= db.max_equipment_level(str(entry.key)) else "升级")

func unlocked_ship_keys() -> Array:
	var result: Array = []
	for key in db.ships:
		if game.ship_unlocked(str(key)):
			result.append(str(key))
	return result

func candidate_equipment_count(key: String, except_category: String, except_index: int) -> int:
	var count := 0
	for category in ["weapons", "defence"]:
		for index in range(ship_candidate_loadout.get(category, []).size()):
			if category == except_category and index == except_index:
				continue
			if str(ship_candidate_loadout[category][index].get("key", "")) == key:
				count += 1
	return count

func build_ship_tab() -> void:
	var page := Control.new()
	page.name = "战舰"
	equipment_tabs.add_child(page)
	ship_controls = {"page":page,"selectors":{},"notes":{}}
	page.set_meta("runtime_loadout",game.profile.loadout.duplicate(true))
	var keys := unlocked_ship_keys()
	var current := str(game.profile.selectedShip)
	if ship_candidate.is_empty() or not keys.has(ship_candidate):
		ship_candidate = current
		ship_candidate_loadout = game.profile.loadout.duplicate(true)
	elif ship_candidate == current:
		ship_candidate_loadout = game.profile.loadout.duplicate(true)
	if not ship_candidate_loadout.has("weapons") or not ship_candidate_loadout.has("defence"):
		ship_candidate_loadout = game.empty_loadout(ship_candidate)

	var picker := OptionButton.new()
	picker.position = Vector2(12,8)
	picker.size = Vector2(220,30)
	picker.add_theme_font_override("font",font)
	picker.add_theme_font_size_override("font_size",13)
	for key in keys:
		var row: Dictionary = db.ship(key)
		picker.add_item(str(row.des),picker.item_count)
		picker.set_item_metadata(picker.item_count-1,key)
		picker.set_item_tooltip(picker.item_count-1,"武器槽 %s · 防御槽 %s · 移动 %s" % [number(row.weaponSlots),number(row.defenseSlots),number(row.movement)])
		if key == ship_candidate:
			picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index):
		ship_candidate = str(picker.get_item_metadata(index))
		ship_candidate_loadout = game.profile.loadout.duplicate(true) if ship_candidate == str(game.profile.selectedShip) else game.empty_loadout(ship_candidate)
		rebuild_ship_slots()
		refresh_ship_controls()
	)
	page.add_child(picker)

	var valid := game.valid_loadout(ship_candidate,ship_candidate_loadout)
	var status := equipment_label(page,"当前：%s · 空槽可保留，装备需在此页签选定" % game.ship_name(),Vector2(248,14),12,MUTED)
	if ship_candidate != current:
		status.text = "%s · 新舰装备等级从 Lv.1 开始" % ("配置有效" if valid else "请检查装备数量/解锁状态")
	var confirm := button("确认更换",Rect2(1250,8,118,30),func():
		if game.switch_ship(ship_candidate,ship_candidate_loadout):
			ship_candidate = str(game.profile.selectedShip)
			ship_candidate_loadout = game.profile.loadout.duplicate(true)
			refresh_structure()
			refresh_ship_controls()
	,true,ship_candidate == current or not valid)
	confirm.reparent(page,false)
	confirm.add_theme_font_size_override("font_size",13)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10,45)
	scroll.size = Vector2(1358,93)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	scroll.add_child(cards)
	ship_controls.picker = picker
	ship_controls.status = status
	ship_controls.confirm = confirm
	ship_controls.cards = cards
	rebuild_ship_slots()
	refresh_ship_controls()

func rebuild_ship_slots() -> void:
	var cards: HBoxContainer = ship_controls.cards
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	ship_controls.selectors.clear()
	ship_controls.notes.clear()
	for category in ["weapons", "defence"]:
		var entries: Array = ship_candidate_loadout[category]
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var card := Panel.new()
			card.custom_minimum_size = Vector2(184,78)
			card.add_theme_stylebox_override("panel",style(PANEL,LINE))
			cards.add_child(card)
			equipment_label(card,"%s槽 %s" % ["武器" if category == "weapons" else "防御",number(index+1)],Vector2(8,6),12,CYAN)
			var selector := OptionButton.new()
			selector.position = Vector2(8,30)
			selector.size = Vector2(168,27)
			selector.add_theme_font_override("font",font)
			selector.add_theme_font_size_override("font_size",12)
			selector.add_item("空槽")
			for option_key in (EQUIPMENT_PAGES[0].keys if category == "weapons" else EQUIPMENT_PAGES[1].keys):
				if game.profile.unlocked.has(option_key):
					selector.add_item(NAMES[option_key])
					selector.set_item_metadata(selector.item_count-1,option_key)
					selector.set_item_disabled(selector.item_count-1,candidate_equipment_count(option_key,category,index) >= int(db.ship(ship_candidate).get("sameEquipmentLimit",1)))
					if option_key == str(entry.get("key", "")):
						selector.select(selector.item_count-1)
			selector.item_selected.connect(func(option):
				var selected := str(selector.get_item_metadata(option)) if option > 0 else ""
				ship_candidate_loadout[category][index] = {"key":selected,"level":1}
				refresh_ship_controls()
			)
			card.add_child(selector)
			ship_controls.selectors[game.slot_id(category,index)] = selector
			ship_controls.notes[game.slot_id(category,index)] = equipment_label(card,"更换时配置 · Lv.1" if not str(entry.get("key", "")).is_empty() else "可保留为空",Vector2(8,59),11,MUTED)

func refresh_scientists() -> void:
	if not is_instance_valid(scientist_generate_button):
		return
	if not ui_state_changed(scientist_summary,[game.profile.scientists,game.profile.scientistAssignments,game.profile.resources,hightech_buttons.keys()]):
		return
	set_ui_value(scientist_summary,"text","科学家 %s人 · 空闲 %s人" % [number(game.profile.scientists),number(game.idle_scientists())])
	var costs: Array[String] = []
	for id in game.scientist_cost():
		costs.append("%s %s" % [db.data.resources[id],number(game.scientist_cost()[id])])
	set_ui_value(scientist_generate_button,"text","生成 ×1")
	set_ui_value(scientist_generate_button,"tooltip_text"," / ".join(costs))
	set_ui_value(scientist_cost_label,"text","单个消耗：" + " / ".join(costs))
	set_ui_value(scientist_cost_label,"tooltip_text",scientist_cost_label.text)
	set_ui_value(scientist_distribute_button,"disabled",int(game.profile.scientists)<=0 or game.hightech_slots().all(func(key):return str(key).is_empty()))
	for amount in scientist_bulk_buttons:
		set_ui_value(scientist_bulk_buttons[amount],"disabled",not game.can_generate_scientist(amount))
	for key in scientist_assignment_buttons:
		set_ui_value(hightech_buttons[key],"disabled",not game.can_research(key))
		for action in scientist_assignment_buttons[key]:
			set_ui_value(action,"disabled",not game.can_research(key))
	set_ui_value(scientist_generate_button,"disabled",not game.can_generate_scientist())
	for key in scientist_remove_buttons:
		set_ui_value(scientist_remove_buttons[key],"disabled",game.assigned_scientists(key)<=0)

func refresh_hightech_progress(key: String) -> void:
	var controls: Dictionary = hightech_progress[key]
	if not ui_state_changed(controls.label,[game.assigned_scientists(key),game.hightech_level(key),game.profile.techPoints.get(key,0),game.paused]):
		return
	var required := game.hightech_required(key)
	var points := float(game.profile.techPoints.get(key,0))
	var fraction := clampf(points/required,0,1)
	set_ui_value(controls.label,"text","%s人 · %s点/秒 · %s/%s点 · %.0f%%" % [number(game.assigned_scientists(key)),number(game.research_rate(key)),number(points),number(required),floorf(fraction*100)])
	set_ui_value(controls.bar.get_child(0),"size",Vector2(controls.bar.size.x*fraction,controls.bar.get_child(0).size.y))
	set_ui_value(controls.bar.get_child(0),"color",CYAN if game.research_rate(key)>0 and not game.paused else ORANGE)

func build_charge_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "充能"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	equipment_tabs.add_child(scroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	scroll.add_child(cards)
	for key in db.data.get("charge",{}):
		var card := Panel.new()
		card.custom_minimum_size = HIGHTECH_CARD_SIZE
		card.add_theme_stylebox_override("panel",style(PANEL,LINE))
		cards.add_child(card)
		var title := equipment_label(card,"",Vector2(12,5),14,CYAN)
		var status := equipment_label(card,"",Vector2(327,7),11,MUTED)
		status.size.x = 104
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var description := equipment_label(card,"",Vector2(12,27),12,MUTED)
		description.size.x = 419
		description.clip_text = true
		var progress := equipment_label(card,"",Vector2(12,48),11,INK)
		var charge_bar := charge_progress_bar(card,Vector2(12,67),303,CYAN)
		var level_progress := equipment_label(card,"",Vector2(12,78),11,MUTED)
		var level_bar := charge_progress_bar(card,Vector2(12,97),303,Color("aa96ed"))
		var cost := equipment_label(card,"",Vector2(333,48),11,MUTED)
		cost.size.x = 98
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.clip_text = true
		var action := button("",Rect2(331,75,100,28),func():
			game.toggle_charge(key)
			refresh_charge_card(key),true)
		action.reparent(card,false)
		action.add_theme_font_size_override("font_size",14)
		charge_cards[key] = {"title":title,"status":status,"description":description,"progress":progress,"charge_bar":charge_bar,"level_progress":level_progress,"level_bar":level_bar,"cost":cost,"button":action}
		refresh_charge_card(key)

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
	var controls: Dictionary = charge_cards[key]
	var row: Dictionary = db.data.charge[key]
	var job := game.charge_job(key)
	if not ui_state_changed(controls.title,[job,game.charge_unlocked(key),game.profile.resources.get(str(int(row.para_1)),0),row]):
		return
	set_ui_value(controls.title,"text","%s Lv.%s" % [key,number(job.level)])
	set_ui_value(controls.description,"text",game.charge_description(key))
	set_ui_value(controls.description,"tooltip_text",controls.description.text)
	var fraction := clampf(float(job.elapsed)/float(row.para_4),0,1)
	set_ui_value(controls.progress,"text","本次充能  %s/%s秒" % [number(job.elapsed),number(row.para_4)])
	set_ui_value(controls.charge_bar.get_child(0),"size",Vector2(controls.charge_bar.size.x * fraction,controls.charge_bar.get_child(0).size.y))
	set_ui_value(controls.level_progress,"text","升级进度  %s/%s次" % [number(job.count),number(game.charge_required(key))])
	set_ui_value(controls.level_bar.get_child(0),"size",Vector2(controls.level_bar.size.x * clampf((float(job.count)+fraction)/game.charge_required(key),0,1),controls.level_bar.get_child(0).size.y))
	set_ui_value(controls.cost,"text","%s %s/秒" % [db.data.resources[str(int(row.para_1))],number(game.charge_resource_rate(key))])
	set_ui_value(controls.cost,"tooltip_text",controls.cost.text)
	var unlocked := game.charge_unlocked(key)
	set_ui_value(controls.button,"disabled",not unlocked)
	if not unlocked:
		set_ui_value(controls.status,"text","未解锁")
		set_ui_value(controls.button,"text","第%s关解锁" % number(row.unlock))
	elif job.active:
		set_ui_value(controls.status,"text","资源不足" if game.charge_resource_rate(key) > 0 and float(game.profile.resources.get(str(int(row.para_1)),0)) <= 0 and float(job.credit) <= 0 else "充能中")
		set_ui_value(controls.button,"text","暂停")
	else:
		var started := int(job.started) > 0
		set_ui_value(controls.status,"text","已暂停" if started else "未启动")
		set_ui_value(controls.button,"text","继续充能" if started else "启动充能")
	var status_color := CYAN if controls.status.text=="充能中" else Color("ffc178") if controls.status.text=="资源不足" else MUTED
	if controls.status.get_theme_color("font_color") != status_color:
		controls.status.add_theme_color_override("font_color",status_color)

func confirm_unequip(category: String, index: int) -> void:
	var entry := game.slot_entry(category,index).duplicate()
	if entry.is_empty() or str(entry.key).is_empty():
		return
	var ship_key := str(game.profile.selectedShip)
	var dialog := ConfirmationDialog.new()
	dialog.title = "确认卸下装备"
	dialog.dialog_text = "卸下 %s（Lv.%d）？\n返还该装备全部升级资源，槽位将留空。\n重新装备后为1级。" % [NAMES[str(entry.key)],int(entry.level)]
	dialog.ok_button_text = "确认卸下"
	dialog.cancel_button_text = "保留装备"
	add_child(dialog)
	dialog.confirmed.connect(func():
		if str(game.profile.selectedShip) == ship_key and game.slot_entry(category,index) == entry:
			if game.unequip_slot(category,index):
				refresh_structure()
		dialog.queue_free())
	dialog.canceled.connect(func():dialog.queue_free())
	dialog.popup_centered()

func build_hightech_tab() -> void:
	var scroll := ScrollContainer.new()
	hightech_scroll = scroll
	scroll.name = "高科技"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	equipment_tabs.add_child(scroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	scroll.add_child(cards)
	var manager := Panel.new()
	manager.custom_minimum_size = Vector2(330,112)
	manager.add_theme_stylebox_override("panel",style(PANEL,LINE))
	cards.add_child(manager)
	scientist_summary = equipment_label(manager,"",Vector2(10,8),14,CYAN)
	scientist_distribute_button = button("平均分配全部",Rect2(10,30,310,24),func():game.distribute_scientists(),true)
	scientist_distribute_button.reparent(manager,false)
	scientist_distribute_button.add_theme_font_size_override("font_size",12)
	scientist_distribute_button.size.y = 24
	scientist_distribute_button.tooltip_text = "重新均分到已解锁高科技，余数按卡片顺序分配"
	scientist_cost_label = equipment_label(manager,"",Vector2(10,56),12,CYAN)
	scientist_generate_button = button("",Rect2(10,77,100,29),func():game.generate_scientist(),true)
	scientist_generate_button.reparent(manager,false)
	scientist_generate_button.add_theme_font_size_override("font_size",12)
	for amount in [10,-1]:
		var action := button("生成 ×10" if amount==10 else "生成 MAX",Rect2(115 if amount==10 else 220,77,100,29),func():game.generate_scientist(amount),true)
		action.reparent(manager,false)
		action.add_theme_font_size_override("font_size",12)
		scientist_bulk_buttons[amount]=action
	refresh_scientists()
	hightech_container = cards
	var slots := game.hightech_slots()
	for index in range(slots.size()):
		build_hightech_card(index,str(slots[index]))
	scroll.set_deferred("scroll_horizontal",hightech_scroll_offset)

func build_hightech_card(index: int, key: String) -> void:
	var cards := hightech_container
	var card := Panel.new()
	card.set_script(HIGHTECH_SLOT_SCRIPT)
	card.slot_index = index
	card.tech_key = key
	card.swap_requested.connect(func(source,target):
		if game.swap_hightech_slots(source,target):
			call_deferred("sync_hightech_slots"))
	card.custom_minimum_size = HIGHTECH_CARD_SIZE
	card.add_theme_stylebox_override("panel",style(PANEL,LINE))
	card.add_theme_font_override("font",font)
	cards.add_child(card)
	if key.is_empty():
		card.add_theme_stylebox_override("panel",style(BG,LINE))
		equipment_label(card,"空卡槽 %02d" % (index+1),Vector2(16,30),14,MUTED)
		equipment_label(card,"可将高科技卡片拖到这里",Vector2(16,57),12,MUTED)
		return
	var row: Dictionary = db.data.hightech[key]
	card.tooltip_text = "拖动标题到其他卡槽，松手交换位置并保存"
	hightech_titles[key] = equipment_label(card,"%s Lv.%s" % [key,number(game.hightech_level(key))],Vector2(10,5),14,CYAN)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = game.hightech_description(key)
	description.tooltip_text = description.text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	description.position = Vector2(10,29)
	description.size = Vector2(423,24)
	description.add_theme_font_override("font",font)
	description.add_theme_font_size_override("font_size",12)
	description.add_theme_color_override("font_color",MUTED)
	card.add_child(description)
	hightech_descriptions[key] = description
	var progress_text := equipment_label(card,"",Vector2(10,77),11,INK)
	var progress_bar := charge_progress_bar(card,Vector2(10,99),303,CYAN)
	hightech_progress[key] = {"label":progress_text,"bar":progress_bar}
	refresh_hightech_progress(key)
	var b := button("+1",Rect2(387,77,46,29),func():game.assign_scientist(key,1),true,not game.can_research(key))
	b.reparent(card,false)
	b.add_theme_font_size_override("font_size",12)
	b.set_drag_forwarding(Callable(),card._can_drop_data,card._drop_data)
	hightech_buttons[key] = b
	var remove := button("−1",Rect2(331,77,46,29),func():game.assign_scientist(key,-1),true,game.assigned_scientists(key)<=0)
	remove.reparent(card,false)
	remove.set_drag_forwarding(Callable(),card._can_drop_data,card._drop_data)
	scientist_remove_buttons[key] = remove
	scientist_assignment_buttons[key]=[]
	for amount in [10,-1]:
		var action := button("+10" if amount==10 else "MAX",Rect2(331 if amount==10 else 387,46,46,27),func():game.assign_scientist(key,10 if amount==10 else game.idle_scientists()),true,not game.can_research(key))
		action.reparent(card,false)
		action.add_theme_font_size_override("font_size",11)
		action.set_drag_forwarding(Callable(),card._can_drop_data,card._drop_data)
		scientist_assignment_buttons[key].append(action)
	equipment_label(card,"⠿ 拖动换位",Vector2(350,5),12,MUTED)

func draw_unlock() -> void:
	draw_surface.draw_rect(Rect2(0,78,1440,732),Color(0.02,0.04,0.08,0.93))
	box(Rect2(400,240,640,370),Color("142638"),CYAN)
	text_at("新装备已解锁",Vector2(457,303),32,CYAN)
	var line_y := 361
	for key in game.pending_unlocks:
		text_at(NAMES[key],Vector2(457,line_y),24,INK)
		line_y += 42
	text_at("装备已自动装载，可在下方直接升级。",Vector2(457,476),18,MUTED)
	text_at("点击继续后恢复自动前进。",Vector2(457,509),15,MUTED)
