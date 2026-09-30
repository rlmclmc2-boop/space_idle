extends SceneTree
# UI-only fixture. Production scripts/data are unchanged. MAX count is fixed at 7;
# this probe does not validate growth, purchases or balance.
class FixtureGame extends BattleGame:
	var injected = false
	var fixture_value = 1e17
	func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null) -> Variant:
		return fixture_value if injected else super.jewel_equipment_stat(entry,level,effects)
	func slot_upgrade_cost(category: String, index: int, levels := 1) -> Dictionary:
		return {"1":fixture_value*levels} if injected else super.slot_upgrade_cost(category,index,levels)
	func max_upgrade_amount_slot(category: String, index: int) -> int:
		return 7 if injected else super.max_upgrade_amount_slot(category,index)
class FixtureUI extends "res://scripts/main.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return FixtureGame.new(db,false)
var scene
var panel
var output: String
var snapshots: Array = []
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
func measure(control: Control) -> Dictionary:
	var result := {"text":control.text,"rect":str(control.get_global_rect()),"size":[control.size.x,control.size.y],"visible":control.is_visible_in_tree(),"tooltip":control.tooltip_text}
	var font: Font = control.get_theme_font("font")
	var fontsize: int = control.get_theme_font_size("font_size")
	result.font_size=fontsize
	result.text_width=font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fontsize).x
	result.minimum_size=str(control.get_combined_minimum_size())
	if control is Label:
		result.clip_text=control.clip_text
		result.line_count=control.get_line_count()
	return result
func capture(tag: String) -> void:
	await settle()
	var img = root.get_texture().get_image()
	img.save_png(output+"/"+tag+"-viewport.png")
	var native = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	var screenshot_status = OS.execute("import",["-display",":99","-window",str(native),output+"/"+tag+".png"])
	var record := {"tag":tag,"native_screenshot_exit":screenshot_status,"pixels":[img.get_width(),img.get_height()],"window":str(root.size),"viewport":str(root.get_visible_rect()),"hull":scene.game.profile.selectedShip,"stat_cost_input":scene.game.fixture_value,"resources":scene.game.profile.resources.duplicate(true),"amount":panel.upgrade_amount,"max_count_fixture":7,"cards":{},"detail":{},"resource_text":[scene.resource_display("1"),scene.resource_display("2")]}
	for id in panel.cards:
		var card = panel.cards[id]
		var row := {"rect":str(card.get_global_rect()),"size":str(card.size),"compact":card.compact,"level":scene.game.module_entry(panel.items[id].category,panel.items[id].index).level}
		for key in ["title","level","stat"]:row[key]=measure(card.fields[key])
		row.upgrade=measure(card.upgrade_button)
		row.upgrade_right_overflow=card.upgrade_button.position.x+card.upgrade_button.size.x-card.size.x
		row.stat_right_overflow=card.fields.stat.position.x+card.fields.stat.size.x-card.size.x
		record.cards[id]=row
	for key in ["title","meta","primary","description","stats","upgrade","ten","max"]:record.detail[key]=measure(panel.detail[key])
	snapshots.append(record)
	print("CAPTURE ",tag," ",img.get_size())
func run() -> void:
	output=ProjectSettings.globalize_path("res://..").trim_suffix("/")
	root.gui_embed_subwindows=true
	root.size=Vector2i(1373,883)
	scene=FixtureUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.onboarding.completed=true
	scene.game.profile.onboarding.dismissed=true
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	await capture("00-initial-baseline-normal")
	scene.game.injected=true
	scene.game.fixture_value=1e17
	scene.game.profile.resources={"1":1e17,"2":1e17}
	panel.refresh()
	scene.refresh_draw_layers(0)
	await capture("01-initial-100000T-normal")
	scene.game.profile.cleared=range(1,60)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.switch_ship("Heavy_Battleship")
	for i in scene.game.active_slot_count("weapons"):scene.game.equip_slot("weapons",i,BattleGame.WEAPON_KEYS[i%4])
	for i in scene.game.active_slot_count("defence"):scene.game.equip_slot("defence",i,BattleGame.DEFENSE_KEYS[i%2])
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	for sample in [{"name":"100000T","value":1e17,"level":100000},{"name":"999999T","value":9.99999e17,"level":999999},{"name":"scientific","value":1.23456e100,"level":2147483647}]:
		scene.game.fixture_value=sample.value
		scene.game.profile.resources={"1":sample.value,"2":sample.value}
		for category in ["weapons","defence"]:
			for i in scene.game.active_slot_count(category):scene.game.module_entry(category,i).level=sample.level
		panel.refresh()
		scene.refresh_draw_layers(0)
		for resolution in [Vector2i(1373,883),Vector2i(960,540)]:
			root.size=resolution
			await settle()
			var base="heavy-"+sample.name+"-"+str(resolution.x)+"x"+str(resolution.y)
			panel.detail_frame.hide()
			for amount in [1,10,0]:
				panel.set_upgrade_amount(amount)
				await capture(base+"-"+str(amount))
			panel.select_item("weapons_0")
			panel.show_inspector()
			await capture(base+"-detail-weapon")
			panel.select_item("defence_0")
			panel.show_inspector()
			await capture(base+"-detail-armour")
			panel.open_picker("defence_1")
			await capture(base+"-picker-shield")
			panel.detail.slots.show_popup()
			await capture(base+"-picker-dropdown")
			panel.detail.slots.get_popup().hide()
			panel.detail_frame.hide()
	var format_probes=[]
	for n in [1e17,9.99999e17,9.99999e19,1e20,1.23456e100,{"m":1.23456,"e":350}]:format_probes.append({"input":n,"actual":scene.number(n)})
	var file=FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"base_commit":"b0eed6fbfc6a62f1bea27d2f89e8b68dd6ebc5c4","fixture_scope":"UI only; exact stat/cost inputs; fixed MAX=7; levels retain production integer formatter","format_probes":format_probes,"snapshots":snapshots},"\t"))
	quit()
