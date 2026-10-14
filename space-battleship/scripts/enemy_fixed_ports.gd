extends RefCounted
## Shared ordinary-enemy port geometry. No aim input, textures or mutable state.
static func enabled(game)->bool:
 return not game.is_boss_encounter()
static func center(point:Dictionary)->Vector2:
 return Vector2(float(point.pos[0]),float(point.pos[1])*2.0)
static func descriptor(component)->Dictionary:
 var point:Dictionary=component.hardpoint
 var factor=0.42*float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
 var muzzle:Array=component.profile.get("muzzle",[[0.22,0]])
 return {"slot":int(component.owner_slot),"position":center(point),"reach":Vector2(float(muzzle[0][0]),float(muzzle[0][1])).length()*factor,"physical":component.damage_type==2,"under":int(point.get("z",1))<=0}
static func pose(point:Dictionary,width:float,hull_angle:float)->Dictionary:
 var origin:Vector2=(center(point)*width).rotated(PI+hull_angle)
 var factor=0.42*float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
 return {"origin":origin,"angle":PI+hull_angle,"width":width*factor,"port":Vector2.ZERO,"muzzle":origin}
static func radius(port:Dictionary,width:float,screen_scale:float)->float:
 return maxf(4.0/maxf(screen_scale,0.1),float(port.reach)*width/(30.0/32.0)+1.0/maxf(screen_scale,0.1))
