extends SceneTree
const VIEW := preload("res://scripts/presented_ship_view.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output := OS.get_environment("SINGLE_SLOT_VISUAL_OUTPUT")
	assert(not output.is_empty())
	var view = VIEW.new()
	view.size=Vector2(768,768)
	root.add_child(view)
	var source = load("res://main.tscn").instantiate()
	var settings := {}
	for key in ["toon_shadow_threshold","toon_steps","rim_strength","rim_power","specular_strength","outline_strength","emission_strength","engine_emission","shield_opacity"]:
		settings[key]=source.get(key)
	source.free()
	var db := ShipDatabase.new()
	for key in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		var count := int(db.ship(key).weaponSlots)
		view.set_hull(key)
		var entries := []
		for index in count:entries.append({"key":"laser","level":1})
		assert(view.set_loadout(entries,count))
		assert(view.modules.size()==count and view.carriers.is_empty())
		view.apply_parameters(settings,true,true)
		var low:Array=view.hull_config.godot_aabb_min
		var high:Array=view.hull_config.godot_aabb_max
		var span:float=maxf(float(high[0])-float(low[0]),view.model_span)
		var height:float=600.0*view.model_span/span
		view.set_pose(Vector2(384,384),height,0.0,Vector2(384,0),0.0,false,false)
		for plume in view.exhaust_nodes:plume.hide()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var status:int=view.viewport.get_texture().get_image().save_png(output+"/"+key+".png")
		assert(status==OK)
		print("VISUAL ",key," weapons=",view.modules.size()," physical=",view.hull_config.weapon_mounts.size()," carriers=",view.carriers.size())
	quit()
