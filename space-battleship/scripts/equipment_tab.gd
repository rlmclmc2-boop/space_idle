extends Control
## Module projection; growth and equipment remain authoritative in BattleGame.
const Card = preload("res://scripts/equipment_card.gd")
var style_tiles := preload("res://scripts/equipment_style_tiles.gd").new()
var host: Node
var cards: Dictionary = {}
var items: Dictionary = {}
var icons: Dictionary = {}
var selected := ""
var selected_slot := -1
var category_filter := 0
var subtype_filter := 0
var status_filter := 0
var sort_mode := 0
var grid: GridContainer
var grid_scroll: ScrollContainer
var total: Label
var empty: Label
var detail: Dictionary = {}
var slot_options: Array = []
var subtypes := ["all","laser","cannon","missile","shield","armour"]
var dirty := true
var sort_dirty := true
var sorted_ids: Array = []
var last_sort_mode := -1
var observed_resources: Dictionary = {}
var stats_dirty: Dictionary = {}
var selected_next_stat = 0.0
var detail_dirty := true
var details_open := false
var footer: Panel
var footer_title: Label
var footer_buttons: Dictionary = {}
var upgrade_amount := 1
var amount_buttons: Array[Button] = []
var picker_open := false
var pending_key := ""
# Draft belongs to the selected slot and its equipped identity, not its level.
var draft_context: Array = []
var summary: Label
var grid_defence: GridContainer
var slot_list: VBoxContainer
var section_labels: Dictionary = {}
const NAVY := Color("243d50")
const PAPER := Color("ecebdc")
const TEAL := Color("83cfcb")
var filters: Control
var toolbar: Control
var sort_picker: OptionButton
var detail_scroll: ScrollContainer
var detail_frame: Panel
var detail_body: Control
var detail_actions: GridContainer
var new_weapon: Button
var new_weapon_dismiss: Button
var new_weapon_id := ""
var category_picker: OptionButton

func equipment_text(suffix: String) -> String:
	var key := "equipment."+suffix
	return UIText.t(key)

func module_card_id(category: String, index: int) -> String:
	# Stored modules keep their own identity when a smaller hull makes them dormant.
	# Combat slot IDs may instead identify drones beyond the active weapon count.
	return "%s_%d" % [category,index]

func equipment_choices(category: String,index: int = -1) -> Array:
	if host.game.slot_equipment_locked(category,index):return ["armour"]
	var options: Array = [""]
	for key in BattleGame.WEAPON_KEYS if category=="weapons" else BattleGame.DEFENSE_KEYS:
		if host.game.content_unlocked("equipment",key):options.append(key)
	return options

func label(parent: Control, value: String, rect: Rect2, font_size := 12, color := Color("e0ecf4")) -> Label:
	return host.equipment_card_label(parent,value,rect,font_size,color)

func select_box(parent: Control, rect: Rect2, keys: Array, callback: Callable) -> OptionButton:
	var box := OptionButton.new()
	box.position = rect.position
	box.size = rect.size
	box.fit_to_longest_item = false
	preload("res://scripts/dialog_presentation.gd").option(box,false)
	box.add_theme_font_override("font",host.font)
	box.add_theme_font_size_override("font_size",14)
	for key in keys:
		box.add_item(UIText.t(str(key)))
	box.item_selected.connect(func(index):
		box.add_theme_color_override("font_color",NAVY)
		callback.call(index))
	parent.add_child(box)
	return box

# Other pages reuse this public skin helper. Keep their vector styling intact.
func panel_style(fill: Color, edge := NAVY, radius := 16) -> StyleBoxFlat:
	return style_tiles.native_style(fill,edge,radius)

func textured_panel_style(fill: Color, edge := NAVY, radius := 16) -> StyleBoxTexture:
	return style_tiles.panel_style(fill,edge,radius)

# Shared callers retain the original vector skin; equipment opts in explicitly.
func skin_button(button: Button, primary := false, textured := false) -> void:
	button.add_theme_font_override("font",host.font)
	button.add_theme_font_size_override("font_size",20)
	for state in ["normal","hover","pressed","disabled"]:
		var fill := TEAL if primary else PAPER
		if state=="hover":fill=fill.lightened(0.13)
		if state=="pressed":fill=fill.darkened(0.12)
		if state=="disabled":fill=Color("8b9a9e")
		button.add_theme_stylebox_override(state,textured_panel_style(fill) if textured else panel_style(fill))
	button.add_theme_stylebox_override("focus",textured_panel_style(Color.TRANSPARENT,TEAL,14) if textured else panel_style(Color.TRANSPARENT,TEAL,14))
	button.add_theme_color_override("font_color",NAVY)
	button.add_theme_color_override("font_hover_color",NAVY)
	button.add_theme_color_override("font_focus_color",NAVY)
	button.add_theme_color_override("font_pressed_color",NAVY)
	button.add_theme_color_override("font_disabled_color",NAVY)

func action_button(parent: Control, text_key: String, action_id: String, callback: Callable, primary := false, parameters: Dictionary = {}) -> Button:
	var button := Button.new()
	button.text = UIText.t(text_key,parameters)
	button.set_meta("action_id",action_id)
	button.custom_minimum_size = Vector2(120,48)
	skin_button(button,primary,true)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func setup(owner_ui: Node) -> void:
	host = owner_ui
	style_tiles.name="EquipmentStyleTiles"
	add_child(style_tiles)
	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel",textured_panel_style(Color("304c60")))
	add_child(backdrop)
	total = label(self,"",Rect2(24,16,1250,42),27,PAPER)
	summary = label(self,UIText.t("equipment.refit_hint"),Rect2(24,58,1230,32),20,Color("bedbdc"))
	toolbar = Control.new()
	toolbar.position = Vector2(24,101)
	add_child(toolbar)
	label(toolbar,UIText.t("equipment.upgrade_amount"),Rect2(0,0,170,46),20,PAPER)
	for i in 3:
		var amount: int = [1,10,0][i]
		var button := action_button(toolbar,"equipment.amount."+str(amount),"upgrade_amount",func():set_upgrade_amount(amount),amount==1)
		button.position = Vector2(174+i*100,0)
		button.custom_minimum_size.x = 90
		button.size = Vector2(90,48)
		amount_buttons.append(button)
	filters = Control.new()
	filters.position = Vector2(0,0)
	toolbar.add_child(filters)
	category_picker = select_box(filters,Rect2(512,0,210,48),["equipment.all","weapon.tab","defense.tab"],func(i):category_filter=i; apply_filters())
	skin_button(category_picker,false,true)
	new_weapon = action_button(toolbar,"equipment.new_weapon","new_weapon",show_new_weapon,true,{"weapon":""})
	new_weapon.position = Vector2(746,0)
	new_weapon.size = Vector2(370,48)
	new_weapon.add_theme_font_size_override("font_size",18)
	new_weapon_dismiss = action_button(toolbar,"equipment.new_weapon_dismiss","dismiss_new_weapon",dismiss_new_weapon)
	new_weapon_dismiss.position = Vector2(1126,0)
	new_weapon_dismiss.custom_minimum_size.x = 76
	new_weapon_dismiss.size = Vector2(76,48)
	new_weapon_dismiss.add_theme_font_size_override("font_size",18)
	grid_scroll = ScrollContainer.new()
	grid_scroll.name = "EquipmentGrid"
	grid_scroll.position = Vector2(22,165)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(grid_scroll)
	slot_list = VBoxContainer.new()
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation",10)
	grid_scroll.add_child(slot_list)
	for category in ["weapons","defence"]:
		var heading := Label.new()
		heading.add_theme_font_override("font",host.font)
		heading.add_theme_font_size_override("font_size",22)
		heading.add_theme_color_override("font_color",PAPER)
		heading.custom_minimum_size.y = 34
		slot_list.add_child(heading)
		section_labels[category] = heading
		var category_grid := GridContainer.new()
		category_grid.columns = 2
		category_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_grid.add_theme_constant_override("h_separation",14)
		category_grid.add_theme_constant_override("v_separation",12)
		slot_list.add_child(category_grid)
		if category=="weapons":grid=category_grid
		else:grid_defence=category_grid
	empty = label(self,UIText.t("equipment.empty"),Rect2(40,220,840,32),20,PAPER)
	footer = Panel.new()
	footer.add_theme_stylebox_override("panel",textured_panel_style(Color("dae4df")))
	add_child(footer)
	footer_title = label(footer,"",Rect2(18,14,560,42),22,NAVY)
	var footer_actions := HBoxContainer.new()
	footer_actions.position = Vector2(610,10)
	footer_actions.add_theme_constant_override("separation",10)
	footer.add_child(footer_actions)
	footer_buttons.details = action_button(footer_actions,"equipment.inspect","module_detail",show_inspector)
	build_detail()
	resized.connect(layout_contents)
	get_viewport().size_changed.connect(layout_contents)
	layout_contents()
	refresh()

func build_detail() -> void:
	detail_frame = Panel.new()
	detail_frame.name = "EquipmentInspectorFrame"
	detail_frame.add_theme_stylebox_override("panel",textured_panel_style(PAPER))
	add_child(detail_frame)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_frame.add_child(detail_scroll)
	detail_body = Control.new()
	detail_body.custom_minimum_size = Vector2(570,830)
	detail_scroll.add_child(detail_body)
	var close_button := action_button(detail_frame,"equipment.close","close_detail",func():detail_frame.hide())
	close_button.position = Vector2(458,14)
	close_button.size = Vector2(120,48)
	detail.icon = TextureRect.new()
	detail.icon.position = Vector2(16,8)
	detail.icon.size = Vector2(84,84)
	detail.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_body.add_child(detail.icon)
	detail.title = label(detail_body,"",Rect2(116,8,440,36),25,NAVY)
	detail.meta = label(detail_body,"",Rect2(116,50,440,34),20,NAVY)
	detail.primary = label(detail_body,"",Rect2(18,104,540,36),24,NAVY)
	detail.status = label(detail_body,"",Rect2(18,145,540,30),19,NAVY)
	detail.slots = select_box(detail_body,Rect2(18,190,535,52),[],choose_equipment)
	skin_button(detail.slots,true,true)
	detail.equip = action_button(detail_body,"equipment.confirm_free","equip_confirm",confirm_equipment,true)
	detail.equip.position = Vector2(18,254)
	detail.equip.size = Vector2(535,52)
	detail.description = label(detail_body,"",Rect2(18,326,535,70),20,NAVY)
	detail.description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_actions = GridContainer.new()
	detail_actions.columns = 3
	detail_actions.position = Vector2(18,414)
	detail_actions.add_theme_constant_override("h_separation",10)
	detail_actions.add_theme_constant_override("v_separation",10)
	detail_body.add_child(detail_actions)
	for action in ["upgrade","ten","max","remove"]:
		detail[action] = action_button(detail_actions,"equipment.action."+action,action,func():act(action),action=="upgrade")
		detail[action].custom_minimum_size.x = 171
	detail.more = action_button(detail_body,"equipment.attributes.show","toggle_stats",toggle_details)
	detail.more.position = Vector2(18,542)
	detail.more.size = Vector2(535,48)
	detail.stats = label(detail_body,"",Rect2(18,608,535,300),20,NAVY)
	detail.stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.stats.hide()
	detail.basics = label(detail_body,"",Rect2(18,608,535,180),20,NAVY)
	detail.basics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.basics.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.stats.resized.connect(update_detail_height)
	detail_frame.hide()

func layout_contents() -> void:
	if not is_inside_tree() or not is_instance_valid(detail_body):return
	var width := maxf(740,size.x)
	var height := maxf(600,size.y)
	grid_scroll.size = Vector2(width-44,height-260)
	footer.position = Vector2(22,height-80)
	footer.size = Vector2(width-44,70)
	footer.get_child(1).position.x = maxf(340,width-200)
	footer_title.size.x = maxf(280,width-250)
	# Both categories share one grid density. Narrow physical windows reduce columns.
	var logical_columns := floori((grid_scroll.size.x+14.0)/(Card.MIN_SIZE.x+14.0))
	var logical_view := get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	var window_scale := minf(window_size.x/logical_view.x,window_size.y/logical_view.y)
	var screen_scale := get_global_transform().get_scale().x*window_scale
	var physical_columns := floori((grid_scroll.size.x*screen_scale+14.0*screen_scale)/(180.0+14.0*screen_scale))
	var columns := clampi(mini(logical_columns,physical_columns),1,4)
	grid.columns = columns
	grid_defence.columns = columns
	for id in cards:
		cards[id].custom_minimum_size = Card.MIN_SIZE
		cards[id].layout_contents()
	detail_frame.position = Vector2(width-612,96)
	detail_frame.size = Vector2(590,height-190)
	detail_scroll.position = Vector2(8,76)
	detail_scroll.size = Vector2(574,height-278)

func set_upgrade_amount(amount: int) -> void:
	upgrade_amount = amount
	for i in amount_buttons.size():skin_button(amount_buttons[i],[1,10,0][i]==amount,true)
	var quotes := {}
	for id in items:
		update_card_cost(items[id],quotes)
		cards[id].refresh(items[id],selected==id)

func update_card_cost(item: Dictionary, quotes: Dictionary = {}) -> void:
	if item.locked:
		item.cost = "—"
		item.direct_upgradeable = false
		return
	# Module prices depend on category and level, not installed weapon type.
	# Share only within this synchronous refresh; no quote survives a purchase,
	# balance/config change, another refresh or a frame boundary.
	var entry: Dictionary = host.game.slot_entry(item.category,item.index)
	var quote_key := str([item.category,entry.get("level",0),upgrade_amount])
	if quotes.has(quote_key):
		item.cost = quotes[quote_key].cost
		item.direct_upgradeable = quotes[quote_key].available
		return
	var count: int = host.game.max_upgrade_amount_slot(item.category,item.index) if upgrade_amount==0 else upgrade_amount
	var costs: Dictionary = host.game.slot_upgrade_cost(item.category,item.index,maxi(1,count))
	item.cost = host.cost_text(costs)
	item.direct_upgradeable = not entry.is_empty() and count>0 and host.game.can_afford_upgrade_costs(costs)
	quotes[quote_key] = {"cost":item.cost,"available":item.direct_upgradeable}

func upgrade_card(id: String) -> void:
	if not items.has(id):return
	var item: Dictionary = items[id]
	var count: int = host.game.max_upgrade_amount_slot(item.category,item.index) if upgrade_amount==0 else upgrade_amount
	if count>0:host.game.upgrade_slot(item.category,item.index,count)
	refresh(id)

func show_inspector() -> void:
	picker_open = false
	refresh_pending()
	refresh_detail({},true)
	detail_frame.show()

func open_picker(id: String) -> void:
	refresh_pending()
	if cards.has(id) and not cards[id].name_button.disabled:
		cards[id].name_button.show_popup()

func refresh_new_weapon() -> void:
	new_weapon_id = ""
	for id in host.game.unread_tutorial_unlocks():
		var row: Dictionary = host.db.data.unlock.get(id,{})
		var key := str(row.get("target",""))
		if row.get("type","")!="equipment" or (not BattleGame.WEAPON_KEYS.has(key) and not BattleGame.DEFENSE_KEYS.has(key)) or int(row.get("level",0))<=0:continue
		if not host.game.content_unlocked("equipment",key):continue
		var category := "weapons" if BattleGame.WEAPON_KEYS.has(key) else "defence"
		if host.game.module_entries(category).any(func(entry):return str(entry.key)==key):continue
		if discovery_target(category).is_empty():continue
		new_weapon_id = id
		break
	host.set_ui_value(new_weapon,"visible",not new_weapon_id.is_empty())
	host.set_ui_value(new_weapon_dismiss,"visible",not new_weapon_id.is_empty())
	if not new_weapon_id.is_empty():
		var key := str(host.db.data.unlock[new_weapon_id].target)
		host.set_ui_value(new_weapon,"text",UIText.t("equipment.new_weapon",{"weapon":str(host.NAMES.get(key,key))}))

func discovery_target(category: String) -> String:
	if items.has(selected) and items[selected].category==category and not items[selected].locked and not items[selected].get("refit_locked",false):return selected
	for index in host.game.active_slot_count(category):
		if not host.game.slot_equipment_locked(category,index):return module_card_id(category,index)
	return ""

func show_new_weapon() -> void:
	var id := new_weapon_id
	if id.is_empty():return
	var key := str(host.db.data.unlock.get(id,{}).get("target",""))
	var target_slot: String = discovery_target("weapons" if BattleGame.WEAPON_KEYS.has(key) else "defence")
	if not cards.has(target_slot) or not cards[target_slot].equipment_options.has(key):return
	category_filter = 0
	category_picker.select(0)
	apply_filters()
	grid_scroll.ensure_control_visible(cards[target_slot])
	select_item(target_slot)
	open_picker(target_slot)
	if cards[target_slot].name_button.get_popup().visible:
		host.game.read_tutorial_unlock(id)
		refresh_new_weapon()

func dismiss_new_weapon() -> void:
	if new_weapon_id.is_empty():return
	host.game.read_tutorial_unlock(new_weapon_id)
	refresh_new_weapon()

func read_tried_equipment(key: String) -> void:
	if not BattleGame.WEAPON_KEYS.has(key) and not BattleGame.DEFENSE_KEYS.has(key):return
	var id: String = host.db.unlock_id("equipment",key)
	if not id.is_empty():host.game.read_tutorial_unlock(id)

func refit_equipment(category: String, index: int, key: String) -> void:
	var previous_key := str(host.game.slot_entry(category,index).get("key",""))
	var succeeded: bool = host.game.unequip_slot(category,index) if key.is_empty() else host.game.equip_slot(category,index,key)
	if succeeded:
		read_tried_equipment(previous_key)
		read_tried_equipment(key)

func change_card_equipment(id: String, key: String) -> void:
	if not items.has(id) or items[id].locked:return
	var item: Dictionary = items[id]
	refit_equipment(item.category,int(item.index),key)
	refresh(id)

func choose_equipment(index: int) -> void:
	if index<0 or index>=slot_options.size():return
	pending_key = str(slot_options[index])
	refresh_confirm()
	if picker_open and not detail.equip.disabled:
		change_equipment(pending_key)

func refresh_confirm() -> void:
	if not items.has(selected):return
	var item: Dictionary = items[selected]
	host.set_ui_value(detail.equip,"text",UIText.t("equipment.action.remove" if pending_key.is_empty() and not item.key.is_empty() else "equipment.confirm_free"))
	host.set_ui_value(detail.equip,"disabled",item.locked or item.get("refit_locked",false) or pending_key==item.key or (not pending_key.is_empty() and not host.game.profile.unlocked.has(pending_key)))

func confirm_equipment() -> void:
	if detail.equip.disabled:return
	change_equipment(pending_key)
	detail_frame.hide()

func get_action_anchor(action: String, slot_id := "") -> Control:
	var id := selected if slot_id.is_empty() else slot_id
	match action:
		"empty_module":return cards[id].equip_button if cards.has(id) else null
		"upgrade_action":return cards[id].upgrade_button if cards.has(id) else null
		"module_detail":return footer_buttons.details
		"swap_module":return cards[id].name_button if cards.has(id) else null
		"equip_confirm":return cards[id].name_button if cards.has(id) and cards[id].name_button.get_popup().visible else null
	return null

func toggle_details() -> void:
	details_open = not details_open
	host.set_ui_value(detail.stats,"visible",details_open)
	host.set_ui_value(detail.basics,"visible",not details_open)
	host.set_ui_value(detail.more,"text",UIText.t("equipment.attributes.hide" if details_open else "equipment.attributes.show"))
	update_detail_height()

func update_detail_height(force := false) -> void:
	if not is_instance_valid(detail_body):return
	if not force and not detail_frame.is_visible_in_tree():return
	var bottom: float = detail.stats.position.y+maxf(detail.stats.size.y,detail.stats.get_minimum_size().y) if details_open else detail.basics.position.y+maxf(detail.basics.size.y,detail.basics.get_minimum_size().y)
	host.set_ui_value(detail_body,"custom_minimum_size",Vector2(570,bottom+24))

func icon_for(key: String) -> Texture2D:
	if not icons.has(key):
		var path := "res://assets/ui/equipment/%s.svg" % (("cartoon_"+key) if key in BattleGame.EQUIPMENT else key)
		icons[key] = load(path) if ResourceLoader.exists(path) else null
	return icons[key]

func equipment_item(category: String, index: int) -> Dictionary:
	var entry: Dictionary = host.game.module_entry(category,index)
	var key := str(entry.get("key",""))
	var active: bool = index<host.game.active_slot_count(category)
	var equipped := not key.is_empty()
	var projection: Dictionary=host.equipment_display_snapshot(entry) if equipped else {"base":0.0,"expected":0.0}
	var value = projection.expected
	var name: String = host.NAMES.get(key,UIText.t("equipment.vacant"))
	var prefix := ("W" if category=="weapons" else "D")+str(index+1).pad_zeros(2)
	var description := equipment_text("description."+key.to_lower()) if equipped else UIText.t("module.empty_hint")
	return {"id":module_card_id(category,index),"key":key,"index":index,"name":prefix+" "+name,"category":category,
		"subType":"laser" if key=="longLaser" else key,"level":int(entry.level),"levelText":host.game.permanent_level_text(int(entry.level),"equipment"),
		"status":"locked" if not active else ("equipped" if equipped else "unequipped"),
		"equipped":equipped and active,"upgradeable":active and host.game.can_upgrade_slot(category,index),"locked":not active,"refit_locked":host.game.slot_equipment_locked(category,index),
		"slots":[index],"mainStatLabel":UIText.t("weapon.expected_damage" if category=="weapons" else ("defense.shield" if key=="shield" else "defense.armour")),
		"mainStatValue":host.number(value) if equipped else "—","mainStatNumber":value,"icon":icon_for(key) if equipped else null,
		"projection":projection,"description":description,"tooltip":module_tooltip(entry,prefix,name,projection)}

func module_tooltip(entry: Dictionary, prefix: String, name: String, projection: Dictionary) -> String:
	return prefix+" · "+name+" · "+UIText.t("equipment.level",{"level":host.game.permanent_level_text(int(entry.level),"equipment")})+"\n"+host.game.permanent_level_tooltip(int(entry.level),"equipment")+("\n"+host.equipment_expected_details(entry,projection,true) if BattleGame.WEAPON_KEYS.has(str(entry.key)) else "")

func refresh(only_slot := "") -> void:
	refresh_slots([] if only_slot.is_empty() else [only_slot])

func refresh_slots(changed: Array) -> void:
	if not is_visible_in_tree():
		dirty = true
		return
	var detail_changed := dirty or changed.is_empty() or changed.has(selected)
	var structure_changed := false
	# A reforge replaces the stored module array; remove only obsolete cards.
	for id in items.keys():
		var item:Dictionary=items[id]
		if not host.game.module_entry(item.category,item.index).is_empty():continue
		if cards.has(id):
			var card:Control=cards[id]
			card.get_parent().remove_child(card);card.queue_free();cards.erase(id)
		items.erase(id);stats_dirty.erase(id);structure_changed=true;sort_dirty=true
		if selected==id:
			selected="";selected_slot=-1;pending_key="";draft_context=[];picker_open=false
	var quotes := {}
	for category in ["weapons","defence"]:
		for index in host.game.module_entries(category).size():
			var id: String = module_card_id(category,index)
			if changed.is_empty() or dirty or changed.has(id) or not items.has(id):
				items[id] = equipment_item(category,index)
				stats_dirty.erase(id)
				sort_dirty = true
			if not cards.has(id):
				structure_changed = true
				var card := Card.new()
				(grid if category=="weapons" else grid_defence).add_child(card)
				card.setup(host,self)
				card.equip_requested.connect(func():open_picker(id))
				card.equipment_selected.connect(func(key: String):change_card_equipment(id,key))
				card.upgrade_requested.connect(func():upgrade_card(id))
				card.pressed.connect(func():select_item(id))
				cards[id] = card
			if selected.is_empty():selected = id
			# Spending resources changes affordability on other modules, but not their stats.
			if not (changed.is_empty() or dirty or changed.has(id)):
				items[id].upgradeable = host.game.can_upgrade_slot(category,index)
			update_card_cost(items[id],quotes)
			cards[id].refresh(items[id],selected==id)
	dirty = false
	observed_resources = host.game.profile.resources.duplicate()
	refresh_total()
	refresh_new_weapon()
	if structure_changed:layout_contents()
	apply_filters()
	if detail_changed:refresh_detail()
	else:refresh_affordability_detail()

func refresh_pending() -> void:
	if not is_visible_in_tree():return
	refresh_new_weapon()
	if dirty:
		refresh()
	elif observed_resources!=host.game.profile.resources:
		refresh_affordability()
	refresh_stats()
	if detail_dirty and detail_frame.is_visible_in_tree():refresh_detail()
func invalidate_stats(info: Dictionary) -> void:
	# Shared modifiers also change inspector text when the numeric projection is unchanged.
	if info.get("detail",false):detail_dirty=true
	if not is_visible_in_tree():
		dirty = true
		return
	if info.has("slot"):
		stats_dirty[info.slot] = true
	else:
		for id in items:
			if items[id].category==info.category:stats_dirty[id] = true

func refresh_stats() -> void:
	var selected_changed := false
	var selected_preview: Dictionary={}
	for id in stats_dirty:
		if not items.has(id):continue
		var item: Dictionary = items[id]
		var entry: Dictionary = host.game.module_entry(item.category,item.index)
		var projection: Dictionary=host.equipment_display_snapshot(entry)
		var value = projection.expected
		var projection_changed: bool=item.projection!=projection
		if selected==id and not item.key.is_empty():
			if detail_frame.is_visible_in_tree():
				selected_preview=host.equipment_display_snapshot(entry,mini(int(entry.level)+1,host.db.max_equipment_level(item.key)))
				selected_changed = selected_changed or GrowthNumber.compare(selected_preview.expected,selected_next_stat)!=0
			else:detail_dirty=true
			selected_changed = selected_changed or projection_changed
		if GrowthNumber.compare(value,item.mainStatNumber)==0 and not projection_changed:continue
		item.projection=projection
		item.tooltip=module_tooltip(entry,("W" if item.category=="weapons" else "D")+str(int(item.index)+1).pad_zeros(2),host.NAMES.get(item.key,UIText.t("equipment.vacant")),projection)
		item.mainStatNumber = value
		item.mainStatValue = host.number(value) if not item.key.is_empty() else "—"
		# A damage/probability-only event leaves its already quoted upgrade cost valid.
		cards[id].refresh(item,selected==id)
		sort_dirty = sort_dirty or sort_mode==2
		selected_changed = selected_changed or selected==id
	stats_dirty.clear()
	if sort_dirty:apply_filters()
	if selected_changed:refresh_detail(selected_preview)

func refresh_affordability() -> void:
	observed_resources = host.game.profile.resources.duplicate()
	var changed := false
	var quotes := {}
	for id in items:
		var item: Dictionary = items[id]
		var available: bool = host.game.can_upgrade_slot(item.category,item.index)
		if item.upgradeable!=available:
			item.upgradeable = available
			changed = true
		update_card_cost(item,quotes)
		cards[id].refresh(item,selected==id)
	if changed:
		sort_dirty = sort_dirty or sort_mode==3
		if sort_mode==3 or status_filter in [2,3]:apply_filters()
	refresh_affordability_detail()

func refresh_total() -> void:
	var counts: Dictionary = {}
	for category in ["weapons","defence"]:
		var active: int = host.game.active_slot_count(category)
		var used := 0
		var overflow := 0
		for item in items.values():
			if item.category!=category:continue
			if item.locked:overflow+=1
			elif item.equipped:used+=1
		counts[category] = str(used)+"/"+str(active)
		var heading: String = UIText.t("weapon.tab" if category=="weapons" else "defense.tab")+"  "+counts[category]
		if overflow>0:heading+=" · "+UIText.t("equipment.overflow",{"count":str(overflow)})
		host.set_ui_value(section_labels[category],"text",heading)
	host.set_ui_value(total,"text",UIText.data_text("ship",str(host.game.profile.selectedShip),"des")+"  ·  "+UIText.t("weapon.tab")+" "+counts.weapons+"  /  "+UIText.t("defense.tab")+" "+counts.defence)

func select_item(key: String) -> void:
	if not items.has(key):return
	var previous := selected
	selected = key
	selected_slot = int(items[key].index)
	if cards.has(previous):cards[previous].refresh(items[previous],false)
	cards[key].refresh(items[key],true)
	refresh_detail()

func apply_filters() -> void:
	if sort_dirty or last_sort_mode!=sort_mode:
		sorted_ids = items.keys()
		sorted_ids.sort_custom(func(a,b):
			var x: Dictionary = items[a]
			var y: Dictionary = items[b]
			if sort_mode==1 and x.level!=y.level:return x.level>y.level
			if sort_mode==2 and GrowthNumber.compare(x.mainStatNumber,y.mainStatNumber)!=0:return GrowthNumber.compare(x.mainStatNumber,y.mainStatNumber)>0
			if sort_mode==3:
				var sx := int(x.locked)*4+int(not x.equipped)*2-int(x.upgradeable)
				var sy := int(y.locked)*4+int(not y.equipped)*2-int(y.upgradeable)
				if sx!=sy:return sx<sy
			return int(x.index)<int(y.index))
		sort_dirty = false
		last_sort_mode = sort_mode
	var visible_count := 0
	var positions := {"weapons":0,"defence":0}
	for i in sorted_ids.size():
		var key: String = sorted_ids[i]
		var item: Dictionary = items[key]
		var show: bool = (category_filter==0 or item.category==("weapons" if category_filter==1 else "defence")) and (subtype_filter==0 or item.subType==subtypes[subtype_filter])
		show = show and (status_filter==0 or (status_filter==1 and item.equipped) or (status_filter==2 and item.upgradeable) or (status_filter==3 and not item.equipped and not item.locked) or (status_filter==4 and item.locked))
		host.set_ui_value(cards[key],"visible",show)
		visible_count += int(show)
		var parent_grid: GridContainer = grid if item.category=="weapons" else grid_defence
		var position_in_group: int = positions[item.category]
		if cards[key].get_index()!=position_in_group:
			parent_grid.move_child(cards[key],position_in_group)
		positions[item.category]+=1
	host.set_ui_value(empty,"visible",visible_count==0)
	host.set_ui_value(section_labels.weapons,"visible",category_filter!=2)
	host.set_ui_value(section_labels.defence,"visible",category_filter!=1)

func refresh_affordability_detail() -> void:
	if not items.has(selected):return
	if not detail_frame.is_visible_in_tree():
		detail_dirty=true
		return
	var item: Dictionary = items[selected]
	for action in ["upgrade","ten","max"]:
		host.set_ui_value(detail[action],"disabled",not host.game.can_upgrade_slot(item.category,item.index,10 if action=="ten" else 1))

func refresh_detail(next_projection: Dictionary = {}, force := false) -> void:
	if not items.has(selected):return
	var item: Dictionary = items[selected]
	var category: String = item.category
	selected_slot = int(item.index)
	# The page footer stays live even while the inspector is closed.
	host.set_ui_value(footer_title,"text",item.name)
	if not force and not detail_frame.is_visible_in_tree():
		detail_dirty=true
		return
	detail_dirty=false
	var entry: Dictionary = host.game.module_entry(category,selected_slot)
	var key := str(entry.key)
	if next_projection.is_empty():next_projection=host.equipment_display_snapshot(entry,mini(int(entry.level)+1,host.db.max_equipment_level(key))) if not key.is_empty() else {"expected":0.0}
	selected_next_stat = next_projection.expected
	var options := equipment_choices(category,selected_slot)
	if host.ui_state_changed(detail.slots,options):
		detail.slots.clear()
		for option in options:
			detail.slots.add_item(host.NAMES.get(option,UIText.t("equipment.vacant")))
		slot_options = options
	var context: Array = [selected,key,item.locked]
	var draft_valid: bool = options.has(pending_key)
	if draft_context!=context or not draft_valid:
		pending_key=key
		draft_context=context
	if detail.slots.selected!=options.find(pending_key):detail.slots.select(options.find(pending_key))
	refresh_confirm()
	host.set_ui_value(detail.slots,"disabled",item.locked or item.get("refit_locked",false))
	host.set_ui_value(detail.icon,"texture",item.icon)
	host.set_ui_value(detail.title,"text",item.name)
	host.set_ui_value(detail.meta,"text",UIText.t("equipment.level",{"level":host.game.permanent_level_text(int(entry.level),"equipment")})+" · "+UIText.t("weapon.tab" if category=="weapons" else "defense.tab"))
	host.set_ui_value(detail.meta,"tooltip_text",host.game.permanent_level_tooltip(int(entry.level),"equipment"))
	host.set_ui_value(detail.primary,"text",item.mainStatLabel+"  "+item.mainStatValue)
	host.set_ui_value(detail.primary,"tooltip_text",host.equipment_expected_details(entry,item.projection,true))
	host.set_ui_value(detail.status,"text",UIText.t("equipment.fixed_armour") if item.get("refit_locked",false) else UIText.t("equipment.state."+item.status)+(" · "+UIText.t("equipment.state.upgradeable") if item.upgradeable else ""))
	host.set_ui_value(detail.status,"modulate",Color("687781") if item.locked else NAVY)
	for action in ["upgrade","ten","max"]:
		host.set_ui_value(detail[action],"visible",true)
		host.set_ui_value(detail[action],"disabled",not host.game.can_upgrade_slot(category,selected_slot,10 if action=="ten" else 1))
	host.set_ui_value(detail.equip,"visible",not picker_open)
	host.set_ui_value(detail.remove,"visible",not key.is_empty())
	host.set_ui_value(detail.remove,"disabled",item.locked or item.get("refit_locked",false))
	var cost: String = host.cost_text(host.game.slot_upgrade_cost(category,selected_slot)) if not item.locked else "—"
	host.set_ui_value(detail.upgrade,"tooltip_text",UIText.t("upgrade.cost_one",{"cost":cost}))
	host.set_ui_value(detail.ten,"tooltip_text",UIText.t("upgrade.cost_ten",{"cost":host.cost_text(host.game.slot_upgrade_cost(category,selected_slot,10)) if not item.locked else "—"}))
	var description: String = ""
	if not key.is_empty():
		description=host.equipment_stat_text(entry,item.projection,next_projection)+"\n"
		if category=="weapons":description+=host.equipment_expected_details(entry,item.projection)+"\n"
		description+=host.equipment_detail_text(entry)+"\n"+equipment_attributes(entry)+"\n"
		if key=="longLaser":description=UIText.t("equipment.continuous_beam_snapshot_hint")+"\n"+description
	description += UIText.t("upgrade.cost_one",{"cost":cost})
	host.set_ui_value(detail.description,"text",item.description)
	host.set_ui_value(detail.title,"tooltip_text",detail.title.text)
	host.set_ui_value(detail.stats,"text",description)
	var row: Dictionary = host.db.equip(key,int(entry.level)) if not key.is_empty() else {}
	var basic_text := ""
	if not row.is_empty():
		if category=="weapons":basic_text=UIText.t("equipment.attack_interval",{"seconds":host.number(float(row.cd))})
		else:basic_text=UIText.t("equipment.current_reduction",{"percent":host.number(float(host.db.config.dmgReduce)*100)})
		basic_text+="\n"+equipment_attributes(entry,false)
	host.set_ui_value(detail.basics,"text",basic_text)
	host.set_ui_value(detail.stats,"tooltip_text",host.equipment_expected_details(entry,item.projection,true))
	update_detail_height(force)

func change_equipment(key: String) -> void:
	if not items.has(selected):return
	var category: String = items[selected].category
	refit_equipment(category,selected_slot,key)
	refresh(selected)

func equipment_attributes(entry: Dictionary, include_enhancement := true) -> String:
	var key: String = entry.key
	var row: Dictionary = host.db.equip(key,int(entry.level))
	var lines: Array[String] = []
	var damage_type := UIText.t("equipment.energy" if int(row.get("dmgtype",0))==1 else "equipment.physical")
	lines.append(UIText.t("equipment.attribute",{"label":UIText.t("equipment.resistance" if key in BattleGame.DEFENSE_KEYS else "equipment.damage_type"),"value":damage_type}))
	var fields: Array = []
	match key:
		"laser","cannon":fields=[["speed",float(row.para1)]]
		"missile":fields=[["salvo",int(row.para1)],["speed",float(row.para2)]]
		"longLaser":fields=[["charge_seconds",maxf(0,float(row.para3)) if row.get("para3")!=null else float(row.cd)],["ramp_seconds",float(row.para1)],["max_multiplier",float(row.para2)]]
		"shield":fields=[["recovery_percent",float(row.para2)*100],["recovery_delay",float(row.para3)]]
	for field in fields:
		lines.append(UIText.t("equipment.attribute",{"label":equipment_text("attribute."+str(field[0])),"value":host.number(float(field[1]))}))
	if include_enhancement and host.game.enhancement_unlocked():
		lines.append(UIText.t("enhance.equipment_slots",{"count":host.game.available_effect_count(entry)}))
		if is_instance_valid(host.enhancement_panel):
			for effect in host.game.enhancement_effects(entry):
				lines.append(host.enhancement_panel.effect_name(str(effect.kind))+" · "+host.enhancement_panel.effect_description(str(effect.kind)))
	return "\n".join(lines)

func act(action: String) -> void:
	if not items.has(selected) or selected_slot<0:return
	var category: String = items[selected].category
	match action:
		"upgrade","ten","max":
			var amount := 10 if action=="ten" else 1
			if action=="max":amount=host.game.max_upgrade_amount_slot(category,selected_slot)
			host.game.upgrade_slot(category,selected_slot,amount)
		"remove":host.game.unequip_slot(category,selected_slot)
	refresh(selected)
