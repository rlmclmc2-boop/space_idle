extends "res://scripts/enemy_recognition_visual.gd"
## QA-only rotating gun art. The stationary burgundy foundation exists only in hull PNG.
var gun_texture:Texture2D
var pivot_px:=Vector2.ZERO
var muzzle_px:=Vector2.ZERO
var housing_width_px:=256.0
var housing_per_w:=1.0
var muzzle_factor:=.43
var probe_yaw:=0.0
func configure(meta:Dictionary,housing_world_width:float,w:float)->void:
 gun_texture=load(str(meta.texture));pivot_px=Vector2(meta.pivot_px[0],meta.pivot_px[1]);muzzle_px=Vector2(meta.muzzle_px[0],meta.muzzle_px[1]);housing_width_px=float(meta.housing_width_px)
 housing_per_w=housing_world_width/w
 muzzle_factor=(muzzle_px.y-pivot_px.y)*housing_per_w/housing_width_px*.45
func draw_weapon(surface:CanvasItem,pos:Vector2,pose:Dictionary,damage_type:int,scale_value:float)->void:
 if damage_type!=2:super.draw_weapon(surface,pos,pose,damage_type,scale_value);return
 var w:=maxf(1.0/maxf(.1,scale_value),float(pose.width)*.45)
 var shift:=Vector2(pose.port)-Vector2(.64*w,0)
 surface.draw_set_transform(pos+Vector2(pose.origin)+shift.rotated(pose.angle),float(pose.angle)-PI/2)
 var scale:=float(pose.port.x)/(muzzle_px.y-pivot_px.y)
 var axis:=Vector2(0,.64*w-float(pose.port.x))
 draw_gun_quad(surface,scale,axis)
 surface.draw_set_transform(Vector2.ZERO)
func draw_weapon_body(surface:CanvasItem,w:float,physical:bool)->void:
 if not physical:super.draw_weapon_body(surface,w,physical);return
 var per_w:=float(surface.get_meta("qa_housing_per_w",housing_per_w))
 var factor:=float(surface.get_meta("qa_muzzle_factor",muzzle_factor))
 var scale:=w*per_w/housing_width_px
 var axis:=Vector2(0,(.64-factor/.45)*w)
 draw_gun_quad(surface,scale,axis)
func draw_gun_quad(surface:CanvasItem,scale:float,axis:Vector2)->void:
 var size:Vector2=gun_texture.get_size()
 var points:PackedVector2Array=[]
 for pixel in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:points.append(axis+((pixel-pivot_px)*scale).rotated(probe_yaw))
 surface.draw_polygon(points,PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),gun_texture)
