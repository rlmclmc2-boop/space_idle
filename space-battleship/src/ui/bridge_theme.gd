extends RefCounted
const ART := "res://assets/ui/public_shell/"
const CONTROL_MATERIALS := "res://assets/ui/equipment/materials-20261029/control-materials.png"
const PUBLIC_STATES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const CONTROL_CONTENT_Y := 7
static var _public_faces: Dictionary = {}
static var _public_font: FontVariation

static func public_font() -> FontVariation:
	if _public_font == null:
		_public_font = FontVariation.new()
		_public_font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
		_public_font.variation_opentype = {"wght": 450}
		_public_font.variation_embolden = 0.8
	return _public_font

static func _public_face(role: String) -> Texture2D:
	if not _public_faces.has(role):
		# Take only the painted face: its bright outer key rim belongs to the
		# module, while the public control needs a quieter structural role.
		var image: Image = load(CONTROL_MATERIALS).get_image()
		var face := image.get_region(Rect2i(120, 800, 1200, 130))
		face.resize(298, 64, Image.INTERPOLATE_LANCZOS)
		for y in face.get_height():
			for x in face.get_width():
				var pixel: Color = face.get_pixel(x, y)
				var light: float = pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				var pigment: float = clampf(0.44 + 1.60 * light, 0.71, 0.94)
				face.set_pixel(x, y, Color(pigment, pigment, pigment, pixel.a))
		_public_faces[role] = ImageTexture.create_from_image(face)
	return _public_faces[role]

class PublicControlSurface extends StyleBox:
	var texture: Texture2D
	var tone: Color
	var edge: Color
	var focus_only := false
	var raised := false
	func _draw(canvas: RID, rect: Rect2) -> void:
		var face := rect.grow(-2)
		var cut := minf(5.0, minf(face.size.x, face.size.y) * 0.25)
		var points := PackedVector2Array([
			face.position + Vector2(cut, 0), Vector2(face.end.x - cut, face.position.y),
			Vector2(face.end.x, face.position.y + cut), face.end - Vector2(0, cut),
			face.end - Vector2(cut, 0), Vector2(face.position.x + cut, face.end.y),
			Vector2(face.position.x, face.end.y - cut), face.position + Vector2(0, cut)])
		if not focus_only:
			var uv := PackedVector2Array()
			for point in points: uv.append((point - face.position) / face.size)
			RenderingServer.canvas_item_add_polygon(canvas, points, PackedColorArray([tone]), uv, texture.get_rid())
		var outline := points.duplicate()
		outline.append(points[0])
		RenderingServer.canvas_item_add_polyline(canvas, outline, PackedColorArray([edge]), 1.5 if focus_only else 1.0, true)
		if not focus_only:
			var upper := PackedVector2Array([points[7], points[0], points[1], points[2]])
			RenderingServer.canvas_item_add_polyline(canvas, upper, PackedColorArray([Color("e6e8d7", 0.37 if raised else 0.23)]), 1.0, true)
			var lower := PackedVector2Array([points[3], points[4], points[5], points[6]])
			RenderingServer.canvas_item_add_polyline(canvas, lower, PackedColorArray([Color("091b28", 0.55)]), 1.0, true)

static func _texture_style(path: String, inset: float, padding: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ART + path)
	style.texture_margin_left = inset
	style.texture_margin_right = inset
	style.texture_margin_top = inset
	style.texture_margin_bottom = inset
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = CONTROL_CONTENT_Y
	style.content_margin_bottom = CONTROL_CONTENT_Y
	return style

static func public_panel() -> StyleBoxTexture:
	var style := _texture_style("panel-frame.svg", 18, 16)
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func public_button(state: String, padding: float = 10.0, role: String = "secondary") -> StyleBox:
	var style := PublicControlSurface.new()
	style.texture = _public_face("paint")
	style.focus_only = state == "focus"
	style.raised = role == "commit"
	style.tone = Color("819995") if state in ["pressed", "hover_pressed", "selected"] else Color("253d47") if state == "disabled" else Color("3c5c65") if state == "hover" else Color("52695f") if role == "commit" else Color("304d57")
	style.edge = Color("e5c784", 0.88) if state == "focus" else Color("b6d3cb", 0.65) if state in ["hover", "hover_pressed"] else Color("577b81", 0.36) if state == "disabled" else Color("baa779", 0.69) if role == "commit" else Color("89a8a7", 0.47)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = CONTROL_CONTENT_Y
	style.content_margin_bottom = CONTROL_CONTENT_Y
	return style

## The live public control entry point. Settings actions, resource-detail close,
## and the shell use these same native Button overrides rather than copying a
## palette or placing a decorative control over the real one.
static func apply_public_button(button: BaseButton, padding: float = 8.0, role: String = "secondary") -> void:
	button.add_theme_font_override("font", public_font())
	if not button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", 15)
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, public_button(state, padding, role))
	button.add_theme_color_override("font_color", Color("f0f2e9"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("19363d"))
	button.add_theme_color_override("font_hover_pressed_color", Color("19363d"))
	button.add_theme_color_override("font_focus_color", Color("f0f2e9"))
	button.add_theme_color_override("font_disabled_color", Color("9cb4b4"))

static func apply_route_button(button: Button, selected: bool) -> void:
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, route_button("selected" if selected else state))
	var ink := Color("173e4c") if selected else Color("f0f2e9")
	for state in ["font_color", "font_hover_color"]: button.add_theme_color_override(state, ink)
	for state in ["font_pressed_color", "font_hover_pressed_color"]: button.add_theme_color_override(state, Color("173e4c"))
	button.add_theme_color_override("font_disabled_color", Color("173e4c") if selected else Color("869b9b"))

static func apply_top_button(button: Button) -> void:
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, top_button(state))
	# top-control-hover.svg is a deep cyan face even while held.
	button.add_theme_color_override("font_pressed_color", Color("f0f2e9"))
	button.add_theme_color_override("font_hover_pressed_color", Color("f0f2e9"))

static func apply_public_input(control: Control) -> void:
	for state in PUBLIC_STATES + ["read_only"]:
		control.add_theme_stylebox_override(state, public_input(state))
	if control is OptionButton:
		control.add_theme_color_override("font_pressed_color", Color("f0f2e9"))
		control.add_theme_color_override("font_hover_pressed_color", Color("f0f2e9"))
	if control is SpinBox:
		var spin := control as SpinBox
		apply_public_input(spin.get_line_edit())
		var up := preload("res://assets/ui/public_shell/stepper-up.svg")
		var down := preload("res://assets/ui/public_shell/stepper-down.svg")
		for state in ["up", "up_hover", "up_pressed"]: spin.add_theme_icon_override(state, up)
		for state in ["down", "down_hover", "down_pressed"]: spin.add_theme_icon_override(state, down)
		spin.add_theme_icon_override("up_disabled", preload("res://assets/ui/public_shell/stepper-up-disabled.svg"))
		spin.add_theme_icon_override("down_disabled", preload("res://assets/ui/public_shell/stepper-down-disabled.svg"))
		spin.add_theme_icon_override("updown", preload("res://assets/ui/public_shell/stepper-pair.svg") if spin.editable else preload("res://assets/ui/public_shell/stepper-pair-disabled.svg"))
		for direction in ["up", "down"]:
			for suffix in ["", "_hovered", "_pressed", "_disabled"]:
				var frame := StyleBoxFlat.new()
				frame.bg_color = Color("1b4856") if suffix == "_hovered" else Color("2b5b64") if suffix == "_pressed" else Color("172f3c") if suffix == "_disabled" else Color("123746")
				frame.border_color = Color("a9d7c9") if suffix == "_hovered" else Color("547b81")
				frame.set_border_width_all(1)
				spin.add_theme_stylebox_override(direction + "_background" + suffix, frame)

static func public_check(control: CheckBox) -> void:
	apply_public_button(control)
	for entry in [["unchecked", "check-off.svg"], ["checked", "check-on.svg"],
		["unchecked_disabled", "check-off-disabled.svg"], ["checked_disabled", "check-on-disabled.svg"]]:
		control.add_theme_icon_override(entry[0], load(ART + entry[1]))
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
	theme.default_font = public_font()
	theme.set_color("font_color", "Button", Color("f0f2e9"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("f0f2e9"))
	theme.set_color("font_hover_pressed_color", "Button", Color("f0f2e9"))
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
