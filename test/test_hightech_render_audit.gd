extends SceneTree
## Isolated diagnostic. Counts writes, CanvasItem redraws and polling separately.
## CPU timings include counter instrumentation, not GPU time or whole-game FPS.
class AuditedUI extends "res://scripts/main.gd":
	var auditing := false
	var calls := {"scientists":0,"card":0,"progress":0,"property_checks":0,"writes":0,"snapshots":0,"builds":0}
	func refresh_scientists() -> void:
		if auditing:calls.scientists+=1
		super.refresh_scientists()
	func refresh_hightech_card(key: String) -> void:
		if auditing:calls.card+=1
		super.refresh_hightech_card(key)
	func refresh_hightech_progress(key: String) -> void:
		if auditing:calls.progress+=1
		super.refresh_hightech_progress(key)
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if auditing:
			calls.property_checks+=1
			if control.get(property)!=value:calls.writes+=1
		super.set_ui_value(control,property,value)
	func ui_state_changed(control: Node, state: Array) -> bool:
		var changed := super.ui_state_changed(control,state)
		if auditing and changed:calls.snapshots+=1
		return changed
	func build_ui() -> void:
		if auditing:calls.builds+=1
		super.build_ui()

var scene: AuditedUI
var measuring := false
var draws := {"geometry":0,"art":0,"fx":0,"labels":0,"cards":0,"offscreen_geometry":0,"offscreen_art":0,"offscreen_fx":0,"background":0}
var observations: Array=[]
var render_breakdown: Array=[]
var count := 4
var checks := 0
var failures := 0
const FRAMES := 120

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func count_draw(kind: String, construction: Control=null) -> void:
	if not measuring:return
	draws[kind]+=1
	if construction!=null and not construction.active_in_view():draws["offscreen_"+kind]+=1

func wire_cards() -> void:
	for key in scene.hightech_progress:
		var c: Dictionary=scene.hightech_progress[key]
		if c.construction.has_meta("audit_wired"):continue
		c.construction.set_meta("audit_wired",true)
		c.construction.draw.connect(count_draw.bind("geometry",c.construction))
		if c.construction.art!=null:c.construction.art.draw.connect(count_draw.bind("art",c.construction))
		c.construction.effects.draw.connect(count_draw.bind("fx",c.construction))
		scene.hightech_titles[key].get_parent().draw.connect(count_draw.bind("cards"))
		for field in ["label","state","percent","workers"]:c[field].draw.connect(count_draw.bind("labels"))

func count_nodes(node: Node) -> int:
	var result := 1
	for child in node.get_children():result+=count_nodes(child)
	return result

func extend_to(amount: int) -> void:
	for i in range(count,amount):
		var key := "audit_tech_%03d" % i
		scene.db.data.hightech[key]=scene.db.data.hightech[BattleGame.FURNACE].duplicate(true)
		scene.db.data.hightech[key].name=key
		scene.db.data.unlock[key]={"type":"hightech","target":key,"level":0,"mode":"cleared"}
		UIText.bindings.hightech[key]=UIText.bindings.hightech[BattleGame.FURNACE].duplicate(true)
	count=amount
	scene.sync_hightech_slots()
	wire_cards()

func uniform_totals() -> Vector2i:
	var result := Vector2i.ZERO
	for controls: Dictionary in scene.hightech_progress.values():
		result+=Vector2i(controls.construction.progress_writes,controls.construction.energy_writes)
	return result

func benchmark(mode: String, repetition: int) -> void:
	measuring=false
	scene.auditing=false
	scene.game.paused=mode=="paused"
	scene.game.profile.scientists=count*17+4
	for key in scene.hightech_progress:
		scene.game.profile.hightechLevels[key]=20
		scene.game.profile.scientistAssignments[key]=0 if mode=="idle" else 17
		scene.game.profile.techPoints[key]=scene.game.hightech_required(key)*0.3
		var building=scene.hightech_progress[key].construction
		building.completed=0
		building.completion_cooldown=0
		building.sample=0
		scene.refresh_hightech_card(key)
	scene.equipment_tabs.current_tab=0 if mode=="hidden" else 1
	scene.hightech_scroll.scroll_horizontal=0
	scene.refresh_scientists()
	for i in 8:
		scene.refresh_visible_cards(1.0/60.0)
		await process_frame
	for key in draws:draws[key]=0
	for key in scene.calls:scene.calls[key]=0
	var times: Array[int]=[]
	var uniforms_before := uniform_totals()
	var memory_start := OS.get_static_memory_usage()
	var wall_started := Time.get_ticks_usec()
	var monitor: float=0
	scene.auditing=true
	measuring=true
	for i in FRAMES:
		if mode in ["active","resources","hidden"]:
			# Real research step only; exclude unrelated combat from this probe.
			scene.game.advance_hightech(1.0/60.0)
		if mode=="resources":scene.game.profile.resources["1"]+=100
		var began := Time.get_ticks_usec()
		scene.refresh_visible_cards(1.0/60.0)
		times.append(Time.get_ticks_usec()-began)
		await process_frame
		monitor+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	measuring=false
	scene.auditing=false
	times.sort()
	var total := 0
	for value in times:total+=value
	var uniforms := uniform_totals()-uniforms_before
	var record := {"technologies":count,"mode":mode,"repeat":repetition,"frames":FRAMES,
		"refresh_us_mean":float(total)/FRAMES,"refresh_us_p95":times[int(FRAMES*0.95)],
		"calls":scene.calls.duplicate(),"canvas_redraws":draws.duplicate(),
		"shader_uniform_writes":{"progress":uniforms.x,"energy":uniforms.y},
		"whole_viewport_draw_calls_mean":monitor/FRAMES,"research_nodes":count_nodes(scene.hightech_page),
		"process_static_memory_bytes":OS.get_static_memory_usage(),"process_memory_delta_bytes":OS.get_static_memory_usage()-memory_start,"wall_seconds":(Time.get_ticks_usec()-wall_started)/1000000.0}
	observations.append(record)
	print(JSON.stringify(record))
	check(scene.calls.builds==0,"No full UI rebuild during research")
	check(draws.cards==0 and draws.background==0,"Research never redraws ancestor cards or static background")
	check(draws.offscreen_geometry==0 and draws.offscreen_art==0 and draws.offscreen_fx==0,"Offscreen research surfaces do not redraw")
	if mode in ["paused","idle","hidden"]:
		check(draws.geometry==0 and draws.art==0 and draws.fx==0 and uniforms==Vector2i.ZERO and scene.calls.writes==0,"Stationary or hidden research has no writes/redraws")

func run() -> void:
	Engine.max_fps=60
	var first := preload("res://scripts/hightech_construction.gd").new()
	var began := Time.get_ticks_usec()
	first.setup(BattleGame.FURNACE)
	var plan_bake_us := Time.get_ticks_usec()-began
	first.free()
	scene=AuditedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.rebuild_unlocks()
	scene.game.profile.hightechOrder=[]
	scene.game.profile.resources={"1":1e12,"2":1e12}
	scene.build_ui()
	var qa := root.get_node_or_null("QATools")
	if qa!=null:qa.hide()
	scene.background_layer.draw.connect(count_draw.bind("background"))
	wire_cards()
	var detail_only := OS.get_environment("HIGHTECH_AUDIT_ONLY_DETAIL")=="1"
	for amount in ([4] if detail_only else [4,40,120]):
		extend_to(amount)
		for repetition in (1 if detail_only else 3):
			for mode in (["paused"] if detail_only else ["paused","idle","active","resources","hidden"] if amount==4 else ["active","resources","hidden"]):
				await benchmark(mode,repetition)
	# Known edge case: completion cooldown continues after all AI are recalled.
	scene.equipment_tabs.current_tab=1
	scene.game.paused=false
	var c=scene.hightech_progress[BattleGame.FURNACE].construction
	c.set_workers(0)
	c.completed=0
	c.completion_cooldown=1.5
	await process_frame
	await RenderingServer.frame_post_draw
	var empty_draws := [0]
	var count_empty := func():empty_draws[0]+=1
	c.effects.draw.connect(count_empty)
	for i in 60:
		c.advance(1.0/60.0,false)
		await process_frame
	await RenderingServer.frame_post_draw
	c.effects.draw.disconnect(count_empty)
	check(empty_draws[0]==0,"No effects redraw for a workerless completion cooldown")
	for key in scene.db.data.hightech.keys():
		if str(key).begins_with("audit_tech_"):
			scene.db.data.hightech.erase(key)
			scene.db.data.unlock.erase(key)
			UIText.bindings.hightech.erase(key)
	scene.sync_hightech_slots()
	scene.hightech_scroll.scroll_horizontal=0
	scene.game.paused=true
	scene.refresh_visible_cards()
	await process_frame
	for variant in ["full","no_fx","no_construction","no_battle"]:
		for key in scene.hightech_progress:
			var building=scene.hightech_progress[key].construction
			building.completed=0
			building.set_workers(17)
			building.set_fraction(0.3)
			building.visible=variant!="no_construction"
			building.effects.visible=variant not in ["no_fx","no_construction"]
		scene.battle_layer.visible=variant!="no_battle"
		for i in 5:await process_frame
		var draw_calls := 0.0
		for i in 30:
			await process_frame
			draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		render_breakdown.append({"variant":variant,"draw_calls":draw_calls/30.0})
	scene.battle_layer.visible=true
	scene.game.paused=false
	scene.refresh_draw_layers(1.0/60.0)
	await process_frame
	var covered_battle_draws := [0]
	scene.battle_layer.draw.connect(func():covered_battle_draws[0]+=1)
	for i in 60:
		scene.refresh_draw_layers(1.0/60.0)
		await process_frame
	check(covered_battle_draws[0]==0 and not scene.battle_layer.visible,"Covered battlefield does not render")
	var inventory := {"parts":0,"vertices":0}
	for key in scene.hightech_progress:
		var building=scene.hightech_progress[key].construction
		inventory.parts+=building.parts.size()
		for part in building.parts:inventory.vertices+=part.size()
	var report := {"first_setup_and_four_plan_bake_us":plan_bake_us,"shared_atlas_rgba_bytes":1254*1254*4,"scope":"Research refresh and CanvasItem callbacks with 60 FPS cap; synthetic 40/120 technology fixtures; CPU includes counters, whole viewport draw calls are not GPU milliseconds.","observations":observations,"empty_cooldown_fx_redraws_in_60_frames":empty_draws[0],"inventory_at_4":inventory,"four_bay_render_breakdown":render_breakdown,"covered_battle_redraws_in_60_frames":covered_battle_draws[0],"checks":checks,"failures":failures}
	var file := FileAccess.open("res://.runtime/hightech-render-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("Hightech render audit: %d checks, %d failures; empty cooldown redraws=%d" % [checks,failures,empty_draws[0]])
	quit(1 if failures else 0)
