extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1000, 360)
	root.content_scale_size = Vector2i(1000, 360)
	var regular = load("res://assets/fonts/NotoSansSC-Regular.tres")
	var text_server := TextServerManager.get_primary_interface()
	var weight_tag := text_server.name_to_tag("wght")
	var thin := FontVariation.new()
	thin.base_font = regular.base_font
	thin.variation_opentype = {weight_tag: 100.0}
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	# Rows: old Thin appearance, shipped regular font, Windows development font.
	var fonts: Array[Font] = [thin, regular, system]
	print("AXES: ", regular.get_supported_variation_list())
	for i in range(fonts.size()):
		var label := Label.new()
		label.text = "太空战舰 资源总量 护卫舰 武器升级 1234567890"
		label.position = Vector2(20, 20 + 100 * i)
		label.add_theme_font_override("font", fonts[i])
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		root.add_child(label)
		print("VARIANT ", i, ": ", TextServerManager.get_primary_interface().font_get_variation_coordinates(fonts[i].get_rids()[0]))
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://.runtime/font-comparison.png")
	var energies: Array[float] = []
	for i in range(fonts.size()):
		var energy := 0.0
		var bright := 0
		for y in range(20 + 100 * i, mini(85 + 100 * i, picture.get_height())):
			for x in range(20, mini(950, picture.get_width())):
				var pixel := picture.get_pixel(x,y)
				energy += maxf(0.0, pixel.r - 0.025)
				if pixel.r > 0.7: bright += 1
		print("INK ", i, ": energy=", energy, " bright=", bright)
		energies.append(energy)
	var axes := text_server.font_get_variation_coordinates(regular.get_rids()[0])
	var passed: bool = axes.get(weight_tag) == 400.0 and energies[1] > energies[0] * 1.5
	print("RELEASE FONT: ", "PASS" if passed else "FAIL", " (actual weight=", axes.get(weight_tag), ", ink ratio=", energies[1]/maxf(energies[0],1.0), ")")
	quit(0 if passed else 1)
