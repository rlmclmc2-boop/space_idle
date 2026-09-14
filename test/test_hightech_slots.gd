extends SceneTree

var checks := 0
var failures := 0
var scene
var view: SubViewport
var last_mouse := Vector2.ZERO

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func frames() -> void:
	await process_frame
	await process_frame

func move_mouse(pos: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos-last_mouse
	last_mouse = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	view.push_input(event,true)
	await frames()

func click_mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	view.push_input(event,true)
	await frames()

func card(index: int) -> Control:
	return scene.hightech_scroll.get_child(0).get_child(index)

func title_position(index: int) -> Vector2:
	return card(index).global_position+Vector2(190,16)

func begin_drag(index: int) -> void:
	var position := title_position(index)
	await move_mouse(position)
	await click_mouse(position,true)
	await move_mouse(position+Vector2(25,0),true)
	check(view.gui_is_dragging(), "Native card drag begins from header")

func capture(name: String) -> void:
	scene.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://"+name+".png")

func run() -> void:
	# A standalone viewport uses injected mouse coordinates; the native desktop
	# pointer can lie outside this isolated test window.
	view = SubViewport.new()
	view.size = Vector2i(1440,810)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	scene = load("res://main.tscn").instantiate()
	view.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.profile.cleared = []
	scene.game.profile.hightechOrder = []
	scene.build_ui()
	await frames()
	var qa := root.get_node_or_null("QATools")
	if qa != null:
		qa.hide()
	await frames()
	check(scene.hightech_buttons.is_empty(), "All locked technologies hidden")
	check(scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.current_tab==0, "Hightech tab hidden before first unlock")
	check(scene.game.hightech_slots()==["","","","","",""], "Six anonymous expansion slots reserved")
	check(card(0).tech_key=="" and card(0)._get_drag_data(Vector2.ZERO)==null, "Empty slot cannot start drag")
	scene.game.profile.cleared = [int(scene.db.data.hightech[BattleGame.FURNACE].unlock)]
	scene.build_ui()
	await frames()
	check(scene.hightech_buttons.keys()==[BattleGame.FURNACE], "Only cleared-gate tech shown")
	check(not scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.current_tab==0, "First unlock reveals tab without switching selection")
	scene.equipment_tabs.current_tab = 2
	await frames()
	await capture("hightech-one-unlocked")
	scene.game.profile.cleared = scene.db.data.hightech.values().map(func(row):return int(row.unlock))
	scene.build_ui()
	await frames()
	check(scene.hightech_buttons.size()==3 and scene.game.hightech_slots().slice(0,3)==[BattleGame.FURNACE,BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR], "New unlocks fill vacant slots")
	await begin_drag(0)
	var original_card := card(0)
	scene.build_ui()
	check(card(0)==original_card and scene.ui_rebuild_pending, "Automatic UI rebuild waits until drag ends")
	await move_mouse(title_position(1),true)
	check(card(1).drop_highlight, "Valid target highlights during native drag")
	await capture("hightech-drag-preview")
	await click_mouse(title_position(1),false)
	scene._process(0)
	await frames()
	check(not view.gui_is_dragging(), "Release ends drag")
	check(scene.game.hightech_slots().slice(0,3)==[BattleGame.ENERGY_FOCUS,BattleGame.FURNACE,BattleGame.DENSE_ARMOUR], "Native drop swaps instead of inserting")
	check(scene.equipment_tabs.current_tab==2, "Drop rebuild preserves hightech tab")
	await begin_drag(0)
	var button_position: Vector2 = scene.hightech_buttons[BattleGame.DENSE_ARMOUR].global_position+scene.hightech_buttons[BattleGame.DENSE_ARMOUR].size/2
	await move_mouse(button_position,true)
	await click_mouse(button_position,false)
	check(scene.game.hightech_slots()[2]==BattleGame.ENERGY_FOCUS and scene.game.profile.hightechResearch.is_empty(), "Dropping onto research button swaps without starting research")
	var ordered: Array = scene.game.hightech_slots().duplicate()
	await begin_drag(0)
	await move_mouse(Vector2(750,250),true)
	await click_mouse(Vector2(750,250),false)
	check(scene.game.hightech_slots()==ordered, "Drop outside slots cancels without moving cards")
	check(not card(1)._can_drop_data(Vector2.ZERO,{"kind":"other","container":0,"source":0}), "Foreign drag rejected")
	await begin_drag(1)
	var edge: Vector2 = scene.hightech_scroll.global_position+Vector2(scene.hightech_scroll.size.x-8,16)
	await move_mouse(edge,true)
	for i in range(20):
		scene._process(0.1)
		await process_frame
	check(scene.hightech_scroll.scroll_horizontal>600, "Dragging at edge scrolls to expansion slots")
	var empty_position := title_position(4)
	check(scene.hightech_scroll.get_global_rect().has_point(empty_position), "Target expansion slot visible after scroll")
	await move_mouse(empty_position,true)
	await click_mouse(empty_position,false)
	check(scene.game.hightech_slots()[4]==BattleGame.FURNACE and scene.game.hightech_slots()[1]=="", "Drop into empty fixed slot leaves source empty")
	check(scene.hightech_scroll.scroll_horizontal>600, "Drop rebuild retains scroll position")
	await capture("hightech-empty-slot-drop")
	scene.game.save_enabled = true
	scene.game.save_progress()
	var loaded := BattleGame.new(scene.db)
	check(loaded.hightech_slots()==scene.game.hightech_slots(), "Player order and empty positions survive actual save/load")
	scene.game.save_enabled = false
	check(not scene.game.swap_hightech_slots(-1,0) and not scene.game.swap_hightech_slots(4,100) and not scene.game.swap_hightech_slots(1,0), "Invalid indices and empty source rejected")
	var before: Dictionary = scene.game.profile.hightechResearch.duplicate(true)
	scene.game.research(BattleGame.ENERGY_FOCUS)
	scene.game.swap_hightech_slots(0,2)
	check(scene.game.profile.hightechResearch.has(BattleGame.ENERGY_FOCUS), "Sorting leaves active research attached to technology")
	scene.game.profile.hightechResearch = before
	for i in range(7):
		var key := "扩展测试%d" % i
		var row: Dictionary = scene.db.data.hightech[BattleGame.FURNACE].duplicate(true)
		row.name = key
		row.unlock = 0
		scene.db.data.hightech[key] = row
	var previous: Array = scene.game.hightech_slots().duplicate()
	scene.build_ui()
	await frames()
	check(scene.hightech_buttons.size()==10 and scene.game.hightech_slots().size()==12, "Configuration growth adds cards and full pages with spare slots")
	check(scene.game.hightech_slots()==previous and scene.game.hightech_slots()[4]==BattleGame.FURNACE, "Expansion preserves existing assigned positions")
	for i in range(7):
		scene.db.data.hightech.erase("扩展测试%d" % i)
	scene.game.profile.hightechOrder = [BattleGame.FURNACE,BattleGame.FURNACE,"removed",23]
	var cleaned: Array = scene.game.hightech_slots()
	check(cleaned.count(BattleGame.FURNACE)==1 and not cleaned.has("removed") and not cleaned.has(23), "Duplicate or removed saved entries are normalized")
	scene.game.profile.cleared = []
	scene.build_ui()
	await frames()
	check(scene.hightech_buttons.is_empty() and scene.game.hightech_slots().count("")==6, "Relocked configuration never leaks names through saved order")
	check(scene.equipment_tabs.is_tab_hidden(2) and scene.equipment_tabs.current_tab==0, "Relock hides selected hightech tab and returns to weapons")
	check(scene.equipment_tabs.get_rect().end.y<=778, "Slots and horizontal scrolling fit above footer")
	print("Hightech slots: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
