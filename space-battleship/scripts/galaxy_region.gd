extends RefCounted
## Work owns progress; map cells and macro slots never derive durations.
signal cell_claimed(cell: int)
const SAVE_VERSION := 2
var row: Dictionary
var builds: Dictionary
var state: Dictionary
var slots: Array = []
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
	row=definition
	builds=definitions
	chunk_size=chunk
	random.seed=int(row.slot_seed)+71
	map_random.seed=int(row.slot_seed)+193
	if saved.has("rng_state"):random.state=int(str(saved.rng_state))
	if saved.has("map_rng_state"):map_random.state=int(str(saved.map_rng_state))
	state={"version":SAVE_VERSION,"status":str(saved.get("status","locked")),"explore_work":0.0,"upgrade_work":maxf(0,float(saved.get("upgrade_work",0))),"slot_seed":int(saved.get("slot_seed",row.slot_seed)),"build_elapsed":clampf(float(saved.get("build_elapsed",0)),0,float(row.build_interval)),"bag":[],"rounds":maxi(0,int(saved.get("rounds",0))),"special_due":bool(saved.get("special_due",false))}
	if not state.status in ["locked","available","exploring","developing","complete"]:state.status="locked"
	if saved.get("bag") is Array:
		for key in saved.bag:
			if builds.has(str(key)) and builds[str(key)].group=="normal" and not state.bag.has(str(key)):state.bag.append(str(key))
	cells.resize(int(row.map_w)*int(row.map_h))
	cells.fill(0)
	if saved.get("owned","") is String and not str(saved.get("owned","")).is_empty():
		var decoded := Marshalls.base64_to_raw(saved.owned).decompress(cells.size(),FileAccess.COMPRESSION_DEFLATE)
		if decoded.size()==cells.size():
			cells=decoded
			for id in cells.size():cells[id]=1 if cells[id]!=0 else 0
	for y in range((int(row.map_h)-int(row.start_h))/2,(int(row.map_h)+int(row.start_h))/2):
		for x in range((int(row.map_w)-int(row.start_w))/2,(int(row.map_w)+int(row.start_w))/2):cells[y*int(row.map_w)+x]=1
	owned_count=cells.count(1)
	var initial := int(row.start_w)*int(row.start_h)
	var old_fraction := clampf(float(owned_count-initial)/maxi(1,cells.size()-initial),0,1)
	state.explore_work=clampf(float(saved.get("explore_work",old_fraction*float(row.explore_work_total))),0,float(row.explore_work_total))
	for id in cells.size():
		if cells[id]!=0 and has_unowned_neighbor(id):add_frontier(id)
	var layout := RandomNumberGenerator.new()
	layout.seed=int(state.slot_seed)
	var incoming: Array=saved.get("slots",[]) if saved.get("slots",[]) is Array else []
	if int(saved.get("version",0))<SAVE_VERSION:incoming=incoming.filter(func(slot):return slot is Dictionary and builds.has(str(slot.get("type",""))))
	for id in int(row.building_slot_count):
		var angle := id*2.39996323+layout.randf_range(-0.16,0.16)
		var radius := 23.0+sqrt(float(id)/maxi(1,int(row.building_slot_count)-1))*44.0
		var pos := Vector2(cos(angle),sin(angle))*radius
		while slots.any(func(slot):return pos.distance_to(Vector2(slot.world_pos[0],slot.world_pos[1]))<13.0):
			radius+=2.0
			pos=Vector2(cos(angle),sin(angle))*radius
		var threshold := 1.0 if id==int(row.building_slot_count)-1 else clampf((float(id)+1)/int(row.building_slot_count)+layout.randf_range(-0.008,0.008),0.025,0.99)
		var slot := {"id":id,"world_pos":[pos.x,pos.y],"unlock_progress":threshold,"status":"empty","type":"","level":0,"construction":0.0,"upgrade_progress":0.0,"visual_seed":layout.randi()}
		if id<incoming.size() and incoming[id] is Dictionary:
			var raw: Dictionary=incoming[id]
			if builds.has(str(raw.get("type",""))):
				slot.type=str(raw.type)
				slot.level=clampi(int(raw.get("level",1)),1,int(builds[slot.type].max_lv))
				slot.construction=clampf(float(raw.get("construction",0)),0,float(row.construction_time))
				slot.status="constructing" if slot.construction>0 else "active"
				if raw.get("status")=="upgrading" and slot.level<int(builds[slot.type].max_lv):
					slot.status="upgrading"
					slot.upgrade_progress=clampf(float(raw.get("upgrade_progress",0)),0,upgrade_cost(slot))
		slots.append(slot)
	state.slots=slots
	sync_map()
	refresh_counts()
	if state.status in ["exploring","developing","complete"]:
		state.status="developing" if progress()>=1 else "exploring"
		if is_complete():state.status="complete"

func progress() -> float:return clampf(float(state.explore_work)/float(row.explore_work_total),0,1)
func map_full() -> bool:return owned_count==cells.size()
func slot_unlocked(slot: Dictionary) -> bool:return progress()+0.0000001>=float(slot.unlock_progress)
func upgrade_cost(slot: Dictionary) -> float:return float(row.get("upgrade_cost_lv%d"%(int(slot.level)+1),0))
func refresh_counts() -> void:
	occupied_count=0
	max_level_count=0
	for slot in slots:
		if slot.status=="empty":continue
		occupied_count+=1
		if slot.status=="active" and slot.level>=int(builds[slot.type].max_lv):max_level_count+=1
func is_complete() -> bool:return progress()>=1 and occupied_count==slots.size() and max_level_count==slots.size()
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
	cell_claimed.emit(id)
func sync_map() -> void:
	var initial := int(row.start_w)*int(row.start_h)
	var target := initial+floori((cells.size()-initial)*progress())
	while owned_count<target and not frontier.is_empty():
		var source: int=frontier[map_random.randi_range(0,frontier.size()-1)]
		var choices := adjacent(source).filter(func(id):return cells[id]==0)
		if choices.is_empty():remove_frontier(source)
		else:paint(choices[map_random.randi_range(0,choices.size()-1)])
func next_build_type() -> String:
	if state.special_due:
		state.special_due=false
		var special := builds.keys().filter(func(key):return builds[key].group=="special")
		return str(special[random.randi_range(0,special.size()-1)]) if not special.is_empty() else ""
	if state.bag.is_empty():
		state.bag=builds.keys().filter(func(key):return builds[key].group=="normal")
		for i in range(state.bag.size()-1,0,-1):
			var j := random.randi_range(0,i)
			var swap=state.bag[i]
			state.bag[i]=state.bag[j]
			state.bag[j]=swap
	if state.bag.is_empty():return ""
	var result := str(state.bag.pop_back())
	if state.bag.is_empty():
		state.rounds+=1
		if int(state.rounds)%int(row.special_cycle)==0:state.special_due=true
	return result
func build_attempt() -> bool:
	var key := next_build_type()
	var candidates := slots.filter(func(slot):return slot.status=="empty" and slot_unlocked(slot))
	if key.is_empty() or candidates.is_empty():return false
	var slot: Dictionary=candidates[random.randi_range(0,candidates.size()-1)]
	slot.type=key
	slot.level=1
	slot.construction=float(row.construction_time)
	slot.status="constructing" if slot.construction>0 else "active"
	building_revision+=1
	refresh_counts()
	return true
func select_upgrades() -> Array:
	var active := slots.filter(func(slot):return slot.status=="upgrading")
	if state.status!="developing":return []
	var candidates := slots.filter(func(slot):return slot.status=="active" and slot.level<int(builds[slot.type].max_lv))
	while active.size()<int(row.concurrent_upgrade_count) and not candidates.is_empty():
		var index := random.randi_range(0,candidates.size()-1)
		var slot: Dictionary=candidates[index]
		candidates.remove_at(index)
		slot.status="upgrading"
		active.append(slot)
		building_revision+=1
	return active
func advance(elapsed: float, crew_count: int, _visible: bool=false) -> void:
	if elapsed<=0 or not state.status in ["exploring","developing"]:return
	var remaining := elapsed
	var explore_power := float(row.explore_power_base)+crew_count*float(row.explore_power_per_crew)
	var upgrade_power := float(row.upgrade_power_base)+crew_count*float(row.upgrade_power_per_crew)
	while remaining>0.0000001 and state.status!="complete":
		if progress()>=1:state.status="developing"
		if occupied_count<slots.size() and float(state.build_elapsed)+0.0000001>=float(row.build_interval):
			state.build_elapsed=0.0
			build_attempt()
		var upgrading := select_upgrades()
		var share := upgrade_power/maxi(1,upgrading.size())
		var step := remaining
		if state.status=="exploring" and explore_power>0:
			step=minf(step,(float(row.explore_work_total)-float(state.explore_work))/explore_power)
			for slot in slots:
				var work_to_unlock := float(slot.unlock_progress)*float(row.explore_work_total)-float(state.explore_work)
				if work_to_unlock>0.0000001:step=minf(step,work_to_unlock/explore_power)
		if occupied_count<slots.size():step=minf(step,float(row.build_interval)-float(state.build_elapsed))
		for slot in slots:
			if slot.status=="constructing":step=minf(step,float(slot.construction))
		for slot in upgrading:
			if share>0:step=minf(step,(upgrade_cost(slot)-float(slot.upgrade_progress))/share)
		step=maxf(step,0.0000001)
		if state.status=="exploring":state.explore_work=minf(float(row.explore_work_total),float(state.explore_work)+explore_power*step)
		if occupied_count<slots.size():state.build_elapsed+=step
		for slot in slots:
			if slot.status=="constructing":
				slot.construction=maxf(0,float(slot.construction)-step)
				if slot.construction<0.0000001:slot.construction=0.0;slot.status="active";building_revision+=1
		for slot in upgrading:
			var amount := minf(share*step,upgrade_cost(slot)-float(slot.upgrade_progress))
			slot.upgrade_progress+=amount
			state.upgrade_work+=amount
			if float(slot.upgrade_progress)+0.0000001>=upgrade_cost(slot):
				slot.level+=1
				slot.upgrade_progress=0.0
				slot.status="active"
				building_revision+=1
		remaining-=step
		refresh_counts()
		if progress()>=1:state.status="developing"
		if is_complete():state.status="complete"
	sync_map()
func save_data() -> Dictionary:
	if compressed_revision!=revision:
		compressed_map=Marshalls.raw_to_base64(cells.compress(FileAccess.COMPRESSION_DEFLATE))
		compressed_revision=revision
	var result := state.duplicate(true)
	result.owned=compressed_map
	result.rng_state=str(random.state)
	result.map_rng_state=str(map_random.state)
	return result
