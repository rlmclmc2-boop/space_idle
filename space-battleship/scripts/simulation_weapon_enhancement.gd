extends RefCounted
## Ordered assembly commands compile eligibility/parameters; ticks use typed state.
## UI counter invalidations are returned as values, never synchronous UI callbacks.
const N=preload("res://scripts/growth_number.gd")
const State=preload("res://scripts/simulation_battle_state.gd")
class Configuration extends RefCounted:
	var focus_enabled:bool=false
	var next_enabled:bool=false
	var stacks_enabled:bool=false
	var focus_interval:float=1.0
	var focus_growth:float=0.0
	var next_damage_bonus:float=0.0
	var next_attacks:int=0
	var stack_limit:int=0
	var stack_duration:float=0.0
	var stack_damage_bonus:float=0.0
	var base_multiplier:float=1.0
class WeaponState extends RefCounted:
	var index:int=0
	var target:int=-1
	var target_generation:int=0
	var dwell:float=0.0
	var next_attack_count:int=0
	var stacks:int=0
	var stack_time:float=0.0
	var configuration:Configuration
class AttackContext extends RefCounted:
	var index:int=0
	var primary:int=-1
	var primary_generation:int=0
	var derived:bool=false
	var next_multiplier:float=1.0
	var critical:bool=false

func compile_configuration(game,entry:Dictionary)->Configuration:
	# Main-thread/assembly boundary only. No Game/entry/config reference is retained.
	var result=Configuration.new()
	result.focus_enabled=game.enhancement_branches.active(game,entry,"proficiency",1,"B")
	result.next_enabled=game.enhancement_branches.active(game,entry,"critical",1,"B")
	result.stacks_enabled=game.enhancement_branches.active(game,entry,"critical",2,"B")
	result.focus_interval=game.enhancement_parameter("proficiency_b1_interval")
	result.focus_growth=game.enhancement_parameter("proficiency_b1_growth")
	result.next_damage_bonus=game.enhancement_parameter("critical_b1_damage_bonus")
	result.next_attacks=int(game.enhancement_parameter("critical_b1_attacks"))
	result.stack_limit=int(game.enhancement_parameter("critical_b2_stacks"))
	result.stack_duration=game.enhancement_parameter("critical_b2_duration")
	result.stack_damage_bonus=game.enhancement_parameter("critical_b2_damage_bonus")
	result.base_multiplier=1.0+float(game.enhancement_branches.a_count(game,entry,"proficiency"))*game.enhancement_parameter("proficiency_a_damage_bonus")
	return result

func reconfigure(weapon:WeaponState,configuration:Configuration)->void:
	weapon.configuration=configuration
	if not configuration.focus_enabled:weapon.target=-1;weapon.target_generation=0;weapon.dwell=0.0
	if not configuration.next_enabled:weapon.next_attack_count=0
	if not configuration.stacks_enabled:weapon.stacks=0;weapon.stack_time=0.0

func advance(weapon:WeaponState,entity:State.EntityState,combat:bool,dt:float)->bool:
	var config=weapon.configuration
	var before_stacks=weapon.stacks
	var before_focus=int(floor(weapon.dwell/config.focus_interval))
	weapon.stack_time=maxf(0.0,weapon.stack_time-dt)
	if weapon.stack_time<=0.000000001:weapon.stacks=0;weapon.stack_time=0.0
	if combat and entity!=null and entity.id==weapon.target and entity.generation==weapon.target_generation and entity.alive and N.compare(entity.health.value(),0)>0 and config.focus_enabled:
		weapon.dwell+=dt
	else:weapon.target=-1;weapon.target_generation=0;weapon.dwell=0.0
	return before_stacks!=weapon.stacks or before_focus!=int(floor(weapon.dwell/config.focus_interval))

func begin_attack(weapon:WeaponState,target:State.EntityState,derived:bool=false,track_primary:bool=true)->AttackContext:
	var result=AttackContext.new();result.index=weapon.index;result.derived=derived
	if target!=null:result.primary=target.id;result.primary_generation=target.generation
	if not derived and track_primary and (weapon.target!=result.primary or weapon.target_generation!=result.primary_generation):
		weapon.target=result.primary;weapon.target_generation=result.primary_generation;weapon.dwell=0.0
	if not derived and weapon.next_attack_count>0 and weapon.configuration.next_enabled:
		result.next_multiplier+=weapon.configuration.next_damage_bonus;weapon.next_attack_count-=1
	return result

func finish_attack(weapon:WeaponState,context:AttackContext)->bool:
	if context.derived or not context.critical:return false
	var config=weapon.configuration
	if config.next_enabled:weapon.next_attack_count=config.next_attacks
	if config.stacks_enabled:
		weapon.stacks=mini(config.stack_limit,weapon.stacks+1);weapon.stack_time=config.stack_duration
	return true

func damage_multiplier(weapon:WeaponState,include_timed_buffs:bool=true)->Variant:
	var config=weapon.configuration
	var result:Variant=config.base_multiplier
	if not include_timed_buffs:return result
	if config.focus_enabled:
		var jumps=int(floor(weapon.dwell/config.focus_interval))
		result=N.multiply(result,N.power(1.0+config.focus_growth,jumps))
	if config.stacks_enabled:result=N.multiply(result,1.0+weapon.stacks*config.stack_damage_bonus)
	return result
