extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class Meter extends RefCounted:
 var rows={}
 func record(key,us):
  if not rows.has(key):rows[key]={"calls":0,"us":0}
  rows[key].calls+=1;rows[key].us+=us
class UI extends "res://scripts/battlefield.gd":
 var exact=false
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func advance_game_time(seconds:float)->void:
  if not exact:super.advance_game_time(seconds);return
  var remaining=seconds
  while remaining>1e-9:
   var step=minf(remaining,1./60.);game.tick(step);remaining-=step
var meter=Meter.new()
var damage=0.
var incoming=0.
var hit_count=0
var fires=0
var receipts={}
func _initialize()->void:
 Engine.set_meta("x10_meter",meter);call_deferred("run")
func run()->void:
 var args=OS.get_cmdline_user_args();var mode=args[0] if args.size()>0 else "x1"
 var frames=int(args[1]) if args.size()>1 else 600
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.exact=mode=="exact10";scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
 var g=scene.game
 g.save_enabled=false;g.stat_cache_enabled=true;g.speed=1 if mode in ["x1","live1"] else 10
 g.profile.chronoParticles=1e12;g.profile.onboarding.completed=true
 if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.enhancementLevel=30;g.profile.enhancementAttacks=1000000;g.profile.enhancementHits=1000000
 g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":1e40,"2":1e40}
 for key in g.db.data.hightech:g.profile.hightechLevels[key]=303
 for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
 g.profile.loadout={"weapons":[],"defence":[]}
 for i in 8:g.profile.loadout.weapons.append({"key":"missile","level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.start(1,false);g.spawn_group()
 for effect in ["proficiency","repeat","critical"]:
  for node in [1,2,3]:g.set_enhancement_branch("weapons",effect,node,"B")
 var hp=N.multiply(g.jewel_equipment_stat(g.weapon_entries()[0]),1e6)
 for enemy in g.enemies:enemy.hp=hp;enemy.max_hp=hp
 if mode=="threat10":
  for enemy in g.enemies:enemy.dmgMultiple=float(g.player.armour)*.001
  for effect in ["adaptation","memory_material","delayed_damage"]:
   for node in [1,2,3]:g.set_enhancement_branch("defence",effect,node,"B")
 g.refresh_missile_target_registry();g.rng.seed=1701
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0);scene.equipment_panel.set_upgrade_amount(1)
 scene.background_unfocused=false;g.paused=false
 g.event.connect(func(kind,payload):
  if kind=="hit":
   if payload.player:incoming=N.add(incoming,payload.amount)
   else:damage=N.add(damage,payload.amount);hit_count+=1
  if kind=="fire":fires+=1
  if kind=="collect":receipts[str(payload.id)]=N.add(receipts.get(str(payload.id),0),payload.amount))
 if mode in ["x10-noaa","x10-noshadow","x10-scale"]:scene.ship_view.viewport.msaa_3d=Viewport.MSAA_DISABLED
 if mode in ["x10-noshadow","x10-scale"]:scene.ship_view.world.get_node("KeyLight").shadow_enabled=false
 if mode=="x10-scale":scene.ship_view.viewport.scaling_3d_scale=.5
 Engine.max_fps=0 if DisplayServer.get_name()=="headless" else 60
 var replay: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../replay_delta.json")) if mode=="replay10" else []
 var rows=[]
 var start=Time.get_ticks_usec()
 var previous=start-16667
 var supplied_delta=0.0
 var clamp_loss=0.0
 var consumed_seconds=0.0
 for frame in frames:
  meter.rows.clear();var began=Time.get_ticks_usec()
  var actual_delta=(began-previous)/1e6 if mode.begins_with("live") else float(replay[frame]) if mode=="replay10" else 1./60.
  previous=began
  supplied_delta+=actual_delta;clamp_loss+=maxf(0.0,actual_delta-.1);consumed_seconds+=minf(actual_delta,.1)*g.speed
  scene._process(actual_delta)
  var main_us=Time.get_ticks_usec()-began
  if DisplayServer.get_name()=="headless":await process_frame
  else:await RenderingServer.frame_post_draw
  var frame_us=Time.get_ticks_usec()-began
  rows.append({"frame":frame,"supplied_delta":actual_delta,"main_us":main_us,"frame_us":frame_us,"phases":meter.rows.duplicate(true),"projectiles":g.projectiles.size(),"queue":g.missile_queue.size(),"repeats":g.jewel_repeats.size(),"damage":damage,"hits":hit_count,"attacks":g.profile.enhancementAttacks,"rng":str(g.rng.state),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://../"+mode+".png")
 var result={"mode":mode,"game_seconds":consumed_seconds,"supplied_delta_seconds":supplied_delta,"clamp_loss_seconds":clamp_loss,"cadence":"wall" if mode.begins_with("live") else "fixed","wall_us":Time.get_ticks_usec()-start,"speed":g.speed,"step":1./60. if scene.exact or g.speed==1 else 1./15.,"initial_enemy_hp":hp,"damage":damage,"incoming":incoming,"hits":hit_count,"fires":fires,"attacks":g.profile.enhancementAttacks,"rng":str(g.rng.state),"state":g.state,"stage":g.stage,"group":g.group_index,"motion_clock":g.motion_clock,"defense_time":g.enhancement_defense_time,"receipts":receipts,"resources":g.profile.resources,"player":g.player,"enemy_hp":g.enemies.map(func(e):return e.hp),"rows":rows}
 FileAccess.open("res://../"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("X10 PROBE ",mode," frames=",frames," hits=",hit_count," damage=",damage," peak shots fixture nonempty")
 g.launch_provider=Callable();g.target_provider=Callable();scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("x10_meter");quit()
