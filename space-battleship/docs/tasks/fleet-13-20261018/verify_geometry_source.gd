extends SceneTree

const RECOGNITION = preload("res://scripts/enemy_recognition_visual.gd")
const KEYS = ["scout", "sentry", "interceptor", "swarm", "anchor", "reactive", "shielded", "command"]

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var baseline := OS.get_environment("FLEET_MAIN51_GAME")
	assert(not baseline.is_empty() and DirAccess.dir_exists_absolute(baseline))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join("data/ship_weapon_visuals.json")))
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	# Exercise Main._ready's actual image-center rebase, not only JSON authoring.
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene);scene.set_process(false)
	assert(not scene.game.save_enabled)
	var recognition = RECOGNITION.new()
	for suffix in KEYS:
		var key: String = "enemy_opening_" + suffix
		var original: Dictionary = previous.ships[key]
		var candidate: Dictionary = current.ships[key]
		assert(str(candidate.geometry_texture) == str(original.texture), key + " source")
		assert(candidate.slot_map == original.slot_map and candidate.hardpoints == original.hardpoints, key + " mounts")
		assert(str(candidate.texture) != str(candidate.geometry_texture), key + " display split")
		var source_bytes := FileAccess.get_file_as_bytes(baseline.path_join(str(original.texture).trim_prefix("res://")))
		var geometry_bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(str(candidate.geometry_texture)))
		assert(source_bytes == geometry_bytes, key + " source pixels")
		var old_texture=load(str(original.texture)) as Texture2D
		var center=preload("res://scripts/enemy_protection_geometry.gd").image_center(old_texture.get_image())
		var old_offset:Vector2=(center-old_texture.get_size()*0.5)/old_texture.get_size()
		original=original.duplicate(true)
		for point in original.hardpoints:
			point.pos=[float(point.pos[0])-old_offset.x,float(point.pos[1])-old_offset.y]
		candidate=scene.visual_config.ships[key]
		assert(candidate.hardpoints==original.hardpoints,key+" runtime rebased mounts")
		var display_texture=scene.ship_hull_texture(key)
		var display_center=preload("res://scripts/enemy_protection_geometry.gd").image_center(display_texture.get_image())
		assert(candidate.origin_offset==(display_center-display_texture.get_size()*0.5)/display_texture.get_size(),key+" display center")
		var old_profile: PackedVector2Array = recognition.hull_profile(load(str(original.texture)) as Texture2D)
		var new_profile: PackedVector2Array = recognition.hull_profile(load(str(candidate.geometry_texture)) as Texture2D)
		assert(old_profile == new_profile, key + " alpha boundary")
		var checked := 0
		for width in [24.0, 48.0, 80.0]:
			for shape in ["legacy", "physical", "energy"]:
				var mounts: Array = []
				for index in candidate.hardpoints.size():
					var point: Dictionary = candidate.hardpoints[index]
					var old_point: Dictionary = original.hardpoints[index]
					var cls := float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.visual_size_class),0.7))
					var mount := {"pos":Vector2(float(point.pos[0]),float(point.pos[1])*2.0),"class_scale":cls,"base":-PI/2+deg_to_rad(float(point.base_rotation)),"limit":deg_to_rad(float(point.rotation_limit)),"muzzle":Vector2(0.22,0),"shape":shape,"mode":str(point.mode)}
					mounts.append(mount)
					var baseline_port: Vector2 = Vector2(float(old_point.pos[0]),float(old_point.pos[1])*2.0)*width+Vector2(0.22,0)*width*0.42*float({"small":0.7,"medium":0.9,"large":1.1}.get(str(old_point.visual_size_class),0.7))
					var candidate_port: Vector2 = Vector2(mount.pos)*width+Vector2(mount.muzzle)*width*0.42*cls
					assert(baseline_port == candidate_port, key + " muzzle")
				var old_packet: Dictionary = recognition.geometry_from_profile(1,old_profile,width,mounts,false,{},1.0,width>=80.0)
				var new_packet: Dictionary = recognition.geometry_from_profile(2,new_profile,width,mounts,false,{},1.0,width>=80.0)
				for field in ["inner", "outer", "front", "single_front", "audit_points"]:
					assert(old_packet[field] == new_packet[field], key + " " + field)
				checked += 1
		print("GEOMETRY_MATCH ", key, " profile_points=", old_profile.size(), " mounts=", candidate.hardpoints.size(), " width_shape_cases=", checked)
	for key in ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]:
		var original: Dictionary = previous.ships[key]
		var candidate: Dictionary = current.ships[key]
		assert(str(candidate.geometry_texture) == str(original.texture), key + " source")
		assert(candidate.slot_map == original.slot_map and candidate.hardpoints == original.hardpoints, key + " mounts")
		var source_bytes := FileAccess.get_file_as_bytes(baseline.path_join(str(original.texture).trim_prefix("res://")))
		var geometry_bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(str(candidate.geometry_texture)))
		assert(source_bytes == geometry_bytes, key + " source pixels")
		var image := (load(str(candidate.geometry_texture)) as Texture2D).get_image()
		print("PLAYER_GEOMETRY_MATCH ", key, " opaque_rect=", image.get_used_rect(), " mounts=", candidate.hardpoints.size())
	print("GEOMETRY_SOURCE_DONE enemy_keys=8 player_keys=5")
	scene.queue_free()
	await process_frame
	quit()
