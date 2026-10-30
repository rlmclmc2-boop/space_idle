extends RefCounted
const ART := "res://assets/ui/public_shell/"
const CONTROL_MATERIALS := "res://assets/ui/equipment/materials-20261029/control-materials.png"
static var _public_faces: Dictionary = {}

static func _public_face(role: String) -> Texture2D:
	if not _public_faces.has(role):
		# Reuse the approved control material itself, rather than drawing a
		# second outline over the old public button art.
		var image: Image = load(CONTROL_MATERIALS).get_image()
		var region := Rect2i(42, 132, 1366, 256) if role == "glass" else Rect2i(42, 772, 1366, 204)
		var face := image.get_region(region)
		var height := 44 if role == "glass" else 40
		face.resize(roundi(face.get_width() * float(height) / face.get_height()), height, Image.INTERPOLATE_LANCZOS)
		_public_faces[role] = ImageTexture.create_from_image(face)
	return _public_faces[role]

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

static func public_button(state: String, padding: float = 10.0) -> StyleBox:
	if state == "focus":
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("f0c987")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(5)
		return focus
	var style := StyleBoxTexture.new()
	style.texture = _public_face("glass" if state in ["pressed", "hover_pressed", "selected"] else "navy")
	style.modulate_color = Color(1.08, 1.08, 1.05) if state in ["hover", "hover_pressed"] else Color(0.63, 0.68, 0.71) if state == "disabled" else Color.WHITE
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_texture_margin(side, 7)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

static func public_check(control: CheckBox) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		control.add_theme_stylebox_override(state, public_button(state, 8))
	for entry in [["unchecked", "check-off.svg"], ["checked", "check-on.svg"],
		["unchecked_disabled", "check-off-disabled.svg"], ["checked_disabled", "check-on-disabled.svg"]]:
		control.add_theme_icon_override(entry[0], load(ART + entry[1]))
	control.add_theme_color_override("font_color", Color("f0f2e9"))
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_pressed_color", Color("173e4c"))
	control.add_theme_color_override("font_hover_pressed_color", Color("173e4c"))
	control.add_theme_color_override("font_focus_color", Color("f0f2e9"))
	control.add_theme_color_override("font_disabled_color", Color("9cb4b4"))
	control.add_theme_constant_override("h_separation", 7)

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
