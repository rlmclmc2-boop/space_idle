extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	var writes: Array=[]
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
var scene
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(message)
func frames() -> void:
	await process_frame
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	# Dismiss any manually opened tooltip before a different fixture is captured.
	var motion:=InputEventMouseMotion.new()
	motion.position=Vector2(10,10)
	root.push_input(motion,true)
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../crew-xp-"+name+".png")
func click(control: Control) -> void:
	var position:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=position
	root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
		await frames()
func run() -> void:
	print("QA HARDWARE: ",JSON.stringify({"cpu":OS.get_processor_name(),"logical_cpu_count":OS.get_processor_count(),"memory":OS.get_memory_info(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"display_server":DisplayServer.get_name()}))
	root.gui_embed_subwindows=true
	scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	scene.automation_args=["--capture"]
	root.add_child(scene)
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	var g=scene.game
	g.save_enabled=false
	g.paused=true
	g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.visible=false
	for gate in g.db.data.unlock.values():gate.level=0
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	scene.refresh_structure()
	if DisplayServer.get_name()!="headless":root.size=Vector2i(1180,760)
	await frames()
	await click(scene.system_nav_buttons[5])
	var panel=scene.crew_panel
	var item: Dictionary=g.crew.entry(g,"navigator")
	item.level=103
	item.exp=13159583000.0
	panel.refresh_member(item)
	var required: float=g.crew.required_exp(g,103)
	var original: Dictionary=item.duplicate(true)
	check(scene.equipment_tabs.current_tab==5,"Actual navigation opens crew page")
	check(panel.exp_label.text==g.crew.format_text(g,"exp_bar",{"exp":scene.number(item.exp),"needed":scene.number(required)}),"Screenshot XP uses both shared compact endpoints")
	check(panel.exp_label.tooltip_text==g.crew.format_text(g,"exp_bar",{"exp":NumberFormat.precise(item.exp),"needed":NumberFormat.precise(required)}),"XP label exposes precise endpoints")
	check(panel.experience.tooltip_text==panel.exp_label.tooltip_text and panel.rows.navigator.tooltip_text.contains(panel.exp_label.tooltip_text),"List and progress hover share exact XP")
	check(panel.exp_label.mouse_filter!=Control.MOUSE_FILTER_IGNORE,"XP hover can receive input")
	check(panel.experience.step==0.0 and is_equal_approx(panel.experience.value,float(item.exp)/required*100.0),"Bar uses actual ratio without range rounding")
	check(item==original and panel.title.text.contains("103") and panel.row_fields.navigator.name.text.contains("103"),"Presentation leaves exact XP and level unchanged")
	await capture("sample")
	if OS.get_environment("CREW_XP_HOLD")=="1" and DisplayServer.get_name()!="headless":
		print("CREW XP READY FOR HOVER")
		while not FileAccess.file_exists("res://../continue-crew-xp"):await create_timer(0.1).timeout
	var base=g.db.data.crew_config.base_exp.value
	var multiplier=g.db.data.crew_config.exp_multiplier.value
	g.db.data.crew_config.exp_multiplier.value=1.0
	for fixture in [["zero",0.0,100.0,"0","100"],["K",1234.0,2345.0,"1.23K","2.35K"],["M",1234567.0,2345678.0,"1.23M","2.35M"],["B",1234567890.0,2345678901.0,"1.23B","2.35B"],["T",1.23456789e12,2.3456789e12,"1.23T","2.35T"],["Qa",1.23456789e15,2.3456789e15,"1.23Qa","2.35Qa"],["scientific",1.23456789e33,2.3456789e33,"1.23e+33","2.35e+33"]]:
		g.db.data.crew_config.base_exp.value=fixture[2]
		item.exp=fixture[1]
		panel.refresh_member(item)
		check(panel.exp_label.text==g.crew.format_text(g,"exp_bar",{"exp":fixture[3],"needed":fixture[4]}),"Shared ladder renders "+fixture[0])
		check(item.exp==fixture[1] and item.level==103 and panel.experience.value<100,"Display does not advance "+fixture[0])
		await capture(fixture[0])
		if DisplayServer.get_name()!="headless":check(panel.exp_label.get_line_count()==1 and panel.exp_label.get_global_rect().end.x<=panel.detail_scroll.get_global_rect().end.x,"XP fits normal width: "+fixture[0])
	for threshold in [1000.0,1e6,1e9,1e12,1e15,1e33]:
		g.db.data.crew_config.base_exp.value=threshold
		# High exponents need a representable delta, still below compact precision.
		var delta: float=maxf(1.0,threshold*1e-6)
		item.exp=threshold-delta
		var level: int=item.level
		panel.refresh_member(item)
		var prefix: String="<" if scene.number(item.exp)==scene.number(threshold) else ""
		check(panel.exp_label.text==g.crew.format_text(g,"exp_bar",{"exp":prefix+scene.number(item.exp),"needed":scene.number(threshold)}) and panel.experience.value<100,"Threshold stays visibly incomplete: "+str(threshold))
		g.add_crew_exp("navigator",0)
		check(item.level==level,"Rounded presentation does not trigger a level")
		if threshold==1e6:await capture("below-level")
		g.add_crew_exp("navigator",delta)
		check(item.level==level+1 and item.exp==0.0 and panel.experience.value==0.0 and panel.title.text.contains(str(level+1)),"Actual threshold upgrades once and resets remainder: "+str(threshold))
		if threshold==1e6:await capture("leveled")
	g.db.data.crew_config.base_exp.value=base
	g.db.data.crew_config.exp_multiplier.value=multiplier
	item.level=103
	item.exp=13159583000.0
	panel.refresh_member(item)
	var other: Button=panel.rows.engineer
	var row: Button=panel.rows.navigator
	scene.writes.clear()
	panel.refresh_member(item)
	check(scene.writes.is_empty(),"Repeated paused refresh performs no property writes")
	panel.jobs.grab_focus()
	var draft: int=panel.jobs.selected
	g.add_crew_exp("navigator",1)
	check(root.gui_get_focus_owner()==panel.jobs and panel.jobs.selected==draft and panel.rows.navigator==row,"Visible XP preserves focus and assignment draft")
	scene.select_system(0)
	await frames()
	scene.writes.clear()
	g.add_crew_exp("navigator",1)
	check(panel.dirty and panel.rows.navigator==row and not scene.writes.has(other),"Hidden XP event preserves controls and unrelated row")
	await click(scene.system_nav_buttons[5])
	check(panel.exp_label.tooltip_text.contains("13159583002") and panel.jobs.selected==draft and panel.rows.navigator==row,"Reveal catches up exact XP without losing draft or row")
	await click(panel.rows.engineer)
	check(panel.selected=="engineer" and panel.exp_label.tooltip_text.contains("0 /"),"Real selection replaces XP hover")
	await click(panel.rows.navigator)
	check(panel.selected=="navigator" and panel.exp_label.tooltip_text.contains("13159583002"),"Repeat selection restores correct member XP")
	await click(scene.system_nav_buttons[6])
	var planet=scene.planet_panel
	var id: String=planet.selected_planet_id
	var reward: float=g.planet_exp_reward(id)
	for amount in [0.0,1234.0,1.23456789e9,1.23456789e15,1.23456789e33]:
		check(planet.crew_reward_text(amount)==g.crew.format_text(g,"planet_exp",{"exp":scene.number(amount)}),"Exploration XP reward shares ladder")
		planet.show_completion(id,amount)
		if amount>0:check(planet.cards[id].feedback.text.contains(scene.number(amount)) and planet.cards[id].feedback.tooltip_text.contains(NumberFormat.precise(amount)),"Completion text keeps compact and exact reward")
	check(planet.cards[id].detail.tooltip_text.contains(NumberFormat.precise(reward)) if reward>0 else true,"Reward detail exposes exact XP")
	print("CREW EXPERIENCE DISPLAY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
