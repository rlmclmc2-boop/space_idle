extends SceneTree
## Real main.tscn loop, isolated saves. No manual tick/advance or frozen progress.
var scene
var page
var checks:=0
var failures:=0
var milestones: Array=[]
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _initialize() -> void:call_deferred("run")
func settle(seconds:=0.25) -> void:
	await create_timer(seconds).timeout
func click(control: Control) -> void:
	check(control.is_visible_in_tree(),"Input target is visible: "+control.name)
	var window:=control.get_window()
	var point:=control.get_global_rect().get_center()
	if window!=root:point+=Vector2(window.position)
	point=point*Vector2(root.size)/root.get_visible_rect().size
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.position=point
		Input.parse_input_event(event)
		await process_frame
	await settle(0.1)
func snapshot() -> Dictionary:
	var energy:=0
	var uniforms:=0
	for c in page.machines.values():
		energy+=c.energy_writes
		uniforms+=c.progress_writes
	return {"refresh":page.refresh_count,"writes":page.writes,"refresh_usec":page.refresh_usec,"quotes":page.quote_evaluations,"energy":energy,"progress_uniforms":uniforms,"room_draws":page.room.draws}
func difference(after: Dictionary,before: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in before:result[key]=after[key]-before[key]
	return result
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/"+name+".png")
func run() -> void:
	root.size=Vector2i(1360,876)
	root.position=Vector2i.ZERO
	scene=load("res://main.tscn").instantiate()
	# Capture flag only isolates startup saves; clear it before the first live frame.
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	var g: BattleGame=scene.game
	g.save_enabled=false
	g.profile.cleared=[]
	g.profile.grantedUnlocks=[]
	g.profile.scientists=32
	g.profile.resources={"1":1000000.0,"2":100000.0}
	g.pending_unlocks.clear()
	scene.refresh_structure()
	scene.refresh_tab_visibility()
	await settle()
	page=scene.hightech_page
	check(scene.is_processing() and not g.paused,"Normal main.tscn is processing and unpaused")
	check(scene.equipment_tabs.is_tab_hidden(1) and page.rows.is_empty(),"Factory unlock gate hides page and identities")
	g.profile.cleared=range(1,51)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	for key in scene.db.data.hightech:
		g.profile.hightechLevels[key]=0
		g.profile.techPoints[key]=0.0
		g.profile.scientistAssignments[key]=0
	scene.refresh_structure()
	scene.refresh_tab_visibility()
	await settle()
	await click(scene.system_nav_buttons[1])
	await settle()
	check(scene.equipment_tabs.current_tab==1 and page.is_visible_in_tree(),"Navigation opens the production factory")
	check(page.get_script().resource_path=="res://scripts/hightech_workshop.gd","Production uses the approved workshop owner")
	check(page.rows.size()==4 and page.machines.values().all(func(c):return c.parts.size()==23),"Four real devices retain 23 assembly stages")
	check(not scene.find_children("*","Control",true,false).any(func(n):return n.get_script()!=null and n.get_script().resource_path in ["res://scripts/hightech_dock_bay.gd","res://scripts/hightech_inspector.gd","res://scripts/hightech_scroll.gd"]),"No old factory card, inspector or scrolling page is running")
	if page.rows.is_empty():
		await capture("navigation-failure")
		print("NAV DEBUG ",scene.system_nav_buttons[1].get_global_rect()," root ",root.get_visible_rect()," hidden ",scene.equipment_tabs.is_tab_hidden(1)," tab ",scene.equipment_tabs.current_tab)
		quit(1)
		return
	await click(page.rows[BattleGame.ENERGY_FOCUS].button)
	check(page.selected==BattleGame.ENERGY_FOCUS,"Worklist selection reaches the focused cell")
	var identity: int=page.get_instance_id()
	var row_ids: Array=page.rows.values().map(func(r):return r.button.get_instance_id())
	# Recorder handshake. While waiting, all ordinary AI are idle by real game state.
	if OS.get_cmdline_user_args().has("--record"):
		FileAccess.open("res://.runtime/record-ready",FileAccess.WRITE).store_string("ready")
		var deadline:=Time.get_ticks_msec()+60000
		while not FileAccess.file_exists("res://.runtime/record-start") and Time.get_ticks_msec()<deadline:await process_frame
		check(FileAccess.file_exists("res://.runtime/record-start"),"External live screen recorder started")
	var before_record:=snapshot()
	var start_clock: float=scene.clock
	var record_started:=Time.get_ticks_msec()
	await settle(0.4)
	await click(page.actions[2]) # +10 ordinary AI, real click starts research from zero.
	check(g.assigned_scientists(BattleGame.ENERGY_FOCUS)==10,"+10 AI uses the original allocation method")
	await settle(1.2)
	await click(page.actions[1])
	check(g.assigned_scientists(BattleGame.ENERGY_FOCUS)==11,"+1 AI and remaining pool update live")
	await settle(1.0)
	var total_before:=int(g.profile.scientists)
	await click(page.generate_actions[1])
	check(int(g.profile.scientists)==total_before+1,"Generate one AI uses real affordability and purchase")
	while Time.get_ticks_msec()-record_started<10500:
		milestones.append({"wall_ms":Time.get_ticks_msec()-record_started,"clock":scene.clock-start_clock,"level":g.hightech_level(BattleGame.ENERGY_FOCUS),"points":g.profile.techPoints[BattleGame.ENERGY_FOCUS],"stage":page.machines[BattleGame.ENERGY_FOCUS].built})
		await settle(0.25)
	var visible_counts:=difference(snapshot(),before_record)
	check(g.hightech_level(BattleGame.ENERGY_FOCUS)>0 and page.factory_events>0,"Live normal loop completes research and starts a new round")
	check(scene.is_processing() and not g.paused and g.speed==1.0,"Recording retained normal unpaused 1x gameplay")
	check(page.get_instance_id()==identity and row_ids==page.rows.values().map(func(r):return r.button.get_instance_id()),"No page or row rebuild during production")
	await capture("factory-main-live")
	# Option/help uses its real input and original modal chrome.
	var rules: Button=page.console.find_children("*","Button",true,false).filter(func(b):return b.text==UIText.t("research.workshop.details"))[0]
	await click(rules)
	var dialogs: Array=page.get_children().filter(func(n):return n is AcceptDialog)
	check(dialogs.size()==1 and dialogs[0].visible,"Rules option opens without replacing the page")
	if not dialogs.is_empty():
		var dialog=dialogs[0]
		await click(dialog.get_ok_button())
		check(not is_instance_valid(dialog) or not dialog.visible,"Rules dialog closes through actual input")
	await click(page.rows[BattleGame.DENSE_ARMOUR].button)
	await click(page.distribute)
	check(g.idle_scientists()==0 and page.selected==BattleGame.DENSE_ARMOUR,"Distribution keeps the selected independent workstation")
	# Real crew configuration supplies free dedicated AI; they cannot be removed.
	g.crew.load_state(g,[{"crewId":"navigator","level":1,"assignmentType":"hightech_scientists","targetId":"hightech"}])
	g.assign_scientist(BattleGame.DENSE_ARMOUR,-g.assigned_scientists(BattleGame.DENSE_ARMOUR))
	page.invalidate()
	await settle()
	var free_ai:=g.dedicated_scientists(BattleGame.DENSE_ARMOUR)
	check(free_ai>0 and page.dedicated.text.contains(str(free_ai)),"Free dedicated AI appear separately from removable allocation")
	check(page.actions[0].disabled and g.assigned_scientists(BattleGame.DENSE_ARMOUR)==0,"Remove is disabled when only free AI remain")
	check(page.machines[BattleGame.DENSE_ARMOUR].assigned==free_ai,"Free AI continue real construction")
	await capture("factory-free-ai-only")
	await click(scene.system_nav_buttons[0])
	var before_hidden:=snapshot()
	var research_before:=float(g.profile.techPoints[BattleGame.DENSE_ARMOUR])
	await settle(2.0)
	var hidden_counts:=difference(snapshot(),before_hidden)
	check(not page.is_processing() and hidden_counts.refresh==0 and hidden_counts.energy==0 and hidden_counts.progress_uniforms==0 and hidden_counts.writes==0,"Hidden factory stops processing, readouts and material writes")
	check(float(g.profile.techPoints[BattleGame.DENSE_ARMOUR])!=research_before,"Game research continues while factory is hidden")
	await click(scene.system_nav_buttons[1])
	await settle()
	check(page.get_instance_id()==identity and page.selected==BattleGame.DENSE_ARMOUR,"Returning preserves the same page and selected workstation")
	var expected:=float(g.profile.techPoints[BattleGame.DENSE_ARMOUR])/g.hightech_required(BattleGame.DENSE_ARMOUR)
	# Live readout samples at 5 Hz; include one running main-loop frame in the bound.
	var sample_bound: float=g.research_rate(BattleGame.DENSE_ARMOUR)*(0.2+scene.get_process_delta_time())/g.hightech_required(BattleGame.DENSE_ARMOUR)+0.001
	check(absf(page.machines[BattleGame.DENSE_ARMOUR].fraction-expected)<=sample_bound,"Reveal catches up within the visible sampling interval")
	await capture("factory-main-dedicated-ai")
	var evidence:={"checks":checks,"failures":failures,"visible_counts":visible_counts,"hidden_2s_counts":hidden_counts,"normal_loop_seconds":scene.clock-start_clock,"milestones":milestones}
	FileAccess.open("res://.runtime/factory-production-evidence.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("FACTORY_PRODUCTION ",JSON.stringify({"checks":checks,"failures":failures,"visible_counts":visible_counts,"hidden_2s_counts":hidden_counts}))
	quit(1 if failures else 0)
