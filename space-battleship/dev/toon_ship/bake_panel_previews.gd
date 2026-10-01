extends SceneTree
const SHIP_VIEW = preload("res://scripts/presented_ship_view.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output := OS.get_environment("SHIP_PREVIEW_OUTPUT")
	var view = SHIP_VIEW.new()
	view.size=Vector2(768,768)
	root.add_child(view)
	var source = load("res://main.tscn").instantiate()
	var settings := {}
	for key in ["toon_shadow_threshold","toon_steps","rim_strength","rim_power","specular_strength","outline_strength","emission_strength","engine_emission","shield_opacity"]:
		settings[key]=source.get(key)
	source.free()
	var mapping := {"renderer":"res://scripts/presented_ship_view.gd","source_manifest":"res://dev/toon_ship/hybrid_manifest.json","canvas":[768,768],"settings":settings,"hulls":{}}
	for key in view.manifest.hulls:
		view.set_hull(key)
		view.apply_parameters(settings,true,true)
		# Source sockets and hull use the same live model transform and exact top-down camera.
		var low:Array=view.hull_config.godot_aabb_min
		var high:Array=view.hull_config.godot_aabb_max
		var span:float=maxf(float(high[0])-float(low[0]),view.model_span)
		var height:float=600.0*view.model_span/span
		view.set_pose(Vector2(384,384),height,0.0,Vector2(384,0),0.0,false,false)
		for plume in view.exhaust_nodes:plume.hide()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var texture_path:String="res://assets/ui/ships/"+key+".png"
		var error:int=view.viewport.get_texture().get_image().save_png(output+"/"+key+".png")
		assert(error==OK)
		var sockets:Array=[]
		for mount in view.hull_config.weapon_mounts:
			var node:Node3D=view.ship.find_child(str(mount.node),true,false)
			var p:Vector2=view.camera.unproject_position(node.global_position)
			sockets.append([p.x,p.y])
		mapping.hulls[key]={"texture":texture_path,"model":view.hull_config.path,"mounts":sockets,"height":height}
		print("Baked "+str(key))
	mapping.source_sha256={}
	var paths:Array=[mapping.renderer,mapping.source_manifest,"res://addons/flexible_toon_shader/flexible_toon.gdshader","res://scripts/battlefield.gd"]
	for hull in mapping.hulls.values():paths.append(hull.model)
	for path in paths:mapping.source_sha256[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(mapping,"  ")+"\n")
	quit()
