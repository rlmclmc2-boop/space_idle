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
static func launch_position(host,enemy:Dictionary,slot:int)->Vector2:
 # A committed fixed-port carrier keeps its birth semantics across mode changes.
 var component=host.enemy_component_for_slot(enemy,slot)
 var point:Dictionary=component.hardpoint if component!=null else host.hardpoint_for_slot("enemy_"+str(clampi(int(enemy.size),1,6)),slot)
 var position:Vector2=host.enemy_render_position(enemy)
 var offset:Vector2=Vector2.ZERO if point.is_empty() else pose(point,host.enemy_render_width_at_y(enemy,position.y),host.enemy_render_angle(enemy)).muzzle
 return host.battle_logical_point(position+offset)
