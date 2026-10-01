extends SceneTree
class Meter extends RefCounted:
 var rows={}
 func record(key,us):
  if not rows.has(key):rows[key]={"calls":0,"us":0}
  rows[key].calls+=1;rows[key].us+=us
var meter=Meter.new()
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(reference:bool):
 seed(1701)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);scene.set_process(false);scene.automation_args=[]
 var g=scene.game
 g.save_enabled=false;g.stat_cache_enabled=true;g.speed=1;g.profile.onboarding.completed=true
 if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.enhancementLevel=30;g.profile.enhancementAttacks=1000000;g.profile.enhancementHits=1000000
 g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":1e40,"2":1e40}
 for key in g.db.data.hightech:g.profile.hightechLevels[key]=303
 for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
 g.profile.loadout={"weapons":[],"defence":[]}
 for i in 8:g.profile.loadout.weapons.append({"key":"missile","level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.rng.seed=1701;g.state=BattleGame.State.COMBAT;g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100;enemy.equipment=[]
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0);scene.equipment_panel.set_upgrade_amount(1)
 scene.background_unfocused=false;g.paused=false
 return scene
func _initialize()->void:
 Engine.set_meta("saved_perf",meter)
 call_deferred("run")
func run()->void:
 Engine.max_fps=60
 var scene=fixture(true);current_scene=scene;var g=scene.game
 for effect in ["proficiency","repeat","critical"]:
  for node in [1,2,3]:g.set_enhancement_branch("weapons",effect,node,"B")
 for enemy in g.enemies:enemy.drops=[]
 g.rng.seed=1701
 var rows=[];var retired=[]
 for frame in 300:
  # Controlled ordinary target loss; replacement identity appears next step.
  if frame>=90 and frame%60==30:
   var victim=g.enemies[0];victim.hp=0
   var replacement=victim.duplicate(true);g.uid+=1;replacement.uid=g.uid;replacement.hp=1e100;replacement.max_hp=1e100
   g.enemies.erase(victim);g.enemies.append(replacement);g.refresh_missile_target_registry()
  meter.rows.clear()
  var began=Time.get_ticks_usec()
  scene._process(1./60.)
  var main_us=Time.get_ticks_usec()-began
  await RenderingServer.frame_post_draw
  var frame_us=Time.get_ticks_usec()-began
  var orphan=0;var own=0;var hostile=0
  for shot in g.projectiles:
   if shot.hostile:hostile+=1
   elif shot.get("prototype_missile",false):
    own+=1
    if shot.target.is_empty():orphan+=1
  rows.append({"frame":frame,"main_us":main_us,"frame_us":frame_us,"phases":meter.rows.duplicate(true),"projectiles":g.projectiles.size(),"own_missiles":own,"hostile":hostile,"orphans":orphan,"queue":g.missile_queue.size(),"repeats":g.jewel_repeats.size(),"attacks":g.profile.enhancementAttacks,"rng":str(g.rng.state),"player":g.player.duplicate(true),"hits":g.hit_records.size(),"launches":g.launch_records.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 FileAccess.open("res://density.json",FileAccess.WRITE).store_string(JSON.stringify({"cache":g.stat_cache_enabled,"speed":g.speed,"amount":scene.equipment_panel.upgrade_amount,"branches":g.profile.enhancementBranches,"loadout":g.profile.loadout,"rows":rows,"launches":g.launch_records.size(),"hits":g.hit_records.size()}))
 print("DENSITY DONE frames=",rows.size()," cache=",g.stat_cache_enabled," speed=",g.speed," amount=",scene.equipment_panel.upgrade_amount)
 g.launch_provider=Callable();g.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf");quit()
