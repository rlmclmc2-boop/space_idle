extends RefCounted
## Unique double-precision motion storage. A lease owns each stable slot until
## the last authoritative/display reference disappears; no live dictionary copy.
const STRIDE=9
var values:=PackedFloat64Array()
var free_slots:=PackedInt32Array()
func allocate(shot:Dictionary)->int:
	var slot:int
	if free_slots.is_empty():
		slot=values.size()/STRIDE;values.resize(values.size()+STRIDE)
	else:slot=free_slots[-1];free_slots.resize(free_slots.size()-1)
	var i:=slot*STRIDE
	var direction:Vector2=shot.direction
	var aim:Vector2=shot.get("last_target_point",Vector2.ZERO)
	values[i]=shot.x;values[i+1]=shot.y
	values[i+2]=direction.x;values[i+3]=direction.y;values[i+4]=shot.speed
	values[i+5]=shot.get("motion_age",0.0);values[i+6]=shot.get("orphan_age",0.0)
	values[i+7]=aim.x;values[i+8]=aim.y
	return slot
func release(slot:int)->void:
	free_slots.append(slot)
