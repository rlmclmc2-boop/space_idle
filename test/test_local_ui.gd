extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	var property_checks: Array = []
	var builds := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		property_checks.append(control)
		if control.get(property) != value:
			writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds += 1
		super.build_ui()

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position = control.get_global_rect().get_center()
	Input.parse_input_event(mouse)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = mouse.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e6,"2":1e6}
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	scene._process(0)
	await process_frame
	var tabs := scene.equipment_tabs
	var builds := scene.builds
	var defence: Label = scene.equipment_panel.cards.defence_0.fields.title
	var tech: String = scene.hightech_buttons.keys()[0]
	var tech_panel: Node = scene.hightech_buttons[tech].get_parent()
	var charge: String = scene.charge_cards.keys()[0]
	var charge_title: Label = scene.charge_cards[charge].title
	var draws := {"background":0,"resources":0,"battle":0,"stars":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.resource_layer.draw.connect(func():draws.resources+=1)
	scene.battle_layer.draw.connect(func():draws.battle+=1)
	scene.stars_layer.draw.connect(func():draws.stars+=1)
	await process_frame
	for key in draws: draws[key]=0
	scene.writes.clear()
	for i in 3: scene._process(0)
	await process_frame
	check(scene.writes.is_empty(),"Unchanged paused UI has no property writes")
	check(draws.values().all(func(count):return count==0),"Unchanged paused layers are not redrawn")
	var before := int(scene.game.slot_entry("weapons",0).level)
	await click(scene.equipment_panel.detail.upgrade)
	check(int(scene.game.slot_entry("weapons",0).level)==before+1,"Real click upgrades equipment")
	check(not scene.writes.has(defence) and not scene.writes.has(charge_title),"Upgrade does not write unrelated card titles")
	check(scene.equipment_tabs==tabs and scene.builds==builds,"Upgrade keeps complete UI tree")
	check(scene.hightech_buttons[tech].get_parent()==tech_panel,"Upgrade preserves research card")
	scene._process(0)
	await process_frame
	check(draws.background==0 and draws.stars==0 and draws.resources>0,"Resource spending redraws resources without static background or stars")
	scene.equipment_tabs.current_tab=1
	await process_frame
	await click(scene.scientist_generate_button)
	await click(scene.hightech_buttons[tech])
	check(scene.game.assigned_scientists(tech)==1,"Real mouse generates and assigns scientist")
	check(scene.builds==builds and scene.hightech_buttons[tech].get_parent()==tech_panel,"Scientific actions retain all UI instances")
	check(scene.hightech_buttons.values().all(func(button):return button.disabled),"All research buttons reflect shared idle count")
	scene.game.profile.hightechLevels[tech]=1
	scene.on_event("hightech_complete",{"key":tech})
	check(scene.hightech_titles[tech].text.contains("Lv.1") and scene.builds==builds,"Completion updates research card without full rebuild")
	scene.on_event("state",{})
	check(scene.builds==builds and scene.equipment_tabs==tabs,"Battle state preserves UI")
	var source: int=tech_panel.slot_index
	check(scene.game.swap_hightech_slots(source,source+1),"Research order changes")
	scene.sync_hightech_slots()
	check(tech_panel.slot_index==source+1 and scene.hightech_buttons[tech].get_parent()==tech_panel,"Drag ordering moves existing card")
	await process_frame
	var target: Control=scene.hightech_container.get_child(source+1)
	var start: Vector2=tech_panel.get_global_rect().position+Vector2(100,12)
	var end: Vector2=target.get_global_rect().position+Vector2(100,12)
	var motion := InputEventMouseMotion.new()
	motion.position=start
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.position=start
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	Input.parse_input_event(press)
	await process_frame
	for position in [start+Vector2(-30,0),end]:
		motion=InputEventMouseMotion.new()
		motion.position=position
		motion.relative=Vector2(-30,0)
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
	press=InputEventMouseButton.new()
	press.position=end
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=false
	Input.parse_input_event(press)
	await process_frame
	scene._process(0)
	check(tech_panel.slot_index==source and scene.builds==builds,"Real drag moves research card without rebuilding UI")
	scene.equipment_tabs.current_tab=2
	await process_frame
	await click(scene.charge_panel.detail.button)
	check(scene.game.charge_job(charge).active and scene.charge_panel.detail.button.text=="暂停","Real charge click refreshes owning card and selected details")
	check(scene.builds==builds,"Charge action does not rebuild UI")
	scene.equipment_tabs.current_tab=0
	var hidden_text: String=scene.charge_cards[charge].progress.text
	scene.game.charge_job(charge).elapsed=1
	scene._process(0)
	check(scene.charge_cards[charge].progress.text==hidden_text,"Hidden charge page is not refreshed each frame")
	scene.equipment_tabs.current_tab=2
	check(scene.charge_cards[charge].progress.text!=hidden_text,"Showing charge page catches up immediately")
	await click(scene.help_button)
	scene._process(0)
	check(scene.help_open and not tabs.visible and scene.builds==builds,"Help toggles visibility without rebuilding")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/local-help.png")
	scene.help_open=false
	scene.refresh_navigation()
	check(tabs.visible and scene.equipment_tabs==tabs,"Closing help restores same tab tree")
	await click(scene.sound_button)
	check(scene.sound_on and scene.builds==builds,"Sound toggles only its control")
	scene.equipment_tabs.current_tab=3
	var ship: Control=scene.ship_controls.page
	await click(ship.choices.Destroyer)
	check(ship.candidate!=scene.game.profile.selectedShip and scene.builds==builds,"Ship candidate selection is read-only and local")
	var mount: Button=ship.mounts.weapons_0
	ship.refresh()
	check(ship.mounts.weapons_0==mount and scene.builds==builds,"Candidate refresh preserves mount controls")
	await click(ship.confirm)
	check(scene.game.profile.selectedShip==ship.candidate and scene.builds==builds,"Ship confirmation preserves UI")
	check(scene.charge_cards[charge].title==charge_title and scene.hightech_buttons[tech].get_parent()==tech_panel,"Ship change preserves charge and research controls")
	scene.equipment_tabs.current_tab=0
	var defence_panel: Button=scene.equipment_panel.cards.defence_0
	check(scene.game.unequip_slot("weapons",0),"Isolated fixture can empty a weapon slot")
	scene.refresh_structure()
	var empty_panel: Button=scene.equipment_panel.cards.weapons_0
	scene.equipment_panel.select_item("weapons_0")
	scene.equipment_panel.selected_slot=0
	scene.equipment_panel.refresh_detail()
	scene.equipment_panel.change_equipment("laser")
	check(scene.equipment_panel.cards.weapons_0==empty_panel and scene.equipment_panel.cards.defence_0==defence_panel,"Installing updates catalog in place without rebuilding cards")
	check(scene.builds==builds and scene.game.slot_entry("weapons",0).key=="laser","Installing equipment updates related current-ship draft without full rebuild")
	# Relock/unlock fixtures verify only affected hightech slot content changes.
	var other_tech: String=scene.hightech_buttons.keys().filter(func(key):return key!=tech)[0]
	var other_panel: Node=scene.hightech_buttons[other_tech].get_parent()
	scene.db.data.hightech[tech].unlock=99
	scene.game.profile.cleared.erase(1)
	scene.refresh_structure()
	check(not scene.hightech_buttons.has(tech) and scene.hightech_buttons[other_tech].get_parent()==other_panel,"Relocking one technology preserves unrelated research cards")
	scene.game.profile.cleared.append(99)
	scene.refresh_structure()
	check(scene.hightech_buttons.has(tech) and scene.hightech_buttons[other_tech].get_parent()==other_panel and scene.builds==builds,"Unlocking one technology adds only affected slot content")
	scene.game.pending_unlocks=["shield"]
	scene.on_event("unlock",{})
	check(scene.continue_button.visible and not tabs.visible and scene.builds==builds,"Unlock overlay preserves underlying UI")
	await process_frame
	await click(scene.continue_button)
	check(tabs.visible and scene.game.pending_unlocks.is_empty() and scene.builds==builds,"Unlock acknowledgment restores existing controls")
	scene.equipment_tabs.current_tab=1
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/local-research.png")
	await check_navigation_scope(scene)
	await check_exact_levels(scene)
	print("Local UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_navigation_scope(scene: TrackedUI) -> void:
	scene.refresh_navigation()
	var tabs := scene.equipment_tabs
	var builds := scene.builds
	var extra := Control.new()
	extra.hide()
	scene.ui.add_child(extra)
	var draws := {"tabs":0,"background":0,"resources":0}
	tabs.draw.connect(func():draws.tabs+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.resource_layer.draw.connect(func():draws.resources+=1)
	await process_frame
	for key in draws:draws[key]=0
	scene.property_checks.clear()
	await click(scene.sound_button)
	check(scene.property_checks.size()==1 and scene.property_checks[0]==scene.sound_button,"Sound checks only its own text, no visibility sweep")
	check(draws.values().all(func(count):return count==0),"Sound does not redraw unrelated tabs/background/resources")
	check(not extra.visible,"Navigation never manages arbitrary sibling controls")
	scene.property_checks.clear()
	scene.game.profile.loop=not scene.game.profile.loop
	scene.refresh_navigation()
	check(not scene.property_checks.is_empty() and scene.property_checks.all(func(control):return control==scene.loop_button),"Guard toggle checks only its own button")
	scene.property_checks.clear()
	scene.game.profile.guardDeath=2
	scene.refresh_navigation()
	check(scene.property_checks.is_empty() and scene.guard_settings.get_popup().is_item_checked(2),"Guard setting changes only menu checkmarks")
	scene.game.state=BattleGame.State.TRAVEL
	scene.refresh_navigation()
	scene.property_checks.clear()
	scene.game.state=BattleGame.State.COMBAT
	scene.refresh_navigation()
	check(scene.property_checks.is_empty(),"Travel to combat has no changed navigation display")
	scene.property_checks.clear()
	scene.game.state=BattleGame.State.LEVEL_CLEAR
	scene.refresh_navigation()
	check(scene.property_checks==[scene.advance_button] and scene.advance_button.visible,"Level clear updates only advance visibility")
	var picker := scene.loop_select
	var sentinel := RefCounted.new()
	picker.set_item_metadata(1,sentinel)
	var count := picker.item_count
	scene.property_checks.clear()
	scene.game.profile.loopLevel=picker.get_item_id(1)
	scene.refresh_navigation()
	check(picker.item_count==count and is_same(picker.get_item_metadata(1),sentinel),"Changing destination preserves dropdown entries")
	check(picker.get_selected_id()==scene.game.profile.loopLevel and scene.property_checks.is_empty(),"Destination updates selection without touching unrelated properties")
	var last := picker.get_item_id(count-1)
	scene.game.profile.cleared.erase(last)
	scene.refresh_navigation()
	check(picker.item_count==count-1 and is_same(picker.get_item_metadata(1),sentinel),"Removing level preserves unrelated options")
	scene.game.profile.cleared.append(last)
	scene.refresh_navigation()
	check(picker.item_count==count and picker.get_item_id(count-1)==last and is_same(picker.get_item_metadata(1),sentinel),"Adding level preserves existing options")
	scene.property_checks.clear()
	for i in 3:scene.refresh_navigation()
	check(scene.property_checks.is_empty(),"Unchanged navigation never enters property setters")
	check(scene.equipment_tabs==tabs and scene.builds==builds,"Navigation actions never rebuild UI")
	extra.queue_free()

func check_exact_levels(scene: TrackedUI) -> void:
	var builds := scene.builds
	scene.equipment_tabs.current_tab=0
	var title: Label = scene.equipment_panel.cards.weapons_0.fields.level
	var tech: String = scene.hightech_titles.keys()[0]
	var charge: String = scene.charge_cards.keys()[0]
	for level in [99, 100, 101, 109, 119, 999, 1234]:
		scene.game.slot_entry("weapons",0).level=level
		scene.refresh_equipment_cards("weapons_0")
		check(title.text.ends_with("Lv.%d" % level),"Equipment shows exact level %d" % level)
		scene.game.profile.hightechLevels[tech]=level
		scene.refresh_hightech_card(tech)
		check(scene.hightech_titles[tech].text.ends_with("Lv.%d" % level),"Research shows exact level %d" % level)
		scene.game.charge_job(charge).level=level
		scene.refresh_charge_card(charge)
		check(scene.charge_cards[charge].title.text.ends_with("Lv.%d" % level),"Charge shows exact level %d" % level)
	while scene.db.levels.size()<110:
		scene.db.levels.append(scene.db.levels[-1].duplicate(true))
	scene.game.stage=109
	scene.game.profile.cleared.append(109)
	scene.game.profile.highestLevel=110
	scene.game.profile.loopLevel=109
	scene.refresh_navigation()
	check(scene.loop_select.get_item_text(scene.loop_select.get_item_index(109))=="跃迁 · 第 109 关","Warp option preserves exact three-digit stage")
	check(scene.number(1234)=="1.2K","Resource quantity formatting remains compact")
	check(scene.equipment_panel.cards.weapons_0.fields.level==title and scene.builds==builds,"Exact levels preserve existing controls")
	scene.equipment_tabs.current_tab=0
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/local-exact-levels.png")
