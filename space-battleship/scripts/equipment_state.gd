extends RefCounted
## Owns hull and ordinary modules. Read-only views are stable between changes;
## source identity survives numeric growth and changes only with replacement.
const N=preload("res://scripts/growth_number.gd")
const Economy=preload("res://scripts/economy_state.gd")
const WEAPONS=["laser","missile","cannon","longLaser"]
const DEFENCES=["armour","shield"]
var _ship:=""
var _modules:Dictionary={"weapons":[],"defence":[]}
var _active:Dictionary={"weapons":[],"defence":[]}
var _switch_until:Dictionary={}
var _serial:=0
var revision:=0
var contribution_revision:=0
var _quotes:Dictionary={}

func selected_ship()->String:return _ship
func entries(category:String,active_only:bool=false)->Array:
	return (_active if active_only else _modules).get(category,[])
func entry(category:String,index:int,active_only:bool=false)->Dictionary:
	var values:=entries(category,active_only)
	return values[index] if index>=0 and index<values.size() else {}
func switch_remaining(category:String,index:int,now:float)->float:
	return maxf(0.0,float(_switch_until.get("%s_%d"%[category,index],0.0))-now) if not entry(category,index,true).is_empty() else 0.0
func clear_switches()->void:
	if not _switch_until.is_empty():_switch_until.clear();revision+=1

static func same_source(a:Dictionary,b:Dictionary)->bool:
	if a.has("_module_uid") or b.has("_module_uid"):return a.get("_module_uid","")==b.get("_module_uid","!")
	return is_same(a,b)

static func count(db,key:String,category:String)->int:
	return int(db.ship(key).get("weaponSlots" if category=="weapons" else "defenseSlots",0)) if category in ["weapons","defence"] else 0
static func empty_loadout(db,key:String)->Dictionary:
	var result:Dictionary={"weapons":[],"defence":[]}
	for category in result:
		for i in count(db,key,category):result[category].append({"key":"","level":1})
	return result
static func default_loadout(db,key:String,unlocked:Array)->Dictionary:
	var result:=empty_loadout(db,key)
	if not result.defence.is_empty():result.defence[0].key="armour"
	for key_value in unlocked:
		var category:="weapons" if key_value in WEAPONS else "defence"
		if key_value not in WEAPONS+DEFENCES or (key_value=="armour" and not result.defence.is_empty()):continue
		var index:int=result[category].find_custom(func(value):return str(value.key).is_empty())
		if index>=0:result[category][index].key=str(key_value)
	return result

static func valid_snapshot(raw:Dictionary,db)->bool:
	if not raw.get("selectedShip") is String or not db.ships.has(raw.selectedShip) or raw.get("moduleVersion")!=1:return false
	if not raw.get("loadout") is Dictionary or raw.loadout.size()!=2 or not raw.get("equipmentSwitchUntil") is Dictionary:return false
	for category in ["weapons","defence"]:
		var values=raw.loadout.get(category)
		var maximum:=0
		for key in db.ships:maximum=maxi(maximum,count(db,key,category))
		if not values is Array or values.size()<count(db,raw.selectedShip,category) or values.size()>maximum:return false
		for value in values:
			if not value is Dictionary or not value.get("key") is String or (not value.key.is_empty() and value.key not in (WEAPONS if category=="weapons" else DEFENCES)):return false
			var level=value.get("level")
			if not (level is int or level is float) or not is_finite(float(level)) or level!=floorf(float(level)) or level<1 or level>2147483647:return false
	for id in raw.equipmentSwitchUntil:
		if not id is String:return false
		var parts:Array=Array(id.split("_"))
		if parts.size()!=2 or parts[0] not in ["weapons","defence"] or not str(parts[1]).is_valid_int():return false
		var index:=int(parts[1]);var value=raw.equipmentSwitchUntil[id]
		if index<0 or index>=raw.loadout[parts[0]].size() or id!="%s_%d"%[parts[0],index]:return false
		if not (value is int or value is float) or not is_finite(float(value)) or value<0:return false
	return true

func _install(db,ship:String,modules:Dictionary,deadlines:Dictionary,preserve:bool)->void:
	var next:Dictionary={}
	var active:Dictionary={}
	for category in ["weapons","defence"]:
		var values:Array=[]
		for value in modules[category]:
			if preserve and value.is_read_only():values.append(value);continue
			var uid:String=str(value.get("_module_uid","")) if preserve else ""
			if uid.is_empty():_serial+=1;uid="%d:%d"%[get_instance_id(),_serial]
			var projection:Dictionary={"key":str(value.key),"level":int(value.level),"_module_uid":uid}
			projection.make_read_only();values.append(projection)
		values.make_read_only();next[category]=values
		active[category]=values.slice(0,count(db,ship,category));active[category].make_read_only()
	_ship=ship;_modules=next;_active=active;_switch_until=deadlines.duplicate();revision+=1;contribution_revision+=1

func reset(db,ship:String,unlocked:Array)->void:
	_install(db,ship,default_loadout(db,ship,unlocked),{},false)
func install_snapshot(raw:Dictionary,db)->bool:
	if not valid_snapshot(raw,db):return false
	_install(db,raw.selectedShip,raw.loadout,raw.equipmentSwitchUntil,false);return true
func save_data()->Dictionary:
	var result:Dictionary={"weapons":[],"defence":[]}
	for category in result:
		for value in _modules[category]:result[category].append({"key":value.key,"level":value.level})
	return {"selectedShip":_ship,"loadout":result,"moduleVersion":1,"equipmentSwitchUntil":_switch_until.duplicate()}
func reconcile(db,unlocked:Array,fallback:String,keep_ship:bool=true)->void:
	var ship:String=_ship if keep_ship and db.ships.has(_ship) else fallback
	var base:=default_loadout(db,ship,unlocked)
	var next:Dictionary={}
	for category in ["weapons","defence"]:
		var values:Array=[];var old:=entries(category)
		for index in maxi(count(db,ship,category),old.size()):
			var value:Dictionary=old[index] if index<old.size() else base[category][index]
			values.append({"key":value.key if str(value.key).is_empty() or unlocked.has(value.key) else "","level":value.level})
		next[category]=values
	_install(db,ship,next,_switch_until,false)

func prepare_refit(db,ship:String,choices:Dictionary,now:float,cooldown:float)->Dictionary:
	var next:Dictionary={};var changed:Array=[];var deadlines:=_switch_until.duplicate()
	for category in ["weapons","defence"]:
		var values:=entries(category).duplicate()
		while values.size()<count(db,ship,category):values.append({"key":"","level":1})
		if choices.has(category):
			for index in choices[category]:
				var requested:String=choices[category][index]
				if str(values[index].key)==requested:continue
				if switch_remaining(category,int(index),now)>0:return {}
				values[index]={"key":requested,"level":values[index].level}
				deadlines["%s_%d"%[category,index]]=now+maxf(0.0,cooldown)
				changed.append({"category":category,"index":int(index)})
		next[category]=values
	return {"ship":ship,"modules":next,"deadlines":deadlines,"changed":changed,"revision":revision}
func proposal_current(plan:Dictionary)->bool:return int(plan.revision)==revision
func commit_refit(db,plan:Dictionary)->void:_install(db,plan.ship,plan.modules,plan.deadlines,true)

static func cost_key(category:String)->String:return "laser" if category=="weapons" else "armour"
func costs(db,key:String,current:int,levels:int)->Dictionary:
	if levels<=0 or current+levels>db.max_equipment_level(key):return {}
	var total:Dictionary={}
	for target in range(current+1,current+levels+1):
		var expense:Dictionary=db.equipment_cost(key,target)
		for id in expense:total[id]=float(total.get(id,0))+float(expense[id])
	return total
func maximum(db,category:String,index:int,wallet:Dictionary,material_enabled:bool)->Dictionary:
	var value:=entry(category,index,true)
	if value.is_empty():return {"amount":0,"costs":{}}
	var key:=cost_key(category);var current:=int(value.level)
	var signature:Array=[wallet,material_enabled,db.equipment.get(key,[]),db.max_equipment_level(key)]
	var cache_key:String=str([key,current]);var cached:Dictionary=_quotes.get(cache_key,{})
	if not cached.is_empty() and cached.signature==signature:return cached.quote.duplicate(true)
	var available:=wallet.duplicate(true);var total:Dictionary={};var amount:=0
	var target:=current+1
	while target<=db.max_equipment_level(key):
		var expense:Dictionary=db.equipment_cost(key,target)
		if expense.has(db.evolution_material_id()) and not material_enabled:break
		var next:=Economy.prepare_equipment_balances(available,expense,db.evolution_material_id())
		if next.is_empty():break
		available=next;amount+=1;target+=1
		for id in expense:total[id]=float(total.get(id,0))+float(expense[id])
	var quote:Dictionary={"amount":amount,"costs":total}
	if _quotes.size()>=32 and not _quotes.has(cache_key):_quotes.clear()
	_quotes[cache_key]={"signature":signature.duplicate(true),"quote":quote.duplicate(true)}
	return quote
func prepare_upgrades(db,wallet:Dictionary,material_enabled:bool,mode:String,only:Dictionary={})->Dictionary:
	var available:=wallet.duplicate(true);var purchases:Array=[];var next:Dictionary={}
	for category in ["weapons","defence"]:
		var values:=entries(category).duplicate()
		for index in entries(category,true).size():
			if not only.is_empty() and (only.category!=category or only.index!=index):continue
			var levels:int=int(maximum(db,category,index,available,material_enabled).amount) if mode=="max" else int(mode)
			var value:Dictionary=values[index];var expense:=costs(db,cost_key(category),int(value.level),levels)
			if expense.is_empty() or (expense.has(db.evolution_material_id()) and not material_enabled):continue
			var debited:=Economy.prepare_equipment_balances(available,expense,db.evolution_material_id())
			if debited.is_empty():continue
			available=debited
			values[index]={"key":value.key,"level":int(value.level)+levels,"_module_uid":value._module_uid}
			purchases.append({"category":category,"index":index,"levels":levels,"before":value,"after":values[index],"costs":expense})
		next[category]=values
	if purchases.is_empty():return {}
	return {"ship":_ship,"modules":next,"deadlines":_switch_until.duplicate(),"revision":revision,"purchases":purchases,"wallet":available}
