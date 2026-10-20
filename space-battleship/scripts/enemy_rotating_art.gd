extends RefCounted
## Authored rotating art only. Never changes a loadout, profile or logical port.
var texture:Texture2D

func pose(scene,enemy:Dictionary,component)->Dictionary:
 var row:Dictionary=scene.ship_visual_entry(scene.enemy_ship_key(enemy))
 var mounts:Array=row.get("rotating_mounts",[])
 if mounts.is_empty():return {}
 var kind:=str(component.profile.get("visual_class",""))
 if not ((component.damage_type==2 and kind=="gun") or (component.damage_type==1 and kind=="energy")):return {}
 var index:int=scene.enemy_weapon_components(enemy).find(component)
 # Overflow/unsupported weapons keep their existing painter; never invent slots.
 if index<0 or index>=mounts.size():return {}
 var meta:Dictionary=scene.visual_config.enemy_rotating_art
 if texture==null:texture=load(str(meta.texture))
 var mount:Dictionary=mounts[index]
 var rect:Rect2=scene.enemy_hull_rect(enemy,scene.enemy_render_width(enemy))
 var centre:=Vector2(float(mount.centre_px[0]),float(mount.centre_px[1]))
 var hull:Texture2D=scene.ship_hull_texture(scene.enemy_ship_key(enemy))
 var origin:Vector2=(rect.position+centre/hull.get_size()*rect.size).rotated(PI+scene.enemy_render_angle(enemy))
 var angle:float=scene.enemy_component_pose(enemy,component).angle
 var scale_value:float=float(mount.housing_width_uv)*rect.size.x/float(meta.housing_width_px)
 var pivot:=Vector2(float(meta.pivot_px[0]),float(meta.pivot_px[1]))
 var muzzle:=Vector2(float(meta.muzzle_px[0]),float(meta.muzzle_px[1]))
 return {"origin":origin,"angle":angle,"scale":scale_value,"pivot":pivot,"muzzle":origin+((muzzle-pivot)*scale_value).rotated(angle-PI/2)}

func draw_local(surface:CanvasItem,art:Dictionary)->void:
 surface.draw_texture_rect(texture,Rect2(-Vector2(art.pivot)*float(art.scale),texture.get_size()*float(art.scale)),false)
