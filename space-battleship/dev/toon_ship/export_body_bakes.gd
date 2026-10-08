extends SceneTree
## Offline art export only. Does not instantiate the game or read/write saves.
const OUTPUT := "res://assets/ships/body_bakes/"
const SETTINGS := {"toon_steps":3,"toon_shadow_threshold":0.60,"rim_strength":0.22,
	"rim_power":4.5,"specular_strength":0.04,"emission_strength":1.0,
	"engine_emission":1.4,"shield_opacity":0.12}
var catalog: Dictionary = {}
var view

func _initialize() -> void:
	call_deferred("export_assets")

func export_assets() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	view = load("res://scripts/presented_ship_view.gd").new()
	view.size = Vector2(572,960)
	view.body_baker.export_mode = true
	root.add_child(view)
	view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for hull in view.manifest.hulls:
		view.set_hull(str(hull))
		view.apply_parameters(SETTINGS,true,true)
		await save_body(view.ship,"hull:"+str(hull))
	var carrier: Node3D = load(str(view.manifest.drone.path)).instantiate()
	view.world.add_child(carrier)
	view._install_materials(carrier,"carrier")
	view.body_baker.attach(carrier,"carrier")
	view.apply_parameters(SETTINGS,true,true)
	await save_body(carrier,"carrier")
	carrier.free()
	var appearance = load("res://scripts/hyperspace_appearance.gd")
	var visual = load("res://scripts/hyperspace_drone_visual.gd").new()
	for weapon in ["laser","missile","cannon","longLaser"]:
		for quality in ["white","blue","gold","legendary"]:
			var model: Node3D = appearance.scene(weapon).instantiate()
			view.world.add_child(model)
			var style: Dictionary = appearance.project({"weapon":weapon,"origin_quality":quality})
			visual.install_materials(model,style)
			view.body_baker.attach(model,"drone:"+weapon+":"+quality)
			await save_body(model,"drone:"+weapon+":"+quality)
			model.free()
	visual.free()
	var output := FileAccess.open(OUTPUT+"catalog.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(catalog,"\t")+"\n")
	print("BODY ART EXPORT COMPLETE: ",catalog.size()," assets")
	quit()

func save_body(model: Node3D, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	# Baker publishes the texture on frame_post_draw; resume on the next frame.
	await process_frame
	var baker = view.body_baker
	var record: Dictionary = baker.records[model.get_instance_id()]
	var entry: Dictionary = baker.textures[record.key]
	var texture: Texture2D = entry.material.get_shader_parameter("body_texture")
	var signature: String = baker.appearance_signature(record.parts)
	if signature == "unsupported":
		push_error("No stable appearance identity for "+label)
		quit(1)
		return
	var path := OUTPUT+signature+".png"
	var error := texture.get_image().save_png(path)
	if error != OK:
		push_error("Asset export failed: "+label)
		quit(1)
		return
	var center: Vector3 = entry.center
	catalog[signature] = {"path":path,"center":[center.x,center.y,center.z],"span":entry.span,"source":label}
	print("EXPORTED ",label," -> ",signature)
