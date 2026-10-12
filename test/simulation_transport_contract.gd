extends SceneTree
# Actual Owner/Presenter protocol, synthetic geometry values, no rendering/thread claim.
const Owner=preload("res://scripts/simulation_battle_owner.gd")
const Presenter=preload("res://scripts/simulation_battle_presenter.gd")
const Display=preload("res://scripts/simulation_display_game.gd")
class Pose extends RefCounted:
 var orbit_elapsed:float=0.0
class Geometry extends RefCounted:
 var fx_time:float=0.0
 var demo_time:float=0.0
 var turret_visuals:Dictionary={}
 var fleet_pose=Pose.new()
 func before_tick(dt:float)->void:fx_time+=dt;demo_time+=dt
 func after_tick()->void:pass
 func visual_muzzle(_shot:Dictionary)->Vector2:return Vector2.ZERO
class Surface extends RefCounted:
 var fx_time:float=0.0
 var demo_time:float=0.0
 var ship_view=Pose.new()
 var turret_visuals:Dictionary={}
 var simulation_event_muzzles:Dictionary={}
 var shield_before_hit:Variant=0.0
 var projectile_visuals:Array=[]
 var beam_visuals:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 game.save_enabled=false;game.rng.seed=1701
 game.profile.resources={"1":1e30,"2":1e30}
 game.profile.loadout.weapons=[{"key":"laser","level":1}]
 game.invalidate_stat_cache();game.reset_player();game.state=BattleGame.State.COMBAT;game.spawn_group()
 for enemy in game.enemies:enemy.hp=1e30;enemy.max_hp=1e30
 game.enable_simulation_state_bridge()
 var owner=Owner.new();owner.attach(game,Geometry.new())
 var presenter=Presenter.new();presenter.owner=owner;presenter.model=Display.new(ShipDatabase.new(),false,game.profile.duplicate(true));presenter.scene=Surface.new()
 assert(not owner.dispatch("set_field",["paused","bad"]).accepted)
 assert(not owner.dispatch("set_speed",["bad"]).accepted)
 assert(not owner.dispatch("collect_uid",[{},false]).accepted)
 var first=owner.dispatch("set_field",["paused",true]);var second=owner.dispatch("set_field",["paused",false])
 assert(first.accepted and second.accepted and second.sequence==first.sequence+1 and not game.paused)
 var foreign=RefCounted.new()
 assert(not owner.dispatch("start",[1,false,{"foreign":foreign}]).accepted)
 assert(owner.dispatch("upgrade_slot",["weapons",0,1]).accepted)
 for tick in 90:assert(owner.advance(1.0/60.0))
 assert(owner.mailbox.metrics().dropped_snapshots>0)
 var lease=owner.mailbox.acquire_latest()
 for key in ["entities_added","shots_added","configuration","retired_shots"]:assert(not lease.frame.has(key))
 owner.mailbox.release(lease.slot)
 # All one-shot descriptors must survive even after every dynamic slot was skipped.
 presenter.consume()
 assert(presenter.model.profile.loadout.weapons[0].level==game.profile.loadout.weapons[0].level)
 assert(presenter.enemy_views.size()>=game.enemies.size())
 assert(owner.advance(0.0));presenter.consume()
 assert(presenter.model.projectiles.size()==game.projectiles.size())
 for shot in game.projectiles:
  assert(presenter.shot_views.has(int(shot.serial)))
  var view:Dictionary=presenter.shot_views[int(shot.serial)]
  assert(not is_same(shot,view))
  assert(Vector2(view.x,view.y)==Vector2(game.projectile_x(shot),game.projectile_y(shot)))
 # Force FIFO backpressure in a completed substep; retained events are retried.
 owner.mailbox.event_limit=1
 var complete=owner.advance(1.0)
 if not complete:complete=owner.advance(0.25)
 var retries=0
 while not complete:
  presenter.consume();complete=owner.advance(0.0);retries+=1;assert(retries<1000)
 presenter.consume();assert(owner.pending_events.is_empty())
 assert(owner.logical_steps==165) # 90 prior steps plus all 1.25 seconds of debt.
 assert(presenter.applied_events==owner.event_count)
 print("SIMULATION_TRANSPORT_CONTRACT_PASS snapshots_skipped=",owner.mailbox.metrics().dropped_snapshots,"; retries=",retries,"; commands_value_checked; births_configuration_lossless; no_battle_thread")
 presenter.close();game.simulation_bridge.close();quit()
