extends SceneTree
class TrackedScene extends "res://scripts/main.gd":
	var checked_controls: Array = []
	var writes := 0
	var builds := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		checked_controls.append(control)
		if control.get(property)!=value:writes+=1
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds+=1
		super.build_ui()
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1952,1256)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var scene := TrackedScene.new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	for gate in scene.db.data.unlock.values():gate.level=0
	scene.game.rebuild_unlocks()
	scene.game.pending_unlocks.clear()
	scene.game.paused=true
	scene.refresh_structure()
	scene.equipment_tabs.current_tab=5
	await process_frame
	var panel=scene.crew_panel
	panel.select("navigator")
	var rows: Dictionary=panel.rows.duplicate()
	var tab_id := scene.equipment_tabs.get_instance_id()
	var builds := scene.builds
	var unrelated=panel.row_fields.engineer.name
	panel.jobs.grab_focus()
	var selected_job: int=panel.jobs.selected
	var scroll: int=panel.scroll.scroll_vertical
	scene.checked_controls.clear()
	scene.game.add_crew_exp("navigator",1.0)
	check(not scene.checked_controls.has(unrelated),"XP updates only the changed crew row and selected inspector")
	check(panel.rows==rows and scene.builds==builds,"XP preserves row instances and the UI tree")
	check(panel.jobs.has_focus() and panel.jobs.selected==selected_job and panel.scroll.scroll_vertical==scroll,"XP preserves focus, assignment draft and scroll")
	scene.equipment_tabs.current_tab=0
	await process_frame
	scene.checked_controls.clear()
	scene.game.add_crew_exp("navigator",1.0)
	check(panel.dirty and not scene.checked_controls.has(panel.title),"Hidden crew page defers its refresh")
	scene.equipment_tabs.current_tab=5
	await process_frame
	check(not panel.dirty and panel.rows==rows,"Reveal catches up without replacing rows")
	var trip: Dictionary=scene.game.profile.planets["1"]
	trip.conquered=true
	trip.crewId="navigator"
	trip.elapsed=0.0
	scene.game.advance_planets(scene.game.planet_duration("1"))
	var navigator: Dictionary=scene.game.crew.entry(scene.game,"navigator")
	var required: float=scene.game.crew.required_exp(scene.game,int(navigator.level))
	var expected_exp: String=scene.game.crew.format_text(scene.game,"exp_bar",{"exp":NumberFormat.precise(float(navigator.exp)),"needed":NumberFormat.precise(required)})
	check(not panel.dirty and panel.exp_label.text==expected_exp,"Shared planet payout updates selected XP before returning")
	check(panel.rows==rows and scene.builds==builds,"Shared planet payout preserves crew controls")
	scene.equipment_tabs.current_tab=0
	await process_frame
	scene.refresh_draw_layers(0)
	await process_frame
	var hud_draws := [0]
	var background_draws := [0]
	scene.battle_hud_layer.draw.connect(func():hud_draws[0]+=1)
	scene.background_layer.draw.connect(func():background_draws[0]+=1)
	if not scene.game.enemies.is_empty():scene.game.enemies[0].cooldowns.append(123.0)
	scene.refresh_draw_layers(0)
	await process_frame
	check(hud_draws[0]==0,"Enemy cooldown changes do not redraw player HUD")
	scene.game.player.armour=GrowthNumber.multiply(scene.game.player.armour,0.5)
	scene.refresh_draw_layers(0)
	await process_frame
	check(hud_draws[0]==1 and background_draws[0]==0,"Player health redraws HUD without static background")
	var cards: Dictionary=scene.equipment_panel.cards.duplicate()
	scene.equipment_panel.stats_dirty.clear()
	scene.on_event("planet_changed",{"id":"1","reward":1.0})
	check(scene.equipment_panel.cards==cards and scene.equipment_tabs.get_instance_id()==tab_id and scene.builds==builds,"Shared planet modifier refresh preserves equipment controls")
	check(scene.equipment_panel.stats_dirty.size()==scene.equipment_panel.items.size(),"Shared planet modifier defers equipment projections to the visible refresh")
	scene._process(0)
	check(scene.equipment_panel.stats_dirty.is_empty(),"Visible equipment projections catch up after planet payout")
	scene.on_event("enhancement_changed",{"purchased":1})
	check(scene.equipment_panel.stats_dirty.size()==scene.equipment_panel.items.size(),"Enhancement change coalesces equipment projections")
	scene._process(0)
	check(scene.equipment_panel.stats_dirty.is_empty(),"Visible equipment projections catch up after enhancement")
	await process_frame
	scene.writes=0
	for i in 3:scene._process(0)
	await process_frame
	check(scene.writes==0,"Unchanged paused UI performs no property writes")
	print("PERFORMANCE UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
