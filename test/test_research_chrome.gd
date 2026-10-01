extends SceneTree
## Readable workstation chrome and persistent AI/detail controls; isolated in-memory state.
class TrackedUI extends "res://scripts/main.gd":
	var writes := 0
	var builds := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes+=1
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds+=1
		super.build_ui()
var checks := 0
var failures := 0
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
func run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1952,1256)
	root.add_child(view)
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	for player in scene.find_children("*","AudioStreamPlayer",true,false):player.stop()
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,51)
	scene.game.rebuild_unlocks()
	scene.game.profile.scientists=49
	scene.game.profile.resources={"1":1e12,"2":1e12}
	var keys: Array=scene.db.data.hightech.keys()
	for key in keys:
		scene.game.profile.hightechLevels[key]=20
		scene.game.profile.scientistAssignments[key]=11
		scene.game.profile.techPoints[key]=scene.game.hightech_required(key)*0.28
	scene.refresh_structure()
	scene.select_system(1)
	await frames()
	scene.refresh_visible_cards()
	var builds: int=scene.builds
	var first: String=keys[0]
	var card: Control=scene.hightech_titles[first].get_parent()
	var construction=scene.hightech_progress[first].construction
	var summary: Label=scene.scientist_summary
	check(scene.hightech_selected.is_empty() and scene.hightech_inspector.overview.visible,"Entry shows workstation overview")
	check(scene.workspace_title.text==UIText.t("upgrade.research_tab") and not scene.workspace_title.has_theme_stylebox_override("normal"),"Research uses a readable shared title without an empty cream plate")
	var emphasis := preload("res://scripts/hightech_presentation.gd")
	var focus: String=BattleGame.ENERGY_FOCUS
	var saved_level: int=scene.game.profile.hightechLevels[focus]
	scene.game.profile.hightechLevels[focus]=0
	var baseline: String=emphasis.effect_text(scene.game,focus)
	var baseline_markup: String=emphasis.effect_markup(scene.game,focus)
	scene.game.profile.hightechLevels[focus]=saved_level
	var above: String=emphasis.effect_text(scene.game,focus)
	check(baseline.ends_with("100%") and baseline_markup.contains("100%[/color]") and not baseline.contains("+") and above!=baseline and not above.contains("+"),"Total research percentage reads accurately at baseline and above baseline, with the whole % token emphasized")
	var iron_markup: String=emphasis.effect_markup(scene.game,BattleGame.FURNACE)
	check(iron_markup.contains(" 秒[/color]") and iron_markup.contains(" 铁[/color]"),"Furnace amount and duration emphasis includes full units")
	check(keys.size()==4 and scene.hightech_container.get_child_count()==4,"Four distinct configured workstations remain")
	for key in keys:
		var c=scene.hightech_progress[key].construction
		check(c.ART==construction.ART and is_equal_approx(c.fraction,0.28),"Existing atlas and points still own artwork progress: "+key)
		check(not scene.hightech_descriptions[key].scroll_active and scene.hightech_descriptions[key].size==Vector2(588,68),"Workstation effect has two readable lines: "+key)
		check(scene.hightech_titles[key].get_theme_color("font_color")==preload("res://scripts/hightech_presentation.gd").NAVY,"Station name is navy on cream: "+key)
	check(scene.hightech_page.find_children("*","Button",true,false).filter(func(b):return b.text==UIText.t("research.dock_distribute")).size()==1,"AI distribution exists exactly once")
	scene.select_hightech_bay(first)
	await frames()
	check(card.selected and scene.hightech_buttons[first].visible,"Selection outlines card and exposes its allocation")
	check(scene.hightech_inspector.details[first].panel.visible and not scene.hightech_inspector.overview.visible,"Selected persistent inspector is visible")
	var assigned: int=scene.game.assigned_scientists(first)
	scene.hightech_buttons[first].pressed.emit()
	check(scene.game.assigned_scientists(first)==assigned+1 and summary.text.contains("待命 4"),"Allocate button keeps real AI and shared idle semantics")
	scene.scientist_remove_buttons[first].pressed.emit()
	check(scene.game.assigned_scientists(first)==assigned,"Recall returns real AI")
	scene.scientist_distribute_button.pressed.emit()
	check(scene.game.idle_scientists()==0 and scene.hightech_buttons[first].disabled,"Distribute consumes the idle pool and disables allocation")
	check(scene.hightech_selected==first and scene.builds==builds and scene.hightech_titles[first].get_parent()==card,"AI actions retain page, selection and card identity")
	var detail: Dictionary=scene.hightech_inspector.details[first]
	var effect: RichTextLabel=detail.effect
	var bay_effect: RichTextLabel=scene.hightech_descriptions[first]
	bay_effect.text="这是一个需要完整阅读的科研说明。".repeat(30)
	await frames()
	check(bay_effect.get_visible_line_count()>=2,"Long compact effect actually shows two lines")
	check(bay_effect.size.y>=bay_effect.get_theme_font("normal_font").get_height(bay_effect.get_theme_font_size("normal_font_size"))*2,"Compact effect area physically fits two font lines")
	# A long text fixture exercises the actual persistent scroll layout without editing tables.
	effect.text="这是一个需要完整阅读的科研说明。".repeat(30)
	await frames()
	check(effect.fit_content and effect.get_line_count()>2,"Full effect wraps without a two-line limit")
	check(detail.effect_scroll.get_v_scroll_bar().max_value>detail.effect_scroll.get_v_scroll_bar().page,"Long effect can scroll to every line")
	detail.effect_scroll.scroll_vertical=100000
	await frames()
	var offset: int=detail.effect_scroll.scroll_vertical
	check(offset>0,"Description reaches lower lines")
	scene.select_system(0)
	await frames()
	scene.refresh_visible_cards(1)
	check(scene.hightech_selected==first,"Leaving research preserves selection")
	scene.select_system(1)
	await frames()
	check(scene.hightech_selected.is_empty() and scene.hightech_inspector.overview.visible and not detail.panel.visible,"Reopen catches up to the existing overview navigation contract")
	scene.select_hightech_bay(first)
	await frames()
	check(detail.panel.visible and detail.effect_scroll.scroll_vertical==offset,"Reselect retains persistent description scroll")
	scene.select_hightech_bay("")
	await frames()
	check(not card.selected and scene.hightech_inspector.overview.visible,"Dismiss restores unselected overview")
	# Relocking a known bay must reveal no title, type silhouette or assignment action.
	scene.game.profile.cleared.erase(int(scene.db.unlock_row("hightech",first).level))
	scene.game.profile.get("grantedUnlocks",[]).erase(scene.db.unlock_id("hightech",first))
	scene.refresh_hightech_card(first)
	scene.select_hightech_bay(first)
	await frames()
	check(scene.hightech_titles[first].text==UIText.t("research.unrevealed") and scene.hightech_descriptions[first].get_parsed_text().is_empty(),"Locked station hides identity and description")
	check(construction.research_pending and construction.unknown_art.visible and not construction.art.visible,"Locked machine uses identity-free placeholder")
	check(scene.hightech_progress[first].state.text==UIText.t("research.pending") and not scene.hightech_buttons[first].visible,"Locked state and hidden controls retain pending semantics")
	check(detail.title.text==UIText.t("research.unrevealed") and detail.effect.text.is_empty() and detail.workers.text.is_empty(),"Locked inspector reveals no future detail")
	check(detail.title.tooltip_text==UIText.t("research.unrevealed") and [detail.effect,detail.progress,detail.time,detail.workers].all(func(control):return control.tooltip_text.is_empty()),"Locked inspector clears stale identifying tooltips as well as visible text")
	scene.select_hightech_bay("")
	scene.writes=0
	scene.refresh_visible_cards()
	await frames()
	scene.writes=0
	var phase: float=construction.phase
	for i in 3:scene.refresh_visible_cards(0.1)
	check(scene.writes==0 and construction.phase==phase,"Paused unchanged research performs no property writes or animation")
	scene.select_system(0)
	await frames()
	scene.writes=0
	scene.refresh_visible_cards(1)
	check(scene.writes==0,"Hidden research stops refreshing")
	print("Research chrome: %d checks, %d failures" % [checks,failures])
	view.queue_free()
	await frames()
	quit(1 if failures else 0)
