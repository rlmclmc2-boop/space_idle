extends "res://simulation_transport_contract.gd"
# Actual Thread/Owner/Presenter, fixed-step source equivalence and bounded FIFO.
# Synthetic geometry; native arenas are separate. No rendering/performance claim.
func make_game():
 var game=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 game.save_enabled=false;game.rng.seed=1701
 game.profile.resources={"1":1e30,"2":1e30}
 game.profile.hightechSavedAt=0.0;game.profile.hyperspace.random_state="739"
 game.profile.loadout.weapons=[{"key":"laser","level":1}]
 game.invalidate_stat_cache();game.reset_player();game.state=BattleGame.State.COMBAT;game.spawn_group()
 for enemy in game.enemies:enemy.hp=1e30;enemy.max_hp=1e30
 game.enable_simulation_state_bridge()
 return game
func combat_state(game)->String:
 return JSON.stringify({"player":game.player,"enemies":game.enemies,"shots":game.projectile_contract_snapshot(),"rng":str(game.rng.state),"motion_clock":game.motion_clock,"missile_queue":game.missile_queue,"production":game.profile.productionElapsed})
func run()->void:
 var baseline=make_game();var candidate=make_game()
 var original=Owner.new();original.attach(baseline,Geometry.new())
 var owner=Owner.new();owner.attach(candidate,Geometry.new())
 var presenter=Presenter.new();presenter.owner=owner;presenter.model=Display.new(ShipDatabase.new(),false,candidate.profile.duplicate(true));presenter.scene=Surface.new()
 presenter.model.command_gateway=presenter.dispatch_command;presenter.model.display_ready=true
 assert(owner.advance(0.0));presenter.consume()
 assert(owner.ownership_hazards().is_empty(),str(owner.ownership_hazards()))
 owner.mailbox.event_limit=1
 assert(presenter.start_worker()==OK)
 var main_id=OS.get_thread_caller_id()
 # Capacity one forces worker-side backpressure while the main consumes during
 # acknowledgement waits. Every time job keeps its original 60Hz boundary.
 for tick in 60:
  assert(original.advance(1.0/60.0))
  presenter.advance(1.0/60.0)
 assert(presenter.synchronize())
 assert(int(presenter.last_input_ack.authority_thread)!=main_id)
 presenter.dispatch_command("set_field",["paused",true]);assert(presenter.model.paused)
 presenter.dispatch_command("set_field",["paused",false]);assert(not presenter.model.paused)
 var nested=[false]
 var subscriber=func(kind:String,_payload:Dictionary):
  if kind=="upgrade" and not nested[0]:
   nested[0]=true;presenter.dispatch_command("set_field",["paused",true])
 presenter.model.event.connect(subscriber)
 assert(presenter.model.upgrade_slot("weapons",0,1))
 assert(nested[0] and presenter.model.paused)
 presenter.model.event.disconnect(subscriber)
 presenter.dispatch_command("set_field",["paused",false])
 assert(original.dispatch("upgrade_slot",["weapons",0,1]).accepted)
 assert(presenter.synchronize())
 for tick in 5:
  assert(original.advance(1.0/60.0));presenter.advance(1.0/60.0)
 owner.stop_worker() # Default graceful drain, without a caller-provided barrier.
 # Source reads below occur after join; all accepted time is retained.
 assert(owner.logical_steps==65 and original.logical_steps==65)
 assert(combat_state(candidate)==combat_state(baseline))
 assert(owner.pending_events.is_empty()) # Closing may discard display-only events after source completion.
 assert(owner.mailbox.acknowledgements.is_empty())
 assert(owner.remainder<1e-10)
 print("SIMULATION_WORKER_CONTRACT_PASS thread_distinct; steps=65; graceful_stop_retains_time; FIFO_backpressure; command_confirmation; reentrant_confirmation; source_equal; join_before_read; wait_us=",presenter.input_wait_us)
 presenter.close();original.close();candidate.simulation_bridge.close();baseline.simulation_bridge.close();quit()
