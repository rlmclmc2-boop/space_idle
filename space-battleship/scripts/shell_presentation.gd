extends RefCounted
## Opt-in shell skin. Never changes the shared main.style or page themes.
const NAVY := Color("243d50")
const PAPER := Color("ecebdc")
const TEAL := Color("83cfcb")
const STRUCTURE := Color("182b3b")
const SLATE := Color("304c60")
static var fonts: Dictionary = {}
const ICONS := [
	preload("res://assets/ui/shell/equipment.svg"),
	preload("res://assets/ui/shell/research.svg"),
	preload("res://assets/ui/shell/reactor.svg"),
	preload("res://assets/ui/shell/ship.svg"),
	preload("res://assets/ui/shell/jewel.svg"),
	preload("res://assets/ui/shell/crew.svg"),
	preload("res://assets/ui/shell/planet.svg"),
	preload("res://assets/ui/shell/chrono.svg"),
	preload("res://assets/ui/shell/galaxy.svg")
]

static func face(weight: int) -> Font:
	if not fonts.has(weight):
		var variant := FontVariation.new()
		variant.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
		variant.variation_opentype = {2003265652:float(weight)}
		variant.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"):1}
		fonts[weight] = variant
	return fonts[weight]

static func surface(fill: Color, border := NAVY, radius := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	return box

static func setup_navigation(button: Button, index: int) -> void:
	button.add_theme_font_override("font",face(600))
	button.add_theme_font_size_override("font_size",19)
	var icon := TextureRect.new()
	icon.name = "SystemIcon"
	icon.texture = ICONS[index]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	icon.offset_left = -14
	icon.offset_right = 14
	icon.offset_top = 5
	icon.offset_bottom = 33

static func skin_navigation(button: Button, selected: bool) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill := TEAL if selected else SLATE
		var edge := NAVY
		if state=="hover":fill=TEAL.lightened(0.12) if selected else PAPER
		if state=="pressed":fill=TEAL.darkened(0.10)
		if state=="disabled":fill=Color("a4b5b6")
		if state=="focus":
			fill=Color.TRANSPARENT
			edge=PAPER if selected else TEAL
		var box := surface(fill,edge)
		box.content_margin_left=7
		box.content_margin_right=7
		box.content_margin_top=31
		box.content_margin_bottom=5
		button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_color",NAVY if selected else PAPER)
	for color_name in ["font_hover_color","font_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(color_name,NAVY)
	button.add_theme_color_override("font_focus_color",NAVY if selected else PAPER)

static func skin_header(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill := STRUCTURE
		var edge := NAVY
		if state=="hover":fill=SLATE
		if state=="pressed":fill=SLATE.darkened(0.12)
		if state=="disabled":fill=Color("192832")
		if state=="focus":
			fill=Color.TRANSPARENT
			edge=TEAL
		var box := surface(fill,edge,8)
		box.set_content_margin_all(4)
		button.add_theme_stylebox_override(state,box)
	for color_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(color_name,PAPER)
	button.add_theme_color_override("font_disabled_color",Color("b2c1c2"))
