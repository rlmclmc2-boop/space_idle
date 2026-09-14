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
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
var db: ShipDatabase
var game: BattleGame
var font: SystemFont
var ui: Control
var stars: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var clock := 0.0
var star_travel := 0.0
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
var hightech_buttons: Dictionary = {}
var hightech_descriptions: Dictionary = {}
const HIGHTECH_SLOT_SCRIPT := preload("res://scripts/hightech_slot.gd")
const HIGHTECH_CARD_SIZE := Vector2(443,112)
var hightech_scroll: ScrollContainer
var hightech_scroll_offset := 0
var ui_rebuild_pending := false
var automation_args := OS.get_cmdline_user_args()
var capture_frame := 0

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	db = ShipDatabase.new()
	game = BattleGame.new(db, not automation_args.has("--capture"))
	game.event.connect(on_event)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	for i in range(200):
		stars.append({"x":randf()*1440,"y":randf()*810,"z":randf_range(0.2,1.0)})
	audio = AudioStreamPlayer.new()
	audio.volume_db = -25
	add_child(audio)
	game.start(int(game.profile.loopLevel) if game.profile.loop else int(game.profile.highestLevel), bool(game.profile.loop))
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
		star_travel += dt * (-250.0*game.speed if game.state == BattleGame.State.RETREAT else float(db.config.movement)*game.speed if game.state == BattleGame.State.TRAVEL else 2.0)
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
	if is_instance_valid(loop_button):
		loop_button.text = "⟳  循环：" + ("开启" if game.profile.loop else "关闭")
	for key in upgrade_buttons:
		var b: Button = upgrade_buttons[key]
		if is_instance_valid(b):
			b.disabled = not game.can_upgrade(key)
	for key in ten_upgrade_buttons:
		var b: Button = ten_upgrade_buttons[key]
		if is_instance_valid(b):
			b.disabled = not game.can_upgrade_amount(key,10)
	for key in max_upgrade_buttons:
		var b: Button = max_upgrade_buttons[key]
		if is_instance_valid(b):
			b.disabled = game.max_upgrade_amount(key) <= 0
	for key in equipment_cooldowns:
		var cd := float(db.equip(key,int(game.profile.levels[key])).cd)
		equipment_cooldowns[key].size.x = 196*clampf(1.0-float(game.cooldowns.get(key,0))/maxf(cd,0.001),0,1)
	for key in hightech_buttons:
		var b: Button = hightech_buttons[key]
		b.disabled = not game.can_research(key)
		b.text = hightech_button_text(key)
	for key in hightech_descriptions:
		hightech_descriptions[key].text = game.hightech_description(key)
		hightech_descriptions[key].tooltip_text = hightech_descriptions[key].text
	if is_instance_valid(hightech_scroll) and hightech_scroll.is_visible_in_tree() and get_viewport().gui_is_dragging():
		var mouse := hightech_scroll.get_local_mouse_position()
		if mouse.y >= 0 and mouse.y <= hightech_scroll.size.y:
			if mouse.x >= hightech_scroll.size.x-36 and mouse.x <= hightech_scroll.size.x:
				hightech_scroll.scroll_horizontal += int(600*delta)+1
			elif mouse.x >= 0 and mouse.x < 36:
				hightech_scroll.scroll_horizontal -= int(600*delta)+1
	queue_redraw()
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
				build_ui()
			else:
				game.paused = not game.paused

func on_event(kind: String, info: Dictionary) -> void:
	match kind:
		"state":
			call_deferred("build_ui")
		"hit":
			var color := ORANGE if info.player else (CYAN if info.type == 1 else ORANGE)
			floats.append({"pos":Vector2(info.x,info.y-36),"text":"−%s" % number(info.amount),"color":color,"life":0.9})
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
			build_ui()
		"research", "hightech_complete":
			toast(str(info.key) + ("研发完成" if kind == "hightech_complete" else "开始研发"))
			call_deferred("build_ui")
		"unlock":
			help_open = false
			call_deferred("build_ui")
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
	queue_redraw()

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

func build_ui() -> void:
	# Combat and research events must not remove a card while it is being dragged.
	if get_viewport().gui_is_dragging():
		ui_rebuild_pending = true
		return
	if is_instance_valid(hightech_scroll):
		hightech_scroll_offset = hightech_scroll.scroll_horizontal
	hightech_scroll = null
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	loop_button = null
	upgrade_buttons.clear()
	ten_upgrade_buttons.clear()
	max_upgrade_buttons.clear()
	equipment_cooldowns.clear()
	hightech_buttons.clear()
	hightech_descriptions.clear()
	if not game.pending_unlocks.is_empty():
		button("继续", Rect2(600,535,240,48),func():game.acknowledge_unlocks(),true)
		return
	button("?  操作指南",Rect2(1262,25,140,38),func():help_open=not help_open;build_ui())
	resource_mode_button = button("资源：每秒" if resource_rate_mode else "资源：总量",Rect2(664,25,156,38),toggle_resource_display)
	resource_mode_button.tooltip_text = "切换总量 / 最近60秒实际拾取量÷60（现实时间）"
	if help_open:
		button("知道了",Rect2(600,626,240,44),func():help_open=false;build_ui(),true)
		return
	loop_select = OptionButton.new()
	loop_select.position = Vector2(1010,92)
	loop_select.size = Vector2(190,38)
	loop_select.add_item("选择循环关卡", 0)
	for level in range(1, db.levels.size()+1):
		if game.profile.cleared.has(level):
			loop_select.add_item("第 %s 关" % number(level), level)
			if level == int(game.profile.get("loopLevel", 0)):
				loop_select.select(loop_select.item_count-1)
	loop_select.set_item_disabled(0, true)
	loop_select.item_selected.connect(func(index):game.select_loop_level(loop_select.get_item_id(index));build_ui())
	ui.add_child(loop_select)
	loop_button = button("⟳  循环：" + ("开启" if game.profile.loop else "关闭"),Rect2(1210,92,192,38),func():game.toggle_loop();build_ui(),false,int(game.profile.get("loopLevel", 0))==0)
	build_equipment_tabs()
	button("音效：" + ("开" if sound_on else "关"),Rect2(1262,778,140,26),func():sound_on=not sound_on;build_ui())

func text_at(value: String, pos: Vector2, size := 16, color := INK) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func box(rect: Rect2, color := PANEL, border := LINE) -> void:
	draw_style_box(style(color,border),rect)

func bar(rect: Rect2, percent: float, color: Color) -> void:
	draw_rect(rect,Color("243144"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(percent,0,1),rect.size.y)),color)

func _draw() -> void:
	if game == null:
		return
	draw_rect(Rect2(0,0,1440,810),BG)
	# Layered translucent disks produce a soft procedural nebula without assets.
	for j in range(22,0,-1):
		draw_circle(Vector2(1020,345),float(j)*18,Color(0.12,0.23,0.38,0.012))
		draw_circle(Vector2(625,530),float(j)*13,Color(0.21,0.12,0.34,0.008))
	for s in stars:
		var x := fposmod(float(s.x)-star_travel*float(s.z)*4,1440)
		var a := 0.2+float(s.z)*0.5
		draw_circle(Vector2(x,s.y),float(s.z)*1.35,Color(0.7,0.83,1,a))
		if game.state == BattleGame.State.TRAVEL and not game.paused:
			draw_line(Vector2(x,s.y),Vector2(x+float(s.z)*9*game.speed,s.y),Color(0.5,0.8,1,a*0.3))
	draw_line(Vector2(38,76),Vector2(1402,76),LINE)
	text_at("◈",Vector2(39,52),30,CYAN)
	text_at("太空战舰",Vector2(83,49),22)
	text_at("DEEP SPACE / EXPEDITION",Vector2(210,47),12,MUTED)
	text_at(str(db.data.resources["1"]),Vector2(850,34),11,MUTED)
	text_at(resource_display("1"),Vector2(850,58),22,INK)
	text_at(str(db.data.resources["2"]),Vector2(1040,34),11,MUTED)
	text_at(resource_display("2"),Vector2(1040,58),22,PURPLE)
	draw_battle()
	if message_time > 0 and not help_open and game.pending_unlocks.is_empty():
		box(Rect2(470,91,465,38),Color("132637"),Color("315468"))
		text_at(message,Vector2(490,117),15,CYAN)
	text_at("原型 0.2    /    本地自动保存",Vector2(40,795),11,MUTED)
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
		draw_circle(Vector2(xx,156),4,CYAN if game.group_index>j else LINE)
	text_at("后退中 / RETREAT" if game.state==BattleGame.State.RETREAT else "自动交战 / AUTO ENGAGE" if game.state==BattleGame.State.COMBAT else "自动巡航 / CRUISING",Vector2(40,197),12,CYAN)
	text_at("遭遇 %s / %s" % [number(game.group_index),number(9)],Vector2(1266,197),13,MUTED)
	var offset := Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
	for slot in range(10):
		text_at("%02d" % slot,Vector2(1370,202+slot*44),10,Color("34475c"))
		draw_line(Vector2(1330,198+slot*44),Vector2(1353,198+slot*44),Color("253345"))
	if game.player.armour>0 or game.state==BattleGame.State.RETREAT:
		draw_ship(Vector2(game.player.x,game.player.y)+offset,1.15,false,1,game.player.shield>0)
		text_at("先锋号",Vector2(246,489),16,INK)
		text_at("VANGUARD / 01",Vector2(215,515),11,MUTED)
	for enemy in game.enemies:
		if enemy.hp <= 0:
			continue
		var pos := Vector2(enemy.x,enemy.y)+offset
		draw_ship(pos,1.4 if enemy.boss else 0.53,true,int(enemy.armourType),false)
		var w := 155.0 if enemy.boss else 78.0
		bar(Rect2(pos.x-w/2,pos.y-(58 if enemy.boss else 27),w,4),float(enemy.hp)/float(enemy.max_hp),ORANGE if int(enemy.armourType)==2 else CYAN)
		if not boss_battle:
			text_at("%s / %s" % [enemy_health(float(enemy.hp)),enemy_health(float(enemy.max_hp))],Vector2(pos.x+65,pos.y+4),12,INK)
		else:
			box(Rect2(pos + Vector2(-20, -10), Vector2(40, 20)), PANEL, LINE)
			text_at("#%02d" % (int(enemy.slot)+1),pos+Vector2(-15,5),12,INK)
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
		draw_set_transform(pos, direction.angle())
		draw_texture_rect(PROJECTILE_TEXTURES[key],Rect2(-size/2,size),false)
		draw_set_transform(Vector2.ZERO)
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
			draw_line(pos+Vector2(22,0),pos+Vector2(62,0),Color(color,0.25),2)
		elif not furnace:
			draw_arc(pos,24,-PI/2,-PI/2+TAU*clampf(1.0-float(drop.age)/float(db.defaults.autoCollectDelay),0,1),24,Color(color,0.35),2)
		else:
			draw_arc(pos,24,-PI/2,-PI/2+TAU*clampf(1.0-float(drop.age)/10.0,0,1),24,Color(color,0.35),2)
		text_at("⬡" if drop.id=="1" else "◇",pos+Vector2(-10,7+bob),26,color)
		text_at("%s %s" % [number(drop.amount),db.data.resources[drop.id]],pos+Vector2(-19,41),12,color)
	for p in particles:
		draw_circle(p.pos,float(p.size),Color(p.color,clampf(float(p.life)*2,0,1)))
	for f in floats:
		text_at(f.text,f.pos,18,Color(f.color,clampf(float(f.life)*2,0,1)))
	draw_rect(Rect2(0,615,1440,195),Color("0c1522"))
	draw_line(Vector2(38,615),Vector2(1402,615),LINE)
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
		text_at("%s 秒后%s第 %s 关" % [number(maxf(0,game.clear_timer)),"重刷" if target==game.stage else "进入",number(target)],Vector2(458,352),17,INK)
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
	draw_set_transform(pos,PI if hostile else 0.0,Vector2.ONE*scale_value)
	var accent := ORANGE if hostile and type==2 else Color("bf9cf2") if hostile else CYAN
	var body := Color("5e5264") if hostile else Color("698698")
	if shield:
		for r in range(3):
			draw_arc(Vector2.ZERO,97+r*3,-1.5,1.5,48,Color(CYAN,0.15-float(r)*0.04),2)
	var flame := 37.0+sin(clock*24)*7
	draw_colored_polygon(PackedVector2Array([Vector2(-70,-12),Vector2(-70-flame,0),Vector2(-70,12)]),Color(accent,0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(-65,-5),Vector2(-86-sin(clock*30)*5,0),Vector2(-65,5)]),accent)
	var hull := PackedVector2Array([Vector2(91,0),Vector2(25,-19),Vector2(-5,-39),Vector2(-51,-45),Vector2(-35,-17),Vector2(-70,-14),Vector2(-64,0),Vector2(-70,14),Vector2(-35,17),Vector2(-51,45),Vector2(-5,39),Vector2(25,19)])
	draw_colored_polygon(hull,body)
	draw_polyline(hull+PackedVector2Array([hull[0]]),Color("a7c7d6") if not hostile else Color("b592a6"),1.1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(91,0),Vector2(-49,-5),Vector2(-60,0),Vector2(-49,5)]),Color("d0dde0") if not hostile else Color("a99ba5"))
	draw_colored_polygon(PackedVector2Array([Vector2(40,-4),Vector2(17,-14),Vector2(-3,-14),Vector2(2,-5)]),accent)
	draw_line(Vector2(-32,-30),Vector2(3,-23),accent,3,true)
	draw_line(Vector2(-32,30),Vector2(3,23),accent,3,true)
	draw_rect(Rect2(-18,-5,33,10),Color("293b4c"))
	draw_rect(Rect2(-70,-11,7,22),accent)
	draw_set_transform(Vector2.ZERO)

func draw_help() -> void:
	draw_rect(Rect2(0,78,1440,696),Color(0.02,0.04,0.08,0.97))
	box(Rect2(310,143,820,551))
	text_at("操作指南",Vector2(360,203),30,CYAN)
	var lines := ["01   战舰自动前进、锁定并攻击敌人。", "02   点击下方装备的升级按钮，立即强化对应装备。", "03   生命归零后按配置距离后退，恢复生命后自动继续。", "04   未解锁装备不显示；获得新装备时会弹窗通知。", "05   选择已通关关卡并开启循环，持续重刷指定关卡。", "06   鼠标悬停残骸获得全额资源，超时自动拾取有损耗。", "空格 / Esc：暂停或继续；QA 工具可切换 ×1 / ×2 / ×5", "升级武器不会恢复生命；升级防御装备仅增加提升的容量。", "资源与装备自动保存；生命归零不会扣除已获得资源。"]
	for i in range(lines.size()):
		text_at(lines[i],Vector2(360,250+i*39),16,MUTED if i>5 else INK)

func equipment_label(parent: Control, value: String, pos: Vector2, font_size := 13, color := INK) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)

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
	for page in EQUIPMENT_PAGES:
		var scroll := ScrollContainer.new()
		scroll.name = page.title
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		equipment_tabs.add_child(scroll)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation",8)
		scroll.add_child(cards)
		for key in page.keys:
			if not game.profile.unlocked.has(key):
				continue
			var lv := int(game.profile.levels[key])
			var maxed := lv >= db.max_equipment_level(key)
			var next := db.equip(key,mini(lv+1,db.max_equipment_level(key)))
			var defence: bool = key in ["armour","shield"]
			var bulk: bool = BattleGame.BULK_EQUIPMENT.has(key)
			var card := Panel.new()
			card.custom_minimum_size = Vector2(216,112)
			card.add_theme_stylebox_override("panel",style(PANEL,LINE))
			cards.add_child(card)
			if PROJECTILE_TEXTURES.has(key):
				var icon := TextureRect.new()
				icon.texture = PROJECTILE_TEXTURES[key]
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.position = Vector2(8,7)
				icon.size = Vector2(34,20)
				card.add_child(icon)
			equipment_label(card,"%s Lv.%s" % [NAMES[key],number(lv)],Vector2(8 if defence else 46,6),14)
			var cd := float(db.equip(key,lv).get("cd",0))
			if not defence and cd > 0:
				equipment_label(card,"CD %s秒" % number(cd),Vector2(158,8),11,MUTED)
			equipment_label(card,("容量" if defence else "伤害")+" %s → %s" % [number(game.stat(key)),number(game.equipment_stat(key,int(next.level)))],Vector2(10,31),13,MUTED)
			var single_cost := game.upgrade_cost(key)
			var ten_available := lv + 10 <= db.max_equipment_level(key)
			var ten_cost := game.upgrade_costs(key,10)
			equipment_label(card,"已达最高等级" if maxed else "单次：" + cost_text(single_cost),Vector2(10,47),11)
			if bulk:
				equipment_label(card,"10级总计：" + (cost_text(ten_cost) if ten_available else "不可用"),Vector2(10,61),11,MUTED)
			var upgrade := button("已满级" if maxed else "升级 ↑",Rect2(10,79,60,27),func():game.upgrade(key),true,not game.can_upgrade(key))
			upgrade.reparent(card,false)
			upgrade.add_theme_font_size_override("font_size",12)
			upgrade_buttons[key] = upgrade
			if bulk:
				var ten := button("10连",Rect2(78,79,60,27),func():game.upgrade(key,10),false,not game.can_upgrade_amount(key,10))
				ten.reparent(card,false)
				ten.add_theme_font_size_override("font_size",12)
				ten.tooltip_text = "一次升10级，总消耗：" + cost_text(ten_cost)
				ten_upgrade_buttons[key] = ten
				var max_amount := game.max_upgrade_amount(key)
				var max_button := button("MAX",Rect2(146,79,60,27),func():game.upgrade_max(key),false,max_amount <= 0)
				max_button.reparent(card,false)
				max_button.add_theme_font_size_override("font_size",12)
				max_button.tooltip_text = "升级至 Lv.%s，总消耗：%s" % [number(lv + max_amount),cost_text(game.upgrade_costs(key,max_amount))]
				max_upgrade_buttons[key] = max_button
			if not defence:
				var cooldown := ColorRect.new()
				cooldown.position = Vector2(10,73)
				cooldown.size = Vector2(196,3)
				cooldown.color = LINE
				cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(cooldown)
				var fill := ColorRect.new()
				fill.size = Vector2(196,3)
				fill.color = CYAN
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cooldown.add_child(fill)
				equipment_cooldowns[key] = fill
		if cards.get_child_count() == 0:
			equipment_label(cards,"暂无已解锁装备",Vector2(12,12),14,MUTED)
	build_hightech_tab()
	equipment_tabs.set_tab_hidden(2,hightech_buttons.is_empty())
	if equipment_page == 2 and hightech_buttons.is_empty():
		equipment_page = 0
	equipment_tabs.current_tab = mini(equipment_page,equipment_tabs.get_tab_count()-1)
	equipment_tabs.tab_changed.connect(func(index):equipment_page=index)

func hightech_button_text(key: String) -> String:
	if game.profile.hightechResearch.has(key):
		return ("连续研发中" if game.active_research().has(key) else "继续研发") + " · %s秒" % number(ceilf(float(game.profile.hightechResearch[key].remaining)))
	if not game.hightech_unlocked(key):
		return "通关第%s关解锁" % number(db.data.hightech[key].unlock)
	if not game.can_research(key):
		return "研发名额已满"
	return ("切换研发" if not game.active_research().is_empty() else "研发") + " Lv.%s · %s秒" % [number(game.hightech_level(key)+1),number(game.hightech_duration(key))]

func select_research(key: String) -> void:
	var active := game.active_research()
	if active.size() <= 1 or active.size() < int(db.config.hightechLimit):
		game.research(key)
		return
	var menu := PopupMenu.new()
	ui.add_child(menu)
	for current in active:
		menu.add_item("暂停 " + str(current) + "，改研 " + key)
	menu.id_pressed.connect(func(index):game.research(key,str(active[index])))
	menu.popup_hide.connect(func():menu.queue_free())
	menu.position = Vector2i(get_global_mouse_position())
	menu.popup()

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
	var slots := game.hightech_slots()
	for index in range(slots.size()):
		var key: String = slots[index]
		var card := Panel.new()
		card.set_script(HIGHTECH_SLOT_SCRIPT)
		card.slot_index = index
		card.tech_key = key
		card.swap_requested.connect(func(source,target):
			if game.swap_hightech_slots(source,target):
				call_deferred("build_ui"))
		card.custom_minimum_size = HIGHTECH_CARD_SIZE
		card.add_theme_stylebox_override("panel",style(PANEL,LINE))
		card.add_theme_font_override("font",font)
		cards.add_child(card)
		if key.is_empty():
			card.add_theme_stylebox_override("panel",style(BG,LINE))
			equipment_label(card,"空卡槽 %02d" % (index+1),Vector2(16,30),14,MUTED)
			equipment_label(card,"可将高科技卡片拖到这里",Vector2(16,57),12,MUTED)
			continue
		var row: Dictionary = db.data.hightech[key]
		card.tooltip_text = "拖动标题到其他卡槽，松手交换位置并保存"
		equipment_label(card,"%s Lv.%s" % [key,number(game.hightech_level(key))],Vector2(10,5),14,CYAN)
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = game.hightech_description(key)
		description.tooltip_text = description.text
		description.mouse_filter = Control.MOUSE_FILTER_PASS
		description.position = Vector2(10,29)
		description.size = Vector2(423,44)
		description.add_theme_font_override("font",font)
		description.add_theme_font_size_override("font_size",12)
		description.add_theme_color_override("font_color",MUTED)
		card.add_child(description)
		hightech_descriptions[key] = description
		var b := button(hightech_button_text(key),Rect2(10,79,423,27),func():select_research(key),true,not game.can_research(key))
		b.reparent(card,false)
		b.add_theme_font_size_override("font_size",14)
		b.set_drag_forwarding(Callable(),card._can_drop_data,card._drop_data)
		hightech_buttons[key] = b
		equipment_label(card,"⠿ 拖动换位",Vector2(350,5),12,MUTED)
	scroll.set_deferred("scroll_horizontal",hightech_scroll_offset)

func draw_unlock() -> void:
	draw_rect(Rect2(0,78,1440,732),Color(0.02,0.04,0.08,0.93))
	box(Rect2(400,240,640,370),Color("142638"),CYAN)
	text_at("新装备已解锁",Vector2(457,303),32,CYAN)
	var line_y := 361
	for key in game.pending_unlocks:
		text_at(NAMES[key],Vector2(457,line_y),24,INK)
		line_y += 42
	text_at("装备已自动装载，可在下方直接升级。",Vector2(457,476),18,MUTED)
	text_at("点击继续后恢复自动前进。",Vector2(457,509),15,MUTED)
