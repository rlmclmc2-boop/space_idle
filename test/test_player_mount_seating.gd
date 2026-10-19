extends SceneTree
## Independent static-image seat vs imported bearing/pivot check. No game/save/native build.
const VIEW := preload("res://scripts/presented_ship_view.gd")
const KEYS := ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
const WEAPONS := ["cannon","laser","missile","longLaser","cannon"]
# Manually inspected installation-seat centres in the approved transparent atlas.
# These are source pixels, not coordinates read back from ship_weapon_visuals.json.
const SEATS := [
	{"crop":[8,325],"points":[[118,480]]},
	{"crop":[253,229],"points":[[327,374],[466,374]]},
	{"crop":[572,121],"points":[[770,216],[657,455],[887,455]]},
	{"crop":[953,101],"points":[[1064,218],[1329,218],[1068,509],[1328,509]]},
	{"crop":[1434,44],"points":[[1694,171],[1524,298],[1864,298],[1524,457],[1864,457]]}
]
class Markers extends Control:
	var points:Array=[]
	func _draw()->void:
		for row in points:
			draw_arc(row.seat,9,0,TAU,32,Color.GREEN,1.5,true)
			draw_circle(row.bearing,3,Color.CYAN)
			draw_line(row.pivot-Vector2(5,5),row.pivot+Vector2(5,5),Color.MAGENTA,1.5,true)
			draw_line(row.pivot+Vector2(-5,5),row.pivot+Vector2(5,-5),Color.MAGENTA,1.5,true)
var results:Array=[]
var failures:=0
var maximum:=0.0
func _initialize()->void:call_deferred("run")

# Interpolate the actual PlaneMesh triangle UVs rather than assuming UV orientation.
func image_point(plane:MeshInstance3D,uv:Vector2)->Vector3:
	var arrays:Array=plane.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for start in range(0,indices.size(),3):
		var ia:int=indices[start];var ib:int=indices[start+1];var ic:int=indices[start+2]
		var a:Vector2=uvs[ia];var b:Vector2=uvs[ib];var c:Vector2=uvs[ic]
		var denominator:float=(b-a).cross(c-a)
		if absf(denominator)<0.000001:continue
		var wb:float=(uv-a).cross(c-a)/denominator
		var wc:float=(b-a).cross(uv-a)/denominator
		var wa:float=1.0-wb-wc
		if minf(wa,minf(wb,wc))>=-0.00001:return plane.to_global(vertices[ia]*wa+vertices[ib]*wb+vertices[ic]*wc)
	assert(false,"Seat outside actual hull mesh UVs")
	return Vector3.ZERO

func configure(view,key:String,index:int)->void:
	assert(view.set_hull(key))
	var entries:Array=[]
	for slot in index+1:entries.append({"key":WEAPONS[slot]})
	assert(view.set_loadout(entries,index+1))

func pose(view,index:int,state:String)->Array:
	view.set_pose(Vector2(300,350),540.0,0.0,Vector2(300,-200),0.0,false,false)
	var angle:=deg_to_rad(-60 if state.contains("left") else 60 if state.contains("right") else 0)
	var angles:Array=[]
	for slot in index+1:angles.append(0.0 if state.begins_with("fire-") else angle)
	view.set_slot_angles(angles)
	var feedback:Dictionary={}
	if state.begins_with("fire-"):
		for module in view.modules:
			if module.key=="missile":
				module.pivot.rotation.y=-angle
				continue
			feedback[int(module.slot)]={"fire_until":1.0,"fire_angle":angle,"fire_ordinal":0,
				"fire_origin":view.screen_muzzle_for_slot(int(module.slot))}
	view.apply_direct_fire_alignment(feedback,0.0)
	var measured:Array=[]
	var plane:MeshInstance3D=view.approved_body_plane
	var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
	var fixture:Dictionary=SEATS[index]
	for module in view.modules:
		var slot:int=int(module.slot)
		var source:Array=fixture.points[slot]
		var pixel:=Vector2(float(source[0])-float(fixture.crop[0])+16,float(source[1])-float(fixture.crop[1])+16)
		assert(texture.get_image().get_pixelv(Vector2i(pixel)).a>0.9)
		var expected:Vector2=view.camera.unproject_position(image_point(plane,pixel/Vector2(texture.get_size())))
		var bearing:MeshInstance3D=module.node.find_child("RotationBearing",true,false)
		var base:Vector2=view.camera.unproject_position(bearing.to_global(bearing.get_aabb().get_center()))
		var pivot:Vector2=view.camera.unproject_position(module.pivot.global_position)
		var error:float=maxf(base.distance_to(expected),pivot.distance_to(expected))
		maximum=maxf(maximum,error)
		if error>0.05:failures+=1
		var row:Dictionary={"hull":KEYS[index],"slot":slot,"weapon":str(module.key),"state":state,
			"seat":expected,"bearing":base,"pivot":pivot,"bearing_error":base.distance_to(expected),"pivot_error":pivot.distance_to(expected)}
		results.append(row);measured.append(row)
		print("SEAT ",KEYS[index]," slot=",slot," state=",state," bearing=",row.bearing_error," pivot=",row.pivot_error)
	return measured

func text_label(value:String,position:Vector2)->void:
	var label:=Label.new();label.text=value;label.position=position;label.add_theme_font_size_override("font_size",24);root.add_child(label)

func run()->void:
	var output:=OS.get_environment("MOUNT_SEATING_DIR")
	var selected:=OS.get_environment("MOUNT_SEATING_ONLY")
	var graphical:bool=DisplayServer.get_name()!="headless" and not selected.is_empty()
	if graphical:
		assert(KEYS.has(selected) and not output.is_empty())
		root.content_scale_size=Vector2i(1800,800)
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.size=Vector2i(1800,800)
		var background:=ColorRect.new();background.color=Color("102b42");background.size=Vector2(1800,800);root.add_child(background)
		text_label(selected+" | green: image seat  cyan: bearing  magenta: rotation axis",Vector2(15,10))
		var overlays:Array=[]
		for column in 3:
			var state:String=["rest","fire-left","fire-right"][column]
			var view:=VIEW.new();view.size=Vector2(600,700);view.position=Vector2(column*600,75);root.add_child(view)
			configure(view,selected,KEYS.find(selected))
			var rows:Array=pose(view,KEYS.find(selected),state)
			text_label(["REST 0 deg","TURN -60 deg + fire feedback","TURN +60 deg + fire feedback"][column],Vector2(column*600+20,45))
			var overlay:=Markers.new();overlay.points=rows;overlay.position=view.position;overlay.size=view.size;overlay.visible=false;root.add_child(overlay);overlays.append(overlay)
		for frame in 8:await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		assert(root.get_texture().get_image().save_png(output.path_join(selected.to_lower()+"-rotation.png"))==OK)
		for overlay in overlays:overlay.visible=true;overlay.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(selected.to_lower()+"-marked.png"))==OK)
	else:
		var view:=VIEW.new();view.size=Vector2(600,700);root.add_child(view)
		for index in KEYS.size():
			configure(view,KEYS[index],index)
			for state in ["rest","left","right","fire-left","fire-right","release"]:pose(view,index,state)
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var result:=FileAccess.open(output.path_join((selected.to_lower() if graphical else "all")+"-seating.json"),FileAccess.WRITE)
		result.store_string(JSON.stringify({"rows":results,"samples":results.size(),"max_error":maximum,"failures":failures},"  "))
	print("SEATING_DONE samples=",results.size()," max_error=",maximum," failures=",failures)
	quit(1 if failures else 0)
