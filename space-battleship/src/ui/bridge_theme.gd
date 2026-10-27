extends RefCounted
static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.default_font = ThemeDB.fallback_font
	for key in ["font_color", "font_color_hover", "font_color_pressed"]: theme.set_color(key, "Button", Color("e2eff5"))
	theme.set_color("font_color", "Label", Color("c9dce7"))
	theme.set_color("font_color", "LineEdit", Color("e2eff5"))
	for type in ["Button", "OptionButton", "LineEdit", "SpinBox"]:
		for key in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("173447") if key in ["hover", "pressed"] else Color("102736")
			style.border_color = Color("6bc5ce") if key == "focus" else Color("2b566b")
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			theme.set_stylebox(key, type, style)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0b1c2b", 0.98)
	panel.border_color = Color("355569")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
