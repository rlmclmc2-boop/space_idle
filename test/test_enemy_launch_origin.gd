extends SceneTree
class LaunchUI extends "res://scripts/battlefield.gd":
 var muzzle_reads:=0
 var last_muzzle:=Vector2.ZERO
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func visual_muzzle(shot:Dictionary)->Vector2:
  muzzle_reads+=1
  last_muzzle=super.visual_muzzle(shot)
  return last_muzzle
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(LaunchUI);scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.stage=20;g.group_index=0;g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var fleet=g.enemies.duplicate()
 for capped in [false,true]:
  for enemy in fleet:
   for slot in range(enemy.equipment.size()):
    var key=str(enemy.equipment[slot].name)
    if key not in ["laser_mon","cannon_mon"]:continue
    scene.projectile_visuals.clear();scene.enemy_impacts.clear();scene.muzzle_reads=0
    if capped:
     for i in range(256):scene.projectile_visuals.append({"shot":{"serial":-i-1}})
    var rng_before=g.rng.state
    g.fire(enemy,g.player,g.db.enemy_weapon(key),1.0,true,key,g.enemy_weapon_offset(enemy,slot))
    var shot=g.projectiles.back()
    var visual=scene.projectile_visual(shot)
    check(scene.muzzle_reads==(2 if capped else 1),"single solve or missing-record fallback "+key)
    check(scene.enemy_impacts.size()==1,"one ordered fire cue")
    check(scene.enemy_impacts[0].position==(scene.last_muzzle if capped else visual.origin),"exact original cue origin")
    check(visual.is_empty()==capped,"visual capacity boundary")
    check(g.rng.state==rng_before,"no RNG consumption")
 check(checks>0,"actual authored enemy launch cases")
 print("ENEMY_LAUNCH_ORIGIN ",checks," checks ",failures," failures")
 scene.queue_free();await process_frame
 quit(1 if failures else 0)
