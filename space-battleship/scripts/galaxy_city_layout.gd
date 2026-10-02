extends RefCounted
## Deterministic view mapping only. Slot IDs, types, dependencies and save data stay owned by Region.
const FAMILIES := ["colony_ring","interstellar_refinery","stellar_energy_array","crystal_refinery","orbital_shipyard","heavy_element_refinery"]
const CELL := 16.0
var positions := {}
var groups: Array = []
var slot_group := {}
var core_offset := Vector3(-0.43235588,-0.09000003,-1.19500065)*1.2

func configure(region) -> void:
	positions.clear();groups.clear();slot_group.clear()
	for family in FAMILIES:
		var ids:Array[int]=[]
		for slot in region.slots:
			if str(slot.planned_type)==family:ids.append(int(slot.id))
		ids.sort()
		var columns:=mini(2 if groups.size() in [2,3] else 3,maxi(1,ids.size()))
		var rows:=maxi(1,ceili(float(ids.size())/columns))
		groups.append({"family":family,"ids":ids,"columns":columns,"rows":rows,"size":Vector2(columns*CELL+4,rows*CELL+4),"center":Vector3.ZERO,"side":Vector3.ZERO})
	var middle_half:=maxf(groups[2].size.y,groups[3].size.y)*0.5
	for index in groups.size():
		var group:Dictionary=groups[index]
		var half:Vector2=group.size*0.5
		if index in [0,1,4,5]:
			var side:float=-1.0 if index in [0,4] else 1.0
			var front:float=-1.0 if index<2 else 1.0
			var bank_height:float=maxf(groups[0 if index<2 else 4].size.y,groups[1 if index<2 else 5].size.y)*0.5
			group.center=Vector3(side*(half.x+8),0,front*(middle_half+2+bank_height))
			group.side=Vector3(-side,0,0)
		else:
			var side:float=-1.0 if index==2 else 1.0
			group.center=Vector3(side*(36+half.x),0,0)
			group.side=Vector3(-side,0,0)
		for ordinal in group.ids.size():
			var id:int=group.ids[ordinal]
			var col:int=ordinal%int(group.columns)
			var row:int=ordinal/int(group.columns)
			positions[id]=group.center+Vector3((col-(int(group.columns)-1)*0.5)*CELL,0,(row-(int(group.rows)-1)*0.5)*CELL)
			slot_group[id]=index
