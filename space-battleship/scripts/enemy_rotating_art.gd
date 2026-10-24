extends RefCounted
## Authored rotating art only. Never changes a loadout, profile or logical port.
var texture:Texture2D

func draw_local(surface:CanvasItem,art:Dictionary)->void:
 surface.draw_texture_rect(texture,Rect2(-Vector2(art.pivot)*float(art.scale),texture.get_size()*float(art.scale)),false)
