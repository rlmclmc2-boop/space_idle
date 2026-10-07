extends Node
## Equipment-only immutable style tiles. No controls, page snapshots or frame loop.
## Child viewports bake one small native StyleBoxFlat each, then a post-draw
## readback freezes the pixels and releases the viewport. Textures stay page-owned.

var tiles: Dictionary = {}
var pending_tiles: Array[Dictionary] = []
const PAD_LEFT := 4.0
const PAD_TOP := 1.0
const PAD_RIGHT := 4.0
const PAD_BOTTOM := 7.0

static func native_style(fill:Color,edge:Color,radius:int) -> StyleBoxFlat:
	var source:=StyleBoxFlat.new()
	source.bg_color=fill
	source.border_color=edge
	source.set_border_width_all(3)
	source.set_corner_radius_all(radius)
	source.shadow_color=Color(0.02,0.05,0.08,0.35)
	source.shadow_size=3
	source.shadow_offset=Vector2(0,3)
	source.set_content_margin_all(12)
	return source

func panel_style(fill:Color,edge:Color,radius:int) -> StyleBoxTexture:
	var key:String=var_to_str([fill,edge,radius])
	if not tiles.has(key):
		# Leave a flat center strip after accounting for the shadow's Y offset.
		# Padding contains the original 3px shadow, offset (0,3), and AA fringe.
		var body_size:float=float(radius*2+8)
		var view:=SubViewport.new()
		view.name="EquipmentStyleTile%02d" % tiles.size()
		view.size=Vector2i(int(body_size+PAD_LEFT+PAD_RIGHT),int(body_size+PAD_TOP+PAD_BOTTOM))
		view.disable_3d=true
		view.transparent_bg=true
		view.gui_disable_input=true
		view.render_target_update_mode=SubViewport.UPDATE_ONCE
		add_child(view)
		var painter:=Node2D.new()
		view.add_child(painter)
		var source:=native_style(fill,edge,radius)
		var body:=Rect2(Vector2(PAD_LEFT,PAD_TOP),Vector2.ONE*body_size)
		painter.draw.connect(func():painter.draw_style_box(source,body))
		painter.queue_redraw()
		# Controls keep this wrapper throughout the bake-to-static handoff.
		# The first frame uses the original viewport texture, not an empty image.
		var shared:=AtlasTexture.new()
		shared.atlas=view.get_texture()
		tiles[key]=shared
		pending_tiles.append({"view":view,"shared":shared})
		if not RenderingServer.frame_post_draw.is_connected(_freeze_pending_tiles):
			RenderingServer.frame_post_draw.connect(_freeze_pending_tiles)
	# Return a fresh style resource: existing callers duplicate/change content
	# margins, while only the immutable baked texture is shared.
	var box:=StyleBoxTexture.new()
	box.texture=tiles[key]
	box.set_texture_margin(SIDE_LEFT,PAD_LEFT+radius)
	# Top corners include the shadow center shifted three pixels downward.
	box.set_texture_margin(SIDE_TOP,PAD_TOP+radius+3.0)
	box.set_texture_margin(SIDE_RIGHT,PAD_RIGHT+radius)
	box.set_texture_margin(SIDE_BOTTOM,PAD_BOTTOM+radius)
	box.set_expand_margin(SIDE_LEFT,PAD_LEFT)
	box.set_expand_margin(SIDE_TOP,PAD_TOP)
	box.set_expand_margin(SIDE_RIGHT,PAD_RIGHT)
	box.set_expand_margin(SIDE_BOTTOM,PAD_BOTTOM)
	box.set_content_margin_all(12)
	return box

func _freeze_pending_tiles() -> void:
	# One owner connection covers all tiles created before this frame. Detach
	# before emitting texture changes so newly requested styles can queue their
	# own next-frame batch without losing entries or connecting bound duplicates.
	RenderingServer.frame_post_draw.disconnect(_freeze_pending_tiles)
	var batch:Array[Dictionary]=pending_tiles
	pending_tiles=[]
	for tile in batch:
		_freeze_tile(tile.view,tile.shared)

func _freeze_tile(view:SubViewport,shared:AtlasTexture) -> void:
	if not is_instance_valid(view):return
	var pixels:Image=view.get_texture().get_image()
	# Keep the valid UPDATE_ONCE texture if a renderer cannot read it back.
	if pixels==null or pixels.is_empty():return
	var frozen:=ImageTexture.create_from_image(pixels)
	# AtlasTexture emits changed to its existing StyleBoxTexture users. No
	# control traversal, style replacement or page redraw framework is needed.
	shared.atlas=frozen
	view.queue_free()
