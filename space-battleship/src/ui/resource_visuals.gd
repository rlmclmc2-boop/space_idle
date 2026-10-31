extends RefCounted
## Shared presentation identity; business IDs, amount text and prices stay native.
const MATERIAL_ATLAS = preload("res://assets/ui/public_shell/resource-material-atlas.png")
const MATERIAL_SUPPLEMENT = preload("res://assets/ui/public_shell/resource-material-supplement.png")
const MATERIAL_CELLS := {"1": 0, "2": 1, "chrono": 2, "jewel": 3, "degenerate_matter": 4}
const MATERIAL_CELL_SIZE := 724
const MATERIAL_ICON_SIZE := 24
const MATERIAL_BOUNDS := {
	"1": Rect2i(62, 129, 602, 475),
	"2": Rect2i(111, 101, 531, 503),
	"chrono": Rect2i(195, 76, 367, 568),
	"jewel": Rect2i(175, 87, 619, 724),
	"degenerate_matter": Rect2i(96, 117, 723, 669)}
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
			var cell: int = int(MATERIAL_CELLS[id])
			var atlas: Texture2D = MATERIAL_ATLAS if cell < 3 else MATERIAL_SUPPLEMENT
			var cell_size: int = MATERIAL_CELL_SIZE if cell < 3 else 887
			var source: Image = atlas.get_image().get_region(Rect2i(bounds.position + Vector2i((cell if cell < 3 else cell - 3) * cell_size, 0), bounds.size))
			source.fix_alpha_edges()
			var scale: float = 22.0 / float(maxi(bounds.size.x, bounds.size.y))
			source.resize(maxi(1, roundi(bounds.size.x * scale)), maxi(1, roundi(bounds.size.y * scale)), Image.INTERPOLATE_LANCZOS)
			var icon_image := Image.create(MATERIAL_ICON_SIZE, MATERIAL_ICON_SIZE, false, Image.FORMAT_RGBA8)
			icon_image.fill(Color.TRANSPARENT)
			icon_image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), (Vector2i(MATERIAL_ICON_SIZE, MATERIAL_ICON_SIZE) - source.get_size()) / 2)
			_material_icons[id] = ImageTexture.create_from_image(icon_image)
		return _material_icons[id]
	return null

static func color(id: String) -> Color:
	return COLORS.get(id, FALLBACK)

static func icon_modulate(id: String) -> Color:
	# Painted material cells carry their own colour; tint remains for rings and text.
	return Color.WHITE if id in MATERIAL_CELLS else color(id)
