extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.automation_args=[]
	var g=scene.game
	g.save_enabled=false
	g.paused=true
	g.profile.cleared=[]
	g.profile.grantedUnlocks=[]
	g.pending_unlocks.clear()
	scene.refresh_tab_visibility()
	var panel=scene.crew_panel
	panel.invalidate()
	await process_frame
	check(g.profile.crew.size()==6,"Six crew configurations")
	check(scene.equipment_tabs.is_tab_hidden(5) and not panel.is_visible_in_tree(),"Crew tab absent before first unlock")
	check(scene.equipment_tabs.current_tab!=5,"Selection stays on an available page")
	check(panel.locked_preview.tooltip_text.is_empty() and panel.locked_preview.disabled and panel.locked_preview.focus_mode==Control.FOCUS_NONE,"Preview reveals no tooltip or interaction")
	check(panel.detail_controls.all(func(c):return not c.is_visible_in_tree()),"No crew information visible before unlock")
	panel.select("navigator")
	check(panel.selected=="" and not g.assign_crew("navigator","equipment_upgrade","equipment"),"Locked crew cannot be selected or assigned")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/crew-locked.png")
	var silhouette=panel.locked_preview
	var gates: Array=[10,20,25,30,35,40]
	var ids: Array=g.db.data.crew.keys()
	var first_row
	for i in gates.size():
		var id: String=ids[i]
		g.profile.highestLevel=gates[i]+1
		check(not g.crew.unlocked(g,id),"Reaching without specified clear does not unlock "+id)
		g.stage=gates[i]
		g.clear_level()
		check(g.pending_unlocks.has("crew/"+id),"Crew uses existing unlock notification "+id)
		g.pending_unlocks.clear()
		scene.refresh_navigation()
		check(not scene.equipment_tabs.is_tab_hidden(5),"Crew tab visible after first crew unlock")
		scene.equipment_tabs.current_tab=5
		panel.invalidate()
		await process_frame
		check(g.crew.unlocked(g,id) and panel.rows.size()==i+1,"Only cleared crew visible "+id)
		check(panel.locked_preview==silhouette,"Preview control reused")
		if i==0:first_row=panel.rows[id]
		check(panel.rows[ids[0]]==first_row,"Existing unlocked row preserved")
		if i<5:check(panel.locked_preview.visible and panel.locked_preview.text==UIText.t("crew.unlock_at",{"level":gates[i+1]}),"Only next gate shown")
		else:check(not panel.locked_preview.visible,"No silhouette after all crew unlocked")
		if i==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/crew-first-unlocked.png")
			check(panel.locked_preview.tooltip_text=="" and panel.list.get_child_count()==2,"Only first crew plus anonymous next preview exist")
	g.save_enabled=true
	g.save_progress()
	var restored:=BattleGame.new(g.db,false)
	restored.load_progress()
	check(ids.all(func(id):return restored.crew.unlocked(restored,id)),"All six unlocks survive save load")
	var legacy:=BattleGame.new(g.db,false)
	legacy.crew.load_state(legacy,[{"crewId":"navigator","level":2,"exp":17,"assignmentType":"equipment_upgrade","targetId":"equipment"}])
	check(legacy.crew.entry(legacy,"navigator").level==2 and legacy.crew.entry(legacy,"navigator").exp==17 and legacy.profile.crew.size()==6,"Existing crew identity/growth retained; new crew initialized")
	check(legacy.crew.badge(legacy,"weapons_0").text=="","Locked legacy assignment does not reveal crew identity")
	print("CREW UNLOCK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
