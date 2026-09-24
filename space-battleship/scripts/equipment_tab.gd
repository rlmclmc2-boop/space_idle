extends Control
## Module projection; growth and equipment remain authoritative in BattleGame.
const Card = preload("res://scripts/equipment_card.gd")
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
var counts: Label
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
var selected_next_stat := 0.0
var equipment_view_mode := "compact"
var details_open := false
var expand_button: Button
var battlefield_shade: ColorRect
var transition: Tween
var filters: Control
var toolbar: Control
var sort_picker: OptionButton
var detail_scroll: ScrollContainer
var detail_body: Control
var detail_actions: GridContainer
var scroll_positions := {"compact":Vector2.ZERO,"expanded":Vector2(-1,-1)}
var restoring_scroll := false

func equipment_text(suffix: String) -> String:
	var key := "equipment."+suffix
	return UIText.t(key)

func label(parent: Control, value: String, rect: Rect2, font_size := 12, color := Color("e0ecf4")) -> Label:
	return host.equipment_card_label(parent,value,rect,font_size,color)

func select_box(parent: Control, rect: Rect2, keys: Array, callback: Callable) -> OptionButton:
	var box := OptionButton.new()
	box.position = rect.position
	box.size = rect.size
	box.fit_to_longest_item = false
	box.add_theme_font_override("font",host.font)
	box.add_theme_font_size_override("font_size",11)
	for key in keys:
		box.add_item(UIText.t(str(key)))
	box.item_selected.connect(func(index):
		box.add_theme_color_override("font_color",host.CYAN if index>0 else host.INK)
		callback.call(index))
	parent.add_child(box)
	return box

func setup(owner_ui: Node) -> void:
	host = owner_ui
	var overview := Control.new()
	overview.name = "EquipmentOverviewPanel"
	add_child(overview)
	total = label(overview,"",Rect2(10,0,48,34),28,host.CYAN)
	label(overview,UIText.t("equipment.total"),Rect2(61,0,133,18),11,host.MUTED)
	counts = label(overview,"",Rect2(61,18,159,27),10,host.MUTED)
	filters = Control.new()
	filters.name = "EquipmentFilterPanel"
	add_child(filters)
	select_box(filters,Rect2(10,46,94,25),["equipment.all","weapon.tab","defense.tab"],func(i):category_filter=i; apply_filters())
	var subtype_keys: Array = []
	for subtype in subtypes:
		subtype_keys.append("equipment.type."+subtype)
	select_box(filters,Rect2(110,46,105,25),subtype_keys,func(i):subtype_filter=i; apply_filters())
	select_box(filters,Rect2(10,77,205,25),["equipment.any_state","equipment.state.equipped","equipment.state.upgradeable","equipment.state.unequipped","equipment.state.locked"],func(i):status_filter=i; apply_filters())
	toolbar = Control.new()
	toolbar.name = "EquipmentToolbar"
	add_child(toolbar)
	label(toolbar,UIText.t("equipment.catalog"),Rect2(228,0,325,20),12,host.CYAN)
	sort_picker = select_box(toolbar,Rect2(730,0,224,22),["equipment.sort.type","equipment.sort.level","equipment.sort.stat","equipment.sort.state"],func(i):sort_mode=i; apply_filters())
	grid_scroll = ScrollContainer.new()
	grid_scroll.name = "EquipmentGrid"
	grid_scroll.position = Vector2(228,24)
	grid_scroll.size = Vector2(734,90)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",4)
	grid_scroll.add_child(grid)
	empty = label(self,UIText.t("equipment.empty"),Rect2(240,47,690,30),14,host.MUTED)
	build_detail()
	build_view_controls()
	refresh()

func build_detail() -> void:
	var scroll := ScrollContainer.new()
	detail_scroll = scroll
	scroll.name = "EquipmentDetailPanel"
	scroll.position = Vector2(975,0)
	scroll.size = Vector2(366,114)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := Control.new()
	detail_body = body
	body.custom_minimum_size = Vector2(348,315)
	scroll.add_child(body)
	detail.icon = TextureRect.new()
	detail.icon.position = Vector2(0,1)
	detail.icon.size = Vector2(48,42)
	detail.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(detail.icon)
	detail.title = label(body,"",Rect2(55,0,190,22),14,host.CYAN)
	detail.meta = label(body,"",Rect2(55,24,283,18),11,host.MUTED)
	detail.slots = select_box(body,Rect2(0,46,344,25),[],func(i):change_equipment(str(slot_options[i])))
	var actions := GridContainer.new()
	detail_actions = actions
	actions.columns = 6
	actions.position = Vector2(0,77)
	actions.add_theme_constant_override("h_separation",4)
	actions.add_theme_constant_override("v_separation",4)
	body.add_child(actions)
	for action in ["upgrade","ten","max","equip","remove","gems"]:
		var button := Button.new()
		button.text = equipment_text("action."+action)
		button.custom_minimum_size = Vector2(48,27)
		button.add_theme_font_override("font",host.font)
		button.add_theme_font_size_override("font_size",11)
		host.skin_equipment_button(button,action=="upgrade")
		button.pressed.connect(func():act(action))
		actions.add_child(button)
		detail[action] = button
	detail.more = Button.new()
	detail.more.position = Vector2(250,0)
	detail.more.size = Vector2(94,23)
	detail.more.text = UIText.t("equipment.details.open")
	detail.more.add_theme_font_override("font",host.font)
	detail.more.add_theme_font_size_override("font_size",11)
	detail.more.pressed.connect(toggle_details)
	body.add_child(detail.more)
	detail.description = label(body,"",Rect2(0,111,340,70),12,host.INK)
	detail.description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.stats = label(body,"",Rect2(0,190,340,400),12,host.INK)
	detail.stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.stats.visible = false
	detail.stats.resized.connect(update_detail_height)

func build_view_controls() -> void:
	battlefield_shade = ColorRect.new()
	battlefield_shade.name = "EquipmentBattlefieldShade"
	battlefield_shade.position = Vector2(38,84)
	battlefield_shade.size = Vector2(1364,530)
	battlefield_shade.color = Color(0,0,0,0)
	battlefield_shade.visible = false
	host.ui.add_child(battlefield_shade)
	host.ui.move_child(battlefield_shade,host.equipment_tabs.get_index())
	expand_button = Button.new()
	expand_button.position = Vector2(1250,1)
	expand_button.size = Vector2(100,26)
	expand_button.text = UIText.t("equipment.view.expand")
	expand_button.add_theme_font_override("font",host.font)
	expand_button.add_theme_font_size_override("font_size",13)
	expand_button.pressed.connect(func():set_view_mode("expanded" if equipment_view_mode=="compact" else "compact"))
	host.equipment_tabs.get_tab_bar().add_child(expand_button)
	visibility_changed.connect(sync_auxiliary)
	resized.connect(layout_contents)
	sync_auxiliary()
	layout_contents()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and equipment_view_mode=="expanded" and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		set_view_mode("compact")
		get_viewport().set_input_as_handled()

func remember_scroll() -> void:
	if not restoring_scroll:
		scroll_positions[equipment_view_mode] = Vector2(grid_scroll.scroll_vertical,detail_scroll.scroll_vertical)

func stop_transition() -> void:
	if is_instance_valid(transition):
		transition.kill()
	transition = null

func set_view_mode(mode: String) -> void:
	if mode not in ["compact","expanded"] or mode==equipment_view_mode:
		return
	remember_scroll()
	if scroll_positions[mode].x<0:
		scroll_positions[mode] = scroll_positions[equipment_view_mode]
	equipment_view_mode = mode
	apply_view_layout(true)

func apply_view_layout(animated: bool) -> void:
	stop_transition()
	restoring_scroll = true
	var expanded := equipment_view_mode=="expanded"
	if expanded:
		# Keep expanded equipment above battlefield controls, below the existing gem panel.
		host.ui.move_child(battlefield_shade,-1)
		host.ui.move_child(host.equipment_tabs,-1)
		if is_instance_valid(host.jewel_panel):host.ui.move_child(host.jewel_panel,-1)
	var destination := Vector2(38,120 if expanded else 620)
	var dimensions := Vector2(1364,656 if expanded else 156)
	host.set_ui_value(expand_button,"text",UIText.t("equipment.view.collapse" if expanded else "equipment.view.expand"))
	battlefield_shade.visible = is_visible_in_tree()
	layout_contents()
	if animated:
		transition = create_tween().set_parallel(true)
		transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		transition.tween_property(host.equipment_tabs,"position",destination,0.2)
		transition.tween_property(host.equipment_tabs,"size",dimensions,0.2)
		transition.tween_property(battlefield_shade,"color:a",0.55 if expanded else 0.0,0.2)
		transition.chain().tween_callback(finish_layout)
	else:
		host.set_ui_value(host.equipment_tabs,"position",destination)
		host.set_ui_value(host.equipment_tabs,"size",dimensions)
		battlefield_shade.color.a = 0.55 if expanded else 0.0
		finish_layout.call_deferred()

func finish_layout() -> void:
	transition = null
	layout_contents()
	# Scroll ranges settle after container sorting; restore mode-local offsets afterwards.
	restore_scroll.call_deferred()
	sync_auxiliary()

func restore_scroll() -> void:
	var saved: Vector2 = scroll_positions[equipment_view_mode]
	grid_scroll.scroll_vertical = int(saved.x)
	detail_scroll.scroll_vertical = int(saved.y)
	restoring_scroll = false

func sync_auxiliary() -> void:
	if not is_instance_valid(expand_button):return
	var shown := is_visible_in_tree()
	host.set_ui_value(expand_button,"visible",shown)
	if not shown:
		remember_scroll()
		stop_transition()
		restoring_scroll = false
	host.set_ui_value(battlefield_shade,"visible",shown and (equipment_view_mode=="expanded" or (is_instance_valid(transition) and transition.is_running())))

func layout_contents() -> void:
	if not is_instance_valid(detail_body):return
	var expanded := equipment_view_mode=="expanded"
	var height := maxf(90,size.y-6)
	grid.columns = 4 if expanded else 3
	grid_scroll.position = Vector2(150 if expanded else 228,24)
	grid_scroll.size = Vector2(972 if expanded else 734,height-24)
	sort_picker.position.x = 886 if expanded else 730
	toolbar.get_child(0).position.x = 150 if expanded else 228
	counts.position = Vector2(10,35) if expanded else Vector2(61,18)
	counts.size = Vector2(130,40) if expanded else Vector2(159,27)
	counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if expanded else TextServer.AUTOWRAP_OFF
	for index in filters.get_child_count():
		var box: Control = filters.get_child(index)
		box.position = Vector2(10,82+index*32) if expanded else [Vector2(10,46),Vector2(110,46),Vector2(10,77)][index]
		box.size = Vector2(130,26) if expanded else [Vector2(94,25),Vector2(105,25),Vector2(205,25)][index]
	detail_scroll.position.x = 1124 if expanded else 975
	detail_scroll.size = Vector2(217 if expanded else 366,height)
	var width := 198.0 if expanded else 340.0
	detail_body.custom_minimum_size.x = width+4
	detail.icon.position.y = 30 if expanded else 1
	detail.title.position = Vector2(55,30 if expanded else 0)
	detail.title.size = Vector2(width-55 if expanded else 190,44 if expanded else 22)
	detail.title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if expanded else TextServer.AUTOWRAP_OFF
	detail.more.position = Vector2(0,0) if expanded else Vector2(250,0)
	detail.more.size.x = width if expanded else 94
	detail.meta.position = Vector2(0,78) if expanded else Vector2(55,24)
	detail.meta.size = Vector2(width if expanded else 283,40 if expanded else 36)
	detail.meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if expanded else TextServer.AUTOWRAP_OFF
	detail.slots.position.y = 123 if expanded else 46
	detail.slots.size.x = width if expanded else 344
	detail_actions.position.y = 157 if expanded else 77
	detail_actions.columns = 3 if expanded else 6
	detail.description.position.y = 255 if expanded else 123
	detail.description.size = Vector2(width,90)
	detail.stats.position.y = 354 if expanded else 222
	detail.stats.size.x = width
	empty.position.x = grid_scroll.position.x+12
	update_detail_height()

func toggle_details() -> void:
	details_open = not details_open
	host.set_ui_value(detail.stats,"visible",details_open)
	host.set_ui_value(detail.more,"text",UIText.t("equipment.details.close" if details_open else "equipment.details.open"))
	update_detail_height()

func update_detail_height() -> void:
	if not is_instance_valid(detail_body):return
	var bottom: float = detail.description.position.y+detail.description.size.y
	if details_open:bottom = detail.stats.position.y+maxf(detail.stats.size.y,detail.stats.get_minimum_size().y)
	host.set_ui_value(detail_body,"custom_minimum_size",Vector2(detail_body.custom_minimum_size.x,bottom+12))

func icon_for(key: String) -> Texture2D:
	if not icons.has(key):
		if host.SLOT_TEXTURES.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = host.SLOT_TEXTURES[key]
			atlas.region = host.module_regions[key]
			icons[key] = atlas
		else:
			var path := "res://assets/ui/equipment/%s.svg" % key
			icons[key] = load(path) if ResourceLoader.exists(path) else null
	return icons[key]

func equipment_item(category: String, index: int) -> Dictionary:
	var entry: Dictionary = host.game.module_entry(category,index)
	var key := str(entry.get("key",""))
	var active: bool = index<host.game.active_slot_count(category)
	var equipped := not key.is_empty()
	var value: float = host.game.jewel_equipment_stat(entry) if equipped else 0.0
	var name: String = host.NAMES.get(key,UIText.t("equipment.vacant"))
	var prefix := ("W" if category=="weapons" else "D")+str(index+1).pad_zeros(2)
	var description := equipment_text("description."+key.to_lower()) if equipped else UIText.t("module.empty_hint")
	return {"id":host.game.slot_id(category,index),"key":key,"index":index,"name":prefix+" "+name,"category":category,
		"subType":"laser" if key=="longLaser" else key,"level":int(entry.level),
		"status":"locked" if not active else ("equipped" if equipped else "unequipped"),
		"equipped":equipped and active,"upgradeable":active and host.game.can_upgrade_slot(category,index),"locked":not active,
		"slots":[index],"mainStatLabel":UIText.t("weapon.damage" if category=="weapons" else ("defense.shield" if key=="shield" else "defense.armour")),
		"mainStatValue":host.number(value) if equipped else "—","mainStatNumber":value,"icon":icon_for(key) if equipped else null,
		"description":description,"tooltip":prefix+" · "+name+" · "+UIText.t("equipment.level",{"level":str(entry.level)})}

func refresh(only_slot := "") -> void:
	refresh_slots([] if only_slot.is_empty() else [only_slot])

func refresh_slots(changed: Array) -> void:
	if not is_visible_in_tree():
		dirty = true
		return
	var detail_changed := dirty or changed.is_empty() or changed.has(selected)
	for category in ["weapons","defence"]:
		for index in host.game.module_entries(category).size():
			var id: String = host.game.slot_id(category,index)
			if changed.is_empty() or dirty or changed.has(id) or not items.has(id):
				items[id] = equipment_item(category,index)
				stats_dirty.erase(id)
				sort_dirty = true
			if not cards.has(id):
				var card := Card.new()
				grid.add_child(card)
				card.setup(host)
				card.pressed.connect(func():select_item(id))
				cards[id] = card
			if selected.is_empty():selected = id
			# Spending resources changes affordability on other modules, but not their stats.
			if not (changed.is_empty() or dirty or changed.has(id)):
				items[id].upgradeable = host.game.can_upgrade_slot(category,index)
			cards[id].refresh(items[id],selected==id)
	dirty = false
	observed_resources = host.game.profile.resources.duplicate()
	refresh_counts()
	apply_filters()
	if detail_changed:refresh_detail()
	else:refresh_affordability_detail()

func refresh_pending() -> void:
	if not is_visible_in_tree():return
	if dirty:
		refresh()
	elif observed_resources!=host.game.profile.resources:
		refresh_affordability()
	refresh_stats()
func invalidate_stats(info: Dictionary) -> void:
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
	for id in stats_dirty:
		if not items.has(id):continue
		var item: Dictionary = items[id]
		var entry: Dictionary = host.game.module_entry(item.category,item.index)
		var value: float = host.game.jewel_equipment_stat(entry)
		if selected==id and not item.key.is_empty():
			var next_value: float = host.game.jewel_equipment_stat(entry,mini(int(entry.level)+1,host.db.max_equipment_level(item.key)))
			selected_changed = selected_changed or next_value!=selected_next_stat
		if value==item.mainStatNumber:continue
		item.mainStatNumber = value
		item.mainStatValue = host.number(value) if not item.key.is_empty() else "—"
		cards[id].refresh(item,selected==id)
		sort_dirty = sort_dirty or sort_mode==2
		selected_changed = selected_changed or selected==id
	stats_dirty.clear()
	if sort_dirty:apply_filters()
	if selected_changed:refresh_detail()

func refresh_affordability() -> void:
	observed_resources = host.game.profile.resources.duplicate()
	var changed := false
	for id in items:
		var item: Dictionary = items[id]
		var available: bool = host.game.can_upgrade_slot(item.category,item.index)
		if item.upgradeable==available:continue
		item.upgradeable = available
		cards[id].refresh(item,selected==id)
		changed = true
	if changed:
		sort_dirty = sort_dirty or sort_mode==3
		refresh_counts()
		if sort_mode==3 or status_filter in [2,3]:apply_filters()
	refresh_affordability_detail()

func refresh_counts() -> void:
	var equipped := 0
	var upgrades := 0
	var locked := 0
	for item in items.values():
		equipped += int(item.equipped)
		upgrades += int(item.upgradeable)
		locked += int(item.locked)
	host.set_ui_value(total,"text",str(items.size()))
	host.set_ui_value(counts,"text",UIText.t("equipment.counts",{"equipped":str(equipped),"upgradeable":str(upgrades),"locked":str(locked)}))

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
			if sort_mode==2 and x.mainStatNumber!=y.mainStatNumber:return x.mainStatNumber>y.mainStatNumber
			if sort_mode==3:
				var sx := int(x.locked)*4+int(not x.equipped)*2-int(x.upgradeable)
				var sy := int(y.locked)*4+int(not y.equipped)*2-int(y.upgradeable)
				if sx!=sy:return sx<sy
			return str(x.category)+str(x.subType)+str(a)<str(y.category)+str(y.subType)+str(b))
		sort_dirty = false
		last_sort_mode = sort_mode
	var visible_count := 0
	for i in sorted_ids.size():
		var key: String = sorted_ids[i]
		var item: Dictionary = items[key]
		var show: bool = (category_filter==0 or item.category==("weapons" if category_filter==1 else "defence")) and (subtype_filter==0 or item.subType==subtypes[subtype_filter])
		show = show and (status_filter==0 or (status_filter==1 and item.equipped) or (status_filter==2 and item.upgradeable) or (status_filter==3 and not item.equipped and not item.locked) or (status_filter==4 and item.locked))
		host.set_ui_value(cards[key],"visible",show)
		visible_count += int(show)
		if cards[key].get_index()!=i:
			grid.move_child(cards[key],i)
	host.set_ui_value(empty,"visible",visible_count==0)

func refresh_affordability_detail() -> void:
	if not items.has(selected):return
	var item: Dictionary = items[selected]
	for action in ["upgrade","ten","max"]:
		host.set_ui_value(detail[action],"disabled",not host.game.can_upgrade_slot(item.category,item.index,10 if action=="ten" else 1))

func refresh_detail() -> void:
	if not items.has(selected):return
	var item: Dictionary = items[selected]
	var category: String = item.category
	selected_slot = int(item.index)
	var entry: Dictionary = host.game.module_entry(category,selected_slot)
	var key := str(entry.key)
	selected_next_stat = host.game.jewel_equipment_stat(entry,mini(int(entry.level)+1,host.db.max_equipment_level(key))) if not key.is_empty() else 0.0
	var options: Array = [""]
	options.append_array(BattleGame.WEAPON_KEYS if category=="weapons" else BattleGame.DEFENSE_KEYS)
	if host.ui_state_changed(detail.slots,[options,host.game.profile.unlocked]):
		detail.slots.clear()
		for option in options:
			detail.slots.add_item(host.NAMES.get(option,UIText.t("equipment.vacant")))
			detail.slots.set_item_disabled(detail.slots.item_count-1,not str(option).is_empty() and not host.game.profile.unlocked.has(option))
		slot_options = options
	if detail.slots.selected!=options.find(key):detail.slots.select(options.find(key))
	host.set_ui_value(detail.slots,"disabled",item.locked)
	host.set_ui_value(detail.icon,"texture",item.icon)
	host.set_ui_value(detail.title,"text",item.name)
	host.set_ui_value(detail.meta,"text",UIText.t("equipment.level",{"level":str(entry.level)})+" · "+UIText.t("weapon.tab" if category=="weapons" else "defense.tab")+" · "+item.mainStatLabel+" "+item.mainStatValue)
	for action in ["upgrade","ten","max"]:
		host.set_ui_value(detail[action],"visible",true)
		host.set_ui_value(detail[action],"disabled",not host.game.can_upgrade_slot(category,selected_slot,10 if action=="ten" else 1))
	host.set_ui_value(detail.equip,"visible",false)
	host.set_ui_value(detail.remove,"visible",not key.is_empty())
	host.set_ui_value(detail.remove,"disabled",item.locked)
	host.set_ui_value(detail.gems,"visible",host.game.jewels_unlocked())
	host.set_ui_value(detail.gems,"disabled",false)
	var cost: String = host.cost_text(host.game.slot_upgrade_cost(category,selected_slot)) if not item.locked else "—"
	host.set_ui_value(detail.upgrade,"tooltip_text",UIText.t("upgrade.cost_one",{"cost":cost}))
	host.set_ui_value(detail.ten,"tooltip_text",UIText.t("upgrade.cost_ten",{"cost":host.cost_text(host.game.slot_upgrade_cost(category,selected_slot,10)) if not item.locked else "—"}))
	var description: String = UIText.t("module.dormant_hint" if item.locked else "module.keep_hint")
	if not key.is_empty():description = host.equipment_stat_text(entry)+"\n"+host.equipment_detail_text(entry)+"\n"+equipment_attributes(entry)+"\n"+description
	description += "\n"+UIText.t("upgrade.cost_one",{"cost":cost})
	host.set_ui_value(detail.description,"text",item.description+"\n"+UIText.t("module.dormant_hint" if item.locked else "module.keep_hint"))
	host.set_ui_value(detail.title,"tooltip_text",detail.title.text)
	host.set_ui_value(detail.stats,"text",description)
	update_detail_height()

func change_equipment(key: String) -> void:
	if not items.has(selected):return
	var category: String = items[selected].category
	if key.is_empty():host.game.unequip_slot(category,selected_slot)
	else:host.game.equip_slot(category,selected_slot,key)
	refresh(selected)

func equipment_attributes(entry: Dictionary) -> String:
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
	lines.append(UIText.t("module.unlock_condition",{"level":str(host.db.unlock_level(key))}))
	lines.append(UIText.t("module.keep_hint"))
	lines.append(UIText.t("equipment.sockets",{"count":str(host.game.equipment_socket_count(entry))}))
	if is_instance_valid(host.jewel_panel):
		for gem in entry.get("sockets",[]):
			if not gem.is_empty():lines.append(host.jewel_panel.gem_name(gem)+" · "+host.jewel_panel.gem_description(gem))
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
		"gems":host.jewel_panel.open(category,selected_slot)
	refresh(selected)
