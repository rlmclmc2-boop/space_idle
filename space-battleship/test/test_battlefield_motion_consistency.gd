extends SceneTree

class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass

func _initialize()->void:
 call_deferred("run")

func run()->void:
 var baseline:Dictionary=await run_case(false)
 var moving:Dictionary=await run_case(OS.get_environment("BATTLEFIELD_MOTION_COMPARE_OFF")!="1")
 var same_result:bool=baseline.result==moving.result
 var same_rebuilds:bool=baseline.rebuilds==moving.rebuilds
 print("BATTLEFIELD_MOTION_CONSISTENCY ",JSON.stringify({"same_result":same_result,"same_rebuilds":same_rebuilds,"off":baseline,"on":moving}))
 quit(0 if same_result and same_rebuilds else 1)

func run_case(enabled:bool)->Dictionary:
 var scene:Node=load("res://main.tscn").instantiate()
 scene.set_script(UI)
 scene.automation_args=["--capture"]
 root.add_child(scene)
 scene.automation_args=[]
 scene.set_process(false)
 scene.battlefield_motion_enabled=enabled
 var game:BattleGame=scene.game
 game.save_enabled=false
 game.profile.onboarding.completed=true
 game.profile.onboarding.dismissed=true
 game.rng.seed=740221
 assert(game.start(1,false))
 game.group_index=1
 game.spawn_group()
 var setup_rng:int=game.rng.state
 var events:Dictionary={}
 var trace:Array=[]
 game.event.connect(func(kind:String,_info:Dictionary)->void:
  if kind in ["fire","hit","explode","wave_clear","state","collect"]:events[kind]=int(events.get(kind,0))+1
  if kind in ["fire","hit"] and trace.size()<32:
   var shot:Dictionary=_info.get("shot",{})
   trace.append([kind,_info.get("uid",-1),_info.get("x",0),_info.get("y",0),shot.get("x",0),shot.get("y",0),shot.get("mount",-1),game.rng.state,scene.ship_view.display_offset,scene.battle_slice_runtime!=null,scene.ship_view.modules[0].pivot.rotation.y,scene.ship_view.modules[0].node.position,scene.ship_view.ship.position]))
 var first:Dictionary=scene.battlefield_motion_counters()
 for frame in 180:
  scene._process_battlefield(1.0/60.0)
  await process_frame
 var last:Dictionary=scene.battlefield_motion_counters()
 var rebuilds:Dictionary={}
 for key in ["hull_builds","loadout_builds","body_attach_builds","body_texture_bakes","body_material_invalidations","enemy_hull_scans","enemy_envelope_builds"]:
  rebuilds[key]=int(last[key])-int(first[key])
 var enemies:Array=[]
 for enemy in game.enemies:
  enemies.append([enemy.uid,enemy.hp,enemy.shield,enemy.x,enemy.y])
 var shots:Array=[]
 for shot in game.projectiles:
  shots.append([shot.get("serial",-1),shot.get("x",0),shot.get("y",0),shot.get("dead",false),shot.get("target",{}).get("uid",-1)])
 var drops:Array=[]
 for drop in game.drops:drops.append([drop.get("source_uid",-1),drop.get("resourceId",-1),drop.get("amount",0)])
 var result:Dictionary={"state":game.state,"stage":game.stage,"group":game.group_index,"uid":game.uid,"rng_state":game.rng.state,"player_armour":game.player.armour,"player_shield":game.player.shield,"enemies":enemies,"shots":shots,"drops":drops,"events":events}
 scene.queue_free()
 await process_frame
 return {"result":result,"rebuilds":rebuilds,"pose_frames":last.poses,"setup_rng":setup_rng,"trace":trace}
