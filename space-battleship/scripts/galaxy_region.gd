extends RefCounted
## Work owns progress; map cells and macro _slots never derive durations.
signal cell_claimed(cell: int)
const SAVE_VERSION := 3
const Layout := preload("res://scripts/galaxy_layout.gd")
var _blueprint := {}
var row: Dictionary
var builds: Dictionary
var _state: Dictionary
var _slots: Array = []
var state_revision:=0
var _view:Dictionary={}
var state:Dictionary:
	get:return view()
var slots:Array:
	get:return view().get("slots",[])
var blueprint:Dictionary:
	get:return view().get("blueprint",{})

static func freeze(value:Variant)->void:
	if value is Dictionary:
		for child in value.values():freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value:freeze(child)
		value.make_read_only()
func view()->Dictionary:
	if _view.is_empty():
		_view=_state.duplicate(true);freeze(_view)
	return _view
func changed()->void:
	state_revision+=1;_view={}
func unlock()->bool:
	if _state.status!="locked":return false
	_state.status="available";changed();return true
func start()->bool:
	if _state.status!="available":return false
	_state.status="exploring";changed();return true
var cells := PackedByteArray()
var frontier: Array[int] = []
var frontier_index := {}
var dirty_chunks := {}
var owned_count := 0
var occupied_count := 0
var max_level_count := 0
var chunk_size := 32
var revision := 0
var building_revision := 0
var random := RandomNumberGenerator.new()
var map_random := RandomNumberGenerator.new()
var compressed_revision := -1
var compressed_map := ""

func setup(definition: Dictionary, definitions: Dictionary, chunk: int, saved: Dictionary = {}) -> void:
	_slots.clear()
	frontier.clear()
	frontier_index.clear()
	dirty_chunks.clear()
	compressed_revision=-1
	row=definition
	builds=definitions
	chunk_size=chunk
	random.seed=int(row.slot_seed)+71
	map_random.seed=int(row.slot_seed)+193
	if saved.has("rng_state"):random.state=int(str(saved.rng_state))
	if saved.has("map_rng_state"):map_random.state=int(str(saved.map_rng_state))
	if saved.is_empty():
		_state={"version":SAVE_VERSION,"status":"locked","explore_work":0.0,"upgrade_work":0.0,"slot_seed":int(row.slot_seed),"build_elapsed":0.0,"bag":[],"rounds":0,"special_due":false}
		_blueprint=Layout.generate(int(row.building_slot_count),int(_state.slot_seed))
		for id in _blueprint.nodes.size():
			var plan:Dictionary=_blueprint.nodes[id]
			var type:=next_build_type()
			plan.type=type;plan.planned_type=type
			_slots.append({"id":id,"node_id":plan.node_id,"world_pos":plan.world_pos.duplicate(),"unlock_progress":0.0,"status":"empty","type":type,"level":0,"work":0.0,"construction":0.0,"upgrade_progress":0.0,"visual_seed":plan.visual_seed,"planned_type":type,"parent_id":plan.parent_id})
		_state.blueprint=_blueprint;_state.slots=_slots
	else:
		_state=saved.duplicate(true)
		for field in ["owned","rng_state","map_rng_state","pending_online_time","pending_crew_count"]:_state.erase(field)
		for field in ["version","slot_seed","rounds"]:_state[field]=int(_state[field])
		_blueprint=_state.blueprint;_slots=_state.slots
		_blueprint.layout_version=int(_blueprint.layout_version)
		for plan in [_blueprint.core]+_blueprint.nodes:
			for field in ["id","parent_id","depth","visual_seed"]:
				if plan.has(field):plan[field]=int(plan[field])
		for slot in _slots:
			for field in ["id","level","visual_seed","parent_id"]:slot[field]=int(slot[field])
	cells.resize(int(row.map_w)*int(row.map_h));cells.fill(0)
	if not saved.is_empty():cells=Marshalls.base64_to_raw(saved.owned).decompress(cells.size(),FileAccess.COMPRESSION_DEFLATE)
	else:
		for y in range((int(row.map_h)-int(row.start_h))/2,(int(row.map_h)+int(row.start_h))/2):
			for x in range((int(row.map_w)-int(row.start_w))/2,(int(row.map_w)+int(row.start_w))/2):cells[y*int(row.map_w)+x]=1
	owned_count=cells.count(1)
	for id in cells.size():
		if cells[id]!=0 and has_unowned_neighbor(id):add_frontier(id)
	refresh_counts();changed()

func work_cost() -> float:return float(row.explore_work_total)/maxi(1,_blueprint.get("nodes",[]).size())
func node_progress(slot: Dictionary) -> float:
	if slot.status in ["active","upgrading"]:return 1.0
	if slot.status=="empty":return 0.0
	var total := work_cost()+float(row.construction_time)
	return clampf((float(slot.work)+float(row.construction_time)-float(slot.construction))/maxf(0.001,total),0,1)
func progress() -> float:
	var total := 0.0
	for slot in _slots:total+=node_progress(slot)
	return total/maxi(1,_slots.size())
func layout_snapshot() -> Dictionary:
	var result := _blueprint.duplicate(true)
	result.building_revision=building_revision
	result.core.merge({"status":"active","level":1,"progress":1.0})
	for i in _slots.size():
		var slot: Dictionary=_slots[i]
		result.nodes[i].merge({"status":slot.status,"level":slot.level,"progress":node_progress(slot),"upgrade_progress":float(slot.upgrade_progress)/maxf(0.001,upgrade_cost(slot))})
	return result
func map_full() -> bool:return owned_count==cells.size()
func slot_unlocked(slot: Dictionary) -> bool:
	for prerequisite in _blueprint.nodes[int(slot.id)].requires:
		if prerequisite=="core":continue
		var index := int(str(prerequisite).trim_prefix("node_"))
		if index<0 or index>=_slots.size() or not _slots[index].status in ["active","upgrading"]:return false
	return true
func upgrade_cost(slot: Dictionary) -> float:return float(row.get("upgrade_cost_lv%d"%(int(slot.level)+1),0))
func refresh_counts() -> void:
	occupied_count=0
	max_level_count=0
	for slot in _slots:
		if slot.status=="empty":continue
		occupied_count+=1
		if slot.status=="active" and slot.level>=int(builds[slot.type].max_lv):max_level_count+=1
func is_complete() -> bool:return progress()>=1 and occupied_count==_slots.size() and max_level_count==_slots.size()
func adjacent(id: int) -> Array[int]:
	var result: Array[int]=[]
	var width := int(row.map_w)
	if id%width>0:result.append(id-1)
	if id%width<width-1:result.append(id+1)
	if id>=width:result.append(id-width)
	if id<cells.size()-width:result.append(id+width)
	return result
func has_unowned_neighbor(id: int) -> bool:
	for other in adjacent(id):
		if cells[other]==0:return true
	return false
func add_frontier(id: int) -> void:
	if frontier_index.has(id):return
	frontier_index[id]=frontier.size()
	frontier.append(id)
func remove_frontier(id: int) -> void:
	if not frontier_index.has(id):return
	var index: int=frontier_index[id]
	var last: int=frontier.back()
	frontier[index]=last
	frontier_index[last]=index
	frontier.pop_back()
	frontier_index.erase(id)
func paint(id: int) -> void:
	if cells[id]!=0:return
	cells[id]=1
	owned_count+=1
	revision+=1
	if has_unowned_neighbor(id):add_frontier(id)
	for other in adjacent(id):
		if cells[other]!=0 and not has_unowned_neighbor(other):remove_frontier(other)
	var width := int(row.map_w)
	dirty_chunks[(id/width/chunk_size)*ceili(float(width)/chunk_size)+(id%width/chunk_size)]=true
func sync_map() -> void:
	var claimed:Array[int]=[]
	var initial := int(row.start_w)*int(row.start_h)
	var target := initial+floori((cells.size()-initial)*progress())
	while owned_count<target and not frontier.is_empty():
		var source: int=frontier[map_random.randi_range(0,frontier.size()-1)]
		var choices := adjacent(source).filter(func(id):return cells[id]==0)
		if choices.is_empty():remove_frontier(source)
		else:
			var id:int=choices[map_random.randi_range(0,choices.size()-1)]
			paint(id);claimed.append(id)
	for id in claimed:cell_claimed.emit(id)
func next_build_type() -> String:
	if _state.special_due:
		_state.special_due=false
		var special := builds.keys().filter(func(key):return builds[key].group=="special")
		return str(special[random.randi_range(0,special.size()-1)]) if not special.is_empty() else ""
	if _state.bag.is_empty():
		_state.bag=builds.keys().filter(func(key):return builds[key].group=="normal")
		for i in range(_state.bag.size()-1,0,-1):
			var j := random.randi_range(0,i)
			var swap=_state.bag[i]
			_state.bag[i]=_state.bag[j]
			_state.bag[j]=swap
	if _state.bag.is_empty():return ""
	var result := str(_state.bag.pop_back())
	if _state.bag.is_empty():
		_state.rounds+=1
		if int(_state.rounds)%int(row.special_cycle)==0:_state.special_due=true
	return result
func build_attempt() -> bool:
	if _slots.any(func(slot):return slot.status=="constructing"):return false
	var candidates := _slots.filter(func(slot):return slot.status=="empty" and slot_unlocked(slot) and builds.has(slot.type))
	if candidates.is_empty():return false
	var nearest := int(_blueprint.nodes[int(candidates[0].id)].depth)
	for candidate in candidates:nearest=mini(nearest,int(_blueprint.nodes[int(candidate.id)].depth))
	candidates=candidates.filter(func(slot):return int(_blueprint.nodes[int(slot.id)].depth)==nearest)
	var slot: Dictionary=candidates[random.randi_range(0,candidates.size()-1)]
	slot.level=1
	slot.construction=float(row.construction_time)
	slot.status="constructing"
	building_revision+=1
	refresh_counts()
	return true
func select_upgrades() -> Array:
	var active := _slots.filter(func(slot):return slot.status=="upgrading")
	if _state.status!="developing":return []
	var candidates := _slots.filter(func(slot):return slot.status=="active" and slot.level<int(builds[slot.type].max_lv))
	while active.size()<int(row.concurrent_upgrade_count) and not candidates.is_empty():
		var index := random.randi_range(0,candidates.size()-1)
		var slot: Dictionary=candidates[index]
		candidates.remove_at(index)
		slot.status="upgrading"
		active.append(slot)
		building_revision+=1
	return active
# Read-only first-boundary check. Before the first revision, only work/time can
# change; no random choice, map paint or refit is needed to locate that boundary.
func revision_due(elapsed: float, crew_count: int) -> bool:
	if elapsed<=0 or crew_count<=0 or not _state.status in ["exploring","developing"]:return false
	var construction := _slots.filter(func(slot):return slot.status=="constructing")
	if construction.is_empty() and occupied_count<_slots.size():
		if float(_state.build_elapsed)+elapsed+0.0000001<float(row.build_interval):return false
		# advance() stops if no eligible next building exists.
		return _slots.any(func(slot):return slot.status=="empty" and slot_unlocked(slot) and builds.has(slot.type))
	var developing:bool=_state.status=="developing" or progress()>=1
	var upgrading := _slots.filter(func(slot):return slot.status=="upgrading") if developing else []
	if developing and upgrading.size()<int(row.concurrent_upgrade_count) and _slots.any(func(slot):return slot.status=="active" and slot.level<int(builds[slot.type].max_lv)):return true
	var power:=float(row.explore_power_base)+crew_count*float(row.explore_power_per_crew)
	if not construction.is_empty():
		var current:Dictionary=construction[0]
		var work_left:=maxf(0.0,work_cost()-float(current.work))
		if work_left<=0.0000001 or power>0:
			var work_time:=work_left/power if work_left>0.0000001 else 0.0
			if work_time+float(current.construction)<=elapsed+0.0000001:return true
	var share:float=(float(row.upgrade_power_base)+crew_count*float(row.upgrade_power_per_crew))/maxi(1,upgrading.size())
	for slot in upgrading:
		if share>0 and upgrade_cost(slot)-float(slot.upgrade_progress)<=share*elapsed+0.0000001:return true
	return false

# Prediction owns only building/work state. Map painting and its RNG remain live
# and run once, after the refit is committed.
func predict_advance(dt:float, count:int):
	var next=get_script().new()
	next.row=row;next.builds=builds;next._blueprint=_blueprint
	next._state=_state.duplicate(true);next._slots=next._state.slots;next._blueprint=next._state.blueprint
	next.building_revision=building_revision;next.random.state=random.state
	next.refresh_counts()
	next.advance(dt,count,false,false)
	return next

func commit_prediction(next)->void:
	for key in next._state:
		if key not in ["slots","blueprint"]:_state[key]=next._state[key]
	for i in _slots.size():_slots[i].merge(next._slots[i],true)
	building_revision=next.building_revision;random.state=next.random.state
	refresh_counts();changed()

func advance(elapsed: float, crew_count: int, _visible: bool=false, paint_map:bool=true) -> void:
	if elapsed<=0 or crew_count<=0 or not _state.status in ["exploring","developing"]:return
	var remaining := elapsed
	var power := float(row.explore_power_base)+crew_count*float(row.explore_power_per_crew)
	var upgrade_power := float(row.upgrade_power_base)+crew_count*float(row.upgrade_power_per_crew)
	while remaining>0.0000001 and _state.status!="complete":
		if progress()>=1:_state.status="developing"
		var construction := _slots.filter(func(slot):return slot.status=="constructing")
		if construction.is_empty() and occupied_count<_slots.size():
			var delay := minf(remaining,maxf(0.0,float(row.build_interval)-float(_state.build_elapsed)))
			_state.build_elapsed+=delay
			remaining-=delay
			if float(_state.build_elapsed)+0.0000001<float(row.build_interval):break
			if not build_attempt():break
			_state.build_elapsed=0.0
			construction=_slots.filter(func(slot):return slot.status=="constructing")
		var upgrading := select_upgrades()
		var share := upgrade_power/maxi(1,upgrading.size())
		var step := remaining
		var current: Dictionary=construction[0] if not construction.is_empty() else {}
		var doing_work := not current.is_empty() and float(current.work)+0.0000001<work_cost()
		if not current.is_empty():
			if doing_work:
				if power<=0:break
				step=minf(step,(work_cost()-float(current.work))/power)
			else:step=minf(step,float(current.construction))
		for slot in upgrading:
			if share>0:step=minf(step,(upgrade_cost(slot)-float(slot.upgrade_progress))/share)
		if current.is_empty() and (upgrading.is_empty() or share<=0):break
		if not current.is_empty():
			if doing_work:
				var amount := minf(power*step,work_cost()-float(current.work))
				current.work+=amount
				_state.explore_work=minf(float(row.explore_work_total),float(_state.explore_work)+amount)
			else:current.construction=maxf(0,float(current.construction)-step)
			if float(current.work)+0.0000001>=work_cost() and float(current.construction)<0.0000001:
				current.work=work_cost();current.construction=0.0;current.status="active";building_revision+=1
		for slot in upgrading:
			var amount := minf(share*step,upgrade_cost(slot)-float(slot.upgrade_progress))
			slot.upgrade_progress+=amount
			_state.upgrade_work+=amount
			if float(slot.upgrade_progress)+0.0000001>=upgrade_cost(slot):
				slot.level+=1;slot.upgrade_progress=0.0;slot.status="active";building_revision+=1
		remaining-=step
		refresh_counts()
		if progress()>=1:_state.status="developing"
		if is_complete():_state.status="complete"
	changed()
	if paint_map:sync_map()
func save_data() -> Dictionary:
	if compressed_revision!=revision:
		compressed_map=Marshalls.raw_to_base64(cells.compress(FileAccess.COMPRESSION_DEFLATE))
		compressed_revision=revision
	var result := _state.duplicate(true)
	result.owned=compressed_map
	result.rng_state=str(random.state)
	result.map_rng_state=str(map_random.state)
	return result

static func valid_snapshot(raw:Dictionary,definition:Dictionary,definitions:Dictionary,max_crew:int)->bool:
	for key in ["version","status","explore_work","upgrade_work","slot_seed","build_elapsed","bag","rounds","special_due","rng_state","map_rng_state","owned","blueprint","slots","pending_online_time","pending_crew_count"]:
		if not raw.has(key):return false
	if raw.version!=SAVE_VERSION or raw.status not in ["locked","available","exploring","developing","complete"]:return false
	for key in ["explore_work","upgrade_work","build_elapsed","pending_online_time"]:
		if not Layout.number(raw[key]) or raw[key]<0:return false
	if raw.explore_work>float(definition.explore_work_total) or raw.build_elapsed>float(definition.build_interval):return false
	for key in ["slot_seed","rounds","pending_crew_count"]:
		if not Layout.integer(raw[key]):return false
	if raw.rounds<0 or raw.pending_crew_count<0 or raw.pending_crew_count>max_crew or (raw.pending_online_time>0 and raw.pending_crew_count==0):return false
	if not raw.special_due is bool or not raw.bag is Array:return false
	var seen:Dictionary={}
	for key in raw.bag:
		if not key is String or seen.has(key) or not definitions.has(key) or definitions[key].group!="normal":return false
		seen[key]=true
	for key in ["rng_state","map_rng_state"]:
		if not raw[key] is String or not raw[key].is_valid_int() or str(int(raw[key]))!=raw[key]:return false
	if not raw.slots is Array or raw.slots.size()!=int(definition.building_slot_count):return false
	if not raw.get("blueprint") is Dictionary or not raw.blueprint.get("nodes") is Array or raw.blueprint.nodes.size()!=raw.slots.size():return false
	var cost:=float(definition.explore_work_total)/maxi(1,raw.slots.size())
	for i in raw.slots.size():
		var slot=raw.slots[i]
		if not slot is Dictionary:return false
		for field in ["id","node_id","world_pos","unlock_progress","status","type","level","work","construction","upgrade_progress","visual_seed","planned_type","parent_id"]:
			if not slot.has(field):return false
		if not slot.node_id is String or not Layout.point(slot.world_pos):return false
		for field in ["id","level","visual_seed","parent_id"]:
			if not Layout.integer(slot.get(field)):return false
		if slot.id!=i or not slot.get("type") is String or not definitions.has(slot.type) or slot.get("planned_type")!=slot.type:return false
		if slot.get("status") not in ["empty","constructing","active","upgrading"]:return false
		for field in ["unlock_progress","work","construction","upgrade_progress"]:
			if not Layout.number(slot.get(field)) or slot[field]<0:return false
		if (slot.work>cost and not is_equal_approx(slot.work,cost)) or slot.construction>float(definition.construction_time) or slot.level<0 or slot.level>int(definitions[slot.type].max_lv):return false
		if slot.status=="empty" and (slot.level!=0 or slot.work!=0 or slot.construction!=0 or slot.upgrade_progress!=0):return false
		if slot.status!="empty" and slot.level<1:return false
		if slot.status in ["active","upgrading"] and (not is_equal_approx(slot.work,cost) or slot.construction!=0):return false
		if slot.status=="upgrading" and (slot.level>=int(definitions[slot.type].max_lv) or slot.upgrade_progress>float(definition.get("upgrade_cost_lv%d"%(int(slot.level)+1),0))):return false
		if slot.status!="upgrading" and slot.upgrade_progress!=0:return false
		var node=raw.blueprint.nodes[i]
		if not node is Dictionary or slot.get("world_pos")!=node.get("world_pos") or slot.parent_id!=node.get("parent_id") or slot.visual_seed!=node.get("visual_seed"):return false
	var built:bool=raw.slots.all(func(slot):return slot.status in ["active","upgrading"])
	var complete:bool=raw.slots.all(func(slot):return slot.status=="active" and slot.level==int(definitions[slot.type].max_lv))
	if raw.status=="complete" and not complete:return false
	if raw.status=="developing" and (not built or complete):return false
	if raw.status in ["locked","available"] and raw.slots.any(func(slot):return slot.status!="empty"):return false
	var work:=0.0
	for slot in raw.slots:work+=float(slot.work)
	if not is_equal_approx(work,float(raw.explore_work)):return false
	if not Layout.valid_snapshot(raw,definitions):return false
	if not raw.owned is String or raw.owned.is_empty():return false
	var map_size:=int(definition.map_w)*int(definition.map_h)
	var decoded:=Marshalls.base64_to_raw(raw.owned).decompress(map_size,FileAccess.COMPRESSION_DEFLATE)
	if decoded.size()!=map_size or decoded.count(0)+decoded.count(1)!=map_size:return false
	for y in range((int(definition.map_h)-int(definition.start_h))/2,(int(definition.map_h)+int(definition.start_h))/2):
		for x in range((int(definition.map_w)-int(definition.start_w))/2,(int(definition.map_w)+int(definition.start_w))/2):
			if decoded[y*int(definition.map_w)+x]!=1:return false
	return true
