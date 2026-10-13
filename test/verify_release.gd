extends Node

var failures: Array[String] = []
var native_admitted:=false
var native_sha256:=""
var native_path:=""
var default_native_auto:=false
var default_compiled:=false
var default_cache:=false
var default_save:=false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("verify")

func verify() -> void:
	var root := get_tree().root
	check(OS.has_feature("release") and not OS.has_feature("debug"), "Expected release template")
	check(not ProjectSettings.get_setting_with_override("debug/file_logging/enable_file_logging"), "File logging must be disabled")
	check(not FileAccess.file_exists("res://tools/import_workbook.py"), "Development tools leaked into pack")
	check(not FileAccess.file_exists("res://scripts/config_panel.gd"), "QA tool leaked into pack")
	check(not FileAccess.file_exists("res://export_presets.cfg"), "Build paths leaked into pack")
	check(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "Missing bundled font license")
	check(FileAccess.file_exists("res://data/ui_text.json") and FileAccess.file_exists("res://data/ui_text_contract.json"), "Missing embedded UI text catalog")
	check(UIText.reload_catalog().is_empty(), "Embedded UI text contract invalid")
	check(UIText.t("battle.hp",{"current_hp":850,"max_hp":1000}).contains("850"), "Embedded UI text interpolation failed")
	var scene = load("res://main.tscn")
	if scene == null:
		failures.append("Cannot load embedded main scene")
		finish()
		return
	var main = scene.instantiate()
	root.add_child(main)
	get_tree().current_scene = main
	check(ClassDB.class_exists("SpaceCombatKernel"),"Native kernel class missing from release")
	default_native_auto=main.game.native_execution_auto;default_compiled=main.game.compiled_combat_rules!=null
	default_cache=main.game.stat_cache_enabled;default_save=main.game.save_enabled
	check(default_native_auto and default_compiled,"Normal entry must enable native and compiled rules")
	check(default_cache and default_save,"Normal entry must enable statistics cache and persistence")
	for relative in ["space_native.dll","bin/space_native.dll"]:
		var path=OS.get_executable_path().get_base_dir().path_join(relative)
		if FileAccess.file_exists(path):native_path=path;native_sha256=FileAccess.get_sha256(path)
	for frame in range(90):
		await get_tree().process_frame
		if main.game.native_execution!=null:native_admitted=main.game.native_execution.kernel.get_class()=="SpaceCombatKernel"
	if not native_admitted:
		# Check a legal supported loadout through ordinary equip/start APIs; the
		# fresh starter may have an empty module and legitimately select legacy.
		for key in ["armour","shield"]:
			if not main.game.profile.unlocked.has(key):main.game.profile.unlocked.append(key)
		for index in main.game.defense_entries().size():
			main.game.equip_slot("defence",index,"armour" if index==0 else "shield")
		main.game.start(1,false)
		for step in range(300):
			main.game.tick(1.0/60.0)
			if main.game.native_execution!=null:
				native_admitted=main.game.native_execution.kernel.get_class()=="SpaceCombatKernel"
				break
	check(native_admitted,"Normal release game did not admit actual native kernel")
	check(native_sha256.length()==64,"Missing release DLL hash proof")
	check(main.db.levels.size() > 0 and main.db.equipment.size() > 0, "Missing embedded game data")
	check(main.font is FontVariation and main.font.base_font is FontFile, "Release must use embedded font")
	var text_server := TextServerManager.get_primary_interface()
	var weight_tag := text_server.name_to_tag("wght")
	var rendered_axes := text_server.font_get_variation_coordinates(main.font.get_rids()[0])
	check(rendered_axes.get(weight_tag) == 400.0, "Rendered release font must use regular weight, not the Thin default")
	check(not main.font.base_font.allow_system_fallback, "Embedded font must not depend on installed fonts")
	check(main.ui.theme.default_font == main.font, "UI controls must inherit the embedded font")
	check(main.font.has_char("舰".unicode_at(0)), "Missing Chinese glyph")
	check(main.font.has_char("◈".unicode_at(0)), "Missing title symbol")
	check(main.font.fallbacks.size() == 1 and not main.font.fallbacks[0].allow_system_fallback, "Symbol fallback must be embedded")
	check(FileAccess.file_exists("res://assets/fonts/NotoSansSymbols2-OFL.txt"), "Missing symbol font license")
	check(main.automation_args.is_empty(), "Development capture arguments remain enabled")
	main.show_qa_tools()
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	main._unhandled_input(key)
	check(root.get_node_or_null("QATools") == null, "QA enabled in release")
	check(main.game.speed == 1, "Release picked up QA speed")
	check(main.audio != null, "Audio player missing")
	main.sound_on = true
	main.beep(440.0)
	check(main.audio.stream is AudioStreamWAV and main.audio.stream.data.size() == 1100, "Procedural audio unavailable")
	main.sound_on = false
	check(main.visual_config.get("ships",{}).size() == 11 and main.visual_config.get("weapons",{}).size() == 4, "Missing bundled visual profiles")
	for id in main.db.data.get("jewel", {}):
		var path = str(main.db.jewel(str(id)).get("image", "res://assets/jewels/%s.svg" % id))
		check(ResourceLoader.exists(path) and load(path) is Texture2D, "Missing jewel texture: " + path)
	main.game.save_progress()
	check(FileAccess.file_exists("user://progress.json"), "Save not written to user directory")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	check(saved is Dictionary and not saved.is_empty(), "Invalid save")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("user://release-screen.png") == OK, "Screenshot failed")
	finish()

func finish() -> void:
	var report := {"passed": failures.is_empty(), "failures": failures,
		"executable": OS.get_executable_path(), "user_data": OS.get_user_data_dir(),
		"renderer": RenderingServer.get_video_adapter_name(),"native_admitted":native_admitted,"native_sha256":native_sha256,"native_path":native_path,"default_native_auto":default_native_auto,"default_compiled":default_compiled,"default_cache":default_cache,"default_save":default_save}
	var file := FileAccess.open("user://release-verification.json", FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit(0 if failures.is_empty() else 1)
