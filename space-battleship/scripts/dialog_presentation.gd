extends RefCounted
## Scoped modal/option chrome. Does not modify the main or page theme.
const SHELL := preload("res://scripts/shell_presentation.gd")
const NAVY := SHELL.NAVY
const PAPER := SHELL.PAPER
const TEAL := SHELL.TEAL
const MUTED := Color("637782")

static func surface(fill := PAPER, border := NAVY, padding := 16) -> StyleBoxFlat:
	var box := SHELL.surface(fill,border,10)
	box.set_content_margin_all(padding)
	return box

static func button_skin(button: Button, primary := false) -> void:
	button.add_theme_font_override("font",SHELL.face(600))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(key,NAVY)
	button.add_theme_color_override("font_disabled_color",MUTED)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill := TEAL if primary else PAPER
		if state=="hover":fill=fill.lightened(0.10)
		if state=="pressed":fill=TEAL.darkened(0.12)
		if state=="disabled":fill=Color("bcc8c5")
		button.add_theme_stylebox_override(state,surface(Color.TRANSPARENT if state=="focus" else fill,TEAL.darkened(0.4) if state=="focus" else NAVY,4))

static func theme() -> Theme:
	var skin := Theme.new()
	skin.default_font = SHELL.face(500)
	skin.default_font_size = 22
	var window_frame: StyleBoxFlat = ThemeDB.get_default_theme().get_stylebox("embedded_border","Window").duplicate()
	window_frame.bg_color = NAVY
	window_frame.border_color = NAVY
	window_frame.set_border_width_all(3)
	window_frame.set_corner_radius_all(10)
	skin.set_stylebox("embedded_border","Window",window_frame)
	skin.set_color("title_color","Window",PAPER)
	for type in ["Label","RichTextLabel","PopupMenu","Button"]:
		skin.set_color("font_color",type,NAVY)
		skin.set_color("font_hover_color",type,NAVY)
		skin.set_color("font_disabled_color",type,MUTED)
	skin.set_color("default_color","RichTextLabel",NAVY)
	for type in ["AcceptDialog","Window"]:skin.set_stylebox("panel",type,surface())
	skin.set_stylebox("panel","PopupMenu",surface())
	skin.set_stylebox("hover","PopupMenu",surface(TEAL,NAVY,4))
	skin.set_stylebox("separator","PopupMenu",surface(Color("b3c4c0"),Color("b3c4c0"),1))
	skin.set_constant("v_separation","PopupMenu",12)
	skin.set_color("font_separator_color","PopupMenu",MUTED)
	skin.set_color("font_accelerator_color","PopupMenu",MUTED)
	skin.set_color("font_outline_color","PopupMenu",Color.TRANSPARENT)
	skin.set_icon("checked","PopupMenu",preload("res://assets/ui/dialog/check.svg"))
	skin.set_icon("radio_checked","PopupMenu",preload("res://assets/ui/dialog/radio-on.svg"))
	skin.set_icon("radio_unchecked","PopupMenu",preload("res://assets/ui/dialog/radio-off.svg"))
	skin.set_stylebox("scroll","VScrollBar",surface(Color("b3c4c0"),NAVY,4))
	for state in ["grabber","grabber_highlight","grabber_pressed"]:skin.set_stylebox(state,"VScrollBar",surface(TEAL,NAVY,4))
	return skin

static func dialog(window: AcceptDialog) -> void:
	window.theme = theme()
	window.ok_button_text = UIText.t("system.confirm") if window.ok_button_text in ["","OK"] else window.ok_button_text
	window.get_ok_button().custom_minimum_size = Vector2(120,44)
	button_skin(window.get_ok_button(),true)
	if window is ConfirmationDialog:
		if window.cancel_button_text=="Cancel":window.cancel_button_text=UIText.t("system.cancel")
		window.get_cancel_button().custom_minimum_size = Vector2(120,44)
		button_skin(window.get_cancel_button())

static func popup(menu: PopupMenu) -> void:
	menu.theme = theme()

static func option(control: OptionButton, body := true) -> void:
	popup(control.get_popup())
	if body:
		button_skin(control)
		control.add_theme_constant_override("modulate_arrow",1)
