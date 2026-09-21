extends "test_module_ui.gd"
func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=[10]
	scene.build_ui()
	scene.equipment_tabs.current_tab=3
	await process_frame
	var panel: Control=scene.ship_controls.page
	var card: Node=scene.equipment_panel.cards.weapons_0
	var mounts: Dictionary=panel.mounts.duplicate()
	var before: Dictionary=scene.game.profile.duplicate(true)
	for key in panel.choices:
		if scene.game.ship_unlocked(key):continue
		await click(panel.choices[key])
		check(panel.choices[key].text.is_empty() and panel.locked_previews[key].visible,"Locked choice exposes no name or capacity")
		check(panel.locked_labels[key].text==panel.unlock_hint(key),"Locked list shows configured unlock stage")
		check(panel.picture.material==panel.silhouette and panel.heading.text==panel.unlock_hint(key),"Candidate only has silhouette and unlock stage")
		check(not panel.result.visible and not panel.confirm.visible and panel.information.all(func(c):return not c.visible),"No summary actions or explanations leak")
		check(panel.mounts.values().all(func(c):return not c.visible),"No existing mount data leaks into locked preview")
	check(scene.game.profile==before and scene.equipment_panel.cards.weapons_0==card,"Preview is read-only and preserves unrelated card")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://locked-ship.png")
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty(),"Unchanged locked preview has no property writes")
	await click(panel.choices.Frigate)
	check(panel.picture.material==null and panel.confirm.visible and panel.result.visible,"Returning to unlocked hull restores full display")
	for id in mounts:check(panel.mounts[id]==mounts[id],"Existing mounts reused: "+id)
	await click(panel.choices.Heavy_Battleship)
	scene.game.profile.cleared.append(int(scene.db.ship("Heavy_Battleship").unlock))
	panel.refresh()
	check(panel.picture.material==null and panel.confirm.visible and not panel.confirm.disabled,"Unlocking selected hull reveals existing controls")
	check(not panel.locked_previews.Heavy_Battleship.visible and not panel.choices.Heavy_Battleship.text.is_empty(),"Unlocked list restores ship information")
	print("Locked ships: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
