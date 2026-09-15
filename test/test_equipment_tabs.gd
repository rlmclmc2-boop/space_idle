extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.build_ui()
	check(scene.number(4300.0)=="4.3K" and scene.number(10249.0)=="10K" and scene.number(105739.0)=="100K", "Equipment display uses KMBT formatting")
	check(scene.equipment_tabs.get_tab_title(0)=="武器","Weapons first")
	check(scene.upgrade_buttons.size()==2,"Starting unlocked equipment retained")
	check(not scene.upgrade_buttons.armour.is_visible_in_tree(),"Defence hidden on weapons page")
	scene.equipment_tabs.current_tab = 1
	check(scene.upgrade_buttons.armour.is_visible_in_tree(),"Defence switch exposes armour")
	scene.game.profile.resources["1"] = 1000000
	scene.game.profile.resources["2"] = 1000000
	var level := int(scene.game.first_equipment_entry("armour").level)
	scene.build_ui()
	scene.upgrade_buttons.armour.pressed.emit()
	check(scene.game.first_equipment_entry("armour").level==level+1,"Upgrade still works")
	check(scene.equipment_tabs.current_tab==1,"Upgrade preserves selected page")
	scene.game.profile.unlocked = ["armour","shield","laser","cannon","missile"]
	scene.build_ui()
	check(scene.upgrade_buttons.size()==2,"Only installed equipment retains upgrade cards")
	scene.equipment_tabs.current_tab = 0
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-weapons.png")
	scene.equipment_tabs.current_tab = 1
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tabs-defence.png")
	check(scene.equipment_tabs.get_rect().end.y<=778,"Tabs stay above footer")
	check(scene.game.equip_slot("weapons",1,"cannon"),"Empty weapon slot installs cannon")
	check(scene.game.equip_slot("weapons",2,"missile"),"Empty weapon slot installs missile")
	check(scene.game.equip_slot("defence",1,"shield"),"Empty defence slot installs shield")
	scene.build_ui()
	for page_index in [0,1]:
		scene.equipment_tabs.current_tab = page_index
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tabs-filled-%d.png" % page_index)
		var cards = scene.equipment_tabs.get_child(page_index).get_child(0)
		for card in cards.get_children():
			var items: Array[Control] = []
			for child in card.get_children():
				if child is Control and child.visible:
					check(Rect2(Vector2.ZERO,card.size).encloses(child.get_rect()),"Card content stays inside its bounds: %s %s" % [child.get_class(),child.get_rect()])
					items.append(child)
			for a in range(items.size()):
				for b in range(a+1,items.size()):
					check(not items[a].get_rect().intersects(items[b].get_rect()),"Card rows and actions do not overlap")
	print("Equipment tabs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
