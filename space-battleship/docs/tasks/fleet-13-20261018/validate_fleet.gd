extends SceneTree

func nearby_alpha(image:Image,point:Vector2i,radius:int)->float:
	var maximum:=0.0
	for y in range(maxi(0,point.y-radius),mini(image.get_height(),point.y+radius+1)):
		for x in range(maxi(0,point.x-radius),mini(image.get_width(),point.x+radius+1)):
			maximum=maxf(maximum,image.get_pixel(x,y).a)
	return maximum

func _initialize()->void:
	var visuals:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	var previews:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/ships/manifest.json"))
	var expected:=PackedStringArray(["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship","enemy_opening_scout","enemy_opening_sentry","enemy_opening_interceptor","enemy_opening_swarm","enemy_opening_anchor","enemy_opening_reactive","enemy_opening_shielded","enemy_opening_command"])
	var fail_count:=0
	for key in expected:
		var row:Dictionary=visuals.ships[key]
		var path:String=row.texture
		assert(path.begins_with("res://assets/ships/approved_fleet_20261018/"),key)
		var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
		assert(image!=null and image.get_size()==Vector2i(887,1774),key)
		var marks:Array=[]
		for point in row.hardpoints:
			var coordinate:=Vector2i(roundi((0.5+float(point.pos[0]))*image.get_width()),roundi((0.5+float(point.pos[1]))*image.get_height()))
			var alpha:=nearby_alpha(image,coordinate,20)
			marks.append("%.2f"%alpha)
			if alpha<0.1:fail_count+=1
		print("FLEET_HULL ",key," hardpoint_near_alpha=",marks)
	for key in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		var hull:Dictionary=previews.hulls[key]
		var image:=Image.load_from_file(ProjectSettings.globalize_path(str(hull.texture)))
		assert(image!=null and image.get_size()==Vector2i(768,768),key)
		var marks:Array=[]
		for mount in hull.mounts:
			var coordinate:=Vector2i(roundi(float(mount[0])),roundi(float(mount[1])))
			var alpha:=nearby_alpha(image,coordinate,24)
			marks.append("%.2f"%alpha)
			if alpha<0.1:fail_count+=1
		print("FLEET_UI ",key," mount_near_alpha=",marks)
	print("FLEET_VALIDATE_DONE assets=18 failed_mounts=",fail_count)
	quit()
