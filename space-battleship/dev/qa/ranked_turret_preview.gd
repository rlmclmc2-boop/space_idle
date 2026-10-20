extends "res://scripts/enemy_recognition_visual.gd"
## Explicit QA skin only. Same live pivot, aim, muzzle and numerical geometry.
var muzzle_factor:=0.43
func draw_weapon(surface:CanvasItem,pos:Vector2,pose:Dictionary,damage_type:int,scale_value:float)->void:
 if damage_type!=2:super.draw_weapon(surface,pos,pose,damage_type,scale_value);return
 var w:=maxf(1.0/maxf(.1,scale_value),float(pose.width)*.45)
 var shift:=Vector2(pose.port)-Vector2(.64*w,0)
 surface.draw_set_transform(pos+Vector2(pose.origin)+shift.rotated(pose.angle),float(pose.angle)-PI/2)
 draw_weapon_body(surface,w,true)
 surface.draw_set_transform(Vector2.ZERO)
func draw_weapon_body(surface:CanvasItem,w:float,physical:bool)->void:
 if not physical:super.draw_weapon_body(surface,w,physical);return
 # Cancel the existing port/face paint shift so the new base centres on the pivot.
 var base:=Vector2(0,(.64-muzzle_factor/.45)*w)
 surface.draw_circle(base,w*1.03,Color("080f19"))
 surface.draw_circle(base,w*.85,Color("e8b66d"))
 surface.draw_circle(base,w*.69,Color("263648"))
 surface.draw_rect(Rect2(base+Vector2(-.50,-.26)*w,Vector2(1.0,.54)*w),Color("101a27"))
 # Broad silver gun housing and dark muzzle stop at the original live port.
 var outline:=PackedVector2Array([base+Vector2(-.40,-.42)*w,base+Vector2(.40,-.42)*w,Vector2(.35*w,.64*w),Vector2(-.35*w,.64*w)])
 surface.draw_colored_polygon(outline,Color("080e17"))
 var armor:=PackedVector2Array([base+Vector2(-.25,-.28)*w,base+Vector2(.25,-.28)*w,Vector2(.22*w,.47*w),Vector2(-.22*w,.47*w)])
 surface.draw_colored_polygon(armor,Color("c4d7df"))
 surface.draw_rect(Rect2(-.14*w,.47*w,.28*w,.17*w),Color("07101a"))
 surface.draw_rect(Rect2(base+Vector2(-.12,-.22)*w,Vector2(.24,.19)*w),Color("ef8b32"))
