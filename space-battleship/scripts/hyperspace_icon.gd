extends TextureRect
## Eight reusable cards consume cached static textures, never render targets.
const Appearance=preload("res://scripts/hyperspace_appearance.gd")
var style_key=""
func apply(drone: Dictionary) -> void:
 var style=Appearance.project(drone);var key=Appearance.fingerprint(style)
 if key==style_key:return
 style_key=key;texture=Appearance.thumbnail(style)
func clear() -> void:
 if style_key.is_empty() and texture==null:return
 style_key="";texture=null
