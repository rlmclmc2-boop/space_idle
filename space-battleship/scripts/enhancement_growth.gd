extends RefCounted
## Durable shared enhancement growth. Combat-only branch stacks stay in battle.
const N=preload("res://scripts/growth_number.gd")
const LEVEL_LIMIT=9007199254740991
const ORDERS={"weapons":["proficiency","repeat","critical"],"defence":["adaptation","memory_material","delayed_damage"]}
var _level:=0
var _orders:Dictionary={}
var _branches:Dictionary={}
var _attacks:=0
var _hits:=0
var configuration_revision:=0
var counter_revision:=0

func _init()->void:reset()
static func default_order()->Dictionary:return ORDERS.duplicate(true)
static func default_branches()->Dictionary:
	var result:Dictionary={}
	for category in ORDERS:
		result[category]={}
		for effect in ORDERS[category]:result[category][effect]={}
	return result
func reset()->void:
	_level=0;_orders=default_order();_branches=default_branches();_attacks=0;_hits=0
	configuration_revision+=1;counter_revision+=1
func level()->int:return _level
func attacks()->int:return _attacks
func hits()->int:return _hits
func history(effect:String)->int:return _attacks if effect=="proficiency" else _hits
func order(category:String)->Array:return _orders.get(category,[]).duplicate()
func order_position(category:String,kind:String)->int:return _orders.get(category,[]).find(kind)
func branch_choices(category:String,effect:String)->Dictionary:return _branches.get(category,{}).get(effect,{}).duplicate()
func branches()->Dictionary:return _branches.duplicate(true)
func branch_choice(category:String,effect:String,node:int)->String:return str(_branches.get(category,{}).get(effect,{}).get(str(node),""))

static func valid_order(category:String,value:Variant)->bool:
	if not value is Array or value.size()!=3 or not ORDERS.has(category):return false
	var remaining:Array=ORDERS[category].duplicate()
	for effect in value:
		if not effect is String or not remaining.has(effect):return false
		remaining.erase(effect)
	return remaining.is_empty()
static func valid_branch(category:String,effect:String,node:int)->bool:return ORDERS.has(category) and ORDERS[category].has(effect) and node in [1,2,3]
static func valid_counter(value:Variant)->bool:
	if value is String:return value.is_valid_int() and int(value)>=0 and str(int(value))==value
	if value is int:return value>=0
	return value is float and is_finite(value) and value>=0 and value<=LEVEL_LIMIT and value==floorf(value)
static func valid_snapshot(raw:Dictionary)->bool:
	if raw.get("enhancementVersion")!=1:return false
	var level=raw.get("enhancementLevel")
	if not (level is int or level is float) or not is_finite(float(level)) or level<0 or level>LEVEL_LIMIT or level!=floorf(float(level)):return false
	if not valid_counter(raw.get("enhancementAttacks")) or not valid_counter(raw.get("enhancementHits")):return false
	if not raw.get("enhancementOrder") is Dictionary or raw.enhancementOrder.size()!=2 or not raw.get("enhancementBranches") is Dictionary or raw.enhancementBranches.size()!=2:return false
	for category in ORDERS:
		if not valid_order(category,raw.enhancementOrder.get(category)):return false
		var effects=raw.enhancementBranches.get(category)
		if not effects is Dictionary or effects.size()!=3:return false
		for effect in ORDERS[category]:
			var nodes=effects.get(effect)
			if not nodes is Dictionary:return false
			for node in nodes:
				if node not in ["1","2","3"] or nodes[node] not in ["A","B"]:return false
	return true
func install_snapshot(raw:Dictionary)->bool:
	if not valid_snapshot(raw):return false
	_level=int(raw.enhancementLevel);_orders=raw.enhancementOrder.duplicate(true);_branches=raw.enhancementBranches.duplicate(true)
	_attacks=int(raw.enhancementAttacks);_hits=int(raw.enhancementHits);configuration_revision+=1;counter_revision+=1
	return true
func save_data()->Dictionary:
	# JSON numeric values decode through doubles. Histories remain exact int64.
	return {"enhancementVersion":1,"enhancementLevel":_level,"enhancementOrder":_orders.duplicate(true),"enhancementBranches":_branches.duplicate(true),"enhancementAttacks":str(_attacks),"enhancementHits":str(_hits)}

static func parameter(db,key:String)->float:return float(db.data.enhance_config[key].value)
static func effect_threshold(db,index:int)->int:return int(parameter(db,"threshold_%d"%(index+1))) if index in [0,1,2] else -1
func branch_threshold(db,node:int,category:String,effect:String)->int:
	if not valid_branch(category,effect,node):return -1
	return int(parameter(db,"branch_threshold_%d"%node)+parameter(db,"branch_position_offset_%d"%(_orders[category].find(effect)+1)))
func branch_unlocked(db,category:String,effect:String,node:int,effective_level:int,unlocked:bool)->bool:
	return unlocked and valid_branch(category,effect,node) and effective_level>=branch_threshold(db,node,category,effect)
func cost(db,target:int=-1)->Variant:
	if target<0:target=_level+1
	return 0.0 if target<1 else N.ceiling(N.multiply(parameter(db,"cost_base"),N.power(parameter(db,"cost_growth"),target-1)))
func purchase_cost(db,count:int)->Variant:
	if count<=0:return 0.0
	var first=cost(db)
	if count==1:return first
	var growth:=parameter(db,"cost_growth")
	var factor=float(count) if growth==1.0 else N.divide(N.subtract(N.power(growth,count),1.0),growth-1.0)
	return N.ceiling(N.multiply(first,factor))
func max_upgrades(db,budget:Variant,limit:int=-1)->int:
	var low:=0;var high:=LEVEL_LIMIT-_level
	if limit>=0:high=mini(high,limit)
	while low<high:
		var middle:=low+int((high-low+1)/2)
		if N.compare(budget,purchase_cost(db,middle))>=0:low=middle
		else:high=middle-1
	return low
func prepare_upgrade(db,budget:Variant,count:int)->Dictionary:
	var purchased:=max_upgrades(db,budget,count)
	return {} if purchased==0 else {"kind":"upgrade","purchased":purchased,"cost":purchase_cost(db,purchased),"revision":configuration_revision}
func prepare_order(category:String,requested:Array)->Dictionary:
	if not valid_order(category,requested):return {}
	return {"kind":"order","category":category,"order":requested.duplicate(),"revision":configuration_revision}
func prepare_branch(db,category:String,effect:String,node:int,choice:String,effective_level:int,unlocked:bool)->Dictionary:
	if not branch_unlocked(db,category,effect,node,effective_level,unlocked) or choice not in ["A","B"]:return {}
	return {"kind":"branch","category":category,"effect":effect,"node":node,"choice":choice,"revision":configuration_revision}
func proposal_current(plan:Dictionary)->bool:return plan.revision==configuration_revision
func commit_configuration(plan:Dictionary)->void:
	match plan.kind:
		"upgrade":_level+=int(plan.purchased)
		"order":_orders[plan.category]=plan.order.duplicate()
		"branch":_branches[plan.category][plan.effect][str(plan.node)]=plan.choice
	configuration_revision+=1
func record_attack()->void:_attacks+=1;counter_revision+=1
func record_hit()->void:_hits+=1;counter_revision+=1
func commit_combat_counters(attacks:int,hits:int)->Array:
	assert(attacks>=_attacks and hits>=_hits,"Combat history cannot move backwards")
	var changed:Array=[]
	if attacks!=_attacks:changed.append("weapons")
	if hits!=_hits:changed.append("defence")
	_attacks=attacks;_hits=hits
	if not changed.is_empty():counter_revision+=1
	return changed
static func effect_count(db,effective_level:int,unlocked:bool)->int:
	if not unlocked:return 0
	var count:=0
	for index in 3:
		if effective_level>=effect_threshold(db,index):count+=1
	return count
static func effect(db,kind:String,index:int,level:int)->Dictionary:
	var value:Dictionary={"kind":kind,"level":level,"threshold":effect_threshold(db,index),"p2":0.0,"p4":0.0,"p5":0.0}
	match kind:
		"proficiency","adaptation":value.p2=parameter(db,kind+"_growth")
		"repeat":value.p2=parameter(db,"repeat_probability");value.p4=parameter(db,"repeat_growth")
		"critical":value.p4=parameter(db,"critical_growth")
		"delayed_damage":value.p2=deferred_fraction(db,level)
		"memory_material":value.p2=parameter(db,"memory_heal_fraction");value.p4=parameter(db,"memory_buffer_fraction")
	return value
func history_multiplier(db,kind:String,level:int,growth:float)->float:
	return 1.0+history_bonus(db,kind,level,growth)
func history_bonus(db,kind:String,level:int,growth:float)->float:
	var count:=maxi(1,history(kind));var scale:=parameter(db,"bonus_round_scale")
	return roundf(growth*level*log(float(count))/log(parameter(db,"counter_log_base"))*scale)/scale
static func deferred_fraction(db,level:int)->float:
	if level<=0:return 0.0
	var scale:=parameter(db,"deferred_percent_scale")
	var remaining:=maxf(1.0,ceilf(scale/(1.0+parameter(db,"deferred_curve_coefficient")*level)))
	return maxf(0.0,(scale-remaining)/scale)
