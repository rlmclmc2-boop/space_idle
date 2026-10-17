extends SceneTree

func _initialize() -> void:
	var output := OS.get_environment("AI_TECH_PREVIEW_DIR")
	if output.is_empty():
		quit(1)
		return
	for name in ["00-choose-research", "02-uranium-shortage"]:
		var path := output.path_join(name)
		var image := Image.new()
		if image.load(path + ".png") != OK or image.save_jpg(path + ".jpg", 0.75) != OK:
			quit(1)
			return
		print("PREVIEW ", name, " ", image.get_width(), "x", image.get_height())
	quit(0)
