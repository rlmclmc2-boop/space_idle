extends RefCounted
const ART := "res://assets/ui/public_shell/"
const CONTROL_MATERIALS := "res://assets/ui/public_shell/faceted-controls.svg"
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
	var style := operation_plate(16.0, "dark") as StyleBoxTexture
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func public_button(state: String, padding: float = 10.0, role: String = "secondary") -> StyleBox:
	return operation_button(state, padding, role)

static func _operation_surface(region: Rect2, padding: float, plate: bool = false) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(CONTROL_MATERIALS)
	atlas.region = region
	atlas.filter_clip = true
	var style := OperationPlate.new() if plate else StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = 10.0
	style.texture_margin_right = 10.0
	style.texture_margin_top = 10.0 if plate else 6.0
	style.texture_margin_bottom = 10.0 if plate else 6.0
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = CONTROL_CONTENT_Y
	style.content_margin_bottom = CONTROL_CONTENT_Y
	return style

## One editable faceted-paint atlas replaces the previous equipment material
## crop. Existing native controls keep their geometry, text and interactions.
static func operation_button(state: String, padding: float = 10.0, role: String = "secondary") -> StyleBox:
	if state == "focus": return OperationFocus.new()
	var region := Rect2(256, 0, 256, 96) if role == "commit" else Rect2(0, 0, 256, 96)
	if state in ["selected", "selected_hover"] and role != "commit": region = Rect2(0, 288, 256, 96)
	if state == "disabled": region = Rect2(256, 288, 256, 96)
	var style := _operation_surface(region, padding)
	match state:
		"hover", "selected_hover": style.modulate_color = Color(1.10, 1.12, 1.12)
		"pressed": style.modulate_color = Color(0.78, 0.83, 0.88)
		"hover_pressed": style.modulate_color = Color(0.86, 0.91, 0.95)
		"disabled": style.modulate_color = Color(0.84, 0.89, 0.94)
	return style

## Light faces preserve existing module text roles; dark faces let modules
## adopt the accepted console language without duplicating a paint source.
static func operation_plate(padding: float = 10.0, surface: String = "light") -> StyleBox:
	return _operation_surface(Rect2(256, 96, 256, 192) if surface == "dark" else Rect2(0, 96, 256, 192), padding, true)

## Existing retained equipment cards set face.state when selection changes.
## Keep that presentation port while replacing the old drawing implementation.
class OperationPlate extends StyleBoxTexture:
	var state: String = "normal":
		set(value):
			state = value
			match value:
				"selected": modulate_color = Color(0.86, 0.97, 1.00)
				"hover", "selected_hover": modulate_color = Color(1.05, 1.08, 1.08)
				"pressed", "hover_pressed": modulate_color = Color(0.81, 0.89, 0.92)
				"disabled": modulate_color = Color(0.80, 0.86, 0.90)
				_: modulate_color = Color.WHITE

class OperationFocus extends StyleBox:
	var ink := Color("9bcbd7", 0.9)
	func _draw(canvas: RID, rect: Rect2) -> void:
		var box := rect.grow(-1.5)
		var cut := minf(5.0, minf(box.size.x, box.size.y) * 0.25)
		var left := box.position.x
		var top := box.position.y
		var right := box.end.x
		var bottom := box.end.y
		var points := PackedVector2Array([Vector2(left+cut,top), Vector2(right-cut,top), Vector2(right,top+cut), Vector2(right,bottom-cut), Vector2(right-cut,bottom), Vector2(left+cut,bottom), Vector2(left,bottom-cut), Vector2(left,top+cut), Vector2(left+cut,top)])
		RenderingServer.canvas_item_add_polyline(canvas, points, PackedColorArray([ink]), 1.5, true)

## The live public control entry point. Settings actions, resource-detail close,
## and the shell use these same native Button overrides rather than copying a
## palette or placing a decorative control over the real one.
static func apply_public_button(button: BaseButton, padding: float = 8.0, role: String = "secondary") -> void:
	button.add_theme_font_override("font", public_font())
	if not button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", 15)
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, public_button(state, padding, role))
	var ink := Color("1c2a38") if role == "commit" else Color("edf0e9")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink if role == "commit" else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_hover_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color("9fb1bd"))

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
	var menu_theme := Theme.new()
	_configure_popup_theme(menu_theme)
	var menu := button.get_popup()
	menu.theme = menu_theme
	menu.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR

## Menus opened by native OptionButtons inherit create() too. Both paths use
## the panel face, rather than stretching a button face around a tall list.
static func _configure_popup_theme(menu_theme: Theme) -> void:
	menu_theme.set_stylebox("panel", "PopupMenu", public_panel())
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

static func apply_route_button(button: Button, selected: bool) -> void:
	for state in PUBLIC_STATES:
		button.add_theme_stylebox_override(state, route_button("selected" if selected else state))
	var ink := Color("182c40") if selected else Color("f0f2e9")
	for state in ["font_color", "font_hover_color"]: button.add_theme_color_override(state, ink)
	for state in ["font_pressed_color", "font_hover_pressed_color"]: button.add_theme_color_override(state, Color("182c40"))
	button.add_theme_color_override("font_disabled_color", Color("182c40") if selected else Color("869b9b"))

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

class SpinInputFocus extends OperationFocus:
	var spin: WeakRef
	func _draw(canvas: RID, rect: Rect2) -> void:
		var owner := spin.get_ref() as SpinBox if spin != null else null
		ink = Color("9bcbd7", 0.9) if owner != null and owner.editable else Color("637b8d", 0.45)
		super._draw(canvas, rect)

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
		for key in PUBLIC_STATES:
			theme.set_stylebox(key, type, public_input(key) if type == "LineEdit" else operation_button(key))
	theme.set_stylebox("read_only", "LineEdit", public_input("read_only"))
	theme.set_stylebox("panel", "PanelContainer", public_panel())
	_configure_popup_theme(theme)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
