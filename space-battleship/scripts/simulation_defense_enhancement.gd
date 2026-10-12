extends RefCounted
## Typed defense branch state; configuration is compiled only at assembly commands.
const N=preload("res://scripts/growth_number.gd")
const State=preload("res://scripts/simulation_battle_state.gd")
class ModuleConfiguration extends RefCounted:
	var cover_enabled:bool=false
	var cover_interval:float=1.0
	var cover_duration:float=0.0
	var cover_amount:Variant=0.0
	var memory_enabled:bool=false
	var memory_lockout:float=0.0
	var memory_duration:float=0.0
	var memory_resistance:float=0.0
class SharedConfiguration extends RefCounted:
	var adaptation_enabled:bool=false
	var adaptation_reduction:float=0.0
	var adaptation_stacks:int=0
	var memory_enabled:bool=false
	var memory_reduction:float=0.0
	var memory_probability:float=0.0
	var memory_duration:float=0.0
	var clear_enabled:bool=false
	var clear_reduction:float=0.0
	var clear_duration:float=0.0
	var incoming_base:float=1.0
class Feedback extends RefCounted:
	var remaining:Variant=0.0
	var absorbed:Variant=0.0
var configuration:SharedConfiguration
var module_configuration:Array[ModuleConfiguration]=[]
var modules:Array[State.DefenseState]=[]
var sources:Array[State.EntityState]=[]
var memory_reduction_remaining:float=0.0
var clear_reduction_remaining:float=0.0

func compile_shared(game)->SharedConfiguration:
	var result=SharedConfiguration.new();var old=game.enhancement_branches
	result.adaptation_enabled=old.global_active(game,"adaptation",1,"B")
	result.adaptation_reduction=game.enhancement_parameter("adaptation_b1_reduction")
	result.adaptation_stacks=int(game.enhancement_parameter("adaptation_b1_stacks"))
	result.memory_enabled=old.global_active(game,"memory_material",1,"B")
	result.memory_reduction=game.enhancement_parameter("memory_b1_reduction")
	result.memory_probability=game.enhancement_parameter("memory_b1_probability")
	result.memory_duration=game.enhancement_parameter("memory_b1_duration")
	result.clear_enabled=old.global_active(game,"delayed_damage",1,"B")
	result.clear_reduction=game.enhancement_parameter("deferred_b1_reduction")
	result.clear_duration=game.enhancement_parameter("deferred_b1_duration")
	var chance:float=old.clear_underlying_probability(game)
	if old.global_active(game,"delayed_damage",2,"B"):result.incoming_base*=1.0-chance*game.enhancement_parameter("deferred_b2_probability_conversion")
	if old.global_active(game,"delayed_damage",3,"B"):result.incoming_base*=1.0+(1.0-chance)*game.enhancement_parameter("deferred_b3_damage_scale")
	return result

func compile_module(game,index:int)->ModuleConfiguration:
	var result=ModuleConfiguration.new();var old=game.enhancement_branches
	var entry:Dictionary=game.slot_entry("defence",index)
	result.cover_enabled=old.active(game,entry,"adaptation",2,"B")
	result.cover_interval=game.enhancement_parameter("adaptation_b2_interval")
	result.cover_duration=game.enhancement_parameter("adaptation_b2_duration")
	result.cover_amount=N.multiply(N.add(game.jewel_equipment_stat(entry),game.enhancement_module_protection_capacity(index)),game.enhancement_parameter("adaptation_b2_capacity_multiplier"))
	result.memory_enabled=old.active(game,entry,"memory_material",2,"B")
	result.memory_lockout=game.enhancement_parameter("memory_b2_lockout")
	result.memory_duration=game.enhancement_parameter("memory_b2_duration")
	result.memory_resistance=old.resistance(game,entry,game.enhancement_parameter("memory_b2_resistance"))
	return result

func advance(dt:float)->void:
	memory_reduction_remaining=maxf(0.0,memory_reduction_remaining-dt)
	clear_reduction_remaining=maxf(0.0,clear_reduction_remaining-dt)
	for source in sources:
		if not source.alive:source.incoming_stacks=0
	for index in modules.size():
		var state=modules[index];var config=module_configuration[index]
		state.resistance_remaining=maxf(0.0,state.resistance_remaining-dt)
		state.lockout=maxf(0.0,state.lockout-dt)
		if state.resistance_remaining<=0:state.resistance_type=0
		state.cover_remaining=maxf(0.0,state.cover_remaining-dt)
		if state.cover_remaining<=0:state.cover.assign(0.0)
		if config.cover_enabled:
			state.cover_elapsed+=dt
			if state.cover_elapsed+0.000000001>=config.cover_interval:
				state.cover_elapsed=fmod(state.cover_elapsed,config.cover_interval)
				state.cover_remaining=config.cover_duration;state.cover.assign(config.cover_amount)

func incoming_multiplier(source:State.EntityState)->float:
	var result=configuration.incoming_base
	if memory_reduction_remaining>0 and configuration.memory_enabled:result*=1.0-configuration.memory_reduction
	if clear_reduction_remaining>0 and configuration.clear_enabled:result*=1.0-configuration.clear_reduction
	if source!=null and source.id>0 and configuration.adaptation_enabled:
		result*=maxf(0.0,1.0-source.incoming_stacks*configuration.adaptation_reduction)
		source.incoming_stacks=mini(configuration.adaptation_stacks,source.incoming_stacks+1)
	return result

func memory_incoming(damage_type:int)->void:
	for index in modules.size():
		var state=modules[index];var config=module_configuration[index]
		if not config.memory_enabled or state.lockout>0:continue
		if state.resistance_remaining>0 and state.resistance_type!=damage_type:
			state.resistance_type=0;state.resistance_remaining=0.0;state.lockout=config.memory_lockout
		elif damage_type in [1,2]:
			state.resistance_type=damage_type;state.resistance_remaining=config.memory_duration

func memory_resistance(index:int,damage_type:int)->float:
	var state=modules[index];var config=module_configuration[index]
	if not config.memory_enabled or state.lockout>0 or state.resistance_remaining<=0 or state.resistance_type!=damage_type:return 0.0
	return config.memory_resistance

func consume_cover(amount:Variant)->Feedback:
	var result=Feedback.new();result.remaining=amount
	for state in modules:
		var consumed=N.minimum(state.cover.value(),result.remaining)
		state.cover.subtract(consumed);result.remaining=N.subtract(result.remaining,consumed)
		result.absorbed=N.add(result.absorbed,consumed)
		if N.compare(result.remaining,0)<=0:break
	return result

func recovery_pulse(positive:bool,rng:RandomNumberGenerator)->void:
	if positive and configuration.memory_enabled and rng.randf()<configuration.memory_probability:memory_reduction_remaining=configuration.memory_duration
func cleared()->void:
	if configuration.clear_enabled:clear_reduction_remaining=configuration.clear_duration

func reconfigure(shared:SharedConfiguration,configuration_rows:Array[ModuleConfiguration])->void:
	assert(configuration_rows.size()==modules.size())
	configuration=shared;module_configuration=configuration_rows
	if not shared.memory_enabled:memory_reduction_remaining=0.0
	if not shared.clear_enabled:clear_reduction_remaining=0.0
	if not shared.adaptation_enabled:
		for source in sources:source.incoming_stacks=0
	for index in modules.size():
		var state=modules[index];var config=module_configuration[index]
		if not config.cover_enabled:state.cover.assign(0.0);state.cover_remaining=0.0;state.cover_elapsed=0.0
		if not config.memory_enabled:state.resistance_type=0;state.resistance_remaining=0.0;state.lockout=0.0
