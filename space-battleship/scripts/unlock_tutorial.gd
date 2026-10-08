extends Control
## Tutorial archive projects authoritative unlock rows; only explicit entry clicks read.
const SYSTEMS := ["equipment","ships","hightech","reactor","enhancement","crew","planets","galaxy","hyperspace","other"]
var host: Node
var showing_archive := false
var system := "equipment"
var selected := ""
var tabs: HBoxContainer
var archive_button: Button
var entry_badge: Label
var archive_badge: Label
var content: HBoxContainer
var categories: VBoxContainer
var entries: VBoxContainer
var details: VBoxContainer
var detail_scroll: ScrollContainer
var title: Label
var description: Label
var category_buttons := {}
var entry_buttons := {}
var snapshot: Array = []

func setup(owner: Node) -> void:
	host = owner
	name = "UnlockTutorial"
	z_index = 3
	mouse_filter = MOUSE_FILTER_IGNORE
	entry_badge = dot(host.help_button)
	entry_badge.position = Vector2(132,4)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	add_child(tabs)
	make_button(tabs,UIText.t("tutorial.basics"),func():set_archive(false))
	archive_button = make_button(tabs,UIText.t("tutorial.unlocks"),func():set_archive(true))
	archive_badge = dot(archive_button)
	archive_badge.position = Vector2(142,4)
	content = HBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	add_child(content)
	categories = VBoxContainer.new()
	categories.custom_minimum_size.x = 140
	content.add_child(categories)
	for id in SYSTEMS:
		var button := make_button(categories,UIText.t("tutorial.system."+id),select_system.bind(id))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(140,32)
		var badge := dot(button)
		badge.position = Vector2(122,3)
		category_buttons[id] = {"button":button,"badge":badge}
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(210,365)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(list_scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = SIZE_EXPAND_FILL
	list_scroll.add_child(entries)
	detail_scroll = ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(340,365)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(detail_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",18)
	detail_scroll.add_child(details)
	title = text_label(details,24)
	description = text_label(details,18)
	refresh()

func text_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",host.SHELL_PRESENTATION.NAVY)
	parent.add_child(label)
	return label

func make_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(166,36)
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(callback)
	parent.add_child(button)
	preload("res://scripts/dialog_presentation.gd").button_skin(button)
	return button

func dot(parent: Node) -> Label:
	var label := Label.new()
	label.text = "●"
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color("e24949"))
	parent.add_child(label)
	return label

func row_system(row: Dictionary) -> String:
	match str(row.get("type","")):
		"equipment":return "equipment"
		"ship":return "ships"
		"hightech":return "hightech"
		"reactor_module":return "reactor"
		"crew":return "crew"
		"planet":return "planets"
		"feature":
			match str(row.get("target","")):
				"reactor":return "reactor"
				"jewels":return "enhancement"
				"crew_level":return "crew"
				"galaxy":return "galaxy"
				"hyperspace":return "hyperspace"
	return "other"

func set_archive(enabled: bool) -> void:
	showing_archive = enabled
	refresh()
	host.overlay_layer.queue_redraw()
	host.beginner_guide.refresh()

func select_system(id: String) -> void:
	system = id
	selected = ""
	snapshot = []
	refresh()

func open_entry(id: String) -> void:
	if not content.is_visible_in_tree() or not host.game.tutorial_unlocks().has(id):return
	selected = id
	# Fill the authoritative content before committing the read flag.
	refresh_detail()
	detail_scroll.scroll_vertical = 0
	host.game.read_tutorial_unlock(id)
	refresh()

func refresh_detail() -> void:
	show_detail(host.game.tutorial_unlock_row(selected))

func show_detail(row: Dictionary) -> void:
	host.set_ui_value(title,"text",str(row.get("title","")))
	host.set_ui_value(description,"text",str(row.get("desc",UIText.t("tutorial.select_entry"))))

func refresh() -> void:
	if not is_instance_valid(host):return
	var ids: Array[String] = host.game.tutorial_unlocks()
	var unread: Array[String] = host.game.unread_tutorial_unlocks()
	host.set_ui_value(entry_badge,"visible",not unread.is_empty())
	host.set_ui_value(archive_badge,"visible",not unread.is_empty())
	var opened: bool = host.help_open and host.game.pending_unlocks.is_empty()
	host.set_ui_value(tabs,"visible",opened)
	host.set_ui_value(content,"visible",opened and showing_archive)
	if not opened:return
	var rect: Rect2 = host.overlay_panel_rect(Vector2(820,551))
	var scale_value := rect.size.x/820.0
	host.set_ui_value(tabs,"position",rect.position-host.ui.position+Vector2(400,24)*scale_value)
	host.set_ui_value(tabs,"scale",Vector2.ONE*scale_value)
	host.set_ui_value(content,"position",rect.position-host.ui.position+Vector2(50,90)*scale_value)
	host.set_ui_value(content,"scale",Vector2.ONE*scale_value)
	if not showing_archive:return
	# IDs already passed tutorial_unlocks eligibility. Read their current config rows
	# directly; only the synthetic entry needs the domain projection. No cross-frame cache.
	var definitions: Dictionary = host.game.db.data.get("unlock",{})
	var rows: Dictionary = {}
	var grouped: Dictionary = {}
	var unread_ids: Dictionary = {}
	var unread_systems: Dictionary = {}
	for id in unread:unread_ids[id] = true
	for id in ids:
		var row: Dictionary = host.game.tutorial_unlock_row(id) if id=="hyperspace" else definitions.get(id,{})
		rows[id] = row
		var category := row_system(row)
		if not grouped.has(category):grouped[category] = []
		grouped[category].append(id)
		if unread_ids.has(id):unread_systems[category] = true
	for id in SYSTEMS:
		host.set_ui_value(category_buttons[id].button,"visible",grouped.has(id))
		host.set_ui_value(category_buttons[id].button,"button_pressed",system==id)
		host.set_ui_value(category_buttons[id].badge,"visible",unread_systems.has(id))
	if not grouped.has(system) and not ids.is_empty():system = row_system(rows[ids[0]])
	var filtered: Array = grouped.get(system,[])
	# Reconcile only archive entries. Existing controls and scroll survive reads.
	if snapshot != filtered:
		for id in entry_buttons.keys():
			if not filtered.has(id):
				entries.remove_child(entry_buttons[id].button)
				entry_buttons[id].button.queue_free()
				entry_buttons.erase(id)
		for id in filtered:
			if entry_buttons.has(id):continue
			var row: Dictionary = rows[id]
			var button := make_button(entries,str(row.get("title","")),open_entry.bind(id))
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(192,48)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var badge := dot(button)
			badge.position = Vector2(178,3)
			entry_buttons[id] = {"button":button,"badge":badge}
		snapshot = filtered.duplicate()
	for id in entry_buttons:
		host.set_ui_value(entry_buttons[id].badge,"visible",unread_ids.has(id))
		host.set_ui_value(entry_buttons[id].button,"button_pressed",selected==id)
	show_detail(rows.get(selected,{}))
