extends SceneTree

func _initialize()->void:
	var source:=OS.get_environment("FLEET_SOURCE_DIR")
	assert(not source.is_empty())
	var names:=DirAccess.get_files_at(source)
	names.sort()
	assert(names.size()==13)
	for name in names:
		assert(name.ends_with(".png"))
		var image:=Image.load_from_file(source.path_join(name))
		assert(image!=null and image.get_width()>0 and image.get_height()>0)
		var bounds:=image.get_used_rect()
		assert(bounds.has_area())
		var lo:=Vector2i(image.get_width(),image.get_height())
		var hi:=Vector2i(-1,-1)
		var solid:=0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a<0.05:continue
				lo.x=mini(lo.x,x);lo.y=mini(lo.y,y)
				hi.x=maxi(hi.x,x);hi.y=maxi(hi.y,y)
				solid+=1
		var body:=Rect2i(lo,hi-lo+Vector2i.ONE)
		assert(body.has_area())
		var corners:=PackedFloat32Array([
			image.get_pixel(0,0).a,image.get_pixel(image.get_width()-1,0).a,
			image.get_pixel(0,image.get_height()-1).a,
			image.get_pixel(image.get_width()-1,image.get_height()-1).a,
		])
		print("FLEET_SOURCE ",name," dimensions=",image.get_size()," bounds=",bounds," body_05=",body," solid=",solid," corners=",corners)
	print("FLEET_SOURCE_DONE ",names.size())
	quit()
