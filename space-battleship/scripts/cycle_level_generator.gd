extends RefCounted
## Selects saved enemy fleets from existing, measured loadout results.

var database: ShipDatabase

func _init(source: ShipDatabase) -> void:
	database=source

func weapon_kind(keys: Array) -> String:
	var types: Dictionary={}
	for key in keys:
		var rows: Array=database.equipment.get(str(key),[])
		if rows.is_empty() or not rows[0].has("dmgtype"):return ""
		types[int(rows[0].dmgtype)]=true
	if types.is_empty():return ""
	if types.size()>1:return "mixed"
	var damage_type: int=int(types.keys()[0])
	if damage_type==1:return "energy"
	if damage_type==2:return "physical"
	return str(damage_type)

func validate(config: Dictionary,source: Dictionary) -> String:
	var rows=source.get("levels")
	if not rows is Array or rows.is_empty():return "敌舰群分析文件缺少 levels。"
	for key in ["level_count","battle_points_per_level","small_cycle","large_cycle","strength_tolerance","fleet_reuse_limit","recent_fleet_window","similarity_window","seed"]:
		var value=config.get(key)
		if not (value is int or value is float) or float(value)!=floorf(float(value)):return "%s 必须为整数。" % key
		if int(value)<(1 if key in ["level_count","battle_points_per_level","small_cycle","large_cycle","fleet_reuse_limit"] else 0):return "%s 超出允许范围。" % key
	if int(config.large_cycle)%int(config.small_cycle)!=0:return "large_cycle 必须是 small_cycle 的整数倍。"
	if not config.get("strength_pattern") is Array or config.strength_pattern.size()!=int(config.large_cycle):return "strength_pattern 长度必须等于 large_cycle。"
	if not config.get("weapon_pattern") is Array or config.weapon_pattern.is_empty():return "weapon_pattern 不能为空。"
	if not config.get("battle_point_offsets") is Array or config.battle_point_offsets.size()!=int(config.battle_points_per_level):return "battle_point_offsets 数量必须等于每关战点数。"
	for key in ["strength_pattern","battle_point_offsets"]:
		for value in config[key]:
			if not (value is int or value is float) or float(value)!=floorf(float(value)):return "%s 必须由整数组成。" % key
	if rows.size()<int(config.battle_points_per_level):return "现有敌群不足以满足同关不重复。"
	var available: Dictionary={}
	var ids: Dictionary={}
	var groups: Dictionary={}
	for row in rows:
		if not row is Dictionary:return "敌群分析记录无效。"
		var fleet_id: String=str(row.get("enemy_id",""))
		var group_id: int=int(row.get("enemy_group",0))
		if fleet_id.is_empty() or ids.has(fleet_id) or group_id<1 or groups.has(group_id):return "敌群 ID 或 monGroup ID 缺失或重复。"
		if not row.get("group_data") is Dictionary:return "敌群缺少原始编队。"
		var saved_group: Dictionary=database.groups.get(str(group_id),{})
		if saved_group.is_empty() or saved_group.get("slots",[])!=row.get("group_data",{}).get("slots",[]):return "enemy_fleet %s 与现有 monGroup %d 不一致。" % [fleet_id,group_id]
		ids[fleet_id]=true
		groups[group_id]=true
		for measured in row.get("loadout_results",[]):
			if not measured is Dictionary:continue
			var kind:=weapon_kind(measured.get("weapons",[]))
			if kind.is_empty():return "分析结果包含没有 canonical dmgtype 的武器。"
			var strength=measured.get("required_level")
			if strength!=null:
				if not (strength is int or strength is float) or float(strength)!=floorf(float(strength)):return "分析结果包含无效 required_level。"
				available[kind]=true
	for kind in config.weapon_pattern:
		if not available.has(str(kind)):return "分析结果没有武器类型 %s 的已测强度。" % str(kind)
	return ""

func _similarity(left: Dictionary,right: Dictionary) -> float:
	var keys: Dictionary={}
	for key in left:keys[key]=true
	for key in right:keys[key]=true
	var overlap:=0.0
	var union:=0.0
	for key in keys:
		overlap+=minf(float(left.get(key,0)),float(right.get(key,0)))
		union+=maxf(float(left.get(key,0)),float(right.get(key,0)))
	return overlap/union if union>0 else 0.0

func _less(left: Array,right: Array) -> bool:
	for index in range(left.size()):
		if left[index]<right[index]:return true
		if left[index]>right[index]:return false
	return false

func generate(config: Dictionary,source: Dictionary) -> Dictionary:
	var problem:=validate(config,source)
	if not problem.is_empty():return {"error":problem}
	var fleets: Array=source.levels.duplicate()
	fleets.sort_custom(func(a,b):return str(a.enemy_id)<str(b.enemy_id))
	var by_id: Dictionary={}
	var strengths: Dictionary={}
	for fleet in fleets:
		var fleet_id: String=str(fleet.enemy_id)
		by_id[fleet_id]=fleet
		var measured: Dictionary={}
		for row in fleet.get("loadout_results",[]):
			if row.get("required_level")==null:continue
			var kind:=weapon_kind(row.get("weapons",[]))
			if not measured.has(kind):measured[kind]=[]
			measured[kind].append(int(row.required_level))
		strengths[fleet_id]=measured
	var random:=RandomNumberGenerator.new()
	random.seed=int(config.seed)
	var reuse: Dictionary={}
	var history: Array=[]
	var levels: Array=[]
	var exact:=0
	var fallback:=0
	for level_id in range(1,int(config.level_count)+1):
		var level_strength: int=int(config.strength_pattern[(level_id-1)%config.strength_pattern.size()])
		var bias: String=str(config.weapon_pattern[(level_id-1)%config.weapon_pattern.size()])
		var chosen: Dictionary={}
		var points: Array=[]
		for point_index in range(int(config.battle_points_per_level)):
			var offset: int=int(config.battle_point_offsets[point_index])
			var target: int=level_strength+offset
			var best_score: Array=[]
			var peers: Array=[]
			for fleet in fleets:
				var fleet_id: String=str(fleet.enemy_id)
				if chosen.has(fleet_id) or not history.is_empty() and history.back()==fleet_id:continue
				var typed: Array=strengths[fleet_id].get(bias,[])
				var all_values: Array=[]
				for kind in strengths[fleet_id]:all_values.append_array(strengths[fleet_id][kind])
				var distance:=2147483647
				var tier:=4
				if not typed.is_empty():
					for value in typed:distance=mini(distance,absi(target-int(value)))
					tier=0 if distance==0 else 1 if distance<=int(config.strength_tolerance) else 2
				elif not all_values.is_empty():
					for value in all_values:distance=mini(distance,absi(target-int(value)))
					tier=3
				elif fleet.get("recommended_level")!=null:distance=absi(target-int(fleet.recommended_level))
				else:continue
				var recent:=false
				var highest:=0.0
				for backward in range(1,mini(history.size(),maxi(int(config.recent_fleet_window),int(config.similarity_window)))+1):
					var old_id: String=str(history[-backward])
					if backward<=int(config.recent_fleet_window) and old_id==fleet_id:recent=true
					if backward<=int(config.similarity_window):highest=maxf(highest,_similarity(fleet.get("composition",{}),by_id[old_id].get("composition",{})))
				for old_id in chosen:highest=maxf(highest,_similarity(fleet.get("composition",{}),by_id[old_id].get("composition",{})))
				var count: int=int(reuse.get(fleet_id,0))
				var score: Array=[tier,distance,int(recent),int(highest>=0.8),int(count>=int(config.fleet_reuse_limit)),count,-int((1.0-highest)*10000)]
				if best_score.is_empty() or _less(score,best_score):best_score=score;peers=[fleet]
				elif score==best_score:peers.append(fleet)
			if peers.is_empty():return {"error":"L%03d BP%d 没有满足同关与连续去重的敌群。" % [level_id,point_index+1]}
			var selected: Dictionary=peers[random.randi_range(0,peers.size()-1)]
			var selected_id: String=str(selected.enemy_id)
			chosen[selected_id]=true
			history.append(selected_id)
			reuse[selected_id]=int(reuse.get(selected_id,0))+1
			var tier: int=int(best_score[0])
			if tier==0:exact+=1
			else:fallback+=1
			points.append({"battle_point_index":point_index+1,"enemy_fleet_id":selected_id,"mon_group_id":int(selected.enemy_group),"battle_point_offset":offset,"target_strength":target,"fallback_level":tier,"fallback_reason":["exact","within_tolerance","closest_weapon","weapon_relaxed","closest_legal"][tier],"reuse_count":reuse[selected_id]})
		levels.append({"level_id":level_id,"strength_offset":level_strength,"weapon_bias":bias,"battle_points":points})
	var total: int=int(config.level_count)*int(config.battle_points_per_level)
	return {"statistics":{"levels":levels.size(),"battle_points":total,"unique_fleets_used":reuse.size(),"exact_match_rate":float(exact)/float(total),"fallback_count":fallback},"levels":levels}
