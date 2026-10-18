extends RefCounted
## Target anchors are the XZ bounds centre of the authored body. Apply this
## transform to the complete assembly, including its imported socket chains.
static func body_center(row:Dictionary)->Vector3:
	var low:Array=row.godot_aabb_min;var high:Array=row.godot_aabb_max
	return Vector3((float(low[0])+float(high[0]))*0.5,0.0,(float(low[2])+float(high[2]))*0.5)

static func centered_transform(basis:Basis,anchor:Vector3,row:Dictionary)->Transform3D:
	return Transform3D(basis,anchor-basis*body_center(row))

# The Frigate's sole authored mount sits behind its bow. Shift the entire
# weapon assembly (mesh, pivot and real muzzle) forward together so the wide
# cannon discharge leaves the hull instead of starting inside it.
static func weapon_mount_offset(ship_key:String,slot:int)->Vector3:
	return Vector3(0,0,-1.0) if ship_key=="Frigate" and slot==0 else Vector3.ZERO

# Shared pure fit for the approved flat hull. The live scene and the logical
# battle pose must derive the same mount position after display-only fitting.
static func approved_body_fit(opaque:Rect2,mesh_size:Vector2,base_position:Vector3,viewport_size:Vector2,rendered_height:float,rendered_position:Vector2,model_span:float)->Dictionary:
	var ratio:=opaque.size.x/opaque.size.y
	var art_scale:=1.0
	if ratio>1.3:art_scale=clampf(viewport_size.x*0.15/(rendered_height*ratio),1.0,1.35)
	var safe:=Rect2(Vector2(12,12),viewport_size-Vector2(24,64))
	var body:=Vector2(ratio,1.0)*rendered_height*art_scale
	art_scale*=minf(1.0,minf(safe.size.x/body.x,safe.size.y/body.y))
	body=Vector2(ratio,1.0)*rendered_height*art_scale
	var center:=Vector2(clampf(rendered_position.x,safe.position.x+body.x*0.5,safe.end.x-body.x*0.5),clampf(rendered_position.y,safe.position.y+body.y*0.5,safe.end.y-body.y*0.5))
	var local_per_pixel:=model_span/rendered_height
	return {"scale":art_scale,"position":base_position+Vector3(center.x-rendered_position.x,0,center.y-rendered_position.y)*local_per_pixel,"mesh_size":mesh_size}

static func approved_mount_position(fit:Dictionary,point:Array)->Vector3:
	var mesh_size:Vector2=fit.mesh_size
	var scale:float=fit.scale
	return Vector3(fit.position)+Vector3(float(point[0])*mesh_size.x,0.08,float(point[1])*mesh_size.y)*scale
