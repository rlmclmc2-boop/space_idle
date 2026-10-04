extends RefCounted
## Runtime placement authority. Source slots, identities and loadouts stay intact.
static func positions(slots: Array, enemies: Dictionary) -> Dictionary:
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
