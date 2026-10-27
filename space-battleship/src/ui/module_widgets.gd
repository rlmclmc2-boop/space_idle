extends RefCounted
## Shared controls only; each page supplies its own domain model and commands.
static var _visible_textures:Dictionary={}
static func label(parent:Node,text:String,size:int=18)->Label:
	var node:=Label.new()
	node.text=text
	node.add_theme_font_size_override("font_size",size)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node
static func image(parent:Node,path:String,extent:Vector2)->TextureRect:
	var node:=TextureRect.new()
	node.texture=visible_texture(load(path)) if ResourceLoader.exists(path) else null
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size=extent
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
static func plate(parent:Node)->VBoxContainer:
	var frame:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("e9eadf")
	style.border_color=Color("7ba2ac")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left=14;style.content_margin_right=14
	style.content_margin_top=12;style.content_margin_bottom=12
	frame.add_theme_stylebox_override("panel",style)
	frame.theme=Theme.new()
	frame.theme.set_color("font_color","Label",Color("193d50"))
	parent.add_child(frame)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	frame.add_child(box)
	return box
static func heading(parent:Node,text:String,subtitle:String="")->void:
	label(parent,text,26)
	if not subtitle.is_empty():label(parent,subtitle,16)

static func visible_texture(source:Texture2D)->Texture2D:
	if source==null:return null
	var key:int=source.get_instance_id()
	if _visible_textures.has(key):return _visible_textures[key]
	var bitmap:Image=source.get_image()
	if bitmap==null or bitmap.is_empty():return source
	var visible:Rect2i=bitmap.get_used_rect()
	if visible.size==Vector2i.ZERO:return source
	var region:Rect2i=visible.grow(2).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
	var texture:=AtlasTexture.new();texture.atlas=source;texture.region=Rect2(region);texture.filter_clip=true
	texture.set_meta("source_bounds",Rect2i(Vector2i.ZERO,source.get_size()));texture.set_meta("visible_bounds",visible);texture.set_meta("alignment_anchor","visible_center")
	_visible_textures[key]=texture
	return texture
