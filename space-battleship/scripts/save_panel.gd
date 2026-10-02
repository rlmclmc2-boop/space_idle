extends Control
## Save controls share the shell palette; file handling stays with main/save_transfer.
const SKIN := preload("res://scripts/dialog_presentation.gd")
const SHELL := preload("res://scripts/shell_presentation.gd")
const MUTED := SKIN.MUTED
const WARNING := Color("916326")
var scene: Node2D
var scroll: ScrollContainer
var manual_button: Button
var import_button: Button

func setup(owner: Node2D) -> void:
	scene = owner
	theme = SKIN.theme()
	scroll = ScrollContainer.new()
	scroll.name = "SavePageScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",24)
	scroll.add_child(content)
	var current := card(content,"SaveCurrentCard")
	label(current,"save.current_title",30)
	scene.last_save_label = label(current,"",24)
	scene.last_save_label.name = "LastSuccessfulSave"
	scene.last_save_label.add_theme_color_override("font_color",SHELL.NAVY)
	scene.save_status_label = label(current,"",22,WARNING)
	scene.save_status_label.name = "SaveStatus"
	label(current,"save.warning",22,MUTED)
	manual_button = action(current,"ManualSave","save.manual",scene.manual_save,true)
	var transfers := HBoxContainer.new()
	transfers.add_theme_constant_override("separation",24)
	content.add_child(transfers)
	var export_card := card(transfers,"ExportSaveCard")
	label(export_card,"save.export",28)
	label(export_card,"save.export_description",22,MUTED)
	action(export_card,"ExportSave","save.export",scene.open_save_file.bind("export"),true,OS.has_feature("web"))
	var import_card := card(transfers,"ImportSaveCard")
	label(import_card,"save.import",28)
	label(import_card,"save.import_description",22,WARNING)
	import_button = action(import_card,"ImportSave","save.import",scene.open_save_file.bind("import"),false,OS.has_feature("web") or not scene.game.save_enabled)
	scene.save_transfer_feedback = label(content,"save.web_unavailable" if OS.has_feature("web") else "save.transfer_hint",22,SHELL.PAPER)
	scene.save_transfer_feedback.name = "SaveTransferFeedback"
	var automatic := card(content,"AutomaticSaveCard")
	label(automatic,"save.automatic_title",28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	automatic.add_child(row)
	var interval := label(row,"save.interval",24)
	interval.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.save_interval_input = LineEdit.new()
	scene.save_interval_input.name = "SaveIntervalMinutes"
	scene.save_interval_input.custom_minimum_size = Vector2(120,52)
	scene.save_interval_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene.save_interval_input.text = str(scene.game.save_interval_minutes)
	scene.save_interval_input.add_theme_color_override("font_color",SHELL.NAVY)
	scene.save_interval_input.add_theme_color_override("caret_color",SHELL.NAVY)
	scene.save_interval_input.add_theme_color_override("selection_color",SHELL.TEAL)
	scene.save_interval_input.add_theme_stylebox_override("normal",SKIN.surface(Color("f7f6ed"),SHELL.NAVY,8))
	scene.save_interval_input.add_theme_stylebox_override("focus",SKIN.surface(Color.TRANSPARENT,SHELL.TEAL.darkened(.4),8))
	scene.save_interval_input.text_submitted.connect(func(_text):scene.apply_save_interval())
	row.add_child(scene.save_interval_input)
	action(row,"ApplySaveInterval","save.apply_interval",scene.apply_save_interval)
	scene.save_interval_feedback = label(automatic,"save.interval_hint",22,MUTED)
	scene.save_interval_feedback.name = "SaveIntervalFeedback"
	visibility_changed.connect(func():
		if is_visible_in_tree():scene.refresh_save_status())

func refresh_actions() -> void:
	scene.set_ui_value(manual_button,"disabled",not scene.game.save_enabled)
	scene.set_ui_value(import_button,"disabled",OS.has_feature("web") or not scene.game.save_enabled)

func card(parent: Control, node_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",SKIN.surface(SHELL.PAPER,SHELL.NAVY,28))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",18)
	panel.add_child(box)
	return box

func label(parent: Control, key: String, font_size: int, color := SHELL.NAVY) -> Label:
	var value := Label.new()
	value.text = UIText.t(key) if not key.is_empty() else ""
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size",font_size)
	value.add_theme_font_override("font",SHELL.face(600 if font_size>=28 else 500))
	value.add_theme_color_override("font_color",color)
	parent.add_child(value)
	return value

func action(parent: Control, node_name: String, key: String, callback: Callable, primary := false, disabled := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = UIText.t(key)
	button.custom_minimum_size = Vector2(180,56)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.disabled = disabled or (node_name=="ManualSave" and not scene.game.save_enabled)
	button.pressed.connect(callback)
	SKIN.button_skin(button,primary)
	parent.add_child(button)
	return button
