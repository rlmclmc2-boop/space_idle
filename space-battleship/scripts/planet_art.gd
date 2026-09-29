extends RefCounted
## Shared orbital artwork; textures are loaded once, never during animation.
const STATION := preload("res://assets/planets/orbital/models/auto_explore-icon.png")
const REFINERY := preload("res://assets/planets/orbital/models/refinery-icon.png")
const EQUIPMENT := preload("res://assets/planets/orbital/models/equipment-icon.png")
const SHIPYARD := preload("res://assets/planets/orbital/models/shipyard-icon.png")
const SCOUT := preload("res://assets/planets/orbital/scout-v1.png")

static func facility(kind: String) -> Texture2D:
	match kind:
		"space_station", "auto_explore":return STATION
		"refinery":return REFINERY
		"equipment":return EQUIPMENT
		"shipyard":return SHIPYARD
	return null

static func draw_fitted(canvas: CanvasItem, texture: Texture2D, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var dimensions := texture.get_size()
	var factor := minf(bounds.size.x / dimensions.x, bounds.size.y / dimensions.y)
	var fitted := dimensions * factor
	canvas.draw_texture_rect(texture, Rect2(bounds.get_center() - fitted * 0.5, fitted), false, tint)
