extends SceneTree
## Convert accepted raw Godot captures to lightweight review copies.

func _initialize() -> void:
	var folder := "res://docs/tasks/ai-tech-art-20261017/evidence/"
	for name in ["main-active", "drawer"]:
		var image := Image.load_from_file(folder + name + ".png")
		assert(image.get_size() == Vector2i(1344, 1160))
		var destination := ProjectSettings.globalize_path(folder + name + "-preview.jpg")
		for quality in [0.78, 0.7, 0.62, 0.54, 0.46]:
			var error := image.save_jpg(destination, quality)
			assert(error == OK)
			if FileAccess.get_file_as_bytes(destination).size() < 180000:
				break
		assert(FileAccess.get_file_as_bytes(destination).size() < 180000)
		var sidecar := FileAccess.open(ProjectSettings.globalize_path(folder + name + "-preview.base64.txt"), FileAccess.WRITE)
		sidecar.store_string("data:image/jpeg;base64," + Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(destination)))
		sidecar.close()
	quit()
