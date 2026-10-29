extends RefCounted
## Shared presentation identity; business IDs, amount text and prices stay native.
const MATERIAL_ATLAS = preload("res://assets/ui/public_shell/resource-material-atlas.png")
const MATERIAL_CELLS := {"1": 0, "2": 1, "chrono": 2}
const MATERIAL_CELL_SIZE := 724
const MATERIAL_ICON_SIZE := 24
const MATERIAL_BOUNDS := {
	"1": Rect2i(62, 129, 602, 475),
	"2": Rect2i(111, 101, 531, 503),
	"chrono": Rect2i(195, 76, 367, 568)}
const ICONS := {
	"jewel": preload("res://assets/ui/public_shell/resource-jewel.svg"),
	"degenerate_matter": preload("res://assets/ui/public_shell/resource-matter.svg")}
static var _material_icons: Dictionary = {}
const COLORS := {
	"1": Color("d9b681"),
	"2": Color("8ed4bb"),
	"chrono": Color("86cddf"),
	"jewel": Color("b9abf0"),
	"degenerate_matter": Color("b9c8d5")}
const FALLBACK := Color("ceded9")

static func icon(id: String) -> Texture2D:
	if id in MATERIAL_CELLS:
		if not _material_icons.has(id):
			var bounds: Rect2i = MATERIAL_BOUNDS[id]
			var source: Image = MATERIAL_ATLAS.get_image().get_region(Rect2i(bounds.position + Vector2i(int(MATERIAL_CELLS[id]) * MATERIAL_CELL_SIZE, 0), bounds.size))
			source.fix_alpha_edges()
			var scale: float = 22.0 / float(maxi(bounds.size.x, bounds.size.y))
			source.resize(maxi(1, roundi(bounds.size.x * scale)), maxi(1, roundi(bounds.size.y * scale)), Image.INTERPOLATE_LANCZOS)
			var icon_image := Image.create(MATERIAL_ICON_SIZE, MATERIAL_ICON_SIZE, false, Image.FORMAT_RGBA8)
			icon_image.fill(Color.TRANSPARENT)
			icon_image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), (Vector2i(MATERIAL_ICON_SIZE, MATERIAL_ICON_SIZE) - source.get_size()) / 2)
			_material_icons[id] = ImageTexture.create_from_image(icon_image)
		return _material_icons[id]
	return ICONS.get(id)

static func color(id: String) -> Color:
	return COLORS.get(id, FALLBACK)

static func icon_modulate(id: String) -> Color:
	# Painted material cells carry their own colour; line icons still need their semantic tint.
	return Color.WHITE if id in MATERIAL_CELLS else color(id)
