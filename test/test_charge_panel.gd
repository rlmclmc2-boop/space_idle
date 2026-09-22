extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var changed_controls: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			changed_controls.append(control)
		super.set_ui_value(control,property,value)

var checks := 0
var failures := 0
var scene: TrackedUI
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func shot(name: String) -> void:
	scene.refresh_draw_layers(0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+name+".png")

func check_geometry(panel: Control, label: String) -> void:
	panel.refresh_animation_visibility()
	var network = panel.core_feed
	var correct := true
	for key in network.routes:
		var route: Dictionary = network.routes[key]
		correct=correct and route.points[0].distance_to(network.anchor_position(panel.reactor.port))<0.01
		correct=correct and route.points[-1].distance_to(network.anchor_position(panel.cards[key].circuit.port))<0.01
		correct=correct and network.point_at(route,route.length).distance_to(route.end)<0.01
		for point: Vector2 in route.points:
			correct=correct and point.y<=route.end.y+0.01
	check(correct,"Real core and module anchors remain connected: "+label)
	var revision: int = network.geometry_revision
	panel.refresh_animation_visibility()
	check(network.geometry_revision==revision,"Unchanged geometry reuses baked paths: "+label)

func run() -> void:
	scene = TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.profile.resources={"1":1000,"2":1000}
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	await process_frame
	await process_frame
	var panel = scene.charge_panel
	var initial_count: int = panel.cards.size()
	var key: String = panel.cards.keys()[0]
	var second: String = panel.cards.keys()[1]
	var row: Dictionary = scene.db.data.charge[key]
	var id := str(int(row.para_1))
	var job: Dictionary = scene.game.charge_job(key)
	job.active=false
	job.started=0
	job.credit=0
	job.elapsed=0
	panel.refresh_card(key)
	check(panel.state_for(key)=="available","Unstarted funded system is available")
	await click(panel.detail.button)
	check(job.active and panel.state_for(key)=="charging","Actual start button toggles existing job")
	var metrics: Dictionary = panel.core_metrics()
	check(metrics[id].consumption==scene.game.charge_resource_rate(key) and metrics[id].net==-metrics[id].consumption,"Core aggregates current charge consumption and negative net")
	panel.refresh_core()
	check(panel.energy_rows[id].net.text.begins_with("−"),"Negative net keeps its sign instead of being clamped to zero")
	scene.game.resource_samples.append({"id":id,"amount":180.0,"time":Time.get_unix_time_from_system()-1})
	metrics=panel.core_metrics()
	check(metrics[id].production==3.0 and metrics[id].net==3.0-metrics[id].consumption,"Core derives production from the existing sixty-second window")
	scene.game.speed=5
	check(panel.core_metrics()[id].consumption==scene.game.charge_resource_rate(key)*5,"Real-second consumption accounts for simulation speed")
	scene.game.speed=1
	scene.game.resource_samples.clear()
	scene.game.advance_charge(0.5)
	panel.refresh_card(key)
	check(job.elapsed>0 and panel.cards[key].circuit.is_processing(),"Existing charging advances and energizes owning circuit")
	check(is_equal_approx(panel.cards[key].circuit.progress,float(job.elapsed)/float(row.para_4)),"Gauge ring uses actual charge fraction")
	await click(panel.detail.button)
	check(not job.active and panel.state_for(key)=="paused","Actual pause preserves existing job")
	var paused_skin: StyleBox = panel.cards[key].title.get_parent().get_theme_stylebox("panel")
	check(paused_skin is StyleBoxEmpty and panel.cards[key].circuit.selected and panel.cards[key].circuit.visual_state=="paused","Selected paused module keeps only a thin border and a muted pipeline")
	check(panel.core_metrics()[id].consumption==0 and not panel.core_feed.flowing,"Paused jobs are excluded from consumption and reactor flow")
	var elapsed: float = job.elapsed
	scene.game.advance_charge(0.5)
	check(job.elapsed==elapsed,"Paused system makes no progress")
	await click(panel.detail.button)
	check(job.active,"Actual resume uses original toggle")
	scene.game.profile.resources[id]=0
	job.credit=0
	panel.refresh_card(key)
	check(panel.state_for(key)=="insufficient" and panel.detail.button.disabled and panel.detail.button.text==UIText.t("charge.state.insufficient"),"Starved active job cannot show Pause")
	check(not panel.cards[key].circuit.is_processing(),"Starved circuit stops animating")
	check(panel.cards[key].circuit.visual_state=="insufficient" and panel.detail.button.get_theme_color("font_disabled_color")==panel.ORANGE,"Starvation warning agrees across circuit and disabled action")
	var before: Dictionary = scene.game.profile.duplicate(true)
	await click(panel.detail.button)
	check(scene.game.profile==before,"Disabled insufficient button cannot mutate state")
	job.credit=0.2
	panel.refresh_card(key)
	check(panel.state_for(key)=="charging" and not panel.detail.button.disabled,"Prepaid energy remains usable at zero balance")
	job.credit=0
	scene.game.profile.resources[id]=0.5
	panel.refresh_card(key)
	check(panel.state_for(key)=="insufficient","Fractional balance cannot pay integer resource charge")
	var paid_rate: float = row.para_2
	row.para_2=0
	panel.refresh_card(key)
	check(panel.state_for(key)=="charging","Free configured systems do not require a resource balance")
	row.para_2=paid_rate
	scene.game.profile.resources[id]=1000
	panel.refresh_card(key)
	check(panel.state_for(key)=="charging","Replenishment restores active job automatically")
	await click(panel.cards[second].select)
	check(panel.selected==second and panel.detail.title.text==panel.cards[second].title.text,"Actual node selection updates details")
	var selected_skin: StyleBox = panel.cards[second].title.get_parent().get_theme_stylebox("panel")
	var running_skin: StyleBox = panel.cards[key].title.get_parent().get_theme_stylebox("panel")
	check(selected_skin is StyleBoxEmpty and running_skin is StyleBoxEmpty and panel.cards[second].circuit.selected and not panel.cards[second].circuit.flowing and not panel.cards[key].circuit.selected and panel.cards[key].circuit.flowing,"Selection and running are independent instrument states without rectangular card skins")
	await shot("charge-selected-idle")
	scene.changed_controls.clear()
	job.elapsed += 0.1
	panel.refresh_card(key)
	check(not scene.changed_controls.has(panel.detail.title) and not scene.changed_controls.has(panel.detail.progress),"Unselected progress does not write selected details")
	scene.db.unlock_row("charge",second).level=999
	panel.refresh_card(second)
	check(panel.state_for(second)=="locked" and panel.detail.button.disabled and panel.cards[second].title.get_parent().visible,"Locked node remains inspectable")
	check(panel.cards[second].circuit.visual_state=="locked","Locked module uses the disabled circuit palette")
	var identity: Node = panel.cards[key].title
	var tabs: Node = scene.equipment_tabs
	# Runtime-only configuration fixtures: no balance data or player save is edited.
	for i in range(9):
		var extra := "fixture_system_%d" % i
		scene.db.data.charge[extra]=row.duplicate(true)
		scene.db.data.unlock[extra]={"type":"charge","target":extra,"level":0,"mode":"cleared"}
		scene.game.profile.charge[extra]={"level":i,"count":0.0,"elapsed":0.0,"active":false,"started":0,"credit":0.0}
	panel.sync_modules()
	await process_frame
	await process_frame
	check(panel.cards.size()==scene.db.data.charge.size() and panel.cards.size()>6,"All configured systems are generated")
	check(panel.cards[key].title==identity and scene.equipment_tabs==tabs,"Extension preserves unrelated card/tab identity")
	check(panel.modules.get_child(-1)==panel.extension,"Extension slot remains at tail")
	check(panel.scroll.get_h_scroll_bar().max_value>panel.scroll.size.x,"Many systems enable horizontal scrolling")
	check(panel.page_label.text=="1 / 3","Page count includes the extension slot")
	await click(panel.next_button)
	check(panel.scroll.scroll_horizontal>0,"Actual next-page button scrolls modules")
	check(panel.page_label.text=="2 / 3","Page label follows actual next-page click")
	check_geometry(panel,"next page")
	await click(panel.previous_button)
	check(panel.scroll.scroll_horizontal==0,"Actual previous-page button returns to first modules")
	panel.scroll.ensure_control_visible(panel.extension)
	await process_frame
	await process_frame
	await shot("charge-extension")
	before=scene.game.profile.duplicate(true)
	await click(panel.extension)
	check(panel.hint.text==UIText.t("charge.extension_hint") and before==scene.game.profile,"Extension slot explains configuration without inventing a game system")
	panel.scroll.scroll_horizontal=300
	var scroll_position: int = panel.scroll.scroll_horizontal
	panel.refresh_card(key)
	check(panel.scroll.scroll_horizontal==scroll_position,"Value refresh preserves scrolling")
	check_geometry(panel,"partial scroll")
	scene.equipment_tabs.current_tab=0
	await process_frame
	check(not panel.cards[key].circuit.is_processing(),"Hidden page stops continuous rendering")
	scene.equipment_tabs.current_tab=2
	scene.game.paused=true
	scene.refresh_visible_cards()
	check(not panel.cards[key].circuit.is_processing(),"Global pause stops circuit animation")
	await process_frame
	await RenderingServer.frame_post_draw
	var draw_count := [0]
	panel.cards[key].circuit.draw.connect(func():draw_count[0]+=1)
	scene.changed_controls.clear()
	for i in range(3):
		scene.refresh_visible_cards()
		await process_frame
	await RenderingServer.frame_post_draw
	check(scene.changed_controls.is_empty() and draw_count[0]==0,"Unchanged paused page causes no property writes or circuit redraws")
	scene.game.paused=false
	scene.refresh_visible_cards()
	panel.scroll.scroll_horizontal=0
	panel.select_module(key)
	await shot("charge-expanded")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1280,960)]:
		root.size=resolution
		await create_timer(0.3).timeout
		await shot("charge-%dx%d" % [resolution.x,resolution.y])
		print("Requested ",resolution," window ",root.size," rendered ",root.get_texture().get_size())
		check(panel.get_global_rect().encloses(panel.detail.button.get_global_rect()),"Details stay inside page at "+str(resolution))
		check_geometry(panel,str(resolution))
	# Remove extra configuration locally; retain original instances and selection.
	for extra in scene.db.data.charge.keys().duplicate():
		if extra.begins_with("fixture_system_"):
			scene.db.data.charge.erase(extra)
			scene.db.data.unlock.erase(extra)
			scene.game.profile.charge.erase(extra)
	panel.sync_modules()
	panel.scroll.scroll_horizontal=0
	root.size=Vector2i(1440,810)
	await shot("charge-current")
	check(panel.cards.size()==initial_count and panel.cards[key].title==identity,"Removing fixtures preserves actual systems")
	# Stress only the display with in-memory jobs, without adding economic rules.
	for count in [10,20,30]:
		for index in range(initial_count,count):
			var extra := "polish_system_%d" % index
			if scene.db.data.charge.has(extra):
				continue
			scene.db.data.charge[extra]=row.duplicate(true)
			scene.db.data.unlock[extra]={"type":"charge","target":extra,"level":0,"mode":"cleared"}
			scene.game.profile.charge[extra]={"level":0,"count":0.0,"elapsed":1.0,"active":true,"started":index+1,"credit":0.0}
		panel.sync_modules()
		await process_frame
		await process_frame
		panel.refresh_core()
		check(panel.cards.size()==count and panel.page_count()==ceili(float(count+1)/6),"Dynamic pagination at %d systems" % count)
		check(panel.modules.get_child(-1)==panel.extension,"Extension remains last at %d systems" % count)
		check_geometry(panel,"%d systems" % count)
		panel.turn_page(100)
		await process_frame
		check(panel.current_page()==panel.page_count() and panel.next_button.disabled,"Last-page controls clamp correctly at %d systems" % count)
		panel.turn_page(-100)
		await process_frame
		panel.refresh_core()
		var running := 0
		for controls in panel.cards.values():
			if controls.circuit.is_processing():
				running += 1
		check(running<=7,"Offscreen pipeline animation stops at %d systems" % count)
	var saved_profile: Dictionary = scene.game.profile.duplicate(true)
	var started := Time.get_ticks_usec()
	for iteration in range(300):
		scene.refresh_visible_cards()
	var refresh_us := (Time.get_ticks_usec()-started)/300.0
	print("Thirty-system visible refresh average: %.1f us" % refresh_us)
	check(scene.game.profile==saved_profile,"Visual refresh cannot write game state")
	check(refresh_us<16000,"Thirty-system refresh stays within a sixty-Hz frame budget")
	var resource_fixture: String = "polish_system_%d" % initial_count
	scene.db.data.charge[resource_fixture].para_1=1
	panel.refresh_core()
	check(panel.core_metrics().has("1") and panel.energy_rows.size()==2,"Distinct resources receive separate balances and flow metrics")
	var energy_identity: Label = panel.energy_rows[id].available
	scene.db.data.charge[resource_fixture].para_1=int(id)
	panel.refresh_core()
	check(panel.energy_rows.size()==1 and panel.energy_rows[id].available==energy_identity,"Removing a resource dependency preserves unaffected energy controls")
	var counter := [0]
	var gauge_counter := [0]
	var static_counter := [0]
	panel.core_feed.draw.connect(func():counter[0]+=1)
	panel.cards[key].circuit.draw.connect(func():gauge_counter[0]+=1)
	panel.draw.connect(func():static_counter[0]+=1)
	await create_timer(0.25).timeout
	counter[0]=0
	gauge_counter[0]=0
	static_counter[0]=0
	var deadline := Time.get_ticks_msec()+1000
	while Time.get_ticks_msec()<deadline:
		scene.game.advance_charge(1.0/60.0)
		scene.refresh_visible_cards()
		await process_frame
	check(counter[0]>0 and counter[0]<=33 and static_counter[0]==0,"Flow renders at most thirty Hz without redrawing the static panel")
	check(gauge_counter[0]>0 and gauge_counter[0]<=33,"Changing charge progress does not bypass the gauge animation cap")
	print("Feed draws over one second: ",counter[0],"; gauge draws: ",gauge_counter[0],"; static panel draws: ",static_counter[0])
	panel.select_module(key)
	scene.game.profile.resources[id]=0
	job.credit=0
	scene.refresh_visible_cards()
	await shot("charge-warning")
	scene.game.profile.resources[id]=1000
	job.active=false
	scene.refresh_visible_cards()
	await shot("charge-paused")
	job.active=true
	scene.refresh_visible_cards()
	await shot("charge-thirty")
	# Cross a real game round, then allow only visual time to pass.
	job.elapsed=float(row.para_4)-0.02
	panel.refresh_card(key)
	scene.game.advance_charge(0.04)
	panel.refresh_card(key)
	var gauge = panel.cards[key].circuit
	check(gauge.completion_remaining>0 and is_equal_approx(gauge.display_progress,gauge.progress),"A completed game round starts actual new progress immediately, with an independent accent")
	var after_round: Dictionary = scene.game.profile.duplicate(true)
	await shot("charge-round-complete")
	await create_timer(0.3).timeout
	check(gauge.completion_remaining==0 and is_equal_approx(gauge.display_progress,gauge.progress),"Completion feedback returns to actual progress within 300 ms")
	check(scene.game.profile==after_round,"Completion animation never changes the game profile")
	var network = panel.core_feed
	var flow_before: float = network.routes[key].distance
	await create_timer(0.1).timeout
	check(network.routes[key].distance!=flow_before,"Packets advance along the baked core-to-module path")
	job.active=false
	panel.refresh_card(key)
	flow_before=network.routes[key].distance
	await create_timer(0.1).timeout
	check(network.routes[key].distance==flow_before,"Paused module packets retain their position")
	var old_position: Vector2 = gauge.position
	gauge.position+=Vector2(13,9)
	check_geometry(panel,"moved instrument")
	gauge.position=old_position
	panel.refresh_animation_visibility()
	print("Charge panel: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
