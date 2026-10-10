extends SceneTree
class QueryUI extends "res://scripts/battlefield.gd":
 var reads:=0
 var measuring:=false
 func enemy_render_position(enemy:Dictionary)->Vector2:
  if measuring:reads+=1
  return super.enemy_render_position(enemy)
 func reference_damage_text_position(origin: Vector2, value: String, size_value := 19, excluded_entry: Dictionary = {}) -> Vector2:
  var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
  var enemy_bounds: Array[Rect2] = []
  var bounds_ready := false
  # Drawing may hold a precomputed position; retain its original full query.
  var fleet_bottom := INF if battle_draw_active else damage_text_enemy_bottom()
  for row in 2:
   for shift in [0,-56,56,-140,140]:
    var pos := Vector2(clampf(origin.x-width/2+shift,8,BattleGame.BATTLE_SIZE.x-8-width),origin.y-row*40)
    var bounds := damage_text_rect(battle_point(pos),value,size_value)
    if bounds.position.y<8:continue
    var blocked := false
    for entry in floats:
     if entry.get("damage",false) and float(entry.life)>0 and not is_same(entry,excluded_entry) and bounds.grow(8).intersects(damage_text_rect(battle_point(entry.pos),entry.text,entry.size)):blocked = true
    if blocked:continue
    if bounds.position.y<fleet_bottom:
     if not bounds_ready:
      enemy_bounds=damage_text_enemy_bounds();bounds_ready=true
     for obstacle in enemy_bounds:
      if bounds.intersects(obstacle):blocked = true
    if not blocked:return pos
  return Vector2.INF
 func reference_flush()->void:
  for entry in damage_pending.duplicate():
   if fx_time-entry.born>0.3:damage_pending.erase(entry);continue
   var active=floats.filter(func(f):return f.get("target","")==entry.target and not f.get("incoming_lane",false))
   if active.size()>=2:
    active[0].life=minf(active[0].life,0.08);active[0].retiring=true;continue
   var pos=reference_damage_text_position(entry.origin,entry.text,entry.size)
   if pos==Vector2.INF:
    if fx_time-entry.born>0.2:damage_pending.erase(entry)
    continue
   entry.pos=pos;floats.append(entry);damage_pending.erase(entry)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(QueryUI);scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.highestLevel=8;g.profile.cleared=range(1,9);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout.defence[0]={"key":"armour","level":8};g.invalidate_stat_cache();g.start(8,false);g.group_index=3;g.spawn_group();g.paused=true
 check(g.enemies.size()==15,"real stage8 fourth-wave fleet fixture")
 scene.fx_time=5.0
 for enemy in g.enemies:scene.enemy_pose(enemy).born=0.0
 var profile:Dictionary=g.profile.duplicate(true);var finite:=0
 for explicit in [false,true]:
  for enemy in g.enemies:enemy.explicit_formation=explicit
  for origin in [Vector2(286,680),Vector2(160,330),Vector2(430,450)]:
   for value in ["408","物理 408","1.23e+100"]:
    scene.measuring=true;scene.reads=0
    var position:Vector2=scene.damage_text_position(origin,value,19)
    scene.measuring=false
    check(scene.reads in [0,15],"placement skips the fleet or reads every live enemy once")
    if origin.y==680:check(scene.reads==0,"player feedback below the fleet avoids all animated coordinate queries")
    if position==Vector2.INF:continue
    finite+=1;var rect:Rect2=scene.damage_text_rect(scene.battle_point(position),value,19)
    var clear:=true
    for enemy in g.enemies:
     var center:Vector2=scene.enemy_render_position(enemy);var width:float=scene.enemy_render_width_at_y(enemy,center.y)
     var envelope:Vector2=Vector2(width*0.6,width*1.15)+Vector2(float(scene.battle_visual.enemy_idle_x),float(scene.battle_visual.enemy_idle_y))
     if rect.intersects(Rect2(center-envelope,envelope*2.0)):clear=false
    check(clear,"ordinary and explicit fleet footprints still exclude returned text placement")
 # Frozen pre-optimization oracle: exact local placements remain unchanged
 # while obstacles, exclusion, label text and live/dead rows vary.
 for explicit in [false,true]:
  for enemy in g.enemies:enemy.explicit_formation=explicit
  for label_count in [0,1,8]:
   scene.floats.clear()
   for i in label_count:scene.floats.append({"damage":true,"life":0.0 if i==3 else 0.42,"text":"energy 123M" if i%2 else "408","size":15 if i%2 else 19,"pos":Vector2(80+i*56,230+(i%3)*40)})
   var context={}
   for origin in [Vector2(286,680),Vector2(160,330),Vector2(430,450),Vector2(80,230)]:
    for value in ["408","energy 408","1.23e+100"]:
     var excluded:Dictionary=scene.floats[0] if label_count>0 else {}
     var expected:Vector2=scene.reference_damage_text_position(origin,value,19,excluded)
     var actual:Vector2=scene.damage_text_position(origin,value,19,excluded,context)
     check(actual==expected,"synchronous layout matches frozen placement with current live labels")
 # Complete synchronous flush: newly accepted, retired, expired and incoming
 # labels must preserve the frozen oracle's order, placement and backlog.
 for initial_count in [0,2,8]:
  for y in [230,450,680]:
   scene.floats.clear();scene.damage_pending.clear()
   for i in initial_count:
    scene.floats.append({"damage":true,"life":-0.01 if i==1 else 0.4,"text":"408","size":19,"pos":Vector2(80+i*56,230),"target":"enemy0","incoming_lane":i==2})
   for i in 12:
    scene.damage_pending.append({"damage":i!=3,"life":0.5,"text":"energy 408" if i%2 else "408","size":15 if i%2 else 19,"origin":Vector2(160+(i%3)*80,y),"born":4.6 if i==11 else 4.9,"target":"enemy%d"%(i%4)})
   var before_floats=scene.floats.duplicate(true);var before_pending=scene.damage_pending.duplicate(true)
   scene.reference_flush();var expected_floats=scene.floats.duplicate(true);var expected_pending=scene.damage_pending.duplicate(true)
   scene.floats=before_floats;scene.damage_pending=before_pending;scene.flush_damage_numbers()
   check(scene.floats==expected_floats and scene.damage_pending==expected_pending,"flush retains exact placements, retirement and backlog")
 scene.floats.clear()
 scene.battle_draw_active=true;scene.measuring=true;scene.reads=0
 scene.damage_text_position(Vector2(286,680),"408",19);scene.measuring=false
 check(scene.reads==15,"drawing retains full query of its cached enemy positions")
 scene.battle_draw_active=false
 for enemy in g.enemies:enemy.hp=0
 scene.measuring=true;scene.reads=0
 var empty_position:Vector2=scene.damage_text_position(Vector2(286,680),"408",19);scene.measuring=false
 check(scene.reads==0 and empty_position!=Vector2.INF,"dead fleet never requests coordinates or blocks safe feedback")
 check(finite>0 and g.profile==profile,"placement remains read-only and admits safe player feedback")
 scene.queue_free();await process_frame
 print("DAMAGE_POSITION_QUERIES %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
