extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			writes.append(control)
		super.set_ui_value(control,property,value)

const J := BattleGame.JEWEL_FURNACE
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,12)
	scene.game.rebuild_unlocks()
	scene.build_ui()
	scene.equipment_tabs.current_tab=1
	await process_frame
	check(not scene.hightech_titles.has(J),"Locked facility has no card")
	var iron_card: Node = scene.hightech_titles[BattleGame.FURNACE].get_parent()
	var equipment_card: Node = scene.equipment_panel.cards.weapons_0.fields.title
	scene.game.profile.cleared.append(12)
	scene.game.rebuild_unlocks()
	scene.sync_hightech_slots()
	await process_frame
	check(scene.hightech_titles.has(J) and scene.hightech_titles[BattleGame.FURNACE].get_parent()==iron_card,"Unlock adds only new card and preserves iron card")
	scene.game.profile.scientists=1
	scene.refresh_scientists()
	scene.hightech_scroll.scroll_horizontal=1500
	await process_frame
	var button: Button=scene.hightech_buttons[J]
	button.grab_focus()
	for pressed in [true,false]:
		var key := InputEventKey.new()
		key.keycode=KEY_ENTER
		key.pressed=pressed
		Input.parse_input_event(key)
		await process_frame
	check(scene.game.assigned_scientists(J)==1,"Native keyboard activates scientist assignment")
	scene.game.profile.hightechLevels[J]=1
	scene.game.assign_scientist(J,-1)
	scene.game.settle_jewel_fragments(25,"drop",1)
	scene.refresh_hightech_card(J)
	var label: Label=scene.hightech_descriptions[J]
	check(label.text.contains("含有3的") and label.tooltip_text==label.text,"Card and tooltip show matching formula")
	var draws := {"background":0,"resources":0,"stars":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.resource_layer.draw.connect(func():draws.resources+=1)
	scene.stars_layer.draw.connect(func():draws.stars+=1)
	await process_frame
	scene.writes.clear()
	for id in draws: draws[id]=0
	scene.game.settle_jewel_fragments(25,"drop",1)
	scene.refresh_hightech_card(J)
	await process_frame
	check(label.text.contains("含有5的") and scene.writes.all(func(control):return control==label),"Income only writes dependent description and tooltip")
	check(draws.values().all(func(count):return count==0),"Income description does not redraw unrelated layers")
	scene.writes.clear()
	scene.refresh_hightech_card(J)
	check(scene.writes.is_empty(),"Unchanged paused card has zero property writes")
	scene.return_to_battle()
	scene._process(0)
	scene.game.resource_samples.clear()
	scene.game.settle_jewel_fragments(100,"drop",1)
	scene._process(0)
	check(label.text.contains("含有5的"),"Hidden research card is not refreshed")
	scene.equipment_tabs.current_tab=1
	scene._process(0)
	check(label.text.contains("含有10的"),"Returning to page refreshes increased historical peak")
	check(scene.hightech_descriptions[J]==label and scene.equipment_panel.cards.weapons_0.fields.title==equipment_card and scene.hightech_titles[BattleGame.FURNACE].get_parent()==iron_card,"All unrelated instances preserved")
	scene.game.settle_jewel_fragments(25,"drop",1)
	scene.game.advance_hightech(20)
	scene.refresh_hightech_card(J)
	scene.battle_layer.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://.runtime/jewel-furnace.png")
	var core: Dictionary=scene.game.drops.filter(func(drop):return drop.get("hightech",false) and drop.has("jewel"))[0]
	# The expanded research page covers the field; return before collecting.
	scene.return_to_battle()
	await process_frame
	scene.game.paused=false
	scene.refresh_navigation()
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(core.x,core.y)
	motion.global_position=motion.position
	Input.parse_input_event(motion)
	await process_frame
	check(not scene.game.drops.has(core),"Native mouse motion collects core")
	scene.game.paused=true
	print("Jewel furnace UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
