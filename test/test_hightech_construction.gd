extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	var builds := 0
	var inspected: Array = []
	var progress_calls := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		inspected.append(control)
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds+=1
		super.build_ui()
	func refresh_hightech_progress(key: String) -> void:
		progress_calls+=1
		super.refresh_hightech_progress(key)

var checks := 0
var failures := 0
var scene
var view: SubViewport
var mouse := Vector2.ZERO

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func frames() -> void:
	await process_frame
	await process_frame

func motion(pos: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position=pos
	event.global_position=pos
	event.relative=pos-mouse
	mouse=pos
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	view.push_input(event,true)
	await frames()

func press(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=mouse
	event.global_position=mouse
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	view.push_input(event,true)
	await frames()

func click(control: Control) -> void:
	await motion(control.get_global_rect().get_center())
	await press(true)
	await press(false)

func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/"+name+".png")

func run() -> void:
	view=SubViewport.new()
	view.size=Vector2i(2048,1280)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	scene=TrackedUI.new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.rebuild_unlocks()
	scene.game.profile.hightechOrder=[]
	scene.game.profile.scientists=49
	scene.game.profile.resources={"1":1e12,"2":1e12}
	var keys: Array=scene.db.data.hightech.keys()
	var fractions := [0.28,0.64,0.88,0.46]
	for i in keys.size():
		scene.game.profile.hightechLevels[keys[i]]=20+i
		scene.game.profile.scientistAssignments[keys[i]]=11
		scene.game.profile.techPoints[keys[i]]=scene.game.hightech_required(keys[i])*fractions[i]
	scene.build_ui()
	scene.equipment_tabs.current_tab=1
	await frames()
	scene.refresh_visible_cards(0.1)
	await frames()
	check(scene.hightech_selected.is_empty() and scene.hightech_inspector.overview.visible,"Entry shows overview without selecting a building")
	check(scene.scientist_summary.text.contains("待命 5") and scene.scientist_generate_button.is_visible_in_tree(),"AI total and creation actions are directly visible on entry")
	check(scene.hightech_page.find_children("*","Button",true,false).filter(func(b):return b.text==UIText.t("research.dock_distribute")).size()==1,"The entire page contains exactly one distribute AI action")
	check(scene.hightech_inspector.details.values().all(func(d):return not d.panel.visible),"Unselected entry hides all building details")
	check(keys.size()==4 and scene.hightech_progress.size()==4,"All four configured technologies have construction bays")
	check(scene.equipment_tabs.position==scene.WORK_CONTENT_RECT.position and scene.hightech_page.size.y>600,"Research stays inside the shared workspace")
	var identities: Array=[]
	var shapes: Array=[]
	for i in keys.size():
		var controls: Dictionary=scene.hightech_progress[keys[i]]
		var building=controls.construction
		identities.append(scene.hightech_titles[keys[i]].get_parent())
		shapes.append(building.shape)
		check(building.active_in_view(),"All four bays initially visible")
		check(not controls.has("bar") and not controls.has("workers") and controls.state.text.contains("%"),"Station retains merged state and one auxiliary label without redundant bars or AI counts")
		check(is_equal_approx(building.fraction,fractions[i]) and building.built>0 and building.built<building.parts.size(),"Partial building follows real points")
		check(scene.hightech_scroll.get_global_rect().encloses(identities[i].get_global_rect()),"Whole bay and controls fit viewport")
	check(shapes==["furnace","focus","armour","crystal"],"Four distinct silhouettes include jewel furnace")
	var pixels: Image=scene.hightech_progress[keys[0]].construction.ART.get_image()
	var cell_size := pixels.get_size()/2
	for key in keys:
		var c=scene.hightech_progress[key].construction
		check(c.art!=null and c.art.texture==scene.hightech_progress[keys[0]].construction.art.texture,"All official bays share the approved atlas")
		check(c.art.size==Vector2(296,296) and Rect2(Vector2.ZERO,c.size).encloses(c.art.get_rect()),"Artwork stays inside its own bay without covering controls")
		var valid_sites := true
		var valid_map := true
		var seen: Dictionary={}
		for y in c.order_map.get_height():
			for x in c.order_map.get_width():
				var index := int(c.order_map.get_pixel(x,y).r)
				valid_map=valid_map and index>=0 and index<c.parts.size()
				seen[index]=true
		for index in c.work_sites.size():
			for target: Vector2 in c.work_sites[index]:
				var uv: Vector2=target/c.ART_SIZE
				var ink := pixels.get_pixelv(c.atlas_cell*cell_size+Vector2i(uv*Vector2(cell_size)))
				var rank := int(c.order_map.get_pixelv(Vector2i(uv*Vector2(c.MAP_SIZE))).r)
				valid_sites=valid_sites and ink.a>0.55 and maxf(ink.r,maxf(ink.g,ink.b))>0.5 and rank==index
		check(valid_map and seen.size()==c.parts.size(),"Assembly map covers the whole artwork with valid component order: "+key)
		check(valid_sites,"All AI targets land on actual structural ink in their own assembly region: "+key)
	var furnace=scene.hightech_progress[BattleGame.FURNACE].construction
	var last_only_filaments := true
	var last_pixels := 0
	var local_phases: Dictionary={}
	for y in furnace.order_map.get_height():
		for x in furnace.order_map.get_width():
			var order: float=furnace.order_map.get_pixel(x,y).r
			local_phases[int(fposmod(order,1)*100)]=true
			if int(order)!=furnace.parts.size()-1:continue
			last_pixels+=1
			var uv := (Vector2(x,y)+Vector2(0.5,0.5))/float(furnace.MAP_SIZE.x)
			var ink := pixels.get_pixelv(Vector2i(uv*Vector2(cell_size)))
			last_only_filaments=last_only_filaments and ink.a>0.90 and ink.r>0.85 and ink.g>0.55
	check(last_pixels>20 and last_only_filaments,"Final furnace construction affects real bright filaments, never a dark rectangular column")
	check(local_phases.size()>30,"Components contain varied fixed reveal thresholds instead of uniform rectangular fades")
	for key in keys:
		var c=scene.hightech_progress[key].construction
		c.set_fraction((c.parts.size()-1+0.25)/c.parts.size())
		var early: Vector2=c.work_target(0)
		c.set_fraction((c.parts.size()-1+0.75)/c.parts.size())
		check(c.work_target(0)!=early,"Workers follow changing growth sites inside the same component: "+key)
		c.set_fraction(fractions[keys.find(key)])
	var armour=scene.hightech_progress[BattleGame.DENSE_ARMOUR].construction
	var whole_cells := true
	for row in 5:
		for col in (4 if row%2==0 else 3):
			var center := Vector2(0.263+col*0.164+(0.082 if row%2 else 0.0),0.212+row*0.135)
			var expected := int(armour.order_map.get_pixelv(Vector2i(center*Vector2(armour.MAP_SIZE))).r)
			for offset in [Vector2(-0.045,0),Vector2(0.045,0),Vector2(0,-0.045),Vector2(0,0.045)]:
				whole_cells=whole_cells and int(armour.order_map.get_pixelv(Vector2i((center+offset)*Vector2(armour.MAP_SIZE))).r)==expected
	check(whole_cells,"Armour reveals whole hexagonal plates rather than horizontal slices")
	var crystal=scene.hightech_progress[BattleGame.JEWEL_FURNACE].construction
	var whole_crystals := true
	for points in [[Vector2(0.50,0.16),Vector2(0.45,0.30),Vector2(0.56,0.30),Vector2(0.5,0.48)],[Vector2(0.27,0.42),Vector2(0.245,0.50),Vector2(0.3,0.50),Vector2(0.27,0.60)],[Vector2(0.73,0.42),Vector2(0.70,0.50),Vector2(0.76,0.50),Vector2(0.73,0.60)]]:
		var expected := int(crystal.order_map.get_pixelv(Vector2i(points[0]*Vector2(crystal.MAP_SIZE))).r)
		for point: Vector2 in points:whole_crystals=whole_crystals and int(crystal.order_map.get_pixelv(Vector2i(point*Vector2(crystal.MAP_SIZE))).r)==expected
	check(whole_crystals,"Each floating crystal grows as one complete faceted component")
	# Progress jumps must select the same region used by the shader; targets
	# are measured against actual texture pixels above, not a synthetic outline.
	for i in keys.size():
		var c=scene.hightech_progress[keys[i]].construction
		for fraction in [0.0,0.1,0.28,0.46,0.64,0.88,0.999]:
			c.set_fraction(fraction)
			var expected := int(floorf(fraction*c.parts.size()))
			var on_component := true
			for worker in 3:
				var uv: Vector2=c.work_target(worker)/c.ART_SIZE
				var rank := int(c.order_map.get_pixelv(Vector2i(uv*Vector2(c.MAP_SIZE))).r)
				on_component=on_component and rank==expected
			check(on_component,"Every worker lands on the active component: %s at %s" % [keys[i],fraction])
		c.set_fraction(1)
		check(c.work_target(0)==Vector2.ZERO,"Finished geometry has no speculative construction target")
		c.set_fraction(fractions[i])
	# Compact instrument plates keep descriptions below each building.
	var idle_key: String=keys[-1]
	scene.game.profile.scientistAssignments[idle_key]=0
	scene.refresh_scientists()
	scene.refresh_hightech_progress(idle_key)
	check(scene.hightech_buttons[idle_key].text==UIText.t("upgrade.build_hightech_card.text_04"),"Unified local control allocates one AI to start construction")
	for key in keys:scene.hightech_progress[key].construction.advance(0.6,false)
	await capture("hightech-dock-mixed")
	for key in keys:
		var overlay: Label=scene.hightech_descriptions[key]
		check(overlay.visible and overlay.text==preload("res://scripts/hightech_presentation.gd").effect_text(scene.game,key),"Effect shows its technology's value template")
		check(overlay.size==Vector2(344,40) and overlay.max_lines_visible==2 and overlay.clip_text,"Effect stays within its fixed compact area")
		check(overlay.get_parent()==scene.hightech_titles[key].get_parent() and overlay.position.y>=scene.hightech_progress[key].construction.get_rect().end.y,"Effect stays below its building without an opaque overlay")
	check(scene.hightech_page.find_children("*","Button",true,false).all(func(b):return b.text!="效果展示"),"Effect preview action is removed")
	await capture("hightech-nameplates")
	check(scene.hightech_page.find_children("*","OptionButton",true,false).is_empty(),"Filter and sort controls are removed")
	check(scene.hightech_management.visible and scene.scientist_summary.is_visible_in_tree(),"Global AI controls remain visible without an extra popup")
	check(not scene.hightech_buttons[idle_key].visible,"Idle unselected station also hides allocation controls")
	await click(scene.hightech_progress[idle_key].construction)
	await frames()
	await click(scene.hightech_buttons[idle_key])
	check(scene.game.assigned_scientists(idle_key)==1,"Selected idle station starts through real AI assignment")
	scene.select_hightech_bay("")
	for i in keys.size():check(scene.hightech_titles[keys[i]].get_parent()==identities[i],"Effect toggle preserves station identity")
	scene.game.profile.scientistAssignments[idle_key]=11
	scene.refresh_scientists()
	scene.refresh_hightech_progress(idle_key)
	await capture("hightech-four-bays")
	check(scene.battle_layer.visible,"Battlefield remains visible beside research")
	scene.refresh_scientists()
	scene.inspected.clear()
	scene.game.profile.resources["1"]+=100
	scene.refresh_scientists()
	check(not scene.inspected.has(scene.scientist_summary) and not scene.inspected.has(scene.scientist_cost_label),"Income skips AI summary and unchanged cost checks")
	for key in keys:
		check(not scene.inspected.has(scene.hightech_buttons[key]) and not scene.inspected.has(scene.scientist_remove_buttons[key]),"Income skips deployment checks: "+key)
	for key in keys:
		var c=scene.hightech_progress[key].construction
		c.celebrate()
		c.advance(0.25,false)
		scene.refresh_hightech_card(key)
		check(c.work_target(0)==Vector2.ZERO,"Acceptance scan suppresses construction targets")
	await capture("hightech-all-completed")
	var probe=scene.hightech_progress[keys[0]].construction
	for progress in [0.0,0.15,0.5,0.85,0.96,0.99,1.0]:
		for key in keys:
			var c=scene.hightech_progress[key].construction
			c.completed=0
			scene.game.profile.techPoints[key]=scene.game.hightech_required(key)*progress
			scene.refresh_hightech_card(key)
		await capture("hightech-stage-%03d" % int(progress*100))
		if progress==0.96:
			view.get_texture().get_image().get_region(Rect2i(identities[0].get_global_rect())).save_png("res://.runtime/hightech-furnace-096.png")
	probe.set_fraction(0.85)
	probe.effects.hide()
	await frames()
	await RenderingServer.frame_post_draw
	var still: PackedByteArray=view.get_texture().get_image().get_region(Rect2i(probe.get_global_rect())).get_data()
	probe.advance(0.8,false)
	await frames()
	await RenderingServer.frame_post_draw
	var moving: PackedByteArray=view.get_texture().get_image().get_region(Rect2i(probe.get_global_rect())).get_data()
	check(still!=moving,"Energy phase visibly changes artwork independently of hidden construction drones")
	probe.effects.show()

	for i in keys.size():
		var c=scene.hightech_progress[keys[i]].construction
		c.completed=0
		c.completion_cooldown=0
		scene.game.profile.techPoints[keys[i]]=scene.game.hightech_required(keys[i])*fractions[i]
		c.set_fraction(fractions[i])
		scene.refresh_hightech_card(keys[i])
	scene.refresh_visible_cards()
	scene.progress_calls=0
	for i in 60:scene.refresh_visible_cards(1.0/60.0)
	check(scene.progress_calls>=32 and scene.progress_calls<=40,"Progress is sampled at approximately 10 Hz per visible bay")
	var first: String=keys[0]
	var building=scene.hightech_progress[first].construction
	var builds: int=scene.builds
	var assignments: int=scene.game.assigned_scientists(first)
	check(scene.hightech_buttons.values().all(func(b):return not b.visible),"Active unselected bays hide allocation controls")
	await click(building)
	check(scene.hightech_selected==first and scene.hightech_buttons[first].visible and scene.scientist_remove_buttons[first].visible,"Click building selects station and reveals allocation")
	check(not scene.hightech_buttons[keys[1]].visible,"Other station controls stay hidden")
	check(scene.hightech_buttons[first].get_parent()==scene.hightech_inspector.details[first].panel and scene.hightech_management.get_parent()==scene.hightech_page,"Local allocation belongs to selected detail while global management remains independent")
	check(not scene.hightech_inspector.overview.visible and scene.hightech_inspector.details[first].effect.text==preload("res://scripts/hightech_presentation.gd").effect_text(scene.game,first),"Selected detail shows the effect template")
	await capture("hightech-dock-selected")
	await click(building)
	check(scene.hightech_selected.is_empty() and scene.hightech_inspector.overview.visible,"Click selected building returns to overview")
	check(scene.hightech_management.visible and scene.scientist_bulk_buttons[10].is_visible_in_tree() and scene.scientist_bulk_buttons[-1].is_visible_in_tree(),"All global AI creation quantities stay visible after deselection")
	await click(building)
	await motion(scene.hightech_page.global_position+Vector2(4,4))
	await press(true)
	await press(false)
	check(scene.hightech_selected.is_empty() and scene.hightech_inspector.overview.visible,"Click blank header cancels selection")
	await click(building)
	var left_bay: Rect2=scene.hightech_titles[first].get_parent().get_global_rect()
	var right_bay: Rect2=scene.hightech_titles[keys[1]].get_parent().get_global_rect()
	await motion(Vector2((left_bay.end.x+right_bay.position.x)/2,left_bay.get_center().y))
	await press(true)
	await press(false)
	check(scene.hightech_selected.is_empty(),"Shared floor between stations cancels selection")
	await click(building)
	await click(scene.hightech_buttons[first])
	check(scene.game.assigned_scientists(first)==assignments+1,"Real mouse assigns AI")
	check(building.assigned==assignments+1 and scene.scientist_summary.text.contains("待命 4"),"Assignment updates construction and shared idle count")
	await click(scene.scientist_remove_buttons[first])
	check(scene.game.assigned_scientists(first)==assignments,"Real mouse recalls AI")
	check(scene.hightech_management.visible and scene.scientist_generate_button.is_visible_in_tree(),"Selection never hides global AI controls")
	await capture("hightech-ai-management")
	await click(scene.scientist_generate_button)
	check(scene.game.profile.scientists==50,"Real mouse creates AI")
	await click(scene.scientist_distribute_button)
	check(scene.game.idle_scientists()==0 and scene.hightech_buttons.values().all(func(b):return b.disabled),"Average distribution updates all dependent buttons")
	check(scene.hightech_management.visible and scene.hightech_selected==first,"Global operations preserve selected building and remain visible")
	check(scene.builds==builds,"AI operations never rebuild UI")
	for i in keys.size():check(scene.hightech_titles[keys[i]].get_parent()==identities[i],"Unrelated bay identity retained")
	var draws := {"geometry":0,"fx":0,"card":0,"other":0,"background":0}
	building.draw.connect(func():draws.geometry+=1)
	building.effects.draw.connect(func():draws.fx+=1)
	identities[0].draw.connect(func():draws.card+=1)
	scene.hightech_progress[keys[1]].construction.draw.connect(func():draws.other+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	await motion(Vector2(30,80))
	await frames()
	for key in draws:draws[key]=0
	scene.writes.clear()
	for i in 3:
		scene.refresh_visible_cards(0.05)
		await frames()
	check(draws.fx>0 and draws.geometry==0 and draws.card==0 and draws.other==0 and draws.background==0,"Continuous workers redraw only independent FX")
	check(scene.writes.is_empty(),"Animation never rewrites unchanged labels")
	scene.game.paused=true
	scene.refresh_visible_cards()
	await frames()
	for key in draws:draws[key]=0
	scene.writes.clear()
	var phase: float=building.phase
	var uniforms: int=building.progress_writes+building.energy_writes
	for i in 3:
		scene.refresh_visible_cards(0.1)
		await frames()
	check(draws.values().all(func(n):return n==0) and scene.writes.is_empty() and building.phase==phase and building.progress_writes+building.energy_writes==uniforms,"Paused research has zero writes and redraws")
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)*0.71
	scene.refresh_hightech_card(first)
	await frames()
	check(draws.geometry==0 and draws.other==0 and is_equal_approx(building.fraction,0.71) and is_equal_approx(building.art_material.get_shader_parameter("progress"),0.71),"Point change updates target shader without rebuilding static geometry")
	check(draws.fx==1,"Paused progress jump updates retained worker positions in the same frame")
	var component: int=building.built
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)*(component+0.2)/building.parts.size()
	scene.refresh_hightech_card(first)
	await frames()
	var previous_target: Vector2=building.work_target(0)
	for key in draws:draws[key]=0
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)*(component+0.8)/building.parts.size()
	scene.refresh_hightech_card(first)
	await frames()
	check(building.built==component and building.work_target(0)!=previous_target and draws.fx==1 and draws.geometry==0 and draws.other==0,"Paused same-component progress updates the growth frontier without unrelated redraws")

	scene.equipment_tabs.current_tab=0
	await frames()
	check(scene.battle_layer.visible,"Returning restores battlefield immediately")
	for key in draws:draws[key]=0
	scene.writes.clear()
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)*0.83
	scene.refresh_visible_cards(1)
	await frames()
	check(draws.values().all(func(n):return n==0) and scene.writes.is_empty(),"Hidden page stops per-frame refresh and drawing")
	scene.equipment_tabs.current_tab=1
	await frames()
	check(is_equal_approx(building.fraction,0.83),"Return refreshes latest authoritative progress")
	scene.game.paused=false
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)-0.01
	scene.game.advance_hightech(0.01)
	check(building.completed>0 and building.built==building.parts.size(),"Real research completion shows entire finished building")
	await capture("hightech-completed")
	var original_hold: float=building.completed
	building.celebrate()
	check(building.completed==original_hold,"Repeated completions do not restart completion animation")
	scene.game.paused=true
	var hold: float=building.completed
	scene.refresh_visible_cards(0.5)
	check(building.completed==hold,"Pause freezes completion sweep")
	scene.game.paused=false
	for i in 15:scene.refresh_visible_cards(0.1)
	check(building.completed==0 and building.built<int(building.parts.size()),"Completion returns to current next-level construction without changing research")
	building.celebrate()
	check(building.completed==0,"Very fast research retains a visible building phase between celebrations")
	# A new data row needs no dedicated art or page branch.
	var extra := "test_future_hightech"
	scene.db.data.hightech[extra]=scene.db.data.hightech[first].duplicate(true)
	scene.db.data.hightech[extra].name=extra
	scene.db.data.unlock[extra]={"type":"hightech","target":extra,"level":0,"mode":"cleared"}
	scene.sync_hightech_slots()
	scene.refresh_scientists()
	await frames()
	check(scene.hightech_progress.has(extra) and scene.hightech_progress[extra].construction.shape=="prototype","Fifth configuration row receives generic construction automatically")
	check(scene.hightech_titles[first].get_parent()==identities[0] and scene.hightech_container.get_child_count()==5,"Expansion preserves original bays and adds exactly one station")
	scene.hightech_scroll.scroll_vertical=672
	await frames()
	check(not building.active_in_view() and scene.hightech_progress[extra].construction.active_in_view(),"Scrolling exposes new bay and culls offscreen construction")
	phase=building.phase
	uniforms=building.progress_writes+building.energy_writes
	scene.refresh_visible_cards(1)
	check(building.phase==phase and building.progress_writes+building.energy_writes==uniforms,"Offscreen effects and shader parameters stop advancing")
	await capture("hightech-expanded")
	# A gesture must no longer start a drag or change stored research order.
	scene.hightech_scroll.scroll_vertical=0
	await frames()
	var start: Vector2=identities[0].global_position+Vector2(110,18)
	var end: Vector2=identities[1].global_position+Vector2(110,18)
	var order: Array=scene.game.hightech_slots().duplicate()
	await motion(start)
	await press(true)
	await motion(start+Vector2(24,0),true)
	check(not view.gui_is_dragging(),"Research headers do not start drag operations")
	await motion(end,true)
	await press(false)
	await frames()
	check(scene.game.hightech_slots()==order and scene.hightech_titles[first].get_parent()==identities[0],"Pointer gesture leaves research order and bay identity intact")
	check(scene.hightech_scroll.scroll_vertical==0 and scene.builds==builds,"Pointer gesture and extension preserve scroll and full UI")
	# Resource changes keep keyboard focus and additional pages grow from data.
	scene.scientist_generate_button.grab_focus()
	scene.game.profile.resources["1"]+=1
	scene.refresh_scientists()
	check(view.gui_get_focus_owner()==scene.scientist_generate_button,"Shared resource refresh preserves keyboard focus")
	for i in 7:
		var key := "future_%d" % i
		scene.db.data.hightech[key]=scene.db.data.hightech[first].duplicate(true)
		scene.db.data.hightech[key].name=key
		scene.db.data.unlock[key]={"type":"hightech","target":key,"level":0,"mode":"cleared"}
	scene.sync_hightech_slots()
	scene.refresh_scientists()
	await frames()
	check(scene.hightech_inspector.details.size()==12,"New configured projects receive detail controls without hardcoded slots")
	check(scene.hightech_buttons.size()==12 and scene.hightech_container.get_child_count()==12,"Twelve technologies expand without empty drag slots")
	var fixed_ai_rect: Rect2=scene.hightech_management.get_global_rect()
	await capture("hightech-twelve-top")
	scene.hightech_scroll.scroll_vertical=100000
	await frames()
	var scroll: int=scene.hightech_scroll.scroll_vertical
	scene.refresh_scientists()
	check(scroll>0 and scene.hightech_scroll.get_global_rect().encloses(scene.hightech_container.get_child(-1).get_global_rect()) and scene.hightech_scroll.scroll_vertical==scroll,"Last construction bay remains fully reachable and resource refresh retains scrolling")
	check(scene.hightech_container.columns==2 and scene.hightech_scroll.scroll_horizontal==0,"Twelve projects remain in two columns without horizontal scrolling")
	check(scene.hightech_management.get_global_rect()==fixed_ai_rect and not fixed_ai_rect.intersects(scene.hightech_container.get_child(-1).get_global_rect()),"Global AI controls stay fixed without covering the final row")
	var last_key: String=scene.hightech_container.get_child(-1).get_meta("tech_key")
	await click(scene.hightech_progress[last_key].construction)
	check(scene.hightech_selected==last_key and scene.hightech_inspector.details[last_key].panel.is_visible_in_tree(),"Final row selects its own persistent detail")
	var last_workers: int=scene.game.assigned_scientists(last_key)
	scene.game.profile.scientists+=1
	scene.refresh_scientists()
	await click(scene.hightech_buttons[last_key])
	check(scene.game.assigned_scientists(last_key)==last_workers+1 and scene.hightech_scroll.scroll_vertical==scroll,"Real allocation on final row changes the right project without resetting scroll")
	await capture("hightech-twelve-bottom-selected")
	await click(scene.scientist_remove_buttons[last_key])
	scene.game.profile.scientists-=1
	scene.refresh_scientists()
	scene.select_hightech_bay("")
	scene.hightech_scroll.scroll_vertical=scroll/2
	await frames()
	await capture("hightech-twelve-middle")
	var middle_scroll: int=scene.hightech_scroll.scroll_vertical
	await motion(scene.hightech_scroll.get_global_rect().get_center())
	var wheel := InputEventMouseButton.new()
	wheel.position=mouse
	wheel.global_position=mouse
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	view.push_input(wheel,true)
	await frames()
	var row_stride: int=int(scene.HIGHTECH_CARD_SIZE.y)+scene.hightech_container.get_theme_constant("v_separation")
	check(scene.hightech_scroll.scroll_vertical==middle_scroll+row_stride and scene.hightech_management.get_global_rect()==fixed_ai_rect,"Mouse wheel moves exactly one two-station row while AI controls remain fixed")
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	view.push_input(wheel,true)
	await frames()
	check(scene.hightech_scroll.scroll_vertical==middle_scroll,"Reverse wheel returns to the previous complete row")
	scene.hightech_scroll.get_v_scroll_bar().value=middle_scroll+row_stride*0.7
	await frames()
	check(scene.hightech_scroll.scroll_vertical==middle_scroll+row_stride,"Scrollbar intermediate position snaps to a complete row")
	var visible_rect: Rect2=scene.hightech_scroll.get_global_rect()
	var complete_visible := 0
	var partial_visible := 0
	for bay in scene.hightech_container.get_children():
		if visible_rect.encloses(bay.get_global_rect()):complete_visible+=1
		elif visible_rect.intersects(bay.get_global_rect()):partial_visible+=1
	check(complete_visible==4 and partial_visible==0,"Snapped viewport contains four complete stations and no partial station")
	await capture("hightech-twelve-row-snapped")
	scene.hightech_scroll.scroll_vertical=0
	await frames()
	scene.game.profile.techPoints[first]=0
	scene.refresh_hightech_card(first)
	check(building.built==0,"Zero research renders blueprint only")
	scene.game.profile.techPoints[first]=scene.game.hightech_required(first)*0.999
	scene.refresh_hightech_card(first)
	check(building.built<building.parts.size(),"Near-complete research retains an unfinished component")
	building.set_workers(0)
	building.completed=0
	building.completion_cooldown=1.5
	await frames()
	draws.fx=0
	for i in 60:
		building.advance(1.0/60.0,false)
		await process_frame
	check(draws.fx==0 and building.completion_cooldown<0.6,"Cooldown without workers has no empty effect redraws")
	await verify_worker_motion(keys)
	var furnace_key: String=BattleGame.FURNACE
	scene.game.profile.hightechLevels[furnace_key]=185
	scene.game.profile.furnaceIncomePeak=2.612345e25
	scene.refresh_hightech_card(furnace_key)
	scene.select_hightech_bay(furnace_key)
	check(not scene.hightech_descriptions[furnace_key].text.contains("？") and scene.hightech_descriptions[furnace_key].text.contains("e+"),"Large furnace yield is readable in the station nameplate")
	check(scene.hightech_inspector.details[furnace_key].effect.text==preload("res://scripts/hightech_presentation.gd").effect_text(scene.game,furnace_key),"Selected detail and station use the same large-number effect")
	await capture("hightech-large-yield")
	print("Hightech construction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func verify_worker_motion(keys: Array) -> void:
	# Exercise the real presentation clock, independently of research speed.
	var bays: Array=[]
	for key in keys:bays.append(scene.hightech_progress[key].construction)
	var fallback=load("res://scripts/hightech_construction.gd").new()
	view.add_child(fallback)
	fallback.setup("motion-future-tech")
	bays.append(fallback)
	for c in bays:
		c.completed=0
		c.completion_cooldown=0
		c.set_workers(3)
		c.set_fraction(0.16)
		for i in 100:c.advance(0.05,false)
		check(c.worker_welding(0) and c.worker_welding(1) and c.worker_welding(2),"All units arrive and settle before welding: "+c.shape)
		var before: PackedVector2Array=c.worker_positions.duplicate()
		var target: Vector2=c.work_target(0)
		c.set_workers(1)
		check(c.worker_positions==before and c.work_target(0)==target and c.worker_welding(0),"Recall preserves surviving unit identity, position and work site: "+c.shape)
		c.set_workers(3)
		check(c.worker_positions==before and not c.worker_welding(1),"Reassignment retains positions and requires renewed arrival: "+c.shape)
		c.set_fraction(0.76)
		check(c.worker_positions==before and not c.worker_welding(0),"Large progress jump stops old beam without moving units: "+c.shape)
		c.advance(1.0,true)
		check(c.worker_positions==before,"Pause freezes travel: "+c.shape)
		c.hide()
		c.advance(1.0,false)
		c.show()
		check(c.worker_positions==before,"Hidden bays do not catch up movement: "+c.shape)
		c.advance(1.0,false)
		var bounded := true
		for j in 3:bounded=bounded and before[j].distance_to(c.worker_positions[j])<=14.001
		check(bounded and c.worker_positions!=before,"Long frame is capped instead of teleporting: "+c.shape)
		bounded=true
		for i in 100:
			before=c.worker_positions.duplicate()
			c.advance(0.05,false)
			for j in 3:bounded=bounded and before[j].distance_to(c.worker_positions[j])<=7.001
		check(bounded and c.worker_welding(0) and c.worker_welding(1) and c.worker_welding(2),"Flight remains bounded and welding resumes at destination: "+c.shape)
		before=c.worker_positions.duplicate()
		c.celebrate()
		c.set_fraction(0.01)
		check(c.worker_positions==before and not c.worker_welding(0),"Completion keeps units present and stops welding: "+c.shape)
		for i in 20:c.advance(0.05,false)
		check(c.worker_positions==before,"Acceptance holds the same units in place: "+c.shape)
		for i in 8:
			before=c.worker_positions.duplicate()
			c.advance(0.05,false)
			for j in 3:bounded=bounded and before[j].distance_to(c.worker_positions[j])<=7.001
		check(c.completed==0 and bounded,"Next round flies from retained position: "+c.shape)
		# Same-component frontier updates also preserve current positions.
		var component: int=mini(c.parts.size()-1,5)
		c.set_fraction((component+0.2)/c.parts.size())
		for i in 100:c.advance(0.05,false)
		before=c.worker_positions.duplicate()
		c.set_fraction((component+0.8)/c.parts.size())
		check(c.worker_positions==before,"Frontier changes do not reposition units: "+c.shape)
		c.set_workers(0)
		c.advance(1.0,false)
		check(c.worker_positions==before and not c.worker_welding(0),"No workers means no hidden movement or welding: "+c.shape)
		c.set_workers(3)
	fallback.queue_free()
	await frames()
	for c in bays.slice(0,4):
		c.set_fraction(0.16)
		for i in 100:c.advance(0.05,false)
	await capture("hightech-workers-before-travel")
	for c in bays.slice(0,4):c.set_fraction(0.76)
	await capture("hightech-workers-depart")
	for c in bays.slice(0,4):
		for i in 8:c.advance(0.05,false)
	await capture("hightech-workers-travelling")
	for c in bays.slice(0,4):
		for i in 100:c.advance(0.05,false)
	await capture("hightech-workers-arrived")
