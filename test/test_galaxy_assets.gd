extends SceneTree
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	var map=preload("res://scripts/galaxy_map.gd").new()
	root.add_child(map)
	var paths := {}
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/galaxy/v3/manifest.json"))
	for record in manifest.assets:
		if record.key in db.data.galaxy_build:
			check(maxf(float(record.bounds_godot_xyz[0]),float(record.bounds_godot_xyz[2]))*map.BUILDING_SCALE<=14.0,"Model including runtime scale fits reserved footprint")
			check(int(record.triangles)<25000,"Bounded functional model geometry")
	for definition in db.data.galaxy_build.values():
		var family_paths := {}
		for level in range(1,6):
			var path: String=definition['asset_lv%d'%level]
			check(path.ends_with('.glb') and ResourceLoader.exists('res://'+path,'PackedScene'),'Runtime GLB imports')
			var node: Node3D=map.asset(path)
			check(node.find_child('DockSocket',true,false)!=null,'Dock socket exists')
			var body: MeshInstance3D=node.find_child('Structure',true,false)
			check(body!=null,'Merged static structure exists')
			for surface in body.mesh.get_surface_count():
				var mat: Material=body.get_active_material(surface)
				if mat.resource_name.begins_with('GalaxyToon'):check(mat is StandardMaterial3D and mat.vertex_color_use_as_albedo,'Building baked tint is preserved')
			node.free()
			family_paths[path]=true
		check(family_paths.size()==5,'Each family has five distinct models')
	check(db.data.galaxy_build.size()==6,'Six functional building families')
	var core: Node3D=map.asset(db.data.galaxy.galaxy_1.core_asset)
	check(core.find_child('Structure',true,false)!=null,'Independent core imported')
	var structure: MeshInstance3D=core.find_child('Structure',true,false)
	var checked_core_color := false
	for index in structure.mesh.get_surface_count():
		var mat: Material=structure.get_active_material(index)
		if mat.resource_name=='CoreDark':
			checked_core_color=true
			check(mat is StandardMaterial3D and mat.vertex_color_use_as_albedo,'Core hull retains baked tint instead of white fallback')
	check(checked_core_color,'Detailed core hull material imported')
	check(core.find_child('DockSocket',true,false)!=null,'Detailed core hangar dock survives export')
	core.free()
	var fallback: Node3D=map.asset('assets/galaxy/v3/missing.glb')
	check(fallback.get_child_count()>0,'Missing model has safe 3D fallback')
	fallback.free()
	print('GALAXY GLB failures=',failures)
	quit(1 if failures else 0)
