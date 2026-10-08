extends SceneTree
class QueryUI extends "res://scripts/battlefield.gd":
 var reads:=0
 var measuring:=false
 func enemy_render_position(enemy:Dictionary)->Vector2:
  if measuring:reads+=1
  return super.enemy_render_position(enemy)
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
    check(scene.reads==15,"one coordinate read per live enemy in one placement query")
    if position==Vector2.INF:continue
    finite+=1;var rect:Rect2=scene.damage_text_rect(scene.battle_point(position),value,19)
    var clear:=true
    for enemy in g.enemies:
     var center:Vector2=scene.enemy_render_position(enemy);var width:float=scene.enemy_render_width_at_y(enemy,center.y)
     var envelope:Vector2=Vector2(width*0.6,width*1.15)+Vector2(float(scene.battle_visual.enemy_idle_x),float(scene.battle_visual.enemy_idle_y))
     if rect.intersects(Rect2(center-envelope,envelope*2.0)):clear=false
    check(clear,"ordinary and explicit fleet footprints still exclude returned text placement")
 check(finite>0 and g.profile==profile,"placement remains read-only and admits safe player feedback")
 scene.queue_free();await process_frame
 print("DAMAGE_POSITION_QUERIES %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
