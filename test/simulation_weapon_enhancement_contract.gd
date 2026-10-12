extends SceneTree
const State=preload("res://scripts/simulation_battle_state.gd")
const Kernel=preload("res://scripts/simulation_weapon_enhancement.gd")
const N=preload("res://scripts/growth_number.gd")
var checks=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=BattleGame.new(ShipDatabase.new(),false)
	game.profile.cleared=range(1,41);game.rebuild_unlocks();game.profile.enhancementLevel=50
	game.profile.loadout={"weapons":[{"key":"laser","level":150}],"defence":[{"key":"armour","level":150}]}
	game.reset_player();game.spawn_group();game.state=BattleGame.State.COMBAT
	var arena=State.new()
	for enemy in game.enemies:arena.import_enemy(enemy,game.enemy_shield_time)
	var kernel=Kernel.new()
	for focus in ["A","B"]:
		for next_choice in ["A","B"]:
			for stack_choice in ["A","B"]:
				assert(game.set_enhancement_branch("weapons","proficiency",1,focus))
				assert(game.set_enhancement_branch("weapons","critical",1,next_choice))
				assert(game.set_enhancement_branch("weapons","critical",2,stack_choice))
				game.enhancement_branches.reset()
				var weapon=Kernel.WeaponState.new()
				kernel.reconfigure(weapon,kernel.compile_configuration(game,game.combat_entry(0)))
				for step in 80:
					var old_target:Dictionary=game.enemies[(step/13)%game.enemies.size()]
					var target=arena.entity(int(old_target.uid),arena.entity_index[int(old_target.uid)].generation)
					var derived=step%7==0;var track=step%11!=0
					var context=kernel.begin_attack(weapon,target,derived,track)
					var old=game.enhancement_branches.begin_attack(game,0,old_target,derived,track)
					assert(context.next_multiplier==old.next_multiplier)
					context.critical=step%3==0;old.critical=context.critical
					kernel.finish_attack(weapon,context);game.enhancement_branches.finish_attack(game,old)
					var dt=[0.99,0.01,1.0,0.2,0.8,1.99,0.01,1.0/60.0][step%8]
					kernel.advance(weapon,arena.entity(weapon.target,weapon.target_generation),true,dt)
					game.enhancement_branches.advance_weapons(game,dt)
					var reference=game.enhancement_branches.weapon(game,0)
					assert(weapon.dwell==reference.dwell and weapon.stack_time==reference.stack_time and weapon.stacks==reference.stacks and weapon.next_attack_count==reference.next)
					assert(N.compare(kernel.damage_multiplier(weapon),game.enhancement_branches.weapon_multiplier(game,game.combat_entry(0)))==0)
					checks+=1
	print("SIMULATION_WEAPON_ENHANCEMENT_PASS steps=",checks,"; actual_EnhancementBranches_reference; branch_commands_timers_targets_stacks_multipliers_exact")
	quit()
