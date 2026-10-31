extends RefCounted
const ART := "res://assets/ui/public_shell/"
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

## Text roles shared by equipment and reactor on their existing native faces.
## Light means the low-reflection enamel operation face; dark means the navy
## console face. This does not restyle controls or decide business states.
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
			"pressed": tint = Color(0.78, 0.84, 0.84)
			"hover_pressed": tint = Color(0.94, 1.00, 0.98)
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

## The live public control entry point. Settings actions, resource-detail close,
## and the shell use these same native Button overrides rather than copying a
## palette or placing a decorative control over the real one.
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

static func apply_operation_select(button: OptionButton, padding: float = 10.0) -> void:
	apply_public_button(button, padding, "secondary")
	button.add_theme_stylebox_override("normal", operation_button("selected", padding))
	button.add_theme_stylebox_override("hover", operation_button("selected_hover", padding))
	button.add_theme_icon_override("arrow", preload("res://assets/ui/public_shell/stepper-down.svg"))
	button.add_theme_constant_override("arrow_margin", 8)
	button.add_theme_constant_override("h_separation", 8)
	# OptionButton's list is a separate PopupMenu window. Style the native menu
	# itself so opening a select does not fall back to Godot's gray editor menu.
	var menu_theme := Theme.new()
	menu_theme.set_stylebox("panel", "PopupMenu", operation_button("normal", 7.0))
	menu_theme.set_stylebox("hover", "PopupMenu", operation_button("selected_hover", 5.0))
	menu_theme.set_font("font", "PopupMenu", public_font())
	menu_theme.set_font_size("font_size", "PopupMenu", 15)
	menu_theme.set_color("font_color", "PopupMenu", Color("f0f2e9"))
	menu_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	menu_theme.set_color("font_disabled_color", "PopupMenu", Color("9cb4b4"))
	menu_theme.set_constant("item_start_padding", "PopupMenu", 8)
	menu_theme.set_constant("item_end_padding", "PopupMenu", 8)
	menu_theme.set_constant("v_separation", "PopupMenu", 5)
	menu_theme.set_icon("radio_checked", "PopupMenu", preload("res://assets/ui/dialog/radio-on.svg"))
	menu_theme.set_icon("radio_unchecked", "PopupMenu", preload("res://assets/ui/dialog/radio-off.svg"))
	button.get_popup().theme = menu_theme

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
		var field := spin.get_line_edit()
		apply_public_input(field)
		# SpinBox keeps a focusable LineEdit when it becomes read-only. Keep its
		# copyable focus, but do not draw an actionable bright focus edge then.
		var focus := SpinInputFocus.new()
		focus.spin = weakref(spin)
		field.add_theme_stylebox_override("focus", focus)
		apply_public_spin_editable(spin, spin.editable)
		for direction in ["up", "down"]:
			for suffix in ["", "_hovered", "_pressed", "_disabled"]:
				var state := "hover" if suffix == "_hovered" else "pressed" if suffix == "_pressed" else "disabled" if suffix == "_disabled" else "normal"
				spin.add_theme_stylebox_override(direction + "_background" + suffix, operation_button(state, 1.0))

## SpinBox's valid updown texture overrides its individual disabled icons and
## never changes with interaction. Use this when the public field changes
## editability; SpinBox itself keeps the inner LineEdit's read-only flag synced.
static func apply_public_spin_editable(spin: SpinBox, editable: bool) -> void:
	spin.editable = editable
	spin.add_theme_icon_override("updown", preload("res://assets/ui/public_shell/stepper-pair.svg") if editable else preload("res://assets/ui/public_shell/stepper-pair-disabled.svg"))

class SpinInputFocus extends StyleBox:
	var spin: WeakRef
	func _draw(canvas: RID, rect: Rect2) -> void:
		var owner := spin.get_ref() as SpinBox if spin != null else null
		var edge := Color("b9e5d8", 0.86) if owner != null and owner.editable else Color("678a8d", 0.48)
		var box := rect.grow(-1.5)
		RenderingServer.canvas_item_add_polyline(canvas, PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position]), PackedColorArray([edge]), 1.5, true)

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

static func public_input(state: String = "normal") -> StyleBox:
	# Recessed input and text stay on the existing native control. The old SVG
	# well is retired here, so no line frame remains underneath this paint.
	var face := "disabled" if state in ["read_only", "disabled"] else "selected_hover" if state == "hover" else "selected" if state == "normal" else state
	return operation_button(face, 15.0, "secondary")

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
