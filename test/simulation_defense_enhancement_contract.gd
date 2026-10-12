extends SceneTree
const State=preload("res://scripts/simulation_battle_state.gd")
const Kernel=preload("res://scripts/simulation_defense_enhancement.gd")
const N=preload("res://scripts/growth_number.gd")
var checks=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=BattleGame.new(ShipDatabase.new(),false)
	game.profile.cleared=range(1,41);game.rebuild_unlocks();game.profile.enhancementLevel=50
	game.profile.loadout={"weapons":[{"key":"laser","level":150}],"defence":[{"key":"armour","level":150},{"key":"shield","level":150}]}
	game.reset_player();game.spawn_group();game.state=BattleGame.State.COMBAT
	var arena=State.new()
	for enemy in game.enemies:arena.import_enemy(enemy,game.enemy_shield_time)
	for adaptation in ["A","B"]:
		for memory in ["A","B"]:
			for deferred in ["A","B"]:
				for row in [["adaptation",adaptation],["memory_material",memory],["delayed_damage",deferred]]:
					for node in [1,2,3]:assert(game.set_enhancement_branch("defence",row[0],node,row[1]))
				game.enhancement_branches.reset();game.rng.seed=9971
				var rng=RandomNumberGenerator.new();rng.state=game.rng.state
				var kernel=Kernel.new();var configurations:Array[Kernel.ModuleConfiguration]=[]
				for source in arena.entities:source.incoming_stacks=0;kernel.sources.append(source)
				for index in game.defense_entries().size():kernel.modules.append(State.DefenseState.new());configurations.append(kernel.compile_module(game,index))
				kernel.reconfigure(kernel.compile_shared(game),configurations)
				for step in 80:
					var dt=[0.99,0.01,1.0,0.2,0.8,1.99,0.01,1.0/60.0][step%8]
					kernel.advance(dt);game.enhancement_branches.advance_defense(game,dt)
					var damage_type=step%3
					kernel.memory_incoming(damage_type);game.enhancement_branches.memory_incoming(game,damage_type)
					var source=arena.entities[step%arena.entities.size()]
					assert(kernel.incoming_multiplier(source)==game.enhancement_branches.incoming_multiplier(game,source.id))
					var amount:Variant=[0.0,1.0,1e30,1e90][step%4]
					var feedback={"absorbed":0.0};var expected=game.enhancement_branches.consume_cover(game,amount,feedback);var actual=kernel.consume_cover(amount)
					assert(N.compare(actual.remaining,expected)==0 and N.compare(actual.absorbed,feedback.absorbed)==0)
					kernel.recovery_pulse(step%2==0,rng);game.enhancement_branches.recovery_pulse(game,step%2==0)
					if step%11==0:kernel.cleared();game.enhancement_branches.cleared(game)
					assert(rng.state==game.rng.state and kernel.memory_reduction_remaining==game.enhancement_branches.memory_reduction_remaining and kernel.clear_reduction_remaining==game.enhancement_branches.clear_reduction_remaining)
					for index in kernel.modules.size():
						var actual_state=kernel.modules[index];var expected_state=game.enhancement_branches.defense(game,index)
						assert(N.compare(actual_state.cover.value(),expected_state.cover)==0 and actual_state.cover_remaining==expected_state.cover_time and actual_state.cover_elapsed==expected_state.cover_elapsed)
						assert(actual_state.resistance_type==expected_state.resistance_type and actual_state.resistance_remaining==expected_state.resistance_time and actual_state.lockout==expected_state.lockout)
						assert(kernel.memory_resistance(index,damage_type)==game.enhancement_branches.memory_resistance(game,index,damage_type))
					checks+=1
	print("SIMULATION_DEFENSE_ENHANCEMENT_PASS steps=",checks,"; actual_EnhancementBranches_reference; timers_cover_resistance_source_stacks_RNG_exact")
	quit()
