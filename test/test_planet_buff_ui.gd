extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)
func update_planet(g,id: String,fields: Dictionary) -> void:
	var snapshot: Dictionary=g.portable_save_data();snapshot.planets[id].merge(fields,true)
	check(g.planets.install_snapshot(snapshot,g.db),"Valid planet fixture installs")
func update_building(g,id: String,key: String,fields: Dictionary) -> void:
	var snapshot: Dictionary=g.portable_save_data();snapshot.planets[id].buildings[key].merge(fields,true)
	check(g.planets.install_snapshot(snapshot,g.db),"Valid building fixture installs")
func _initialize() -> void:
	call_deferred("run")
func capture(viewport: SubViewport, name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/"+name+".png")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2048,1280)
	viewport.gui_embed_subwindows=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene:=preload("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	viewport.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	var g=scene.game
	g.save_enabled=false;g.paused=true
	g.profile.cleared=range(1,101)
	g.profile.grantedUnlocks=[]
	for gate in g.db.data.unlock.values():
		if gate.type in ["planet","crew"]:g.profile.grantedUnlocks.append(gate.name)
	g.rebuild_unlocks();g.pending_unlocks.clear()
	g.planets.reset(g)
	update_planet(g,"1",{"conquered":true})
	scene.refresh_tab_visibility()
	scene.equipment_panel.refresh()
	var item: Dictionary=scene.equipment_panel.items.values()[0]
	var card=scene.equipment_panel.cards[item.id]
	check(card.fields.level.text.contains("1 (+35)") and card.tooltip_text.contains("效果等级：36"),"Equipment actual/bonus/effective display")
	check(g.planet_unlocked("1") and not scene.equipment_tabs.is_tab_hidden(6),"Earned first planet exposes its tab")
	scene.select_system(6)
	await process_frame
	scene.planet_panel.refresh()
	check(scene.equipment_tabs.current_tab==6 and scene.planet_panel.cards.has("1"),"Visible planet tab builds the first card")
	if not scene.planet_panel.cards.has("1"):
		quit(1)
		return
	scene.planet_panel.show_bonuses("1")
	var detail: String=scene.planet_panel.bonus_text("1")
	var previous: int=-1
	var conquest_rows: Array=g.planet_buffs.rows(g,"1","conquer")
	for row in conquest_rows:
		var description: String=g.planet_buffs.description(row)
		var index: int=detail.find(description)
		check(index>previous,"Conquest description order: "+str(row.id))
		var key: String="buff:"+str(int(row.id))
		check(scene.planet_panel.bonus_rows.has(key) and scene.planet_panel.bonus_rows[key].root.visible and scene.planet_panel.bonus_rows[key].root.tooltip_text==description,"Visible bonus row preserves authored description: "+str(row.id))
		previous=index
	await process_frame
	await process_frame
	check(scene.planet_panel.bonus_dialog.visible,"Conquest bonus dialog is visible in the captured viewport")
	check(scene.planet_panel.bonus_label.text==detail,"Bonus dialog retains the complete ordered reward text")
	await capture(viewport,"planet-conquest-buffs")
	scene.planet_panel.bonus_dialog.hide()
	scene.select_system(2)
	await process_frame
	g.set_reactor_allocation("weapons",g.reactor_capacity())
	scene.reactor_panel.refresh()
	var controls: Dictionary=scene.reactor_panel.module_controls.weapons
	check(controls.share.text=="占用100%（免费+10%）","Allocation and free charge shown separately: "+controls.share.text)
	check(controls.scene_fx.ratio==1 and controls.bay_track.ratio==1 and controls.slider.value==g.reactor_capacity(),"Overfull effects use full visuals and original slider range")
	check(controls.share.get_minimum_size().x<=207,"Charge text fits existing allocation header")
	await process_frame
	await capture(viewport,"reactor-free-charge")
	g.db.data.planet_buff["3"].value=.25;g.notify_configuration_changed()
	scene.reactor_panel.refresh()
	check(controls.share.text=="占用100%（免费+25%）" and controls.scene_fx.ratio==1 and is_equal_approx(g.reactor_effective_ratio("weapons"),1.25),"Configurable free charge has no 110 percent cap: "+controls.share.text+" / "+str(g.reactor_effective_ratio("weapons")))
	update_planet(g,"1",{"conquered":false})
	scene.reactor_panel.refresh()
	scene.select_system(0)
	await process_frame
	scene.equipment_panel.refresh()
	check(g.charge_free_ratio()==0.0 and controls.share.text=="占用100%（免费+0%）" and not card.fields.level.text.contains("(+"),"Unconquered planet gives zero free charge and no equipment level bonus")
	scene.select_system(6)
	await process_frame
	scene.planet_panel.refresh()
	scene.planet_panel.show_bonuses("1")
	check(g.planet_buffs.rows(g,"1","conquer").is_empty(),"No conquest rewards are active before conquest")
	for row in conquest_rows:
		var key: String="buff:"+str(int(row.id))
		check(not scene.planet_panel.bonus_rows.has(key) or not scene.planet_panel.bonus_rows[key].root.visible,"Unearned conquest reward stays hidden: "+str(row.id))
	print("PLANET BUFF UI: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
