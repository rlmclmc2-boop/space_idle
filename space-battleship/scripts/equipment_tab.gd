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
var details_open := true
var filters: Control
var toolbar: Control
var sort_picker: OptionButton
var detail_scroll: ScrollContainer
var detail_frame: Panel
var detail_body: Control
var detail_actions: GridContainer

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
	box.add_theme_font_size_override("font_size",14)
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
	total = label(overview,"",Rect2(18,14,48,40),30,host.CYAN)
	label(overview,UIText.t("equipment.total"),Rect2(70,17,130,26),15,host.INK)
	counts = label(overview,"",Rect2(18,64,720,24),13,host.MUTED)
	filters = Control.new()
	filters.name = "EquipmentFilterPanel"
	add_child(filters)
	select_box(filters,Rect2(210,18,168,38),["equipment.all","weapon.tab","defense.tab"],func(i):category_filter=i; apply_filters())
	var subtype_keys: Array = []
	for subtype in subtypes:
		subtype_keys.append("equipment.type."+subtype)
	select_box(filters,Rect2(390,18,168,38),subtype_keys,func(i):subtype_filter=i; apply_filters())
	select_box(filters,Rect2(570,18,206,38),["equipment.any_state","equipment.state.equipped","equipment.state.upgradeable","equipment.state.unequipped","equipment.state.locked"],func(i):status_filter=i; apply_filters())
	toolbar = Control.new()
	toolbar.name = "EquipmentToolbar"
	add_child(toolbar)
	label(toolbar,UIText.t("equipment.catalog"),Rect2(18,94,300,24),14,host.CYAN)
	sort_picker = select_box(toolbar,Rect2(790,18,220,38),["equipment.sort.type","equipment.sort.level","equipment.sort.stat","equipment.sort.state"],func(i):sort_mode=i; apply_filters())
	grid_scroll = ScrollContainer.new()
	grid_scroll.name = "EquipmentGrid"
	grid_scroll.position = Vector2(14,130)
	grid_scroll.size = Vector2(892,90)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid_scroll.add_child(grid)
	empty = label(self,UIText.t("equipment.empty"),Rect2(32,150,840,32),16,host.MUTED)
	build_detail()
	resized.connect(layout_contents)
	layout_contents()
	refresh()

func build_detail() -> void:
	detail_frame = Panel.new()
	detail_frame.name = "EquipmentInspectorFrame"
	detail_frame.position = Vector2(920,118)
	detail_frame.add_theme_stylebox_override("panel",host.style(Color("101e2c"),host.LINE))
	add_child(detail_frame)
	var scroll := ScrollContainer.new()
	detail_scroll = scroll
	scroll.name = "EquipmentDetailPanel"
	scroll.position = Vector2(932,130)
	scroll.size = Vector2(406,114)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := Control.new()
	detail_body = body
	body.custom_minimum_size = Vector2(388,1030)
	scroll.add_child(body)
	detail.icon = TextureRect.new()
	detail.icon.position = Vector2(18,12)
	detail.icon.size = Vector2(80,80)
	detail.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(detail.icon)
	detail.title = label(body,"",Rect2(112,15,268,35),22,host.CYAN)
	detail.meta = label(body,"",Rect2(112,52,270,50),14,host.MUTED)
	detail.meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.primary = label(body,"",Rect2(18,125,366,32),18,host.INK)
	detail.status = label(body,"",Rect2(18,164,366,30),14,host.CYAN)
	detail.description = label(body,"",Rect2(18,211,365,115),14,host.INK)
	detail.description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.slots = select_box(body,Rect2(18,756,365,38),[],func(i):change_equipment(str(slot_options[i])))
	var actions := GridContainer.new()
	detail_actions = actions
	actions.columns = 3
	actions.position = Vector2(18,810)
	actions.add_theme_constant_override("h_separation",8)
	actions.add_theme_constant_override("v_separation",8)
	body.add_child(actions)
	for action in ["upgrade","ten","max","equip","remove","gems"]:
		var button := Button.new()
		button.text = equipment_text("action."+action)
		button.custom_minimum_size = Vector2(115,42)
		button.add_theme_font_override("font",host.font)
		button.add_theme_font_size_override("font_size",13)
		host.skin_equipment_button(button,action=="upgrade")
		button.pressed.connect(func():act(action))
		actions.add_child(button)
		detail[action] = button
	detail.more = Button.new()
	detail.more.position = Vector2(18,339)
	detail.more.size = Vector2(365,36)
	detail.more.text = UIText.t("equipment.details.open")
	detail.more.add_theme_font_override("font",host.font)
	detail.more.add_theme_font_size_override("font_size",11)
	detail.more.pressed.connect(toggle_details)
	body.add_child(detail.more)
	detail.stats = label(body,"",Rect2(18,391,365,345),16,host.INK)
	detail.stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.stats.visible = true
	detail.stats.resized.connect(update_detail_height)

func layout_contents() -> void:
	if not is_instance_valid(detail_body):return
	var height := maxf(440,size.y)
	grid_scroll.size.y = height-142
	detail_frame.size = Vector2(430,height-130)
	detail_scroll.size.y = height-154

func toggle_details() -> void:
	details_open = not details_open
	host.set_ui_value(detail.stats,"visible",details_open)
	host.set_ui_value(detail.more,"text",UIText.t("equipment.details.close" if details_open else "equipment.details.open"))
	update_detail_height()

func update_detail_height() -> void:
	if not is_instance_valid(detail_body):return
	var stats_bottom: float = detail.stats.position.y+maxf(detail.stats.size.y,detail.stats.get_minimum_size().y)
	var slots_y: float = maxf(756,stats_bottom+20) if details_open else 405.0
	host.set_ui_value(detail.slots,"position",Vector2(18,slots_y))
	host.set_ui_value(detail_actions,"position",Vector2(18,slots_y+54))
	var bottom: float = detail_actions.position.y+maxf(100,detail_actions.get_minimum_size().y)
	host.set_ui_value(detail_body,"custom_minimum_size",Vector2(detail_body.custom_minimum_size.x,maxf(600,bottom+16)))

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
	host.set_ui_value(detail.meta,"text",UIText.t("equipment.level",{"level":str(entry.level)})+" · "+UIText.t("weapon.tab" if category=="weapons" else "defense.tab"))
	host.set_ui_value(detail.primary,"text",item.mainStatLabel+"  "+item.mainStatValue)
	host.set_ui_value(detail.status,"text",UIText.t("equipment.state."+item.status)+(" · "+UIText.t("equipment.state.upgradeable") if item.upgradeable else ""))
	host.set_ui_value(detail.status,"modulate",host.MUTED if item.locked else host.ORANGE if item.upgradeable else host.CYAN)
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
