extends Control
## Open station selection only; architecture comes from the shared hall asset.
var accent := Color("67dcec")
var selected := false
var selection: TextureRect
var platform: TextureRect
var pending := false

func _ready() -> void:
	for path in ["res://assets/hightech/platform-reference-v2.tres","res://assets/hightech/bay-selected.svg"]:
		var layer := TextureRect.new()
		layer.texture=load(path)
		layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		layer.size=Vector2(644,443)
		if path.ends_with(".tres"):
			platform=layer
			layer.position=Vector2(0,163)
			layer.size=Vector2(644,280)
		layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		if path.ends_with("bay-selected.svg"):
			selection=layer
			selection.z_index=1
			selection.visible=selected
		else:move_child(layer,0)

func set_pending(value: bool) -> void:
	if pending==value:return
	pending=value
	platform.modulate=Color(0.38,0.46,0.53) if pending else Color.WHITE

func set_selected(value: bool) -> void:
	if selected==value:return
	selected=value
	if is_instance_valid(selection):
		selection.modulate=accent.lerp(Color.WHITE,0.45)
		selection.visible=selected
