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
	scene.game.profile.resources = {"1":1000000.0,"2":1000000.0}
	scene.build_ui()
	scene.equipment_tabs.current_tab = 0
	await process_frame
	var panel: Control = scene.equipment_panel
	check(scene.number(4300.0)=="4.3K" and scene.number(10249.0)=="10K", "Equipment display keeps number formatting")
	check(scene.equipment_tabs.get_tab_title(0)==UIText.t("equipment.tab"), "Unified equipment page stays first")
	check(panel.cards.has("weapons_0") and panel.cards.has("defence_0"), "Weapon and defence slots share the overview")
	check(panel.grid.columns==2 and panel.grid_scroll.size.y>900, "Overview uses two columns and full page height")
	check(panel.detail_frame.visible and panel.detail_scroll.size.y>900, "Inspector stays visible beside overview")
	var category_box: OptionButton = panel.filters.get_child(0)
	category_box.select(1)
	category_box.item_selected.emit(1)
	check(panel.cards.weapons_0.visible and not panel.cards.defence_0.visible, "Weapon filter hides defence")
	category_box.select(2)
	category_box.item_selected.emit(2)
	check(panel.cards.defence_0.visible and not panel.cards.weapons_0.visible, "Defence filter hides weapons")
	category_box.select(0)
	category_box.item_selected.emit(0)
	panel.select_item("defence_0")
	check(panel.selected=="defence_0" and panel.detail.title.text==panel.items.defence_0.name, "Defence selection updates inspector")
	var before := int(scene.game.slot_entry("defence",0).level)
	panel.detail.upgrade.pressed.emit()
	check(int(scene.game.slot_entry("defence",0).level)==before+1, "Inspector upgrade still changes selected module")
	check(panel.cards.defence_0.fields.level.text==UIText.t("equipment.level",{"level":str(before+1)}), "Changed card refreshes after upgrade")
	check(scene.equipment_tabs.current_tab==0 and scene.battle_layer.visible, "Equipment action keeps page and battlefield")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(1440,900), "Main window renders at 1440 by 900")
	image.save_png("res://.runtime/equipment-management.png")
	print("Equipment tabs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
