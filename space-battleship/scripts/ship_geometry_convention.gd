extends RefCounted
## Target anchors are the XZ bounds centre of the authored body. Apply this
## transform to the complete assembly, including its imported socket chains.
static func body_center(row:Dictionary)->Vector3:
	var low:Array=row.godot_aabb_min;var high:Array=row.godot_aabb_max
	return Vector3((float(low[0])+float(high[0]))*0.5,0.0,(float(low[2])+float(high[2]))*0.5)

static func centered_transform(basis:Basis,anchor:Vector3,row:Dictionary)->Transform3D:
	return Transform3D(basis,anchor-basis*body_center(row))
