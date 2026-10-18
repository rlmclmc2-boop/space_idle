extends SceneTree

const VIEW := preload("res://scripts/presented_ship_view.gd")
const KEYS := ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
const SAFE := Rect2(Vector2(12,12),Vector2(572,960)-Vector2(24,40))

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var view := VIEW.new()
	view.size=Vector2(572,960)
	root.add_child(view)
	var rows:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json")).ships
	for key in KEYS:
		assert(view.set_hull(key),key)
		var plane:MeshInstance3D=view.approved_body_plane
		assert(plane!=null,key)
		var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
		var pixels:=texture.get_image().get_used_rect()
		var height:=float(pixels.size.y)*0.65*float(rows[key].display_scale)*float(ProjectSettings.get_setting("visuals/player_ship_scale",1.25))
		height*=0.74 if key=="Heavy_Battleship" else 0.85 if key=="Battleship" else 1.0
		# Exercise a near-bottom live anchor; visual fit cannot move the ship root.
		view.set_pose(Vector2(286,920),height,0.0,Vector2(286,100),0.0,false,false)
		var root_transform:Transform3D=view.ship.transform
		var socket:Vector3=view.weapon_mount.global_position
		view.apply_geometry_frame({"hull":key,"elapsed":0.0,"rendered_height":height,
			"rendered_position":Vector2(286,920),"orbit_center":view.orbit_center,
			"orbit_elapsed":view.orbit_elapsed,"ship":root_transform,
			"carriers":[],"pivots":[]},false)
		var image_size:Vector2=texture.get_size()
		var mesh_size:Vector2=(plane.mesh as PlaneMesh).size
		var projected:=Rect2()
		var first:=true
		for xy in [Vector2(pixels.position),Vector2(pixels.end.x,pixels.position.y),Vector2(pixels.end),Vector2(pixels.position.x,pixels.end.y)]:
			var local:=Vector3((xy.x/image_size.x-0.5)*mesh_size.x,0,(xy.y/image_size.y-0.5)*mesh_size.y)
			var screen:Vector2=view.camera.unproject_position(plane.to_global(local))
			projected=Rect2(screen,Vector2.ZERO) if first else projected.expand(screen)
			first=false
		assert(projected.position.x>=SAFE.position.x-1.0 and projected.position.y>=SAFE.position.y-1.0,key)
		assert(projected.end.x<=SAFE.end.x+1.0 and projected.end.y<=SAFE.end.y+1.0,key)
		assert(root_transform==view.ship.transform and socket==view.weapon_mount.global_position,key+": socket moved")
		if key=="Cruiser":assert(plane.scale.x>1.0,"Wide Cruiser was not legible")
		print("VISUAL_FIT ",key," rect=",projected," plane_scale=",plane.scale.x," socket_unchanged=true")
	# Retained display body scaling keeps the mouth position at the original port.
	for width in [40.0,70.0,110.0]:
		for class_scale in [0.7,0.9,1.1]:
			var module_width:float=width*0.42*class_scale
			var body_width:float=maxf(1.0,module_width*0.45)
			for face in [0.64,0.45]:
				var port:=Vector2(0.22,0)*module_width
				var shift:=port-Vector2(face*body_width,0)
				assert((shift+Vector2(face*body_width,0)).distance_to(port)<0.0001)
	print("VISUAL_FIT_DONE hulls=5 muzzle_anchor=unchanged")
	quit()
