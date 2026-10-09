extends SceneTree
## Actual battlefield/main navigation, isolated synthetic claim and forge events.
## Flush times measure synchronous badge work, never whole-frame rendering/FPS.
const Rewards = preload("res://scripts/drone_rewards.gd")
const Bag = preload("res://scripts/drone_inventory.gd")
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;printerr("FAIL: ",message)
func canonical(value)->String:return JSON.stringify(value,"",true,true)
func combat(g)->String:
 return canonical([g.state,g.paused,g.player,g.enemies,g.projectiles,g.rng.state])
func _initialize():call_deferred("run")
func run():
 for count in [3,200]:
  seed(1701)
  var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
  scene.automation_args=["--capture"];scene.music_on=false
  root.add_child(scene);scene.automation_args=[];scene.set_process(false)
  var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.paused=true;g.rng.seed=1701
  g.profile.hightechSavedAt=1700000000.0
  if g.profile.has("chronoSavedAt"):g.profile.chronoSavedAt=1700000000.0
  g.profile.hyperspace.random_state=str(g.rng.state)
  g.profile.onboarding.completed=true;g.profile.highestLevel=40;g.profile.cleared=range(1,41)
  g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
  var rng=RandomNumberGenerator.new();rng.seed=234
  for i in count:
   var d=Rewards.create_drone(rng,g.hyperspace.config,"scene-price:%d"%i,"blue" if i%3==0 else "white",["laser","missile","cannon","longLaser"][i%4],1,"1")
   if i%4==0:
    for affix in d.affixes:affix.locked=true
   check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"fixture insert")
  g.profile.hyperspace.inventory.drones["scene-price:0"].affixes=[]
  g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
  for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=1000000000
  g.profile.hyperspace.ultimate_cores=100
  scene.refresh_tab_visibility();scene.select_system(0)
  await process_frame
  var badge
  for child in scene.system_nav.get_children():
   if child.get_script()==load("res://scripts/system_upgrade_badges.gd"):badge=child
  check(badge!=null,"real navigation controller exists")
  if badge==null:quit(1);return
  badge.flush()
  var s:Dictionary=g.profile.hyperspace
  s.active={"round_id":s.round_id,"run_id":int(s.settled_run)+1,"status":"completed_pending","route":"alpha","mode":"idle","reward":{"drone":{},"materials":{"degenerate_matter":5},"ultimate_cores":0,"hanging_rewards":{}}}
  var run_id:int=s.active.run_id
  s.next_run=run_id+1
  for action in ["claimed","forge_add_affix","hidden_claimed","revealed"]:
   var before_combat=combat(g)
   if action=="hidden_claimed":scene.system_nav_buttons[9].hide();badge.flush()
   var began=Time.get_ticks_usec()
   if action=="claimed":check(g.hyperspace.claim(g,int(s.round_id),run_id),"actual receipt claim succeeds")
   elif action=="forge_add_affix":
    s=g.profile.hyperspace
    var result=g.hyperspace.forge(g,{"round_id":s.round_id,"command_seq":s.command_seq,"operation":"add_affix","drone_id":"scene-price:0","args":{},"expected_revision":s.inventory.drones["scene-price:0"].forge_revision})
    check(str(result.error).is_empty(),"actual forge succeeds: "+str(result))
   elif action=="hidden_claimed":g.event.emit("hyperspace_changed",{"reason":"claimed"})
   else:scene.system_nav_buttons[9].show()
   var event_us=Time.get_ticks_usec()-began
   var after_event=canonical(g.profile);var after_rng=g.rng.state
   began=Time.get_ticks_usec();badge.flush();var flush_us=Time.get_ticks_usec()-began
   check(after_event==canonical(g.profile) and after_rng==g.rng.state,"badge flush read only")
   check(before_combat==combat(g),"warehouse event preserves paused battle")
   check(badge.badges[9].visible==scene.system_nav_buttons[9].visible,"available badge follows hidden/reveal")
   print("SCENE_BADGE ",canonical({"warehouse":count,"action":action,"event_us":event_us,"flush_us":flush_us,"profile_sha256":after_event.sha256_text(),"quotes_sha256":canonical(badge.quotes.get(9,[])).sha256_text(),"combat_sha256":combat(g).sha256_text()}))
  scene.queue_free();await process_frame
 print("Scene badge event failures: ",failures);quit(1 if failures else 0)
