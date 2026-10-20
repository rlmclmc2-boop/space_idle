extends SceneTree

class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass

func _initialize()->void:
 call_deferred("run")

func run()->void:
 var mixed:bool=OS.get_environment("BATTLEFIELD_MOTION_MIXED")=="1"
 var baseline:Dictionary=await run_case(false)
 var moving:Dictionary=await run_case(OS.get_environment("BATTLEFIELD_MOTION_COMPARE_OFF")!="1")
 var same_result:bool=baseline.result==moving.result
 var same_rebuilds:bool=baseline.rebuilds==moving.rebuilds
 var pause_frozen:bool=baseline.pause_frozen and moving.pause_frozen
 print("BATTLEFIELD_MOTION_CONSISTENCY ",JSON.stringify({"mixed":mixed,"same_result":same_result,"same_rebuilds":same_rebuilds,"pause_frozen":pause_frozen,"off":baseline,"on":moving}))
 quit(0 if same_result and same_rebuilds and pause_frozen else 1)

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
 if OS.get_environment("BATTLEFIELD_MOTION_MIXED")=="1":
  game.profile.selectedShip="Heavy_Battleship"
  game.profile.loadout.weapons=[]
  for key in ["longLaser","laser","missile","cannon","cannon"]:game.profile.loadout.weapons.append({"key":key,"level":1})
  game.invalidate_stat_cache()
  assert(scene.ship_view.set_hull("Heavy_Battleship"))
  scene.current_hull="Heavy_Battleship"
  scene._set_reference_dimensions()
  assert(scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons")))
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
 var pause_start:Vector2=Vector2.ZERO
 var pause_end:Vector2=Vector2.ZERO
 var pause_clock_start:=0.0
 var pause_clock_end:=0.0
 for frame in (600 if OS.get_environment("BATTLEFIELD_MOTION_MIXED")=="1" else 180):
  if OS.get_environment("BATTLEFIELD_MOTION_FAST_PAUSE")=="1":
   if frame==150:
    game.paused=true
    pause_start=Vector2(scene.battlefield_motion_player.offset)
    pause_clock_start=scene.battlefield_motion_clock
   if frame==210:
    pause_end=Vector2(scene.battlefield_motion_player.offset)
    pause_clock_end=scene.battlefield_motion_clock
    game.paused=false
    game.speed=10.0
   if frame==330:game.speed=1.0
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
 var launch_errors:Dictionary={"pulse":scene.pulse_origin_max_error,"rail":scene.rail_origin_max_error,"missile":scene.missile_origin_max_error}
 scene.queue_free()
 await process_frame
 return {"result":result,"rebuilds":rebuilds,"pose_frames":last.poses,"setup_rng":setup_rng,"trace":trace,"pause_frozen":pause_start==pause_end and pause_clock_start==pause_clock_end,"launch_errors":launch_errors}
