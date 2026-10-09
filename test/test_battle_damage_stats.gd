extends SceneTree
const CC=preload("res://scripts/combat_context.gd")
const STATS=preload("res://scripts/battle_damage_stats.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key:String="laser",with_drone:bool=false):
 var g=BattleGame.new(ShipDatabase.new(),false);g.stat_cache_enabled=true
 g.profile.hightechSavedAt=0;g.profile.hyperspace.random_state="741"
 g.profile.cleared=range(1,41);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout={"weapons":[{"key":key,"level":50}],"defence":[{"key":"armour","level":50},{"key":"shield","level":50}]}
 if with_drone:
  var rng=RandomNumberGenerator.new();rng.seed=51
  var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"stats-drone","white",key,2,"")
  g.profile.hyperspace.inventory.drones[d.id]=d;g.profile.hyperspace.inventory.equipped=[d.id];g.combat_sources_dirty=true
 g.rng.seed=741;g.reset_player();g.spawn_group();g.state=BattleGame.State.COMBAT
 for e in g.enemies:e.hp=1e12;e.max_hp=1e12;e.cooldowns=e.cooldowns.map(func(_cd):return 999.0)
 g.player.armour=1e12;g.player.shield=1e12
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var s=STATS.new()
 s.record("module:0",10);s.advance(1);s.set_enabled(false)
 check(s.buckets.is_empty() and s.totals.is_empty() and s.elapsed==0,"Stopped path retains no buckets or records")
 s.set_enabled(true);s.advance(.5);s.record("module:0",10);s.record("drone:a",20)
 check(s.total==30 and s.snapshot().dps==60,"Combat-time denominator and source totals")
 s.advance(8)
 check(s.total==0 and s.totals.is_empty() and s.buckets.size()==s.COUNT,"Expired damage released in bounded buckets")
 for i in 80:s.record("drone:"+str(i),1)
 check(s.totals.size()<=s.SOURCE_LIMIT and s.buckets.size()==s.COUNT,"Source and bucket counts bounded")
 check(is_equal_approx(s.snapshot().seconds,7.5),"Denominator matches oldest retained bucket boundary")
 s.set_enabled(false);s.set_enabled(false)
 check(s.buckets.is_empty() and s.totals.is_empty(),"Repeated disable allocates no empty bucket dictionaries")
 var g=fixture();g.damage_stats.set_enabled(true);g.db.config.dmgReduce=.5
 var e=g.enemies[0];e.hp=100;e.max_hp=100;e.shield=50;e.max_shield=50;e.shieldType=1;e.armourType=2;e.shieldRecovery=0
 g.hit_enemy(e,100,1,[],false,CC.root(1,"module:0","laser"))
 check(e.shield==0 and e.hp==100 and g.damage_stats.total==50,"Actual shield absorption, excluding mitigated raw damage")
 g.hit_enemy(e,1000,2,[],false,CC.derive(CC.root(2,"drone:stats-drone","laser"),"secondary"))
 check(g.damage_stats.total==150 and g.damage_stats.totals["drone:stats-drone"]==100,"Overkill capped and derived source retained")
 g.hit_enemy(e,1000,2,[],false,CC.root(2,"drone:stats-drone","laser"))
 check(g.damage_stats.total==150,"Dead target adds no repeated settlement")
 g.paused=true;g.tick(1)
 check(g.damage_stats.elapsed==0,"Pause excludes time")
 g.paused=false;g.speed=10;g.tick(.1)
 check(is_equal_approx(g.damage_stats.elapsed,.1),"Game time used once without second speed multiplication")
 g.group_index=0;g.spawn_group()
 check(g.damage_stats.total==0 and g.damage_stats.elapsed==0,"New wave resets damage and time")
 for key in ["laser","cannon","missile","longLaser"]:
  for with_drone in [false,true]:
   var off=fixture(key,with_drone);var on=fixture(key,with_drone);on.damage_stats.set_enabled(true)
   for i in 360:off.tick(1.0/60.0);on.tick(1.0/60.0)
   check(off.rng.state==on.rng.state and off.enemies==on.enemies and off.player==on.player and off.projectiles==on.projectiles and off.profile==on.profile,"Damage/RNG equivalence: "+key+" drone="+str(with_drone))
   check(on.damage_stats.totals.has("module:0"),"Actual slot attribution: "+key)
   if with_drone:check(on.damage_stats.totals.has("drone:stats-drone"),"Actual drone attribution: "+key)
   check(off.damage_stats.buckets.is_empty() and off.damage_stats.totals.is_empty(),"Disabled combat keeps no statistics: "+key)
 # Black-hole absorption contributes no damage until a real release settlement.
 var black=fixture("laser",true);var d=black.profile.hyperspace.inventory.drones["stats-drone"]
 d.legendary=true;d.origin_quality="legendary";d.legendary_effect={"effect_id":"black_hole","parameters":{}}
 for parameter in black.hyperspace.config.legendary_effects.black_hole.parameters:d.legendary_effect.parameters[parameter]=black.hyperspace.config.legendary_effects.black_hole.parameters[parameter][1]
 black.invalidate_stat_cache();black.damage_stats.set_enabled(true)
 var effect=black.drone_combat.effect(black,"black_hole")
 black.drone_combat.advance(black,float(effect.constants.period))
 black.hit_enemy(black.enemies[0],100,0,[],false,CC.root(7,"module:0","laser"))
 check(black.damage_stats.total==0,"Black-hole absorption is not prematurely counted")
 black.drone_combat.advance(black,float(effect.constants.absorption_duration))
 check(black.damage_stats.total>0 and black.damage_stats.totals.has("drone:stats-drone") and not black.damage_stats.totals.has("module:0"),"Black-hole release counted once under the effect's drone owner")
 var timings={false:[],true:[]}
 for pair in 6:
  for enabled in ([false,true] if pair%2==0 else [true,false]):
   var sample=fixture("laser",true);sample.damage_stats.set_enabled(enabled)
   for i in 30:sample.tick(1.0/60.0)
   var start=Time.get_ticks_usec()
   for i in 600:sample.tick(1.0/60.0)
   timings[enabled].append(Time.get_ticks_usec()-start)
 timings[false].sort();timings[true].sort()
 print("CPU 600 ticks us: off=",timings[false]," on=",timings[true]," median ratio=",float(timings[true][3])/float(timings[false][3]))
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var ui=scene.damage_stats_ui;ui.show();await process_frame
 check(not scene.game.damage_stats.enabled and not ui.enabled.button_pressed,"Opening defaults stopped")
 ui.enabled.button_pressed=true;scene.game.damage_stats.record("module:0",5);ui.show();await process_frame
 check(not scene.game.damage_stats.enabled and not ui.enabled.button_pressed and ui.timer.is_stopped() and scene.game.damage_stats.buckets.is_empty(),"Repeated open synchronizes stopped backend and UI")
 ui.enabled.button_pressed=true;scene.game.damage_stats.advance(.5);scene.game.damage_stats.record("drone:an-extremely-long-drone-source-id",12345678);ui.refresh();await process_frame
 check(ui.dialog.size.x<=700 and ui.summary.size.x<=650 and ui.details.size.x<=650,"Long rows fit dialog width")
 var evidence=OS.get_environment("DAMAGE_STATS_EVIDENCE")
 if DisplayServer.get_name()!="headless" and not evidence.is_empty():
  root.size=Vector2i(1178,814);await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(evidence)
 check(not ui.details.text.contains("an-extremely-long-drone-source-id"),"Internal drone ID never appears in player rows")
 ui.dialog.hide();await process_frame
 check(not scene.game.damage_stats.enabled and scene.game.damage_stats.buckets.is_empty(),"Close stops and releases statistics")
 ui.show();ui.enabled.button_pressed=true;var old_dialog=ui.dialog;scene.build_ui();await process_frame
 check(not scene.game.damage_stats.enabled and scene.game.damage_stats.buckets.is_empty() and not is_instance_valid(old_dialog),"Rebuild stops old timer/statistics and frees old window")
 scene.queue_free();await process_frame
 print("Damage statistics: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
