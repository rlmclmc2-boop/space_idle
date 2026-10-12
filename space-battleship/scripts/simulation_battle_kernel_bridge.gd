extends RefCounted
## Single-thread migration bridge. Typed settlement owns enemy vitals; legacy
## dictionaries are synchronous read-through projections for existing orchestration.
## UI still sees legacy Game: battle thread admission MUST remain closed.
const State=preload("res://scripts/simulation_battle_state.gd")
const EnemyKernel=preload("res://scripts/simulation_enemy_settlement.gd")
var game:BattleGame
var state=State.new()
var enemy_kernel=EnemyKernel.new()
var records:Dictionary={}
var settlement_calls:int=0
var shield_calls:int=0
var external_write_fallbacks:int=0
var enabled:bool=true
func attach(owner:BattleGame)->void:
	game=owner
	state.ownership_transferred=false;state.legacy_writes_remaining=true
	for enemy in game.enemies:resolve(enemy)
func active()->bool:
	if game._native_forced_compatibility and enabled:
		enabled=false;external_write_fallbacks+=1
	return enabled
func resolve(record:Dictionary)->State.EntityState:
	var identity=int(record.uid)
	if not records.has(identity) or not is_same(records[identity],record):
		if state.entity_index.has(identity):state.retire_entity(identity)
		records[identity]=record
		return state.import_enemy(record,game.enemy_shield_time)
	var result:State.EntityState=state.entity_index[identity]
	# Configuration/transient interference remains simulation-owned; health is not
	# reimported each hit. Unknown external writes must declare compatibility first.
	assert(GrowthNumber.compare(record.hp,result.health.value())==0 and GrowthNumber.compare(record.get("shield",0),result.shield.value())==0,"Undeclared enemy vital write")
	result.interference=float(record.get("interference",0))
	return result
func project(record:Dictionary,value:State.EntityState)->void:
	record.hp=value.health.value();record.shield=value.shield.value()
	record.shield_hit_at=value.shield_hit_at;record.shield_updated_at=value.shield_updated_at
func hit_enemy(record:Dictionary,raw:Variant,damage_type:int,resistance:float,collect_statistics:bool):
	var target=resolve(record);settlement_calls+=1
	var result=enemy_kernel.hit(target,raw,damage_type,resistance,game.enemy_shield_time,game.enemy_shield_hit_time,collect_statistics)
	# Publish before synchronous hit/death/chain callbacks: following projectiles
	# in this same step must see the exact settled death and shield state.
	project(record,target)
	return result
func settle_enemy_shield(record:Dictionary,at:float)->void:
	var target=resolve(record);shield_calls+=1
	enemy_kernel.settle_shield(target,at);project(record,target)
func retire_unreferenced(required:Dictionary)->void:
	# Owner calls after a completed logical advance, retaining pending attacks,
	# locked targets and enhancement targets. Immediate callbacks already finished.
	for identity in records.keys():
		if required.has(identity):continue
		var entity=state.entity_index.get(identity)
		state.retire_entity(int(identity))
		if entity!=null:state.entities.erase(entity)
		records.erase(identity)
func metrics()->Dictionary:
	return {"typed_enemy_settlements":settlement_calls,"typed_shield_queries":shield_calls,"external_write_fallbacks":external_write_fallbacks,"battle_thread_admission":false,"legacy_UI_references_remaining":true}
func close()->void:
	records.clear();state.entity_index.clear();state.entities.clear();game=null
