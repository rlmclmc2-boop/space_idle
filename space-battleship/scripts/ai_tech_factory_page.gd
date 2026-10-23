extends Control
## Snapshot-driven AI factory. The game owns all research math and unlock decisions.

signal research_requested(technology_id: String)
signal investment_requested(resource_id: String, amount: Variant)
signal input_ratio_requested(resource_id: String, ratio: float)

const N = preload("res://scripts/growth_number.gd")

const ART = preload("res://scripts/ai_tech_factory_art.gd")
const INK := Color("dce9e8")
const MUTED := Color("9cb3bf")
const CYAN := Color("89dbd4")
const LINE := Color("365669")
const DEEP := Color("0d1d2d")
const PANEL := Color("142c3d")
const CARD := Color("1c394a")

var snapshot: Dictionary = {}
var source_provider: Callable
var drawer_open := false
var art_enabled := true
var art_has_selection := false
var scene: Control
var drawer: Control
var art: Control
var active_name: Label
var active_meta: Label
var effect_text: Label
var status_text: Label
var progress_text: Label
var remaining_text: Label
var progress_fill: ColorRect
var ai_text: Label
var speed_text: Label
var iron_label: Label
var uranium_label: Label
var input_mode: Label
var automatic_input := false
var iron_edit: LineEdit
var uranium_edit: LineEdit
var iron_state: Label
var uranium_state: Label
var drawer_active: Label
var drawer_progress: Label
var drawer_fill: ColorRect
var worklist: VBoxContainer
var row_nodes: Dictionary = {}
var row_fingerprint := ""

func _skin(fill: Color, edge := LINE, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s

func _panel(parent: Control, rect: Rect2, fill := PANEL) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _skin(fill))
	parent.add_child(p)
	return p

func _label(parent: Control, caption: String, rect: Rect2, font_size := 22, color := INK) -> Label:
	var l := Label.new()
	l.text = caption
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	parent.add_child(l)
	return l

func _button(parent: Control, caption: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := Color("62c2bb") if primary else Color("24475a")
		if state == "hover": fill = fill.lightened(0.11)
		if state == "pressed": fill = fill.darkened(0.12)
		if state == "disabled": fill = Color("203341")
		b.add_theme_stylebox_override(state, _skin(Color.TRANSPARENT if state == "focus" else fill, CYAN if state == "focus" else LINE, 9))
		b.add_theme_color_override("font_color", DEEP if primary else INK)
		b.add_theme_color_override("font_hover_color", DEEP if primary else INK)
		b.add_theme_color_override("font_disabled_color", MUTED)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func setup(source: Variant = null) -> void:
	if source is Callable:
		source_provider = source
	if scene != null:
		return
	size = Vector2(1344, 1160)
	clip_contents = true
	_panel(self, Rect2(0, 0, 1344, 1160), DEEP)
	scene = Control.new()
	scene.size = size
	add_child(scene)
	_label(scene, UIText.t("ui.ai_tech_factory_page.message_01"), Rect2(30, 20, 320, 53), 36)
	_label(scene, UIText.t("ui.ai_tech_factory_page.message_02"), Rect2(31, 72, 360, 30), 19, MUTED)
	_button(scene, UIText.t("ui.ai_tech_factory_page.message_03"), Rect2(1060, 26, 254, 60), func(): set_drawer_open(true), true)
	_panel(scene, Rect2(24, 119, 1296, 713), Color("102637"))
	art = ART.new()
	art.position = Vector2(30, 125)
	art.size = Vector2(1284, 701)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(art)
	var caption := _panel(scene, Rect2(52, 143, 420, 86), Color("102637cc"))
	active_name = _label(caption, UIText.t("ui.ai_tech_factory_page.message_04"), Rect2(20, 8, 380, 40), 29)
	active_meta = _label(caption, "", Rect2(20, 49, 380, 29), 18, CYAN)
	var foot := _panel(scene, Rect2(24, 850, 1296, 285), PANEL)
	_label(foot, UIText.t("ui.ai_tech_factory_page.message_05"), Rect2(24, 16, 270, 34), 23, MUTED)
	status_text = _label(foot, UIText.t("ui.ai_tech_factory_page.message_06"), Rect2(24, 53, 760, 39), 27)
	progress_text = _label(foot, "—", Rect2(1078, 49, 174, 45), 30, CYAN)
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel(foot, Rect2(26, 106, 1241, 13), DEEP)
	progress_fill = ColorRect.new()
	progress_fill.position = Vector2(28, 108)
	progress_fill.size = Vector2(0, 9)
	progress_fill.color = CYAN
	foot.add_child(progress_fill)
	effect_text = _label(foot, "", Rect2(25, 129, 755, 32), 21, INK)
	remaining_text = _label(foot, "", Rect2(879, 129, 365, 32), 21, MUTED)
	remaining_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ai_text = _label(foot, "AI —", Rect2(25, 183, 160, 36), 24, CYAN)
	speed_text = _label(foot, "", Rect2(188, 186, 545, 35), 21, INK)
	input_mode = _label(foot, "", Rect2(750, 183, 510, 35), 19, CYAN)
	iron_label = _label(foot, UIText.t("ai_tech.investment.iron_per_second"), Rect2(25, 230, 108, 34), 20, MUTED)
	iron_edit = _investment_input(foot, Rect2(135, 225, 130, 42), "iron")
	iron_state = _label(foot, "", Rect2(352, 231, 282, 33), 18, CYAN)
	uranium_label = _label(foot, UIText.t("ai_tech.investment.uranium_per_second"), Rect2(660, 230, 108, 34), 20, MUTED)
	uranium_edit = _investment_input(foot, Rect2(775, 225, 130, 42), "uranium")
	uranium_state = _label(foot, "", Rect2(992, 231, 270, 33), 18, CYAN)
	_build_drawer()
	set_drawer_open(false)
	if source_provider.is_valid(): refresh_snapshot()

func _investment_input(parent: Control, rect: Rect2, resource_id: String) -> LineEdit:
	var e := LineEdit.new()
	e.position = rect.position
	e.size = rect.size
	e.placeholder_text = "0"
	e.add_theme_font_size_override("font_size", 21)
	e.add_theme_stylebox_override("normal", _skin(DEEP))
	e.add_theme_color_override("font_color", INK)
	e.text_submitted.connect(func(value: String): _submit_investment(resource_id, value))
	parent.add_child(e)
	_button(parent, UIText.t("ui.ai_tech_factory_page.message_07"), Rect2(rect.end.x + 7, rect.position.y, 70, rect.size.y),
		func(): _submit_investment(resource_id, e.text))
	return e

func _submit_investment(resource_id: String, value: String) -> void:
	var cleaned := value.strip_edges()
	var editor: LineEdit=iron_edit if resource_id=="iron" else uranium_edit
	var state_label: Label=iron_state if resource_id=="iron" else uranium_state
	if automatic_input:
		if not cleaned.is_valid_float() or not is_finite(cleaned.to_float()) or cleaned.to_float()<0.1:
			state_label.text=UIText.t("ai_tech.investment.invalid_ratio");return
		editor.release_focus()
		input_ratio_requested.emit(resource_id,cleaned.to_float()/100.0)
	else:
		var amount=N.parse_input(cleaned)
		if amount==null or N.compare(amount,N.floor_value(amount))!=0:
			state_label.text=UIText.t("ai_tech.investment.invalid_amount");return
		editor.release_focus()
		investment_requested.emit(resource_id,amount)

func _build_drawer() -> void:
	drawer = Control.new()
	drawer.size = size
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(drawer)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color("051521bd")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_child(shade)
	var body := _panel(drawer, Rect2(77, 55, 1190, 1050), DEEP)
	_label(body, UIText.t("ui.ai_tech_factory_page.message_08"), Rect2(33, 20, 630, 55), 37)
	_button(body, UIText.t("ui.ai_tech_factory_page.message_09"), Rect2(980, 18, 180, 59), func(): set_drawer_open(false))
	_panel(body, Rect2(24, 91, 1142, 150), PANEL)
	drawer_active = _label(body, UIText.t("ui.ai_tech_factory_page.message_10"), Rect2(48, 106, 860, 37), 25)
	drawer_progress = _label(body, "—", Rect2(983, 106, 158, 37), 25, CYAN)
	drawer_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel(body, Rect2(47, 159, 1094, 11), DEEP)
	drawer_fill = ColorRect.new()
	drawer_fill.position = Vector2(49, 161)
	drawer_fill.size = Vector2(0, 7)
	drawer_fill.color = CYAN
	body.add_child(drawer_fill)
	_label(body, UIText.t("ai_tech.tutorial.research"), Rect2(47, 178, 1080, 25), 18, MUTED)
	_label(body, UIText.t("ai_tech.tutorial.investment"), Rect2(47, 206, 1080, 25), 18, MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 258)
	scroll.size = Vector2(1142, 765)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	worklist = VBoxContainer.new()
	worklist.custom_minimum_size = Vector2(1112, 0)
	worklist.add_theme_constant_override("separation", 12)
	scroll.add_child(worklist)

func set_drawer_open(value: bool) -> void:
	drawer_open = value
	if drawer == null: return
	drawer.visible = value
	if art != null: art.set_obscured(value or not art_enabled)
	if value and source_provider.is_valid(): refresh_snapshot()
	if value: _sync_rows(snapshot.get("technologies", []))

func set_art_enabled(value: bool) -> void:
	art_enabled = value
	if art == null:
		return
	art.visible = value and art_has_selection
	art.set_obscured(drawer_open or not value)

func set_snapshot_provider(provider: Callable) -> void:
	source_provider = provider
	if is_visible_in_tree(): refresh_snapshot()

func refresh_snapshot() -> void:
	if not source_provider.is_valid(): return
	var data: Variant = source_provider.call()
	if data is Dictionary: set_snapshot(data)

func invalidate(_structure := false) -> void:
	if is_visible_in_tree(): refresh_snapshot()

func set_snapshot(data: Dictionary) -> void:
	snapshot = data
	if scene == null: setup()
	var items: Array = data.get("technologies", [])
	var selected_id := str(data.get("display_id", ""))
	if selected_id.is_empty(): selected_id = str(data.get("active_id", ""))
	if selected_id.is_empty() and not items.is_empty() and items[0] is Dictionary:
		selected_id = str(items[0].get("id", ""))
	var shown: Dictionary = {}
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == selected_id:
			shown = item
			break
	var active_id := str(data.get("active_id", ""))
	var active: Dictionary = {}
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == active_id:
			active = item
			break
	var percent := clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	var working := bool(data.get("researching", false))
	art_has_selection = not selected_id.is_empty()
	art.visible = art_enabled and art_has_selection
	art.set_display(_art_id(selected_id), int(shown.get("level", 0)), bool(data.get("advancing",working)) and selected_id == active_id, percent)
	if drawer_open or not art_enabled: art.set_obscured(true)
	active_name.text = str(shown.get("name", UIText.t("ui.ai_tech_factory_page.message_04")))
	active_meta.text = str(shown.get("generation_text", "")) # Caller supplies generation labels.
	status_text.text = str(data.get("status_text", UIText.t("ui.ai_tech_factory_page.message_06")))
	effect_text.text = str(active.get("effect_text", ""))
	progress_text.text = ("%d%%" % roundi(percent * 100.0)) if working else "—"
	remaining_text.text = str(data.get("remaining_text", ""))
	progress_fill.size.x = 1237.0 * percent if working else 0.0
	ai_text.text = str(data.get("ai_text", "AI —"))
	speed_text.text = str(data.get("speed_text", ""))
	var next_automatic := bool(data.get("automatic_input",false))
	if automatic_input!=next_automatic:
		iron_edit.release_focus();uranium_edit.release_focus()
	automatic_input=next_automatic
	iron_label.text=UIText.t("ai_tech.investment.iron_ratio" if automatic_input else "ai_tech.investment.iron_per_second")
	uranium_label.text=UIText.t("ai_tech.investment.uranium_ratio" if automatic_input else "ai_tech.investment.uranium_per_second")
	input_mode.text=UIText.t("ai_tech.investment.automatic") if automatic_input else ""
	iron_edit.tooltip_text=UIText.t("ai_tech.investment.auto_help" if automatic_input else "ai_tech.investment.manual_help")
	uranium_edit.tooltip_text=iron_edit.tooltip_text
	iron_state.text = str(data.get("iron_state", ""))
	uranium_state.text = str(data.get("uranium_state", ""))
	iron_state.tooltip_text=iron_state.text;uranium_state.tooltip_text=uranium_state.text
	iron_state.mouse_filter=Control.MOUSE_FILTER_PASS;uranium_state.mouse_filter=Control.MOUSE_FILTER_PASS
	_sync_input(iron_edit, str(data.get("iron_investment", "0")))
	_sync_input(uranium_edit, str(data.get("uranium_investment", "0")))
	drawer_active.text = UIText.t("ui.ai_tech_factory_page.message_11") + str(active.get("name", UIText.t("ui.ai_tech_factory_page.message_12")))
	drawer_progress.text = progress_text.text
	drawer_fill.size.x = 1090.0 * percent if working else 0.0
	if drawer_open: _sync_rows(items)

func _sync_input(e: LineEdit, value: String) -> void:
	if not e.has_focus() and e.text != value: e.text = value

func _art_id(id: String) -> String:
	match id:
		"AI奇点", "ai_singularity": return "ai_singularity"
		"武器精度", "weapon_accuracy": return "weapon_accuracy"
		"装备强化", "equipment_reinforcement": return "equipment_reinforcement"
		"资源精炼", "resource_refining": return "resource_refining"
		"强化碎片凝聚", "fragment_condensation": return "fragment_condensation"
		"装备精制", "equipment_precision": return "equipment_precision"
		"铀提炼", "uranium_extraction": return "uranium_extraction"
		"联合一体化", "joint_integration": return "joint_integration"
		_: return "ai_singularity"

func _sync_rows(items: Array) -> void:
	var fingerprint := ""
	for item in items:
		if item is Dictionary: fingerprint += str(item.get("id", "")) + "|" + str(item.get("tier", "")) + ";"
	if fingerprint != row_fingerprint:
		row_fingerprint = fingerprint
		for child in worklist.get_children(): child.queue_free()
		row_nodes.clear()
		var previous_tier := ""
		for item in items:
			if not item is Dictionary: continue
			var tier := str(item.get("tier", "basic"))
			if tier != previous_tier:
				var heading := Label.new()
				heading.text = {"independent":UIText.t("ui.ai_tech_factory_page.message_13"), "basic":UIText.t("ui.ai_tech_factory_page.message_14"), "core":UIText.t("ui.ai_tech_factory_page.message_15"), "final":UIText.t("ui.ai_tech_factory_page.message_16")}.get(tier, tier)
				heading.custom_minimum_size = Vector2(1112, 36)
				heading.add_theme_font_size_override("font_size", 23)
				heading.add_theme_color_override("font_color", CYAN)
				worklist.add_child(heading)
				previous_tier = tier
			_create_row(str(item.get("id", "")))
	for item in items:
		if not item is Dictionary: continue
		var id := str(item.get("id", ""))
		if not row_nodes.has(id): continue
		var row: Dictionary = row_nodes[id]
		row.name.text = str(item.get("name", id)) + "  Lv." + str(item.get("level", 0))
		row.effect.text = str(item.get("effect_text", ""))
		row.condition.text = str(item.get("requirement_text", ""))
		row.state.text = str(item.get("state_text", ""))
		row.action.disabled = not bool(item.get("can_research", false))
		row.action.text = str(item.get("action_text", UIText.t("ui.ai_tech_factory_page.message_08")))
		row.art.set_display(_art_id(id), int(item.get("level", 0)), false, 0.0, true)

func _create_row(id: String) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(1112, 137)
	card.add_theme_stylebox_override("panel", _skin(CARD))
	worklist.add_child(card)
	var icon := ART.new()
	icon.icon_mode = true
	icon.position = Vector2(17, 19)
	icon.size = Vector2(99, 99)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var name_label := _label(card, "", Rect2(138, 15, 565, 32), 24)
	var effect_label := _label(card, "", Rect2(138, 52, 691, 27), 18, INK)
	var condition_label := _label(card, "", Rect2(138, 87, 700, 30), 17, MUTED)
	var state_label := _label(card, "", Rect2(838, 24, 246, 29), 19, CYAN)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var action := _button(card, UIText.t("ui.ai_tech_factory_page.message_08"), Rect2(860, 70, 213, 48), func(): research_requested.emit(id), true)
	row_nodes[id] = {"name":name_label, "effect":effect_label, "condition":condition_label,
		"state":state_label, "action":action, "art":icon}
