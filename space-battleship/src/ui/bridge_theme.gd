extends RefCounted
const ART := "res://assets/ui/public_shell/"

static func _texture_style(path: String, inset: float, padding: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ART + path)
	style.texture_margin_left = inset
	style.texture_margin_right = inset
	style.texture_margin_top = inset
	style.texture_margin_bottom = inset
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

static func public_panel() -> StyleBoxTexture:
	var style := _texture_style("panel-frame.svg", 18, 16)
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func public_button(state: String, padding: float = 10.0) -> StyleBoxTexture:
	var path := "button-active.svg" if state in ["pressed", "hover_pressed", "selected"] else "button-hover.svg" if state in ["hover", "focus"] else "button-disabled.svg" if state == "disabled" else "button-idle.svg"
	return _texture_style(path, 12, padding)

static func route_button(state: String) -> StyleBoxTexture:
	var path := "nav-active.svg" if state in ["selected", "pressed", "hover_pressed"] else "nav-hover.svg" if state in ["hover", "focus"] else "nav-idle.svg"
	return _texture_style(path, 8, 1)

static func top_button(state: String) -> StyleBoxTexture:
	return _texture_style("top-control-hover.svg" if state in ["hover", "focus", "pressed", "hover_pressed"] else "top-control.svg", 8, 5)

static func public_input(state: String = "normal") -> StyleBoxTexture:
	var path := "input-well-focus.svg" if state in ["focus", "hover", "pressed", "hover_pressed"] else "input-well-disabled.svg" if state in ["read_only", "disabled"] else "input-well.svg"
	return _texture_style(path, 12, 15)

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.default_font = ThemeDB.fallback_font
	theme.set_color("font_color", "Button", Color("f0f2e9"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("173e4c"))
	theme.set_color("font_hover_pressed_color", "Button", Color("173e4c"))
	theme.set_color("font_disabled_color", "Button", Color("9cb4b4"))
	theme.set_color("font_color", "Label", Color("dfebe6"))
	theme.set_color("font_color", "LineEdit", Color("f0f2e9"))
	for type in ["Button", "OptionButton", "LineEdit", "SpinBox"]:
		for key in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("e4ddca") if key in ["pressed", "hover_pressed"] else Color("244f60") if key == "hover" else Color("213842") if key == "disabled" else Color("143746")
			style.border_color = Color("c5dfd7") if key == "focus" else Color("c5a975") if key in ["pressed", "hover_pressed"] else Color("597e85")
			style.set_border_width_all(2 if key == "focus" else 1)
			style.set_corner_radius_all(5)
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			style.shadow_color = Color("061925", 0.35)
			style.shadow_size = 2
			style.shadow_offset = Vector2(0, 2)
			theme.set_stylebox(key, type, style)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0e2835", 0.98)
	panel.border_color = Color("5f8589")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	panel.shadow_color = Color("04121a", 0.35)
	panel.shadow_size = 4
	panel.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
