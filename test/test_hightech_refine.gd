extends SceneTree
var failed := false

func check(value: bool, message: String) -> void:
	if not value:
		failed=true
		printerr(message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2048,1280)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	viewport.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	var locked: String=BattleGame.JEWEL_FURNACE
	scene.db.unlock_row("hightech",locked).level=99
	scene.game.profile.grantedUnlocks=[]
	scene.game.rebuild_unlocks()
	scene.game.profile.scientists=12
	scene.game.profile.hightechLevels[BattleGame.FURNACE]=185
	scene.game.profile.furnaceIncomePeak=2.6e25
	for project in [BattleGame.FURNACE,BattleGame.ENERGY_FOCUS,BattleGame.DENSE_ARMOUR]:
		scene.game.assign_scientist(project,4)
		scene.game.profile.techPoints[project]=scene.game.hightech_required(project)*0.47
	scene.sync_hightech_slots()
	scene.equipment_tabs.current_tab=1
	await process_frame
	await process_frame
	scene.refresh_visible_cards(0.1)
	check(scene.hightech_container.get_child_count()==4,"Locked project must fill the fourth station")
	var bay=scene.hightech_progress[locked].construction
	var identity=scene.hightech_titles[locked].get_parent()
	check(bay.research_pending and bay.art!=null and bay.fraction==0,"Locked project retains imported blueprint")
	check(not bay.art.visible and bay.unknown_art.visible,"Locked project hides recognizable artwork")
	check(scene.hightech_titles[locked].text==UIText.t("research.unrevealed") and scene.hightech_titles[locked].tooltip_text==UIText.t("research.unrevealed"),"Locked title and tooltip do not reveal project")
	check(scene.hightech_descriptions[locked].text.is_empty() and scene.hightech_descriptions[locked].tooltip_text.is_empty() and scene.hightech_progress[locked].label.text.is_empty(),"Locked station reveals no effect, output or requirement")
	scene.select_hightech_bay(locked)
	var locked_detail=scene.hightech_inspector.details[locked]
	check(locked_detail.title.text==UIText.t("research.unrevealed") and locked_detail.effect.text.is_empty() and locked_detail.progress.text.is_empty() and locked_detail.time.text.is_empty() and locked_detail.workers.text.is_empty(),"Selecting locked station reveals no details")
	check(not scene.hightech_buttons[locked].visible and not scene.scientist_remove_buttons[locked].visible,"Locked station hides local allocation")
	var phase: float=bay.phase
	bay.advance(0.1,false)
	check(bay.phase>phase and not scene.game.assign_scientist(locked,1),"Pending scan runs without enabling AI allocation")
	phase=bay.phase
	bay.advance(0.1,true)
	check(bay.phase==phase,"Pending scan respects pause")
	var effect: Label=scene.hightech_descriptions[BattleGame.FURNACE]
	check(effect.text.begins_with("铁块产量") and effect.text.contains("e+") and effect.text.ends_with("秒") and effect.get_line_count()<=2,"Effect uses type/value/time template")
	check(effect.get_visible_line_count()==effect.get_line_count(),"Effect template fits without hidden lines")
	check(effect.max_lines_visible==2 and effect.size.y==40,"Station effect height and line limit are fixed")
	scene.select_hightech_bay(BattleGame.FURNACE)
	check(scene.hightech_inspector.details[BattleGame.FURNACE].effect.text==effect.text,"Detail shares the same template")
	check(scene.hightech_page.get_theme_stylebox("panel") is StyleBoxTexture and identity.get_child(0) is TextureRect,"Static surfaces use imported textures")
	check(scene.hightech_page.find_children("*","Button",true,false).filter(func(b):return b.text==UIText.t("research.dock_distribute")).size()==1,"Global AI action is not duplicated")
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.runtime/hightech-refined.png")
	scene.game.profile.cleared.append(99)
	scene.sync_hightech_slots()
	scene.refresh_visible_cards(0.1)
	check(scene.hightech_titles[locked].get_parent()==identity and not bay.research_pending,"Unlock updates station in place")
	check(bay.art.visible and not bay.unknown_art.visible and scene.hightech_titles[locked].text!=UIText.t("research.unrevealed"),"Reveal restores real project in place")
	print("Hightech refinement: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
