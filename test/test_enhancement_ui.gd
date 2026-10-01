extends SceneTree
const PARAMETER_TEXT := preload("res://scripts/parameter_text.gd")
class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=root.get_final_transform()*control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	var emphasized := PARAMETER_TEXT.render("enhance.overview.proficiency",{"value":"37"},{"value":{"role":"effect","unit":"%"}})
	check(emphasized.contains("[color=#005449]37%[/color]"),"Selective emphasis colors the complete percent value and unit")
	var unsafe := PARAMETER_TEXT.render("enhance.overview.proficiency",{"value":"[b]37[/b]"},{"value":{"role":"effect","unit":"%"}})
	check(not unsafe.contains("[b]") and unsafe.contains("[lb]b[rb]"),"Substituted values cannot inject BBCode")
	var uncolored := PARAMETER_TEXT.render("enhance.overview.proficiency",{"value":"37"})
	check(not uncolored.contains("[color=") and uncolored.contains("37%"),"Parameters without explicit spans remain plain")
	var scene := TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.music.stop()
	scene.music.stream=null
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,61)
	scene.game.profile.highestLevel=61
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.onboarding.completed=true
	scene.game.profile.jewelFragments=10000.0
	scene.game.profile.enhancementLevel=0
	scene.game.switch_ship("Heavy_Battleship")
	for category in ["weapons","defence"]:
		for index in scene.game.loadout_entries(category).size():
			var entry: Dictionary=scene.game.module_entry(category,index)
			entry.key="laser" if category=="weapons" else "armour"
			entry.level=int(scene.game.enhancement_parameter("threshold_%d" % (mini(index,2)+1)))
	scene.game.invalidate_stat_cache()
	scene.game.reset_player()
	scene.build_ui()
	scene.select_system(4)
	await process_frame
	await process_frame
	var panel: Control=scene.enhancement_panel
	check(panel.visible and scene.workspace_title.text==UIText.t("enhance.tab"),"Enhancement navigation opens replacement page")
	check(scene.get("jewel_panel")==null and scene.equipment_panel.get_action_anchor("gems")==null,"Legacy inventory and socket controls are absent")
	check(panel.level_label.text==UIText.t("enhance.level",{"level":0}),"Purchased zero level is distinct from planet bonus")
	check(not panel.effect_cards.weapons[0].threshold.visible and panel.history_label.visible==false and panel.effect_cards.weapons[0].description is RichTextLabel,"Overview moves repeated thresholds and counters out of the cards")
	check(panel.effect_cards.defence[1].description.get_parsed_text().contains("%/秒"),"Repair overview includes configured recovery time basis")
	check(panel.effect_cards.weapons.size()==3 and panel.effect_cards.defence.size()==3,"Each category has three ordered positions")
	check(panel.effect_cards.defence[2].title.text==UIText.t("enhance.effect.delayed_damage") and panel.effect_description("delayed_damage").contains("免除尚未承受"),"Third defense effect describes delayed damage with global post-payment clearing")
	var card_refs: Array=panel.effect_cards.weapons.map(func(card):return card.panel)
	var cost_before=scene.game.enhancement_cost()
	var balance_before=scene.game.profile.jewelFragments
	await click(panel.upgrade_button)
	check(scene.game.enhancement_level()==1 and GrowthNumber.compare(scene.game.profile.jewelFragments,GrowthNumber.subtract(balance_before,cost_before))==0,"Actual upgrade click buys shared level with exact fragment cost")
	await click(panel.max_button)
	check(scene.game.enhancement_level()==4 and GrowthNumber.compare(scene.game.profile.jewelFragments,0)==0,"Actual MAX click purchases exactly affordable levels")
	var order_before: Array=scene.game.enhancement_order("weapons").duplicate()
	await click(panel.effect_cards.weapons[1].up)
	check(scene.game.enhancement_order("weapons")==[order_before[1],order_before[0],order_before[2]],"Actual arrow click reorders effects immediately")
	for index in 3:check(is_same(card_refs[index],panel.effect_cards.weapons[index].panel),"Reordering preserves card instance "+str(index))
	check(panel.effect_cards.weapons[0].up.disabled and panel.effect_cards.weapons[2].down.disabled,"Boundary arrows cannot move beyond the three positions")
	var order_after: Array=scene.game.enhancement_order("weapons").duplicate()
	panel.move_effect("weapons",0,-1)
	check(scene.game.enhancement_order("weapons")==order_after,"Invalid reorder leaves saved order unchanged")
	scene.game.planet_progress("1").conquered=true
	scene.game.invalidate_stat_cache()
	panel.invalidate()
	check(panel.level_label.text==UIText.t("enhance.level",{"level":4}) and panel.bonus_label.text==UIText.t("enhance.bonus",{"bonus":scene.game.enhancement_level_bonus(),"effective":scene.game.enhancement_effective_level()}),"Planet bonus changes strength without changing purchased level")
	var threshold_before: int=panel.threshold_level(0)
	var repeat_probability: float=scene.db.data.enhance_config.repeat_probability.value
	scene.db.data.enhance_config.threshold_1.value=7
	scene.db.data.enhance_config.repeat_probability.value=0.37
	scene.game.invalidate_stat_cache()
	panel.refresh()
	check(panel.rule_label.text==UIText.t("enhance.overview.thresholds",{"first":7,"second":panel.threshold_level(1),"third":panel.threshold_level(2)}) and panel.effect_description("repeat").contains("37%"),"Alternative valid config drives thresholds and effect descriptions")
	scene.db.data.enhance_config.threshold_1.value=threshold_before
	scene.db.data.enhance_config.repeat_probability.value=repeat_probability
	scene.game.invalidate_stat_cache()
	panel.refresh()
	scene.game.profile.jewelFragments=0
	panel.refresh()
	check(panel.upgrade_button.disabled and panel.max_button.disabled,"Insufficient fragments disables both upgrade controls")
	scene.select_system(0)
	await process_frame
	check(not panel.visible and panel.metrics_timer.is_stopped(),"Hidden enhancement page stops metric refresh")
	scene.game.profile.jewelFragments=12345.67
	panel.invalidate()
	scene.select_system(4)
	await process_frame
	check(panel.balance_label.tooltip_text==UIText.t("enhance.balance",{"amount":"12345.67"}),"Hidden changes catch up on reveal with precise currency tooltip")
	panel.upgrade_button.grab_focus()
	var focused:=root.gui_get_focus_owner()
	scene.game.paused=true
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty() and root.gui_get_focus_owner()==focused,"Unchanged paused refresh makes no property writes and preserves focus")
	check(scene.battle_layer.visible and scene.workspace_frame.visible,"Enhancement page keeps battle and shared workspace visible")
	scene.game.paused=false
	scene.game.reset_player()
	scene.game.advance_jewel_repair(2.0)
	scene.game.paused=true
	scene.refresh_draw_layers(0)
	check(scene.neutral_protection_hud_text()==UIText.t("enhance.protection_hud.runtime",{"current":scene.number(scene.game.enhancement_protection_current()),"capacity":scene.number(scene.game.enhancement_protection_capacity())}) and scene.enhancement_protection_state_text().contains(UIText.t("enhance.protection_state.neutral")),"Temporary protection has separate capacity and live resistance readouts")
	check(GrowthNumber.compare(scene.game.enhancement_protection_current(),0)>0 and GrowthNumber.compare(scene.game.player.shield,scene.game.max_shield())<=0,"Temporary protection does not inflate typed shield health")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-page.png")
	await click(panel.effect_cards.weapons[0].branches)
	check(panel.branch_overlay.visible and panel.branch_effect==scene.game.enhancement_order("weapons")[0],"Actual branch button opens selected effect independently of order")
	check(panel.branch_rows[0].A.disabled and panel.branch_rows[1].A.disabled and panel.branch_rows[2].A.disabled,"Branches below configured thresholds stay locked")
	var branch_refs: Array=panel.branch_rows.map(func(row):return row.A)
	scene.game.profile.enhancementLevel=scene.game.enhancement_branch_threshold(1)-scene.game.enhancement_level_bonus()
	scene.game.invalidate_stat_cache()
	panel.refresh()
	check(not panel.branch_rows[0].A.disabled and panel.branch_rows[1].A.disabled,"Planet-added levels unlock first branch at its configured total without unlocking second")
	var fragment_balance=scene.game.profile.jewelFragments
	await click(panel.branch_rows[0].A_title)
	check(scene.game.enhancement_branch_choice(panel.branch_category,panel.branch_effect,1)=="A","Actual branch A selection persists on its effect")
	await click(panel.branch_rows[0].B_description)
	check(scene.game.enhancement_branch_choice(panel.branch_category,panel.branch_effect,1)=="B" and GrowthNumber.compare(scene.game.profile.jewelFragments,fragment_balance)==0,"Branch B can replace A freely without spending fragments")
	check(panel.branch_metadata(panel.branch_category,panel.branch_effect,1,"B").implemented and panel.branch_rows[0].B_description.get_parsed_text()==panel.branch_option_text(panel.branch_metadata(panel.branch_category,panel.branch_effect,1,"B"),"description_text_id"),"Implemented branch descriptions use core metadata and configured values")
	check(scene.game.enhancement_branch_choice("weapons","critical",1).is_empty(),"A branch choice does not select other effects")
	for index in 3:check(is_same(branch_refs[index],panel.branch_rows[index].A),"Branch interactions preserve option controls "+str(index))
	var second_threshold: int=scene.db.data.enhance_config.branch_threshold_2.value
	scene.db.data.enhance_config.branch_threshold_2.value=13
	scene.game.profile.enhancementLevel=13
	scene.game.invalidate_stat_cache()
	panel.refresh()
	check(panel.branch_rows[1].title.text==UIText.t("enhance.branches.milestone",{"node":2,"level":13}) and not panel.branch_rows[1].A.disabled,"Alternative branch config updates its threshold and availability")
	await click(panel.branch_rows[1].A)
	check(scene.game.enhancement_branch_choice(panel.branch_category,panel.branch_effect,2)=="A","Each milestone stores an independent two-way choice")
	scene.db.data.enhance_config.branch_threshold_2.value=second_threshold
	scene.game.profile.enhancementLevel=second_threshold
	scene.game.invalidate_stat_cache()
	panel.refresh()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-branches.png")
	scene.game.profile.enhancementLevel=scene.game.enhancement_branch_threshold(3)
	scene.game.invalidate_stat_cache()
	for category in ["weapons","defence"]:
		for effect in scene.game.enhancement_order(category):
			panel.open_branches(category,effect)
			await process_frame
			for node in range(1,4):
				for option in ["A","B"]:
					var description: RichTextLabel=panel.branch_rows[node-1][option+"_description"]
					check(not description.get_parsed_text().contains("{") and not description.get_parsed_text().contains("[enhance.") and description.get_content_height()<=description.size.y,"Configured rich branch description fits: %s/%d/%s" % [effect,node,option])
	var guaranteed_rate: float=scene.db.data.enhance_config.critical_b3_guaranteed_rate.value
	scene.db.data.enhance_config.critical_b3_guaranteed_rate.value=0.8
	scene.game.set_enhancement_branch("weapons","critical",3,"B")
	panel.refresh()
	var critical_card: Dictionary=panel.effect_cards.weapons[scene.game.enhancement_order("weapons").find("critical")]
	check(critical_card.description.get_parsed_text().contains("80%") and panel.branch_option_text(panel.branch_metadata("weapons","critical",3,"B"),"description_text_id").contains("80%"),"Configured fixed critical chance drives both overview and branch prose")
	scene.db.data.enhance_config.critical_b3_guaranteed_rate.value=guaranteed_rate
	scene.game.invalidate_stat_cache()
	panel.open_branches("defence","memory_material")
	panel.branch_scroll.scroll_vertical=114
	await process_frame
	await click(panel.branch_rows[1].B_description)
	check(scene.game.enhancement_branch_choice("defence","memory_material",2)=="B","Scrolled description body selects branch B")
	await click(panel.branch_close_button)
	check(not panel.branch_overlay.visible and panel.visible,"Return button dismisses only the branch drawer")
	await click(panel.effect_cards.defence[1].branches)
	check(panel.branch_overlay.visible and panel.branch_scroll.scroll_vertical==114,"Reopening the same effect preserves long-description scroll")
	await click(panel.branch_rows[1].A_title)
	await click(panel.branch_rows[1].B_description)
	check(scene.game.enhancement_branch_choice("defence","memory_material",2)=="B" and GrowthNumber.compare(scene.game.profile.jewelFragments,fragment_balance)==0,"A to B remains free after scrolling and reopening")
	scene.game.set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
	panel.open_branches("defence","memory_material")
	scene.game.set_enhancement_branch("defence","adaptation",3,"B")
	scene.game.paused=false
	scene.game.reset_player()
	scene.game.advance_jewel_repair(2.0)
	scene.game.hit_player(1,1)
	scene.game.paused=true
	panel.refresh()
	check(scene.enhancement_protection_state_text().contains(UIText.t("enhance.protection_state.mixed_energy",{"range":UIText.t("enhance.protection_state.range",{"minimum":"50","maximum":"75"})})) and scene.enhancement_protection_details().contains("能量抗性"),"Mixed protection is labeled partial and details use core-owned energy identity")
	check(panel.branch_rows[1].B_description.get_parsed_text().contains("50% 至 75%"),"Memory description reports mixed common-resolver resistance rather than a false uniform value")
	if DisplayServer.get_name()!="headless":
		scene.refresh_draw_layers(0)
		panel.branch_scroll.scroll_vertical=0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-actual-branches-top.png")
		panel.branch_scroll.scroll_vertical=114
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-memory-active.png")
	scene.game.hit_player(1,2)
	check(scene.enhancement_protection_state_text().contains("重获锁定") and not scene.enhancement_protection_state_text().contains("能量抗性"),"Mismatch HUD shows actual resistance loss and lockout")
	var preserved_scroll: int=panel.branch_scroll.scroll_vertical
	scene.writes.clear()
	panel.refresh()
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty() and panel.branch_scroll.scroll_vertical==preserved_scroll,"Paused unchanged rich drawer refresh preserves scroll without property writes")
	if DisplayServer.get_name()!="headless":
		scene.refresh_draw_layers(0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-actual-branches.png")
	panel.branch_overlay.hide()
	scene.refresh_draw_layers(0)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/enhancement-actual-overview.png")
	panel.branch_overlay.hide()
	scene.game.profile.enhancementLevel=scene.game.enhancement_level_limit()
	scene.game.invalidate_stat_cache()
	panel.refresh()
	check(panel.upgrade_button.disabled and panel.max_button.disabled and panel.cost_label.text==UIText.t("enhance.limit_reached"),"Technical level boundary disables purchases and explains remaining balance")
	var huge_card: Dictionary=panel.effect_cards.defence[scene.game.enhancement_order("defence").find("memory_material")]
	var huge_caption: String=huge_card.description.get_parsed_text()
	check(huge_card.description.get_theme_font("normal_font").get_string_size(huge_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,huge_card.description.get_theme_font_size("normal_font_size")).x<=huge_card.description.size.x and huge_caption.contains("%/秒"),"Extreme recovery values remain bounded and keep the full time unit")
	panel.close()
	check(scene.equipment_tabs.current_tab==0 and not panel.visible,"Close returns to equipment without lingering overlay")
	scene.music.stop()
	scene.music.stream=null
	await process_frame
	scene.queue_free()
	await process_frame
	print("Enhancement UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
