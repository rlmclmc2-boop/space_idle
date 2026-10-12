extends RefCounted
## Explicit single-owner battle records for the pipeline prototype.
## Import is an ownership-transfer boundary, never a per-frame graph mirror.
const N=preload("res://scripts/growth_number.gd")
class NumberValue extends RefCounted:
	var scalar:float=0.0
	var mantissa:float=0.0
	var exponent:float=0.0
	var extended:bool=false
	func assign(value)->void:
		extended=value is Dictionary
		if extended:mantissa=float(value.m);exponent=float(value.e)
		else:scalar=float(value)
	func value():return {"m":mantissa,"e":exponent} if extended else scalar
	func add(value)->void:assign(GrowthNumber.add(self.value(),value))
	func subtract(value)->void:assign(GrowthNumber.subtract(self.value(),value))
class EntityState extends RefCounted:
	var id:int=0
	var generation:int=0
	var position:Vector2=Vector2.ZERO
	var health=NumberValue.new()
	var maximum_health=NumberValue.new()
	var shield=NumberValue.new()
	var maximum_shield=NumberValue.new()
	var shield_hit_at:float=0.0
	var shield_delay:float=0.0
	var shield_recovery:float=0.0
	var alive:bool=true
	var configuration:int=0
	var cooldowns:PackedFloat64Array=PackedFloat64Array()
class AttackState extends RefCounted:
	var id:int=0
	var source:int=0
	var target:int=0
	var target_generation:int=0
	var descriptor:int=0
	var position:Vector2=Vector2.ZERO
	var direction:Vector2=Vector2.UP
	var speed:float=0.0
	var elapsed:float=0.0
	var charge:float=0.0
	var hit_ticks:int=0
	var flags:int=0
	var chain_id:int=0
	var birth_tick:int=0
class PendingLaunch extends RefCounted:
	var id:int=0
	var source:int=0
	var target:int=0
	var target_generation:int=0
	var descriptor:int=0
	var release_at:float=0.0
	var ordinal:int=0
class DefenseState extends RefCounted:
	var module:int=0
	var buffer=NumberValue.new()
	var cover=NumberValue.new()
	var debt=NumberValue.new()
	var cover_remaining:float=0.0
	var resistance_type:int=0
	var resistance_remaining:float=0.0
	var lockout:float=0.0
class ChainState extends RefCounted:
	var id:int=0
	var remaining:int=0
	var used:bool=false
	var ended:bool=false
	var beam:bool=false
	var targets:PackedInt64Array=PackedInt64Array()
var tick:int=0
var rng_state:int=0
var generation:int=0
var entities:Array[EntityState]=[]
var attacks:Array[AttackState]=[]
var pending:Array[PendingLaunch]=[]
var defenses:Array[DefenseState]=[]
var chains:Array[ChainState]=[]
var entity_index:Dictionary={}
var configuration_table:Array=[]
var ownership_transferred:bool=false
var legacy_writes_remaining:bool=true

func entity(identity:int,generation_value:int)->EntityState:
	var value:EntityState=entity_index.get(identity)
	return value if value!=null and value.generation==generation_value else null
func create_entity(identity:int)->EntityState:
	assert(not entity_index.has(identity))
	var value=EntityState.new();value.id=identity;generation+=1;value.generation=generation
	entities.append(value);entity_index[identity]=value
	return value
func retire_entity(identity:int)->void:
	var value:EntityState=entity_index.get(identity)
	if value==null:return
	value.alive=false;entity_index.erase(identity)
func require_thread_ready()->void:
	assert(ownership_transferred and not legacy_writes_remaining,"Typed state ownership must be proven before starting simulation thread")
