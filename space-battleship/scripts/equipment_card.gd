extends Button
## One reusable compact equipment presentation for both categories.
var host: Node
var fields: Dictionary = {}
var picture: TextureRect
var last_state: Array = []

func setup(owner_ui: Node) -> void:
	host = owner_ui
	custom_minimum_size = Vector2(235,43)
	clip_contents = true
	picture = TextureRect.new()
	picture.position = Vector2(5,5)
	picture.size = Vector2(34,32)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	fields.title = host.equipment_card_label(self,"",Rect2(43,1,126,21),13)
	fields.level = host.equipment_card_label(self,"",Rect2(173,1,57,21),11,host.MUTED)
	fields.stat = host.equipment_card_label(self,"",Rect2(43,22,123,18),12,host.CYAN)
	fields.status = host.equipment_card_label(self,"",Rect2(169,22,63,18),11,Color.WHITE)
	fields.crew = host.equipment_card_label(self,"",Rect2(3,22,39,18),10,host.CYAN)
	for field in fields.values():
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fields.crew.mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("hover",host.style(Color("173548"),host.CYAN))
	add_theme_stylebox_override("focus",host.style(Color.TRANSPARENT,host.CYAN))

func refresh(item: Dictionary, chosen: bool) -> void:
	# Crew has its own change event; equipment levels/resources do not change this badge.
	if last_state.is_empty():refresh_crew(str(item.id))
	var state := [item.name,item.level,item.mainStatValue,item.status,item.upgradeable,item.locked,chosen,item.tooltip]
	if last_state == state:
		return
	last_state = state
	host.set_ui_value(fields.title,"text",item.name)
	host.set_ui_value(fields.level,"text",UIText.t("equipment.level",{"level":str(item.level)}))
	host.set_ui_value(fields.stat,"text",item.mainStatLabel+" "+item.mainStatValue)
	var status_key: String = "equipment.state."+("upgradeable" if item.upgradeable else item.status)
	host.set_ui_value(fields.status,"text",UIText.t(status_key))
	host.set_ui_value(fields.status,"modulate",host.ORANGE if item.upgradeable else host.MUTED)
	host.set_ui_value(self,"tooltip_text",item.tooltip)
	host.set_ui_value(picture,"texture",item.icon)
	add_theme_stylebox_override("normal",host.style(Color("183341") if chosen else Color("0c1c2b"),host.CYAN if chosen else (host.ORANGE.darkened(0.5) if item.upgradeable else host.LINE)))
	host.set_ui_value(fields.title,"modulate",host.MUTED if item.locked else Color.WHITE)

func refresh_crew(id: String) -> void:
	var badge: Dictionary = host.game.crew.badge(host.game,id)
	host.set_ui_value(fields.crew,"text",badge.text)
	host.set_ui_value(fields.crew,"tooltip_text",badge.tooltip)
