extends RefCounted
# Candidate-only authoring contract. No reward RNG or probability is introduced here.
static func rolls(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0 or float(value)!=floor(float(value)):
		return -1
	return int(value)

static func _members(group: Dictionary, enemies: Dictionary) -> Array:
	var result: Array=[]
	for id in group.slots:
		if id!=null:result.append(enemies[str(int(id))])
	return result

static func _custom(rows: Array) -> bool:
	for row in rows:
		if row.has("jewelDropRolls") or row.has("rewardDrops"):return true
	return false

static func _multiset(rows: Array) -> Dictionary:
	var result:Dictionary={}
	for row in rows:
		for drop in row.drops:
			var key:=str([int(drop.resourceId),float(drop.amount),float(drop.chance)])
			result[key]=int(result.get(key,0))+1
	return result

static func binding_error(group_id: String, groups: Dictionary, enemies: Dictionary, levels: Array, stage: int, res_ratio: float, jewel_ratio: float) -> String:
	var group:Dictionary=groups[group_id]
	var rows:=_members(group,enemies)
	var binding:Variant=group.get("rewardBinding")
	if binding==null and not _custom(rows):return ""
	if not binding is Dictionary or binding.get("status")!="BOUND":return "candidate rewards UNBOUND"
	var reference_number:=rolls(binding.get("referenceGroupId"))
	var reference:=str(reference_number)
	if reference_number<0 or reference==group_id or not groups.has(reference):return "invalid reward reference group"
	var source:=_members(groups[reference],enemies)
	if groups[reference].has("rewardBinding") or _custom(source):return "reward reference must be a legacy fleet"
	var count:=0
	for row in rows:
		var n:=rolls(row.get("jewelDropRolls",1))
		if n<0:return "invalid jewelDropRolls"
		count+=n
	if count!=source.size():return "fragment draw budget differs from reference"
	if _multiset(rows)!=_multiset(source):return "resource drop multiset differs from reference"
	var bound_level:=rolls(binding.get("levelId"))
	if bound_level<1 or bound_level!=stage:return "candidate mounted outside bound level"
	var level:Dictionary={}
	for row in levels:
		if int(row.id)==bound_level:level=row;break
	if level.is_empty():return "bound level missing"
	var reference_found:=false
	for encounter in level.groups+level.get("rewardReferenceGroups",[]):
		if str(int(encounter.id))==reference:reference_found=true;break
	if not reference_found:return "reference is not instantiated in bound level"
	for key in ["resRatio","jewelRatio"]:
		var v:Variant=binding.get(key)
		if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)) or float(v)<0:return "invalid bound "+key
	if float(binding.resRatio)!=res_ratio or float(binding.jewelRatio)!=jewel_ratio:return "candidate reward multiplier differs from bound budget"
	return ""
