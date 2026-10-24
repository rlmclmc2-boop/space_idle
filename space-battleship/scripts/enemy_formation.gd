extends RefCounted
## Runtime placement authority. Source slots, identities and loadouts stay intact.
static func positions(slots: Array, enemies: Dictionary, explicit: Variant = null) -> Dictionary:
	if explicit != null:
		var error := explicit_error(slots,enemies,explicit)
		if not error.is_empty():
			push_error(error)
			return {}
		var authored := {}
		for slot in slots.size():
			if slots[slot] != null:authored[slot] = Vector2(float(explicit[slot][0]),float(explicit[slot][1]))
		return authored
	var members: Array[Dictionary] = []
	for slot in slots.size():
		if slots[slot] != null:
			members.append({"slot":slot,"id":int(slots[slot]),"size":int(enemies[str(int(slots[slot]))].size)})
	members.sort_custom(func(a,b):
		if a.size != b.size:return a.size > b.size
		if a.id != b.id:return a.id < b.id
		return a.slot < b.slot)
	var result := {}
	var rows := ceili(float(members.size()) / 5.0)
	var cursor := 0
	for row in rows:
		var count := mini(5,ceili(float(members.size()-cursor)/float(rows-row)))
		var columns: Array[int] = []
		for column in count:columns.append(column)
		columns.sort_custom(func(a,b):return absf(float(a)-(count-1)*0.5)<absf(float(b)-(count-1)*0.5) if absf(float(a)-(count-1)*0.5)!=absf(float(b)-(count-1)*0.5) else a<b)
		# Back is toward the top. Larger ships claim back rows and central berths.
		# Logical Y is consumed by combat, then projected by the ordinary battle map.
		var y := 140.0 if rows==1 else (110.0 if row==0 else 270.0 if row==1 else 350.0)
		var spacing := minf(160.0,456.0/maxi(1,count-1))
		for column in columns:
			result[int(members[cursor].slot)] = Vector2(286.0+(float(column)-(count-1)*0.5)*spacing,y)
			cursor += 1
	return result

static func explicit_error(slots:Array,enemies:Dictionary,explicit:Variant)->String:
	if not explicit is Array or explicit.size()!=slots.size():return "formation_positions must match source slots"
	var occupied:Array=[]
	for slot in slots.size():
		var point:Variant=explicit[slot]
		if slots[slot]==null:
			if point!=null:return "empty slot has explicit coordinates"
			continue
		if not point is Array or point.size()!=2:return "occupied slot needs two coordinates"
		for value in point:
			if not (value is int or value is float) or not is_finite(float(value)):return "coordinates must be finite numbers"
		var pos:=Vector2(float(point[0]),float(point[1]))
		if pos.x<54 or pos.x>518 or pos.y<80 or pos.y>350:return "explicit coordinate outside input bounds"
		var size:=int(enemies[str(int(slots[slot]))].size)
		if size>=4 and absf(pos.x-286)>150:return "large hull must remain in central sector"
		occupied.append({"point":pos,"size":size})
	for a in occupied.size():
		for b in range(a+1,occupied.size()):
			if occupied[a].point==occupied[b].point:return "coincident explicit slots"
			var larger:Dictionary=occupied[a] if occupied[a].size>occupied[b].size else occupied[b]
			var smaller:Dictionary=occupied[b] if occupied[a].size>occupied[b].size else occupied[a]
			if larger.size>=4 and larger.size>smaller.size and larger.point.y>smaller.point.y:return "large hull is ahead of smaller hull"
	return ""
