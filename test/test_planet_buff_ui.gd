extends SceneTree
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
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2048,1280)
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
	g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.planets["1"].conquered=true
	for key in g.db.data.hightech:g.profile.hightechLevels[key]=1
	scene.refresh_structure()
	scene.equipment_panel.refresh()
	var item: Dictionary=scene.equipment_panel.items.values()[0]
	var card=scene.equipment_panel.cards[item.id]
	check(card.fields.level.text.contains("1 (+10)") and card.tooltip_text.contains("效果等级：11"),"Equipment actual/bonus/effective display")
	check(preload("res://scripts/hightech_presentation.gd").title(g,BattleGame.ENERGY_FOCUS).contains("1 (+10)"),"Hightech matches equipment level display")
	scene.equipment_tabs.current_tab=6
	scene.planet_panel.refresh()
	var detail: String=scene.planet_panel.cards["1"].detail.text
	var previous: int=-1
	for row in g.planet_buffs.rows(g,"1","conquer"):
		var index: int=detail.find(row.des)
		check(index>previous,"Conquest description order: "+str(row.id))
		previous=index
	await process_frame
	await process_frame
	var detail_label: Label=scene.planet_panel.cards["1"].detail
	check(detail_label.get_visible_line_count()==detail_label.get_line_count(),"Scrollable conquest text retains every reward line")
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/planet-conquest-buffs.png")
	scene.equipment_tabs.current_tab=2
	g.set_reactor_allocation("weapons",g.reactor_capacity())
	scene.reactor_panel.refresh()
	var controls: Dictionary=scene.reactor_panel.module_controls.weapons
	check(controls.share.text=="100% (+10%)","Allocation and free charge shown separately")
	check(controls.scene_fx.ratio==1 and controls.bay_track.ratio==1 and controls.slider.value==g.reactor_capacity(),"Overfull effects use full visuals and original slider range")
	check(controls.share.get_minimum_size().x<=207,"Charge text fits existing allocation header")
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/reactor-free-charge.png")
	g.db.data.planet_buff["3"].value=.25
	scene.reactor_panel.refresh()
	check(controls.share.text=="100% (+25%)" and controls.scene_fx.ratio==1 and is_equal_approx(g.reactor_effective_ratio("weapons"),1.25),"Configurable free charge has no 110 percent cap")
	g.profile.planets["1"].conquered=false
	scene.reactor_panel.refresh()
	scene.equipment_tabs.current_tab=0
	scene.equipment_panel.refresh()
	check(not controls.share.text.contains("(") and not card.fields.level.text.contains("("),"Zero bonuses hide parenthesis")
	scene.equipment_tabs.current_tab=6
	scene.planet_panel.refresh()
	check(not scene.planet_panel.cards["1"].detail.text.contains("征服效果"),"No reward preview before conquest")
	print("PLANET BUFF UI: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
