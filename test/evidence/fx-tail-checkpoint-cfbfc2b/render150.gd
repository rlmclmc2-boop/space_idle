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
 for frame in 90:
  scene._process(1./60.)
  await RenderingServer.frame_post_draw
 var shots=g.projectiles.duplicate();var visuals=scene.projectile_visuals.duplicate()
 assert(not shots.is_empty())
 g.projectiles.clear();scene.projectile_visuals.clear()
 for i in 150:
  var source=shots[i%shots.size()];var shot=source.duplicate();shot.serial=100000+i
  var visual={}
  for candidate in visuals:
   if is_same(candidate.shot,source):visual=candidate.duplicate();break
  assert(not visual.is_empty());visual.shot=shot
  g.projectiles.append(shot);scene.projectile_visuals.append(visual)
 var rows=[]
 var rng_before=str(g.rng.state);var attacks_before=g.profile.enhancementAttacks
 for frame in 120:
  meter.rows.clear();scene.battle_layer.queue_redraw()
  await RenderingServer.frame_post_draw
  rows.append(meter.rows.duplicate(true))
 assert(str(g.rng.state)==rng_before and g.profile.enhancementAttacks==attacks_before)
 FileAccess.open("res://render150.json",FileAccess.WRITE).store_string(JSON.stringify({"count":g.projectiles.size(),"cache":g.stat_cache_enabled,"speed":g.speed,"amount":scene.equipment_panel.upgrade_amount,"rows":rows}))
 print("RENDER150 DONE count=",g.projectiles.size())
 g.launch_provider=Callable();g.target_provider=Callable();scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf");quit()
