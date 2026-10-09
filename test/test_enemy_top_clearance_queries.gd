extends SceneTree
## Top-bound projection must use exactly one angle without changing collision clearance.
class Probe extends "res://scripts/battlefield.gd":
 var angle_calls:=0
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func enemy_render_angle(enemy:Dictionary)->float:
  angle_calls+=1
  return super.enemy_render_angle(enemy)
 func original_clearance(enemy:Dictionary,y:float)->float:
  var pose:=enemy_pose(enemy)
  var width:=enemy_render_width_at_y(enemy,y)
  var scale_value:=enemy_recognition_screen_scale()
  var key:=Vector2(ceili(width*scale_value/2.0),scale_value)
  if not pose.has("top_geometries"):pose.top_geometries={}
  # The target and top-bound solver sample different width buckets; keep each
  # cached separately so stationary frames never rebuild alternating envelopes.
  if not pose.top_geometries.has(key):pose.top_geometries[key]={}
  var packet:Dictionary=enemy_recognition.geometry(ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),width,enemy_recognition.descriptors(enemy_weapon_components(enemy)),float(enemy.get("max_shield",0))>0 and float(enemy.get("shieldRecovery",0))>0,pose.top_geometries[key],scale_value,int(enemy.size)>=4)
  var outlines:Array=[packet.inner]
  if float(enemy.get("max_shield",0))>0:
   outlines.append(packet.outer)
   if int(enemy.get("shieldType",0))==1 and int(enemy.size)>=4:outlines.append(packet.front)
  var top:=0.0
  for outline in outlines:
   for point in outline:top=minf(top,Vector2(point).rotated(PI+enemy_render_angle(enemy)).y)
  # Two 4px meters spaced by 7 logical px; boss captions also need their ascent.
  var status_space:=28.0 if game.is_boss_encounter() else 16.0
  return -top+status_space+6.0+4.0/enemy_recognition_screen_scale()
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(Probe);scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.loadout.defence[0]={"key":"armour","level":8};g.invalidate_stat_cache();g.start(8,false);g.group_index=3;g.spawn_group();g.paused=true
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 var enemy:Dictionary=g.enemies[0]
 for size in [1,4,6]:
  enemy.size=size
  for shield in [false,true]:
   enemy.max_shield=100 if shield else 0;enemy.shieldRecovery=5 if shield else 0
   for shield_type in [1,2]:
    enemy.shieldType=shield_type
    for time in [0.0,0.25,5.0]:
     scene.fx_time=time
     for y in [90.0,200.0,500.0]:
      var expected:float=scene.original_clearance(enemy,y)
      scene.angle_calls=0
      var actual:float=scene.enemy_display_top_clearance(enemy,y)
      check(actual==expected,"exact clearance size%d shield%s type%d time%s y%s"%[size,shield,shield_type,time,y])
      check(scene.angle_calls==1,"one angle query across every outline vertex")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng,"projection preserves profile and RNG")
 scene.queue_free();await process_frame
 print("Enemy top clearance: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
