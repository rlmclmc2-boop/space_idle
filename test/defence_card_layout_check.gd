extends "large_number_ui_audit.gd"
# Focused acceptance: unchanged full loadout, normal/extreme text, two window sizes.
var assertions: Array = []
func verify(ok: bool, message: String) -> void:
	assertions.append({"pass":ok,"message":message})
	if not ok:printerr(message)
func run() -> void:
	output=ProjectSettings.globalize_path("res://..").trim_suffix("/")
	root.gui_embed_subwindows=true
	scene=FixtureUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.onboarding.completed=true
	scene.game.profile.onboarding.dismissed=true
	scene.game.profile.cleared=range(1,60)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.switch_ship("Heavy_Battleship")
	for i in 8:scene.game.equip_slot("weapons",i,BattleGame.WEAPON_KEYS[i%4])
	for i in 4:scene.game.equip_slot("defence",i,BattleGame.DEFENSE_KEYS[i%2])
	scene.build_ui()
	scene.equipment_tabs.current_tab=0
	panel=scene.equipment_panel
	for extreme in [false,true]:
		if extreme:
			scene.game.injected=true
			scene.game.fixture_value=9.99999e19
			scene.game.profile.resources={"1":9.99999e19,"2":{"m":1.23456,"e":350}}
			for category in ["weapons","defence"]:
				for i in scene.game.active_slot_count(category):scene.game.module_entry(category,i).level=10000000
			panel.refresh()
		scene.refresh_draw_layers(0)
		for resolution in [Vector2i(1373,883),Vector2i(960,540)]:
			root.size=resolution
			await settle()
			var tag=("after-extreme-" if extreme else "after-normal-")+str(resolution.x)+"x"+str(resolution.y)
			await capture(tag)
			verify(panel.cards.size()==12,tag+": 12 slots retained")
			for i in 4:
				var c=panel.cards["defence_"+str(i)]
				verify(c.compact and c.size.y==176,tag+": compact card height retained")
				verify(c.picture.get_rect().end.x+8<=c.fields.title.position.x,tag+": icon/name gap")
				verify(maxf(c.picture.get_rect().end.y,c.fields.title.get_rect().end.y)<c.fields.level.position.y,tag+": header/level separate")
				verify(c.fields.level.get_rect().end.y<c.fields.stat.position.y,tag+": level/stat rows separate")
				verify(c.fields.stat.get_rect().end.y<c.upgrade_button.position.y,tag+": stat/button separate")
				verify(c.fields.level.get_theme_font("font").get_string_size(c.fields.level.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.fields.level.get_theme_font_size("font_size")).x<=c.fields.level.size.x,tag+": full level fits")
				verify(panel.grid_scroll.get_global_rect().encloses(c.get_global_rect()),tag+": defence card fully in scroll viewport")
			verify(panel.grid_scroll.scroll_vertical==0,tag+": no additional scrolling")
	var f=FileAccess.open(output+"/fix-measurements.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"snapshots":snapshots,"assertions":assertions},"\t"))
	var failed=assertions.filter(func(a):return not a["pass"])
	print("FOCUSED_CHECKS ",assertions.size()," failures ",failed.size())
	quit(0 if failed.is_empty() else 1)
