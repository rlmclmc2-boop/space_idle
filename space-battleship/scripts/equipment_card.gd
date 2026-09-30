extends Button
## One persistent card per authoritative weapon or defence module.
signal equip_requested
signal upgrade_requested
var host: Node
var panel: Control
var fields: Dictionary = {}
var picture: TextureRect
var last_state: Array = []
var upgrade_button: Button
var equip_button: Button
var slot_id := ""

func setup(owner_ui: Node, equipment_panel: Control) -> void:
	host = owner_ui
	panel = equipment_panel
	custom_minimum_size = Vector2(600,146)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	picture = TextureRect.new()
	picture.position = Vector2(18,16)
	picture.size = Vector2(76,70)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	fields.title = host.equipment_card_label(self,"",Rect2(106,14,470,32),24,panel.NAVY)
	fields.level = host.equipment_card_label(self,"",Rect2(106,52,160,28),20,panel.NAVY)
	fields.type = host.equipment_card_label(self,"",Rect2(18,105,80,25),18,panel.NAVY)
	fields.status = host.equipment_card_label(self,"",Rect2(18,101,170,28),18,panel.NAVY)
	fields.stat = host.equipment_card_label(self,"",Rect2(252,52,350,28),20,panel.NAVY)
	fields.upgrade = host.equipment_card_label(self,"",Rect2(0,0,0,0),12,panel.NAVY)
	fields.upgrade.hide()
	fields.type.hide()
	for field in fields.values():field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_button = panel.action_button(self,"equipment.action.upgrade","upgrade_action",func():upgrade_requested.emit(),true)
	upgrade_button.position = Vector2(350,92)
	upgrade_button.size = Vector2(246,44)
	upgrade_button.custom_minimum_size.y = 44
	upgrade_button.add_theme_font_size_override("font_size",18)
	equip_button = panel.action_button(self,"equipment.free_equip","empty_module",func():equip_requested.emit(),true)
	equip_button.position = Vector2(18,92)
	equip_button.custom_minimum_size.y = 44
	equip_button.size = Vector2(280,44)
	resized.connect(layout_contents)
	add_theme_stylebox_override("hover",panel.panel_style(Color("f8f7e9"),Color("519caa")))
	add_theme_stylebox_override("pressed",panel.panel_style(Color("d8e6de")))
	add_theme_stylebox_override("focus",panel.panel_style(Color.TRANSPARENT,panel.TEAL))

func layout_contents() -> void:
	fields.title.size.x = maxf(240,size.x-124)
	fields.stat.position.x = maxf(245,size.x-310)
	fields.stat.size.x = 290
	upgrade_button.position.x = size.x-250
	equip_button.size.x = maxf(190,size.x-282)

func refresh(item: Dictionary, chosen: bool) -> void:
	var state := [item.name,item.level,item.get("levelText",str(item.level)),item.category,item.mainStatLabel,item.mainStatValue,item.status,item.upgradeable,item.locked,chosen,item.tooltip,item.icon,item.get("cost",""),item.get("direct_upgradeable",false)]
	if last_state == state:return
	last_state = state
	slot_id = item.id
	set_meta("slot_id",slot_id)
	set_meta("action_id","module_select")
	upgrade_button.set_meta("slot_id",slot_id)
	equip_button.set_meta("slot_id",slot_id)
	host.set_ui_value(fields.title,"text",item.name)
	host.set_ui_value(fields.level,"text",UIText.t("equipment.level",{"level":item.get("levelText",str(item.level))}))
	host.set_ui_value(fields.type,"text",UIText.t("weapon.tab" if item.category=="weapons" else "defense.tab"))
	host.set_ui_value(fields.stat,"text",item.mainStatLabel+" "+item.mainStatValue)
	host.set_ui_value(fields.status,"text",UIText.t("equipment.dormant") if item.locked else UIText.t("equipment.selected_hint") if chosen else UIText.t("equipment.card_hint"))
	host.set_ui_value(fields.status,"visible",item.equipped or item.locked)
	host.set_ui_value(fields.upgrade,"text",UIText.t("equipment.state.upgradeable") if item.upgradeable else "")
	host.set_ui_value(self,"tooltip_text",item.tooltip)
	host.set_ui_value(picture,"texture",item.icon)
	host.set_ui_value(equip_button,"visible",not item.equipped and not item.locked)
	host.set_ui_value(upgrade_button,"disabled",not item.get("direct_upgradeable",false))
	host.set_ui_value(upgrade_button,"text",UIText.t("equipment.upgrade_cost",{"cost":item.get("cost","—")}))
	host.set_ui_value(upgrade_button,"tooltip_text",UIText.t("upgrade.cost_one",{"cost":item.get("cost","—")}))
	add_theme_stylebox_override("normal",panel.panel_style(Color("acbabd") if item.locked else Color("d2ece5") if chosen else panel.PAPER,Color("64babd") if chosen else panel.NAVY))
