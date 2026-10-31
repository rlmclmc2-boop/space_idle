extends RefCounted
const CONTROL_MATERIALS := "res://assets/ui/equipment/materials-20261029/control-materials.png"
const PUBLIC_STATES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const CONTROL_CONTENT_Y := 7
static var _public_font: FontVariation

static func public_font() -> FontVariation:
	if _public_font == null:
		_public_font = FontVariation.new()
		_public_font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
		_public_font.variation_opentype = {"wght": 450}
		_public_font.variation_embolden = 0.8
	return _public_font


## Shared numeric roles; colors describe reading hierarchy, not business state.
static func number_role_color(role: String, surface: String = "light") -> Color:
	if surface not in ["light", "dark"]:
		push_warning("Unknown number surface: " + surface)
		return Color("173c48")
	if surface == "dark":
		match role:
			"current": return Color("b1cbd1")
			"gain": return Color("7bd2e2")
			"cost": return Color("e1ded0")
			"insufficient": return Color("ff9f81")
	else:
		match role:
			"current": return Color("4e7580")
			"gain": return Color("087d98")
			"cost": return Color("26718a")
			"insufficient": return Color("a33725")
	push_warning("Unknown number role or surface: " + surface + "/" + role)
	return Color("173c48") if surface == "light" else Color("e9eee6")

static func apply_number_role(label: Label, role: String, surface: String = "light") -> void:
	label.add_theme_color_override("font_color", number_role_color(role, surface))

static func public_button(state: String, padding: float = 10.0, role: String = "secondary") -> StyleBox:
	return operation_button(state, padding, role)

## The accepted R3 operation material, shared with modules through their own
## existing native Button nodes. Never paste the static whole-page study into UI.
static func operation_button(state: String, padding: float = 10.0, role: String = "secondary") -> StyleBox:
	var style := SharedOperationSurface.new()
	style.texture = load(CONTROL_MATERIALS)
	style.focus_only = state == "focus"
	style.primary = role == "commit"
	style.state = state
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = CONTROL_CONTENT_Y
	style.content_margin_bottom = CONTROL_CONTENT_Y
	return style

## An existing module Panel may consume this single operation face in place of
## its old card fill. Geometry, labels and interaction remain module-owned.
static func operation_plate(padding: float = 10.0) -> StyleBox:
	var style := SharedOperationSurface.new()
	style.texture = load(CONTROL_MATERIALS)
	style.plate = true
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = CONTROL_CONTENT_Y
	style.content_margin_bottom = CONTROL_CONTENT_Y
	return style

class SharedOperationSurface extends StyleBox:
	var texture: Texture2D
	var state: String
	var primary := false
	var plate := false
	var focus_only := false
	func _draw(canvas: RID, rect: Rect2) -> void:
		if focus_only:
			var focus_rect := rect.grow(-1.5)
			var focus_outline := PackedVector2Array([focus_rect.position, Vector2(focus_rect.end.x, focus_rect.position.y), focus_rect.end, Vector2(focus_rect.position.x, focus_rect.end.y), focus_rect.position])
			RenderingServer.canvas_item_add_polyline(canvas, focus_outline, PackedColorArray([Color("b9e5d8", 0.86)]), 1.5, true)
			return
		var source := Rect2(45, 131, 1360, 250) if plate else Rect2(45, 470, 1360, 220) if primary else Rect2(45, 770, 1360, 210)
		var tint := Color.WHITE
		match state:
			"hover": tint = Color(1.13, 1.16, 1.14)
			"pressed", "hover_pressed": tint = Color(0.78, 0.84, 0.84)
			"selected": tint = Color(0.79, 0.94, 0.95)
			"selected_hover": tint = Color(0.9, 1.04, 1.04)
			"disabled": tint = Color(0.55, 0.62, 0.65, 0.85)
		var source_edge := Vector2(65, 65)
		var dest_edge := Vector2(minf(13.0, rect.size.x * 0.16), minf(10.0, rect.size.y * 0.25))
		var source_widths := [source_edge.x, source.size.x - 2.0 * source_edge.x, source_edge.x]
		var source_heights := [source_edge.y, source.size.y - 2.0 * source_edge.y, source_edge.y]
		var dest_widths := [dest_edge.x, rect.size.x - 2.0 * dest_edge.x, dest_edge.x]
		var dest_heights := [dest_edge.y, rect.size.y - 2.0 * dest_edge.y, dest_edge.y]
		var source_y := source.position.y
		var dest_y := rect.position.y
		for row in 3:
			var source_x := source.position.x
			var dest_x := rect.position.x
			for col in 3:
				texture.draw_rect_region(canvas, Rect2(dest_x, dest_y, dest_widths[col], dest_heights[row]), Rect2(source_x, source_y, source_widths[col], source_heights[row]), tint)
				source_x += source_widths[col]
				dest_x += dest_widths[col]
			source_y += source_heights[row]
			dest_y += dest_heights[row]


static func apply_public_button(button: BaseButton, padding: float = 8.0, role: String = "secondary") -> void:
	button.add_theme_font_override("font", public_font())
	if not button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", 15)
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, public_button(state, padding, role))
	var ink := Color("173c48") if role == "commit" else Color("f0f2e9")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink if role == "commit" else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_hover_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color("889b9c") if role == "commit" else Color("9cb4b4"))

## Module owners may call these on their existing Buttons/OptionButtons. They
## replace old overrides on the same control; neither adds a new Control layer.
static func apply_operation_button(button: BaseButton, role: String = "secondary", padding: float = 8.0, selected: bool = false) -> void:
	apply_public_button(button, padding, role)
	if selected:
		button.add_theme_stylebox_override("normal", operation_button("selected", padding, role))
		button.add_theme_stylebox_override("hover", operation_button("selected_hover", padding, role))

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
