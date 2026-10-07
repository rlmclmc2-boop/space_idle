extends Control
## State-derived, optional guidance. Profile flags ride the normal save lifecycle.
## Equipment contract: get_action_anchor(action, slot_id), select_item(slot_id),
## open_picker(slot_id). No coordinate or displayed-text dependency for targets.
var host: Node
var panel: PanelContainer
var body: Label
var action: Button
var reopen: Button
var outline: Panel
var target: Control
var target_slot := ""
var phase := ""
var review := false
var manually_opened := false
var elapsed := 0.0
var equip_target := ""
var retreat_pending := false
var retreat_defence: Array = []
var action_id := ""

func setup(owner: Node) -> void:
	host = owner
	name = "BeginnerGuide"
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 3
	panel = PanelContainer.new()
	panel.position = host.BATTLE_ORIGIN - host.ui.position + Vector2(16,570)
	panel.size = Vector2(540,0)
	var guide_style:StyleBoxFlat=host.style(Color("172c3b"),Color("304958"))
	guide_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",guide_style)
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	var title := Label.new()
	title.text = UIText.t("onboarding.heading")
	title.add_theme_color_override("font_color",Color("83cfcb"))
	title.add_theme_font_size_override("font_size",21)
	column.add_child(title)
	body = Label.new()
	body.custom_minimum_size.x = 500
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",20)
	body.add_theme_color_override("font_color",Color("eeeede"))
	column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	action = make_button(row,"next",activate)
	make_button(row,"dismiss",dismiss)
	reopen = make_button(self,"reopen",open_guide)
	preload("res://scripts/dialog_presentation.gd").button_skin(reopen)
	outline = Panel.new()
	outline.mouse_filter = MOUSE_FILTER_IGNORE
	var border: StyleBoxFlat = host.style(Color(0,0,0,0),host.CYAN)
	border.set_border_width_all(3)
	outline.add_theme_stylebox_override("panel",border)
	add_child(outline)
	refresh()

func make_button(parent: Node, key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = UIText.t("onboarding."+key)
	button.custom_minimum_size = Vector2(150,38)
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25:return
	elapsed = 0.0
	refresh()

func flags() -> Dictionary:
	return host.game.profile.onboarding

func dismiss() -> void:
	retreat_pending = false
	retreat_defence.clear()
	flags().dismissed = true
	manually_opened = false
	review = false
	refresh()

func open_guide() -> void:
	# A temporary review must not opt a dismissed profile back into auto-show.
	manually_opened = true
	review = bool(flags().completed)
	host.help_open = false
	host.refresh_navigation()
	refresh()

func decide() -> Dictionary:
	var game: BattleGame = host.game
	var state := flags()
	var empty_slot := ""
	var empty_defence := ""
	var defence_adjusted := false
	var upgrade_slot := ""
	var waiting_slot := ""
	var any_upgraded := false
	var occupied_weapons := 0
	for category in ["weapons","defence"]:
		for index in game.active_slot_count(category):
			var entry: Dictionary = game.slot_entry(category,index)
			var id := game.slot_id(category,index)
			if int(entry.level)>1:
				any_upgraded = true
				if category=="defence" and not str(entry.key).is_empty():defence_adjusted = true
			if category=="defence" and index>0 and not str(entry.key).is_empty():defence_adjusted = true
			if category=="weapons" and not str(entry.key).is_empty():occupied_weapons += 1
			if str(entry.key).is_empty():
				if has_equipment_choice(category,index):
					if category=="weapons" and empty_slot.is_empty():empty_slot = id
					if category=="defence" and empty_defence.is_empty():empty_defence = id
				continue
			if not game.slot_upgrade_cost(category,index).is_empty() and waiting_slot.is_empty():waiting_slot = id
			if game.can_upgrade_slot(category,index) and upgrade_slot.is_empty():upgrade_slot = id
	var starting_weapons := 0
	for entry in game.default_loadout(str(game.profile.selectedShip),Array(str(game.db.config.startEquip).split(","))).weapons:
		if not str(entry.key).is_empty():starting_weapons += 1
	if occupied_weapons>starting_weapons:state.equipped = true
	if any_upgraded:state.upgraded = true
	if state.equipped or state.upgraded or not game.profile.cleared.is_empty():state.intro = true
	if not equip_target.is_empty():
		var parts := equip_target.split("_")
		var entry := game.slot_entry(parts[0],int(parts[1]))
		if not entry.is_empty() and not str(entry.key).is_empty():state.equipped = true
	if empty_slot.is_empty():state.equipped = true
	if review:return {"phase":"review"}
	if not game.pending_unlocks.is_empty():return {"phase":"unlock","action":"continue"}
	if retreat_pending:
		if not empty_defence.is_empty():return {"phase":"retreat","slot":empty_defence,"action":"show_defence","anchor":"empty_module"}
		for index in game.active_slot_count("defence"):
			if not str(game.slot_entry("defence",index).key).is_empty():
				return {"phase":"retreat","slot":game.slot_id("defence",index),"action":"show_upgrade","anchor":"upgrade_action"}
		return {"phase":"retreat","action":"show_equipment"}
	if not state.intro:return {"phase":"intro","action":"next"}
	if game.state==BattleGame.State.RETREAT:return {"phase":"retreat","action":"show_equipment"}
	if not state.equipped:
		equip_target = empty_slot
		return {"phase":"equip","slot":empty_slot,"action":"show_slot","anchor":"empty_module"}
	if not state.upgraded:
		if not upgrade_slot.is_empty():return {"phase":"upgrade","slot":upgrade_slot,"action":"show_upgrade","anchor":"upgrade_action"}
		if not waiting_slot.is_empty():
			var parts := waiting_slot.split("_")
			return {"phase":"waiting","slot":waiting_slot,"action":"show_upgrade","anchor":"upgrade_action","cost":host.cost_text(game.slot_upgrade_cost(parts[0],int(parts[1])))}
		state.upgraded = true
	if not defence_adjusted and not empty_defence.is_empty():
		return {"phase":"defence","slot":empty_defence,"action":"show_defence","anchor":"empty_module"}
	if not game.profile.cleared.is_empty():
		state.completed = true
		manually_opened = false
		return {"phase":"clear"}
	return {"phase":"paused" if game.paused else "progress"}

func has_equipment_choice(category: String, index: int) -> bool:
	# Share the picker eligibility; an earned ID alone need not be an equip option.
	var game: BattleGame = host.game
	if game.slot_equipment_locked(category,index):return false
	var choices: Array = host.equipment_panel.equipment_choices(category,index)
	return choices.any(func(key):return not str(key).is_empty() and game.profile.unlocked.has(key))

func defence_snapshot() -> Array:
	var result: Array = []
	for index in host.game.active_slot_count("defence"):
		var entry: Dictionary = host.game.slot_entry("defence",index)
		result.append([str(entry.key),int(entry.level)])
	return result

func recovery_adjusted() -> bool:
	var current := defence_snapshot()
	for index in current.size():
		var previous: Array = retreat_defence[index] if index<retreat_defence.size() else ["",0]
		if not str(current[index][0]).is_empty() and (current[index][0]!=previous[0] or int(current[index][1])>int(previous[1])):return true
	return false

func refresh() -> void:
	if not is_instance_valid(host) or not is_instance_valid(panel):return
	var playing: bool = host.game.state not in [BattleGame.State.MAIN_MENU,BattleGame.State.LEVEL_SELECT]
	var modal_blocked: bool = (is_instance_valid(host.chrono_login_dialog) and host.chrono_login_dialog.visible) or (is_instance_valid(host.balance_lab) and host.balance_lab.visible)
	if playing and host.game.state==BattleGame.State.RETREAT and not flags().get("retreatSeen",true):
		flags().retreatSeen = true
		retreat_pending = not flags().dismissed
		retreat_defence = defence_snapshot()
	if retreat_pending and recovery_adjusted():
		retreat_pending = false
		retreat_defence.clear()
	# Reconcile completion before deciding visibility, including while dismissed.
	var step := decide() if playing and (not flags().completed or manually_opened or retreat_pending) else {"phase":"review"}
	var visible_now: bool = playing and not host.help_open and not modal_blocked and (manually_opened or (not flags().dismissed and (not flags().completed or retreat_pending)))
	var show_reopen: bool = playing and host.help_open and not modal_blocked and host.game.pending_unlocks.is_empty()
	host.set_ui_value(reopen,"visible",show_reopen)
	if show_reopen:
		var help_panel: Rect2 = host.overlay_panel_rect(Vector2(820,551))
		var help_scale := help_panel.size.x/820.0
		host.set_ui_value(reopen,"position",help_panel.position-host.ui.position+Vector2(50,483)*help_scale)
		host.set_ui_value(reopen,"scale",Vector2.ONE*help_scale)
	host.set_ui_value(panel,"visible",visible_now)
	if not visible_now:
		host.set_ui_value(outline,"visible",false)
		return
	phase = step.phase
	action_id = str(step.get("action",""))
	host.set_ui_value(panel,"position",host.BATTLE_ORIGIN-host.ui.position+Vector2(16,16 if phase=="unlock" else 570))
	target_slot = step.get("slot","")
	host.set_ui_value(body,"text",UIText.t("onboarding."+phase,{"cost":step.cost} if step.has("cost") else {}))
	host.set_ui_value(action,"visible",step.has("action"))
	if step.has("action"):host.set_ui_value(action,"text",UIText.t("onboarding."+str(step.action)))
	target = resolve_anchor(str(step.get("anchor","")),target_slot)
	if phase=="unlock":target = host.continue_button
	var target_rect := visible_anchor_rect(target)
	var show_target := target_rect.has_area()
	host.set_ui_value(outline,"visible",show_target)
	if show_target:
		var rect := get_global_transform().affine_inverse()*target_rect
		host.set_ui_value(outline,"position",rect.position-Vector2(3,3))
		host.set_ui_value(outline,"size",rect.size+Vector2(6,6))

func visible_anchor_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or not control.is_visible_in_tree():return Rect2()
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:rect = rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect

func resolve_anchor(id: String, slot: String) -> Control:
	if id.is_empty():return null
	if host.equipment_tabs.current_tab!=0:return host.system_nav_buttons[0]
	var equipment: Control = host.equipment_panel
	if equipment.has_method("get_action_anchor"):
		var confirm = equipment.call("get_action_anchor","equip_confirm",slot) if action_id in ["show_slot","show_defence"] else null
		if is_instance_valid(confirm) and confirm.is_visible_in_tree():return confirm
		return equipment.call("get_action_anchor",id,slot)
	# Compatibility with the pre-redesign module panel; semantic references only.
	if id=="upgrade_action" and equipment.selected==slot:return equipment.detail.get("upgrade")
	return equipment.cards.get(slot)

func activate() -> void:
	match phase:
		"intro":flags().intro = true
		"unlock":
			# Reuse the existing explicit acknowledgement action.
			host.continue_button.pressed.emit()
		_:
			host.select_system(0)
			if not target_slot.is_empty():
				host.equipment_panel.select_item(target_slot)
				if action_id=="show_upgrade" and host.equipment_panel.has_method("set_upgrade_amount"):host.equipment_panel.set_upgrade_amount(1)
				if host.equipment_panel.cards.has(target_slot):host.equipment_panel.grid_scroll.ensure_control_visible(host.equipment_panel.cards[target_slot])
				if action_id in ["show_slot","show_defence"] and host.equipment_panel.has_method("open_picker"):host.equipment_panel.open_picker(target_slot)
	if phase=="retreat":
		retreat_pending = false
		retreat_defence.clear()
	refresh()
