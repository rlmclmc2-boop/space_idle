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
	for definition in db.data.galaxy_build.values():
		for level in range(1,6):
			var path: String=definition['asset_lv%d'%level]
			check(path.ends_with('.glb') and ResourceLoader.exists('res://'+path,'PackedScene'),'Runtime GLB imports')
			var node: Node3D=map.asset(path)
			check(node.find_child('DockSocket',true,false)!=null,'Dock socket exists')
			node.free()
			if definition.key=='colony_ring':paths[path]=true
	check(paths.size()==5,'Representative family has five distinct models')
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
