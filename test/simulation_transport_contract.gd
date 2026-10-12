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
 var turret_ship:String="transport_hull"
 var published_shapes:Dictionary={}
 var fleet_pose=Pose.new()
 func before_tick(dt:float)->void:fx_time+=dt;demo_time+=dt
 func after_tick()->void:pass
 func finish_display_boundary()->void:pass
 func visual_muzzle(_shot:Dictionary)->Vector2:return Vector2.ZERO
 func shot_mount(_shot:Dictionary)->int:return -1
 func display_descriptor(_enemy:Dictionary)->Dictionary:return {"components":[],"mounts":[],"types":[]}
 func retire_display_entity(uid:int)->void:published_shapes.erase(uid)
 func display_frame(enemies:Array,_with_fleet:bool=true)->Dictionary:
  var rows={};var shapes=[]
  for enemy in enemies:
   var uid:int=int(enemy.uid);var identity:String=str(uid)+":1"
   rows[uid]={"position":Vector2(enemy.x,enemy.y),"width":1.0,"width_low":1.0,"width_high":1.0,"frontline":0.0,"angle":0.0,"components":{},"pose":{"born":0.0},"recognition_id":identity}
   if not published_shapes.has(uid):
    shapes.append({"id":identity,"uid":uid,"value":{}});published_shapes[uid]=true
  return {"player_position":Vector2.ZERO,"enemies":rows,"shapes":shapes}

class Surface extends RefCounted:
 var simulation_geometry_view=preload("res://scripts/simulation_geometry_view.gd").new()
 var fx_time:float=0.0
 var demo_time:float=0.0
 var ship_view=Pose.new()
 var turret_visuals:Dictionary={}
 var turret_ship:String="transport_hull"
 var simulation_event_muzzles:Dictionary={}
 var shield_before_hit:Variant=0.0
 var projectile_visuals:Array=[]
 var beam_visuals:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 game.save_enabled=false;game.rng.seed=1701
 game.profile.resources={"1":1e30,"2":1e30}
 game.profile.cleared=range(1,41);game.rebuild_unlocks()
 game.profile.planets["1"].buildings.station.status="ready"
 game.profile.planets["1"].buildings.shipyard.status="building"
 game.profile.loadout.weapons=[{"key":"laser","level":1}]
 game.invalidate_stat_cache();game.reset_player();game.state=BattleGame.State.COMBAT;game.spawn_group()
 for enemy in game.enemies:enemy.hp=1e30;enemy.max_hp=1e30
 game.enable_simulation_state_bridge()
 var foreign_node=Node.new()
 var node_observer=Callable(foreign_node,"get_instance_id")
 game.native_readonly_observer(node_observer)
 var owner=Owner.new();var restoration=owner.attach(game,Geometry.new())
 assert(not game._native_readonly_observers.has(node_observer))
 assert(restoration.native_observers.has(node_observer))
 foreign_node.free()
 var presenter=Presenter.new();presenter.owner=owner;presenter.model=Display.new(ShipDatabase.new(),false,game.profile.duplicate(true));presenter.scene=Surface.new()
 presenter.model.command_gateway=presenter.dispatch_command;presenter.model.display_ready=true
 var display=presenter.model
 assert(owner.advance(0.0));presenter.consume()
 assert(presenter.scene.turret_ship==owner.geometry.turret_ship)
 assert(not owner.dispatch("hyperspace.set_preset",["bad","name",[]]).accepted)
 assert(not owner.dispatch("planet_buildings.assign",["1","shipyard",RefCounted.new()]).accepted)
 assert(not owner.dispatch("crew.assign",["engineer","equipment_upgrade","equipment",false]).accepted)
 assert(not owner.dispatch("hyperspace.publish",[{}]).accepted)
 assert(not owner.dispatch("hyperspace.set_preset",[0,"foreign",[],{"foreign":RefCounted.new()}]).accepted)
 var sequence=owner.command_serial
 var mode=game.crew.upgrade_modes(game,"equipment_upgrade").back()
 assert(display.crew.assign(display,"engineer","equipment_upgrade","equipment",mode))
 assert(game.crew.entry(game,"engineer").upgradeMode==mode)
 assert(display.crew.entry(display,"engineer").upgradeMode==mode)
 assert(display.crew.assign(display,"engineer","",""))
 assert(display.planet_buildings.assign(display,"1","shipyard","engineer"))
 assert(game.profile.planets["1"].buildings.shipyard.crew==["engineer"])
 assert(display.profile.planets["1"].buildings.shipyard.crew==["engineer"])
 assert(not is_same(display.profile.planets["1"].buildings.shipyard.crew,game.profile.planets["1"].buildings.shipyard.crew))
 assert(display.planet_buildings.assign(display,"1","shipyard","engineer"))
 assert(display.planet_buildings.activate(display,"1","station"))
 assert(game.profile.planets["1"].buildings.station.status=="built" and display.profile.planets["1"].buildings.station.status=="built")
 assert(display.hyperspace.set_preset(display,0,"value preset",[]))
 assert(game.profile.hyperspace.inventory.presets[0].name=="value preset")
 assert(display.profile.hyperspace.inventory.presets==game.profile.hyperspace.inventory.presets)
 assert(display.hyperspace.apply_preset(display,0))
 assert(display.hyperspace.set_favorites(display,[]))
 assert(display.hyperspace.set_filter(display,game.profile.hyperspace.filter.duplicate(true)))
 assert(display.hyperspace.clear_preset(display,0))
 assert(game.profile.hyperspace.inventory.presets.is_empty() and display.profile.hyperspace.inventory.presets.is_empty())
 assert(owner.command_serial==sequence+10)
 assert(not display.hyperspace.clear_preset(display,99)) # Domain rejection remains the original bool result.
 # A death drop is born without its own event. Snapshot must publish it even
 # after its source leaves the encounter; pickup sends values, never the UI record.
 var drop={"uid":99999,"source_uid":99998,"x":100.0,"y":200.0,"age":0.5,"id":"1","amount":17.0}
 game.drops.append(drop)
 assert(owner.advance(0.0));presenter.consume()
 assert(display.drops.size()==1 and display.drops[0]==drop and not is_same(display.drops[0],drop))
 drop.age=0.75;assert(owner.advance(0.0));presenter.consume();assert(display.drops[0].age==0.75)
 game.profile.resources["1"]=100.0
 var resources=game.profile.resources["1"]
 display.collect_near(Vector2(100,200),true,{99999:Vector2(100,200)})
 assert(game.drops.is_empty() and display.drops.is_empty())
 assert(game.profile.resources["1"]>resources)
 assert(display.set_onboarding_flag("retreatSeen",true))
 assert(game.profile.onboarding.retreatSeen and display.profile.onboarding.retreatSeen)
 assert(not display.set_onboarding_flag("uncompiled",true))
 var option={}
 for row in game.chrono_options():
  if float(row.cost)>0:option=row;break
 assert(not option.is_empty())
 game.profile.chronoParticles=100.0
 assert(display.set_speed(option.multiplier))
 var before_particles=game.profile.chronoParticles
 assert(is_equal_approx(display.chrono_affordable_seconds(0.01),0.01))
 assert(is_equal_approx(game.profile.chronoParticles,before_particles-0.01*float(option.cost)))
 assert(display.set_speed(game.default_speed()))
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
 assert(lease.frame.geometry.shapes.is_empty())
 owner.mailbox.release(lease.slot)
 # All one-shot descriptors must survive even after every dynamic slot was skipped.
 presenter.consume()
 assert(presenter.model.profile.loadout.weapons[0].level==game.profile.loadout.weapons[0].level)
 assert(presenter.enemy_views.size()>=game.enemies.size())
 assert(owner.advance(0.0));presenter.consume()
 assert(presenter.model.projectiles.size()==game.projectiles.size())
 assert(presenter.model.cooldowns==game.cooldowns and not is_same(presenter.model.cooldowns,game.cooldowns))
 assert(presenter.model.enhancement_protection_status()==game.enhancement_protection_status())
 assert(presenter.model.enhancement_deferred_total()==game.enhancement_deferred_total())
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
 owner.mailbox.event_limit=4096
 # A future event can exist while the most recent frame is still older.
 assert(owner.mailbox.append_owned_event({"transport_only":true,"fields":{"speed":1.25}}))
 var slot=owner.mailbox.begin_write();assert(owner.mailbox.publish_owned(slot,{"fields":{"speed":1.5}}))
 assert(owner.mailbox.append_owned_event({"transport_only":true,"fields":{"speed":2.0}}))
 presenter.consume();assert(presenter.model.speed==2.0)

 print("SIMULATION_TRANSPORT_CONTRACT_PASS snapshots_skipped=",owner.mailbox.metrics().dropped_snapshots,"; retries=",retries,"; commands_value_checked; UI_helper_commands_ordered=11; births_configuration_lossless; no_battle_thread")
 presenter.close();game.simulation_bridge.close();quit()
