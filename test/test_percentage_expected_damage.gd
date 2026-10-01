extends SceneTree
const DISPLAY := preload("res://scripts/equipment_display.gd")
const FORMAT := preload("res://scripts/number_format.gd")
const N := preload("res://scripts/growth_number.gd")
class IsolatedUI extends "res://scripts/battlefield.gd":
	var writes: Array=[]
	var projections: Array=[]
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
	func equipment_display_snapshot(entry: Dictionary, level := -1) -> Dictionary:
		projections.append([entry,level])
		return super.equipment_display_snapshot(entry,level)
var scene
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func equal(a,b) -> bool:return N.compare(a,b)==0 or (not a is Dictionary and not b is Dictionary and is_equal_approx(float(a),float(b)))
func frames() -> void:
	await process_frame
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../percentage-"+name+".png")
func click(control: Control) -> void:
	var position:=control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true)
		await frames()
func verify_expected(g, entry: Dictionary, probability: float, multiplier: float, label: String) -> void:
	var base=g.jewel_equipment_stat(entry,-1,null,false)
	var rng_state=g.rng.state
	var profile: Dictionary=g.profile.duplicate(true)
	var values: Dictionary=DISPLAY.snapshot(g,entry)
	check(equal(values.expected,N.multiply(base,1.0+probability*(multiplier-1.0))),label+" uses independent expectation formula")
	check(g.rng.state==rng_state and g.profile==profile,label+" presentation consumes no RNG or durable state")
func run() -> void:
	for fixture in [[0.0,"0"],[25.0,"25"],[100.0,"100"],[100.49,"100"],[100.5,"101"],[9680.0,"9.7K"],[14600.0,"14.6K"],[1234567.0,"1.2M"],[1e15,"1Qa"],[1e33,"1e+33"],[999949.0,"999.9K"],[999950.0,"1M"]]:
		check(FORMAT.percentage(fixture[0])==fixture[1],"Integer/suffixed percent "+str(fixture[0]))
	check(FORMAT.percentage({"m":1.23456,"e":400})=="1.2e+400","Percent ladder preserves large dictionary values")
	check(FORMAT.compact(9680.0)=="9.68K" and FORMAT.compact(1234567.0)=="1.23M","Resource compact retains three significant digits")
	root.gui_embed_subwindows=true
	scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
	var g=scene.game
	g.save_enabled=false;g.paused=true;g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.visible=false
	for gate in g.db.data.unlock.values():gate.level=0
	g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.switch_ship("Heavy_Battleship")
	var entry: Dictionary=g.slot_entry("weapons",0)
	entry.key="laser";entry.level=150
	var cfg: Dictionary=g.db.data.enhance_config
	var original_rate=cfg.base_critical_rate.value
	g.db.equipment.laser[0].cri=0;g.db.equipment.laser[0].criDmg=0
	g.profile.enhancementLevel=0;g.invalidate_stat_cache();g.reset_player()
	for probability in [0.0,0.25,1.0]:
		cfg.base_critical_rate.value=probability
		verify_expected(g,entry,probability,float(cfg.base_critical_multiplier.value),"No enhancement p="+str(probability))
	cfg.base_critical_rate.value=original_rate
	g.profile.enhancementLevel=479;g.invalidate_stat_cache();g.reset_player()
	var critical_multiplier: float=float(cfg.base_critical_multiplier.value)+479.0*float(cfg.critical_growth.value)
	verify_expected(g,entry,float(original_rate),critical_multiplier,"Live configured enhancement")
	check(g.set_enhancement_branch("weapons","critical",3,"B"),"30B selection uses game API")
	for probability in [0.0,0.25,1.0]:
		cfg.base_critical_rate.value=probability
		verify_expected(g,entry,float(cfg.critical_b3_guaranteed_rate.value)*probability,critical_multiplier,"30B bonus p="+str(probability))
		var attack: Dictionary=g.jewel_attack(0)
		if probability==0:check(attack.critical and not attack.critical_bonus_applied and equal(attack.damage,g.jewel_equipment_stat(entry)),"30B triggers without applying bonus at zero underlying chance")
		if probability==1:check(attack.critical and attack.critical_bonus_applied and equal(attack.damage,N.multiply(g.jewel_equipment_stat(entry),critical_multiplier)),"30B applies full multiplier at certain underlying chance")
	cfg.base_critical_rate.value=original_rate
	g.set_enhancement_branch("weapons","critical",2,"B")
	var live: Dictionary=g.enhancement_branches.weapon(g,0)
	live.stacks=3;live.stack_time=1.0
	var stacked_probability: float=clampf(float(original_rate)+3.0*float(cfg.critical_b2_probability.value),0,1)
	verify_expected(g,entry,float(cfg.critical_b3_guaranteed_rate.value)*float(original_rate),critical_multiplier,"Timed stacks excluded from 30B display")
	check(is_equal_approx(g.enhancement_branches.underlying_critical_rate(g,entry),stacked_probability),"Timed critical chance remains active in combat")
	var snapshot: Dictionary=DISPLAY.snapshot(g,entry)
	var plain_base=g.equipment_stat("laser",150)
	check(equal(snapshot.base,plain_base),"Displayed base excludes timed damage stacks")
	check(equal(g.jewel_equipment_stat(entry),N.multiply(plain_base,1.0+3.0*float(cfg.critical_b2_damage_bonus.value))),"Combat retains timed damage stacks")
	var projected: Dictionary=DISPLAY.snapshot(g,entry,151)
	check(is_equal_approx(projected.bonus_probability,float(original_rate)*float(cfg.critical_b3_guaranteed_rate.value)),"Next-level preview excludes timed critical stacks")
	entry.level=149
	verify_expected(g,entry,float(original_rate),float(cfg.base_critical_multiplier.value),"Globally selected critical is not active below module threshold")
	entry.level=150
	var projected_profile: Dictionary=g.profile.duplicate(true)
	var state=g.rng.state
	var weapon_row: Dictionary=g.db.equipment.laser[0]
	var old_damage=weapon_row.dmg
	var old_growth=weapon_row.dmgMulti
	var old_multiplier=cfg.base_critical_multiplier.value
	weapon_row.dmg=1e298;weapon_row.dmgMulti=0.0;cfg.base_critical_multiplier.value=1e20;g.invalidate_stat_cache()
	var huge: Dictionary=DISPLAY.snapshot(g,entry)
	check(huge.expected is Dictionary and FORMAT.compact(huge.expected).contains("e+") and g.rng.state==state and g.profile==projected_profile,"Expected damage projection uses large-number arithmetic without mutation")
	weapon_row.dmg=old_damage;weapon_row.dmgMulti=old_growth;cfg.base_critical_multiplier.value=old_multiplier;g.invalidate_stat_cache()
	g.set_enhancement_branch("weapons","critical",2,"A")
	g.set_enhancement_branch("weapons","critical",3,"A")
	g.set_enhancement_branch("weapons","critical",1,"A")
	g.set_enhancement_branch("weapons","repeat",1,"A");g.set_enhancement_branch("weapons","repeat",2,"A");g.set_enhancement_branch("weapons","repeat",3,"B")
	g.invalidate_stat_cache();g.reset_player();scene.refresh_structure();scene.equipment_panel.refresh()
	if DisplayServer.get_name()!="headless":root.size=Vector2i(1180,760)
	await frames()
	await click(scene.system_nav_buttons[4])
	var enhancement=scene.enhancement_panel
	var repeat=enhancement.effect_cards.weapons[g.enhancement_order("weapons").find("repeat")].description
	var critical=enhancement.effect_cards.weapons[g.enhancement_order("weapons").find("critical")].description
	check(repeat.get_parsed_text().contains("9.7K%") and critical.get_parsed_text().contains("14.6K%"),"Live 479 overview matches both user examples")
	check(not repeat.get_parsed_text().contains("倍") and not critical.get_parsed_text().contains("倍") and repeat.get_parsed_text().contains("原伤害"),"Overview distinguishes original-damage percent from extra bonus")
	await capture("overview")
	if DisplayServer.get_name()!="headless":check(repeat.get_content_height()<=repeat.size.y and critical.get_content_height()<=critical.size.y,"Both compact percentage summaries fit normal width")
	await click(enhancement.effect_cards.weapons[2].branches)
	check(enhancement.branch_overlay.visible,"Actual branch button opens drawer")
	await capture("branches")
	await click(enhancement.branch_close_button)
	await click(scene.system_nav_buttons[0])
	var panel=scene.equipment_panel
	await click(panel.cards.weapons_0)
	check(panel.items.weapons_0.mainStatLabel==UIText.t("weapon.expected_damage") and equal(panel.items.weapons_0.mainStatNumber,DISPLAY.snapshot(g,entry).expected),"Module card labels and displays expected damage")
	await capture("modules")
	panel.show_inspector()
	check(panel.items.weapons_0.tooltip.contains("伤害比例生效概率") and panel.detail.primary.tooltip_text.contains("期望伤害"),"Precise detail exposes base, trigger, multiplier and expectation")
	if not panel.details_open:await click(panel.detail.more)
	await capture("detail")
	check(panel.detail.stats.visible and panel.detail.stats.text.contains("期望伤害") and panel.detail.stats.text.contains("单次基础伤害"),"Expanded inspector and next-level preview share expectation")
	var values: Dictionary=panel.items.weapons_0.projection
	for field in ["base","expected"]:
		check(panel.detail.stats.text.contains(FORMAT.compact(values[field])) and not panel.detail.stats.text.contains(FORMAT.precise(values[field])),"Visible "+field+" uses quantity compact format")
		check(panel.detail.stats.tooltip_text.contains(FORMAT.precise(values[field])) and panel.detail.primary.tooltip_text.contains(FORMAT.precise(values[field])) and panel.items.weapons_0.tooltip.contains(FORMAT.precise(values[field])),"Exact "+field+" remains in detail and card hover")
	check(panel.detail.stats.mouse_filter==Control.MOUSE_FILTER_PASS,"Expanded stats accepts hover without blocking scroll")
	panel.detail_frame.hide();panel.cards.weapons_0.grab_focus()
	var card: Button=panel.cards.weapons_0
	var other: Button=panel.cards.weapons_1
	scene.writes.clear();scene.projections.clear()
	for i in 20:panel.refresh_pending()
	check(scene.writes.is_empty() and scene.projections.is_empty(),"Paused stable page performs zero writes or module projections")
	g.set_enhancement_branch("weapons","critical",2,"B")
	live=g.enhancement_branches.weapon(g,0);live.stacks=1;live.stack_time=1.0
	panel.refresh()
	var before=panel.items.weapons_0.mainStatNumber
	scene.writes.clear()
	scene.projections.clear()
	var context: Dictionary=g.begin_enhancement_attack(0,{},false,false);context.critical=true;g.finish_enhancement_attack(0)
	check(panel.stats_dirty.is_empty(),"Timed stack activation does not invalidate module UI")
	panel.refresh_pending()
	check(scene.projections.is_empty() and scene.writes.is_empty(),"Timed stack activation performs no module projection or property write")
	check(equal(panel.items.weapons_0.mainStatNumber,before) and panel.cards.weapons_0==card and root.gui_get_focus_owner()==card,"Stable presentation preserves card and focus")
	check(not scene.writes.has(other),"Timed stack change leaves unrelated module untouched")
	var combat_before=g.jewel_equipment_stat(entry)
	live.stack_time=0.1;g.enhancement_branches.advance_weapons(g,0.1);panel.refresh_pending()
	check(equal(panel.items.weapons_0.mainStatNumber,before) and N.compare(g.jewel_equipment_stat(entry),combat_before)<0,"Timed stack expiry changes combat only")
	check(scene.projections.is_empty() and scene.writes.is_empty(),"Timed expiry performs no panel work")
	g.set_enhancement_branch("weapons","proficiency",1,"B")
	g.spawn_group();g.state=BattleGame.State.COMBAT
	live=g.enhancement_branches.weapon(g,0);live.target=g.enemies[0]
	panel.refresh();scene.projections.clear();scene.writes.clear()
	var stable=DISPLAY.snapshot(g,entry)
	var stable_next=DISPLAY.snapshot(g,entry,151)
	combat_before=g.jewel_equipment_stat(entry)
	g.enhancement_branches.advance_weapons(g,float(cfg.proficiency_b1_interval.value))
	panel.refresh_pending()
	check(DISPLAY.snapshot(g,entry)==stable and DISPLAY.snapshot(g,entry,151)==stable_next,"Dwell interval affects neither current nor next-level display")
	check(N.compare(g.jewel_equipment_stat(entry),combat_before)>0,"Dwell interval still raises combat damage")
	check(scene.projections.is_empty() and scene.writes.is_empty(),"Dwell interval generates no equipment UI refresh")
	scene.select_system(4);await frames();scene.writes.clear();scene.projections.clear()
	live.stacks=2;live.stack_time=.1
	g.enhancement_branches.advance_weapons(g,.1);panel.refresh_pending()
	check(scene.writes.is_empty() and scene.projections.is_empty(),"Hidden timed changes perform no equipment UI work")
	scene.select_system(0);await frames();panel.refresh_pending()
	check(equal(panel.items.weapons_0.mainStatNumber,DISPLAY.snapshot(g,entry).expected) and panel.cards.weapons_0==card,"Reveal retains stable projection without rebuilding card")
	# Persisted attack history remains a display dependency, unlike timed buffs.
	before=panel.items.weapons_0.mainStatNumber
	g.profile.enhancementAttacks=1000000;g.event.emit("equipment_stats",{"category":"weapons"});panel.refresh_pending()
	check(N.compare(panel.items.weapons_0.mainStatNumber,before)>0,"Event-based attack history still refreshes displayed damage")
	check(scene.equipment_detail_text(entry).contains(scene.number(float(g.db.equip("laser",int(entry.level)).cd))),"Static attack interval remains in equipment detail")
	print("PERCENTAGE EXPECTED DAMAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
