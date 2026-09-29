extends Button
## Equipment overview card shared by weapon and defence slots.
var host: Node
var fields: Dictionary = {}
var picture: TextureRect
var last_state: Array = []

func setup(owner_ui: Node) -> void:
	host = owner_ui
	custom_minimum_size = Vector2(426,170)
	clip_contents = true
	picture = TextureRect.new()
	picture.position = Vector2(15,15)
	picture.size = Vector2(66,62)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	fields.title = host.equipment_card_label(self,"",Rect2(92,12,321,28),18)
	fields.level = host.equipment_card_label(self,"",Rect2(92,43,165,23),13,host.MUTED)
	fields.type = host.equipment_card_label(self,"",Rect2(286,43,125,23),12,host.MUTED)
	fields.status = host.equipment_card_label(self,"",Rect2(92,76,208,26),14,host.CYAN)
	fields.stat = host.equipment_card_label(self,"",Rect2(16,116,390,29),16,host.CYAN)
	fields.upgrade = host.equipment_card_label(self,"",Rect2(275,76,135,26),12,host.ORANGE)
	for field in fields.values():
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("hover",host.style(Color("173548"),host.CYAN))
	add_theme_stylebox_override("focus",host.style(Color.TRANSPARENT,host.CYAN))

func refresh(item: Dictionary, chosen: bool) -> void:
	var state := [item.name,item.level,item.get("levelText",str(item.level)),item.category,item.mainStatLabel,item.mainStatValue,item.status,item.upgradeable,item.locked,chosen,item.tooltip,item.icon]
	if last_state == state:
		return
	last_state = state
	host.set_ui_value(fields.title,"text",item.name)
	host.set_ui_value(fields.level,"text",UIText.t("equipment.level",{"level":item.get("levelText",str(item.level))}))
	host.set_ui_value(fields.type,"text",UIText.t("weapon.tab" if item.category=="weapons" else "defense.tab"))
	host.set_ui_value(fields.stat,"text",item.mainStatLabel+" "+item.mainStatValue)
	host.set_ui_value(fields.status,"text",UIText.t("equipment.state."+item.status))
	host.set_ui_value(fields.status,"modulate",host.MUTED if item.locked else host.CYAN if item.equipped else host.INK)
	host.set_ui_value(fields.upgrade,"text",UIText.t("equipment.state.upgradeable") if item.upgradeable else "")
	host.set_ui_value(self,"tooltip_text",item.tooltip)
	host.set_ui_value(picture,"texture",item.icon)
	add_theme_stylebox_override("normal",host.style(Color("183341") if chosen else Color("0c1c2b"),host.CYAN if chosen else (host.ORANGE.darkened(0.5) if item.upgradeable else host.LINE)))
	host.set_ui_value(fields.title,"modulate",host.MUTED if item.locked else Color.WHITE)
