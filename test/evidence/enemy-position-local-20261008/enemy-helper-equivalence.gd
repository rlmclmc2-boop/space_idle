extends SceneTree
class Counted extends "res://scripts/main.gd":
 var position_calls:=0
 func enemy_render_position(enemy:Dictionary)->Vector2:
  position_calls+=1;return super.enemy_render_position(enemy)
class Baseline extends Counted:
 func enemy_component_pose(enemy:Dictionary,component,render_position:=Vector2.INF)->Dictionary:
  var point:Dictionary=component.hardpoint
  var width:=enemy_render_width(enemy)
  var hull_angle:=enemy_render_angle(enemy)
  var normalized:Array=point.pos
  var origin:=Vector2(float(normalized[0])*width,float(normalized[1])*width*2.0).rotated(PI+hull_angle)
  var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
  var module_width:=width*0.42*class_scale
  var angle:=PI/2+hull_angle+enemy_weapon_angle(enemy,component.owner_slot)+deg_to_rad(float(point.get("base_rotation",0)))
  var muzzle:Array=component.profile.get("muzzle",[[0.22,0]])
  var port:=Vector2(float(muzzle[0][0]),float(muzzle[0][1]))*module_width
  return {"origin":origin,"angle":angle,"width":module_width,"port":port,"muzzle":origin+port.rotated(angle)}

 func enemy_port_offset(enemy: Dictionary, index: int,render_position:=Vector2.INF) -> Vector2:
  var component=enemy_component_for_slot(enemy,index)
  if component!=null:return enemy_component_pose(enemy,component).muzzle
  # Unknown external configurations keep the previous logical mount fallback.
  var point:=hardpoint_for_slot("enemy_"+str(clampi(int(enemy.size),1,6)),index)
  if point.is_empty():return Vector2.ZERO
  var width:=enemy_render_width(enemy)
  var angle:=float(enemy_pose(enemy).rotation)
  var origin:=Vector2(float(point.pos[0])*width,float(point.pos[1])*width*2.0).rotated(PI+angle)
  var class_scale:=float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
  return origin+Vector2(width*0.42*class_scale*0.22,0).rotated(PI/2+angle)

 func enemy_weapon_angle(enemy: Dictionary, index: int,render_position:=Vector2.INF) -> float:
  var component = enemy_component_for_slot(enemy,index)
  if component==null:return 0.0
  var role: String = component.mode()
  if role!="main" and role!="secondary":return 0.0
  var pose_angle := enemy_render_angle(enemy)
  var desired := wrapf((player_render_position()-enemy_render_position(enemy)).angle()-PI/2-pose_angle,-PI,PI)
  var limit := deg_to_rad(float(component.hardpoint.get("rotation_limit",0)))
  return clampf(desired,-limit,limit)*(1.0 if role=="main" else 0.2)

 func visual_muzzle(shot: Dictionary) -> Vector2:
  if shot.has("ballistic_target_origin"):return Vector2(shot.launch_point)
  var pos := Vector2(shot.x,shot.y)
  if shot.hostile:
   var nearest: Dictionary = {}
   var distance := INF
   for enemy in game.enemies:
    if is_same(enemy,shot.get("source",{})):
     return battle_logical_point(enemy_render_position(enemy)+enemy_port_offset(enemy,enemy_shot_mount(enemy,shot)))
    for index in enemy.equipment.size():
     var candidate := pos.distance_squared_to(Vector2(enemy.x,enemy.y)+game.enemy_weapon_offset(enemy,index))
     if candidate<distance:
      distance=candidate
      nearest=enemy
   if not nearest.is_empty():return battle_logical_point(enemy_render_position(nearest)+enemy_port_offset(nearest,enemy_shot_mount(nearest,shot)))
   return pos
  var index := shot_mount(shot)
  if index>=0:return turret_muzzle(index)
  var source := Vector2(game.player.x,game.player.y)
  return source+(pos-source)*player_art_scale()/SHIP_VISUALS.scale_for(db.ship(str(game.profile.selectedShip)))

 func enemy_drop_anchor(enemy: Dictionary) -> Vector2:
  return enemy_render_position(enemy)+Vector2(0,enemy_render_width(enemy)+12.0)
var checks:=0
var failures:=0
var records:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.stat_cache_enabled=true;g.profile.highestLevel=34;g.profile.resources={"1":1e9,"2":1e9};g.upgrade_slot("defence",0,33)
 var base=Baseline.new();var candidate=Counted.new()
 for ui in [base,candidate]:
  ui.db=db;ui.game=g;ui.visual_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
  for key in ui.battle_visual:ui.battle_visual[key]=ProjectSettings.get_setting("visuals/"+key,ui.battle_visual[key])
 var worlds_before=var_to_str(g.profile);var rng_before=g.rng.state
 for stage in [13,14,34]:
  check(g.start(stage,false),"startfixture"+str(stage));g.spawn_group()
  var enemy=g.enemies[0];enemy.equipment=[{"name":"laser"},{"name":"missile"},{"name":"cannon"},{"name":"longLaser"}]
  for size in range(1,7):
   enemy.size=size
   for ui in [base,candidate]:ui.enemy_poses.clear()
   for time in [0.0,0.1,1.0,5.0]:
    for ui in [base,candidate]:ui.fx_time=time
    var signature="stage%d,size%d,time%s"%[stage,size,time]
    for index in enemy.equipment.size():
     base.position_calls=0;candidate.position_calls=0
     var shot={"hostile":true,"source":enemy,"mount":index,"x":enemy.x,"y":enemy.y}
     var before=base.visual_muzzle(shot);var after=candidate.visual_muzzle(shot)
     check(before==after,signature+" muzzle"+str(index))
     records.append({"context":signature,"kind":"muzzle","index":index,"before_calls":base.position_calls,"after_calls":candidate.position_calls,"equal":before==after})
     var component=candidate.enemy_component_for_slot(enemy,index)
     if component!=null:check(base.enemy_component_pose(enemy,component)==candidate.enemy_component_pose(enemy,component),signature+" component"+str(index))
    base.position_calls=0;candidate.position_calls=0
    var before=base.enemy_drop_anchor(enemy);var after=candidate.enemy_drop_anchor(enemy)
    check(before==after,signature+" dropanchor")
    records.append({"context":signature,"kind":"drop","before_calls":base.position_calls,"after_calls":candidate.position_calls,"equal":before==after})
    var orphan={"hostile":true,"source":{},"x":enemy.x,"y":enemy.y}
    check(base.visual_muzzle(orphan)==candidate.visual_muzzle(orphan),signature+" nearestfallback")
    enemy.x+=3.0;enemy.y+=5.0
    check(base.enemy_drop_anchor(enemy)==candidate.enemy_drop_anchor(enemy),signature+" aftermovement")
    enemy.x-=3.0;enemy.y-=5.0
 print("HELPERS %d checks,%d failures; RNG unchanged=%s,cache=%s"%[checks,failures,str(rng_before==g.rng.state),str(g.stat_cache_enabled)])
 var file=FileAccess.open("/workspace/bug-qa/performance-20261008/enemy-helper-equivalence.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rng_unchanged":rng_before==g.rng.state,"records":records}));file.close()
 base.free();candidate.free();quit(1 if failures else 0)
