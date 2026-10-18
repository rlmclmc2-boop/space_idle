extends SceneTree

const VIEW := preload("res://scripts/presented_ship_view.gd")
const KEYS := ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]
const WEAPONS := ["cannon", "laser", "missile", "longLaser", "cannon"]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := OS.get_environment("HARDPOINT_CAPTURE_DIR")
	assert(not output.is_empty(), "Set HARDPOINT_CAPTURE_DIR")
	var selected := OS.get_environment("HARDPOINT_ONLY")
	assert(KEYS.has(selected), "Set HARDPOINT_ONLY to one player hull")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(800,800)
	var view := VIEW.new()
	view.size = Vector2(800,800)
	root.add_child(view)
	for index in KEYS.size():
		var key: String = KEYS[index]
		if key!=selected:continue
		assert(view.set_hull(key), key)
		var entries := []
		for slot in index+1:entries.append({"key":WEAPONS[slot]})
		assert(view.set_loadout(entries,index+1),key)
		view.set_pose(Vector2(400,400),550.0,0.0,Vector2(400,-100),0.0,false,false)
		assert(view.modules.size()==index+1,key)
		var plane: MeshInstance3D = view.approved_body_plane
		var texture: Texture2D = (plane.material_override as StandardMaterial3D).albedo_texture
		var image: Image = texture.get_image()
		var mesh_size: Vector2 = (plane.mesh as PlaneMesh).size
		for module in view.modules:
			var local: Vector3 = plane.to_local(module.node.global_position)
			var pixel := Vector2i((local.x/mesh_size.x+0.5)*image.get_width(),(local.z/mesh_size.y+0.5)*image.get_height())
			assert(pixel.x>=0 and pixel.x<image.get_width() and pixel.y>=0 and pixel.y<image.get_height(),key+" mount outside art")
			assert(image.get_pixelv(pixel).a>0.9,key+" mount on transparent art")
			var muzzle: Vector2 = view.screen_muzzle_for_slot(int(module.slot))
			assert(muzzle.distance_to(view.camera.unproject_position(module.muzzle.global_position))<0.01,key+" muzzle origin drift")
			assert(muzzle.x>0 and muzzle.x<800 and muzzle.y>0 and muzzle.y<800,key+" muzzle clipped")
			print("HARDPOINT ",key," slot=",module.slot," base=",view.camera.unproject_position(module.node.global_position)," muzzle=",muzzle)
		for frame in 30:await process_frame
		RenderingServer.force_draw()
		var path: String = output.path_join(key.to_lower()+"-full.png")
		assert(view.viewport.get_texture().get_image().save_png(path)==OK,path)
		print("CAPTURE ",path)
	if selected!="Heavy_Battleship":
		quit()
		return
	# The tall fifth hull must remain wholly visible at the battlefield's low anchor.
	view.set_pose(Vector2(400,755),550.0,0.0,Vector2(400,-100),0.0,false,false)
	var heavy: MeshInstance3D = view.approved_body_plane
	var heavy_size: Vector2 = (heavy.mesh as PlaneMesh).size
	var bounds: Rect2 = view.approved_body_bounds
	var texture_size: Vector2 = ((heavy.material_override as StandardMaterial3D).albedo_texture as Texture2D).get_size()
	for corner in [bounds.position,Vector2(bounds.end.x,bounds.position.y),Vector2(bounds.position.x,bounds.end.y),bounds.end]:
		var local := Vector3((corner.x/texture_size.x-0.5)*heavy_size.x,0,(corner.y/texture_size.y-0.5)*heavy_size.y)
		var screen: Vector2 = view.camera.unproject_position(heavy.to_global(local))
		assert(screen.y>=11 and screen.y<=749,"Heavy hull clipped at low anchor")
	print("HEAVY_LOW_ANCHOR visible=true")
	quit()
