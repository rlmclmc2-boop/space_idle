extends TextureRect
## Shared imported environment. No per-station backgrounds or decorative overlay.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture=preload("res://assets/hightech/hall-background-v2.png")
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
