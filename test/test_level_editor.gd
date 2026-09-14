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

func run() -> void:
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
