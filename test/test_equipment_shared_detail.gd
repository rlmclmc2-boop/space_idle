extends SceneTree

const Tab = preload("res://scripts/equipment_tab.gd")

class TrackedTab extends Tab:
	var detail_refreshes := 0
	func refresh_detail(next_projection: Dictionary = {}, force := false) -> void:
		detail_refreshes += 1
		super.refresh_detail(next_projection,force)

class UI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func show_chrono_login_report() -> void:pass

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.set_script(UI)
	scene.automation_args=["--capture"]
	scene.music_on=false
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	var original = scene.equipment_panel
	scene.equipment_tabs.remove_child(original)
	original.queue_free()
	var panel = TrackedTab.new()
	panel.name="Equipment"
	scene.equipment_panel=panel
	scene.equipment_tabs.add_child(panel)
	scene.equipment_tabs.move_child(panel,0)
	panel.setup(scene)
	var game=scene.game
	game.save_enabled=false
	game.profile.onboarding.completed=true
	game.profile.cleared=range(1,101)
	game.profile.highestLevel=101
	game.profile.grantedUnlocks=[game.db.unlock_id("feature","jewels")]
	game.rebuild_unlocks()
	game.pending_unlocks.clear()
	game.profile.selectedShip="Heavy_Battleship"
	game.profile.loadout.defence=[{"key":"shield","level":10},{"key":"armour","level":10},{"key":"shield","level":10},{"key":"armour","level":10}]
	game.profile.jewelFragments=1e40
	game.profile.enhancementLevel=30
	game.invalidate_stat_cache()
	game.reset_player()
	scene.refresh_structure()
	scene.select_system(0)
	await process_frame # Let the replacement TabContainer child become visible before selection.
	panel.refresh_pending()
	panel.select_item(game.slot_id("defence",0))
	panel.show_inspector()
	await process_frame
	var before_text: String=panel.detail.stats.text
	var before_projection=panel.items[panel.selected].projection.duplicate(true)
	check(before_text.contains("30%") and before_text.contains("300%"),"Open shield detail displays level 30 memory material")
	panel.detail_refreshes=0
	check(game.upgrade_enhancement(1)==1,"Shared enhancement purchases level 31")
	check(panel.detail_refreshes==0,"Event callbacks defer visible detail refresh")
	panel.refresh_pending()
	var after_text: String=panel.detail.stats.text
	check(panel.detail_refreshes==1,"Multiple enhancement events coalesce into one detail refresh")
	check(after_text.contains("31%") and after_text.contains("310%") and after_text!=before_text,"Open detail displays level 31 memory material")
	check(panel.items[panel.selected].projection==before_projection,"Text changes even when selected projection does not")
	panel.detail_frame.hide()
	panel.detail_refreshes=0
	game.profile.enhancementLevel=32
	game.invalidate_stat_cache()
	scene.on_event("enhancement_changed",{"purchased":1})
	panel.refresh_pending()
	check(panel.detail_refreshes==0,"Closed detail skips refresh work")
	panel.show_inspector()
	check(panel.detail.stats.text.contains("32%") and panel.detail.stats.text.contains("320%"),"Reopened detail displays latest text")
	panel.detail_refreshes=0
	scene.select_system(4)
	await process_frame
	game.profile.enhancementLevel=33
	game.invalidate_stat_cache()
	scene.on_event("enhancement_changed",{"purchased":1})
	scene.on_event("planet_changed",{"id":"1","reward":1.0})
	panel.refresh_pending()
	check(panel.detail_refreshes==0,"Hidden equipment page defers detail refresh")
	scene.select_system(0)
	await process_frame
	panel.refresh_pending()
	check(panel.detail.stats.text.contains("33%") and panel.detail.stats.text.contains("330%"),"Revealed page updates real detail text")
	print("EQUIPMENT SHARED DETAIL: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
