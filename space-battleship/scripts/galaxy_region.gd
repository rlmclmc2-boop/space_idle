extends RefCounted
## Work owns progress; map cells and macro slots never derive durations.
signal cell_claimed(cell: int)
const SAVE_VERSION := 3
const Layout := preload("res://scripts/galaxy_layout.gd")
var blueprint := {}
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
	slots.clear()
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
	blueprint=Layout.generate(int(row.building_slot_count),int(state.slot_seed))
	if int(saved.get("version",0))>=SAVE_VERSION and saved.get("blueprint") is Dictionary:
		blueprint=saved.blueprint.duplicate(true)
		blueprint.layout_version=int(blueprint.layout_version)
		for plan in [blueprint.core]+blueprint.nodes:
			for field in ["id","parent_id","depth","visual_seed"]:
				if plan.has(field):plan[field]=int(plan[field])
	var incoming: Array=saved.get("slots",[]) if saved.get("slots",[]) is Array else []
	if int(saved.get("version",0))<2:incoming=incoming.filter(func(slot):return slot is Dictionary and builds.has(str(slot.get("type",""))))
	for id in blueprint.nodes.size():
		var plan: Dictionary=blueprint.nodes[id]
		var slot := {"id":id,"node_id":plan.node_id,"world_pos":plan.world_pos.duplicate(),"unlock_progress":0.0,"status":"empty","type":str(plan.type),"level":0,"work":0.0,"construction":0.0,"upgrade_progress":0.0,"visual_seed":plan.visual_seed}
		if id<incoming.size() and incoming[id] is Dictionary:
			var raw: Dictionary=incoming[id]
			if builds.has(str(raw.get("type",""))):
				slot.type=str(raw.type)
				slot.level=clampi(int(raw.get("level",1)),0,int(builds[slot.type].max_lv))
				slot.construction=clampf(float(raw.get("construction",0)),0,float(row.construction_time))
				slot.status="constructing" if slot.construction>0 or raw.get("status")=="constructing" else "active"
				if raw.get("status")=="empty":slot.status="empty";slot.level=0
				if raw.get("status")=="upgrading" and slot.level<int(builds[slot.type].max_lv):
					slot.status="upgrading"
					slot.upgrade_progress=clampf(float(raw.get("upgrade_progress",0)),0,upgrade_cost(slot))
				slot.work=clampf(float(raw.get("work",work_cost() if slot.status!="empty" else 0.0)),0,work_cost())
		if slot.type.is_empty():slot.type=next_build_type()
		plan.type=slot.type
		plan.planned_type=slot.type
		slot.planned_type=slot.type
		slot.parent_id=plan.parent_id
		slots.append(slot)
	# Legacy exploration becomes prepaid node work, without changing buildings/effects.
	if int(saved.get("version",0))<SAVE_VERSION:
		var prepaid := float(state.explore_work)
		for slot in slots:
			if slot.status!="empty":continue
			slot.work=minf(work_cost(),prepaid)
			prepaid=maxf(0.0,prepaid-float(slot.work))
	state.blueprint=blueprint
	state.slots=slots
	sync_map()
	refresh_counts()
	if state.status in ["exploring","developing","complete"]:
		state.status="developing" if progress()>=1 else "exploring"
		if is_complete():state.status="complete"

func work_cost() -> float:return float(row.explore_work_total)/maxi(1,blueprint.get("nodes",[]).size())
func node_progress(slot: Dictionary) -> float:
	if slot.status in ["active","upgrading"]:return 1.0
	if slot.status=="empty":return 0.0
	var total := work_cost()+float(row.construction_time)
	return clampf((float(slot.work)+float(row.construction_time)-float(slot.construction))/maxf(0.001,total),0,1)
func progress() -> float:
	var total := 0.0
	for slot in slots:total+=node_progress(slot)
	return total/maxi(1,slots.size())
func layout_snapshot() -> Dictionary:
	var result := blueprint.duplicate(true)
	result.building_revision=building_revision
	result.core.merge({"status":"active","level":1,"progress":1.0})
	for i in slots.size():
		var slot: Dictionary=slots[i]
		result.nodes[i].merge({"status":slot.status,"level":slot.level,"progress":node_progress(slot),"upgrade_progress":float(slot.upgrade_progress)/maxf(0.001,upgrade_cost(slot))})
	return result
func map_full() -> bool:return owned_count==cells.size()
func slot_unlocked(slot: Dictionary) -> bool:
	for prerequisite in blueprint.nodes[int(slot.id)].requires:
		if prerequisite=="core":continue
		var index := int(str(prerequisite).trim_prefix("node_"))
		if index<0 or index>=slots.size() or not slots[index].status in ["active","upgrading"]:return false
	return true
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
	if slots.any(func(slot):return slot.status=="constructing"):return false
	var candidates := slots.filter(func(slot):return slot.status=="empty" and slot_unlocked(slot) and builds.has(slot.type))
	if candidates.is_empty():return false
	var nearest := int(blueprint.nodes[int(candidates[0].id)].depth)
	for candidate in candidates:nearest=mini(nearest,int(blueprint.nodes[int(candidate.id)].depth))
	candidates=candidates.filter(func(slot):return int(blueprint.nodes[int(slot.id)].depth)==nearest)
	var slot: Dictionary=candidates[random.randi_range(0,candidates.size()-1)]
	slot.level=1
	slot.construction=float(row.construction_time)
	slot.status="constructing"
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
	if elapsed<=0 or crew_count<=0 or not state.status in ["exploring","developing"]:return
	var remaining := elapsed
	var power := float(row.explore_power_base)+crew_count*float(row.explore_power_per_crew)
	var upgrade_power := float(row.upgrade_power_base)+crew_count*float(row.upgrade_power_per_crew)
	while remaining>0.0000001 and state.status!="complete":
		if progress()>=1:state.status="developing"
		var construction := slots.filter(func(slot):return slot.status=="constructing")
		if construction.is_empty() and occupied_count<slots.size():
			var delay := minf(remaining,maxf(0.0,float(row.build_interval)-float(state.build_elapsed)))
			state.build_elapsed+=delay
			remaining-=delay
			if float(state.build_elapsed)+0.0000001<float(row.build_interval):break
			if not build_attempt():break
			state.build_elapsed=0.0
			construction=slots.filter(func(slot):return slot.status=="constructing")
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
				state.explore_work=minf(float(row.explore_work_total),float(state.explore_work)+amount)
			else:current.construction=maxf(0,float(current.construction)-step)
			if float(current.work)+0.0000001>=work_cost() and float(current.construction)<0.0000001:
				current.work=work_cost();current.construction=0.0;current.status="active";building_revision+=1
		for slot in upgrading:
			var amount := minf(share*step,upgrade_cost(slot)-float(slot.upgrade_progress))
			slot.upgrade_progress+=amount
			state.upgrade_work+=amount
			if float(slot.upgrade_progress)+0.0000001>=upgrade_cost(slot):
				slot.level+=1;slot.upgrade_progress=0.0;slot.status="active";building_revision+=1
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
