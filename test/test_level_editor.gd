extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print(('PASS ' if value else 'FAIL ') + label)
	if not value: failures += 1

func wait_idle(editor: Control) -> void:
	for i in range(1200):
		await process_frame
		if editor.worker == null: return
	check(false, "worker timeout")

func _initialize() -> void:
	call_deferred("run")

func check_python_resolution() -> void:
	var previous_python := OS.get_environment("SPACE_BATTLESHIP_PYTHON")
	var previous_home := OS.get_environment("USERPROFILE")
	var home := ProjectSettings.globalize_path("res://.runtime/python-resolver")
	var bundled := home.path_join(".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe")
	DirAccess.make_dir_recursive_absolute(bundled.get_base_dir())
	var file := FileAccess.open(bundled,FileAccess.WRITE)
	file.close()
	var configured := home.path_join("configured python.exe")
	file = FileAccess.open(configured,FileAccess.WRITE)
	file.close()
	OS.set_environment("USERPROFILE",home)
	var resolver = load("res://scripts/config_panel.gd").new()
	OS.set_environment("SPACE_BATTLESHIP_PYTHON",configured)
	check(resolver.find_python()==configured,"Python environment override precedes bundled path")
	OS.set_environment("SPACE_BATTLESHIP_PYTHON",home.path_join("missing.exe"))
	check(resolver.find_python()==bundled,"Missing override falls back to bundled Python")
	OS.set_environment("SPACE_BATTLESHIP_PYTHON","")
	check(resolver.find_python()==bundled,"Empty override uses bundled Python")
	OS.set_environment("USERPROFILE",home.path_join("missing-home"))
	check(resolver.find_python()=="python","Missing bundled Python falls back to PATH")
	resolver.free()
	OS.set_environment("SPACE_BATTLESHIP_PYTHON",previous_python)
	OS.set_environment("USERPROFILE",previous_home)

func run() -> void:
	check_python_resolution()
	var editor = load("res://level_editor.tscn").instantiate()
	root.add_child(editor)
	await wait_idle(editor)
	check(editor.document.has("tables"), "load three source tables")
	if not editor.document.has("tables"):
		print(editor.status.text)
		quit(1)
		return
	var original_count: int = editor.rows().size()
	editor.add_record(true)
	check(editor.rows().size() == original_count + 1, "duplicate enemy")
	editor.fields.des.text = "UI测试飞行器"
	editor.fields.health.text = "432"
	editor.stash()
	check(editor.rows()[-1].health == 432, "edit numeric field")
	editor.search.text = "UI测试飞行器"
	editor.refresh_list()
	check(editor.listing.item_count == 1, "search record")
	editor.tabs.current_tab = 1
	await process_frame
	check(editor.slots.size() == 10, "ten formation selectors")
	check(not editor.slots[4].get_item_text(editor.slots[4].selected).begins_with("无效"), "integer ID selector resolves")
	editor.slots[4].select(2)
	editor.stash()
	check(editor.rows()[0].mon.contains(",2,"), "change formation enemy")
	editor.show_record(0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://../formation-editor.png")
	editor.tabs.current_tab = 2
	await process_frame
	check(editor.encounters.size() > 0, "encounter rows")
	editor.fields.atkRatio.text = "2"
	editor.run_action("validate")
	await wait_idle(editor)
	print(editor.status.text)
	check(editor.status.text.begins_with("校验通过"), "validate source draft")
	editor.run_action("save")
	await wait_idle(editor)
	print(editor.status.text)
	check(editor.status.text.begins_with("已保存"), "save and import from real UI")
	check(not editor.dirty, "saved draft clean")
	await process_frame
	root.get_texture().get_image().save_png("res://../level-editor.png")
	editor.run_action("load")
	await wait_idle(editor)
	check(editor.document.tables.mon.rows.size() == original_count + 1, "reload persisted new enemy")
	editor.tabs.current_tab = 0
	await process_frame
	editor.show_record(editor.rows().size()-1)
	editor.delete_record()
	editor.confirmation.confirmed.emit()
	check(editor.rows().size() == original_count, "delete unreferenced enemy")
	editor.show_record(0)
	editor.delete_record()
	check(editor.status.text.begins_with("无法删除"), "prevent referenced enemy deletion")
	editor.free()
	quit(1 if failures else 0)
