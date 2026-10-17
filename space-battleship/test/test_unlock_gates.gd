extends SceneTree

const MODEL = preload("res://scripts/ai_tech_tree.gd")
const VIEW = preload("res://scripts/ai_tech_view_model.gd")
const DB = preload("res://scripts/database.gd")
const GAME = preload("res://scripts/game.gd")
const REACTOR_PANEL = preload("res://scripts/reactor_panel.gd")
const REACTOR_SCROLL = preload("res://scripts/reactor_module_scroll.gd")

class FakeGame:
	extends RefCounted
	var db := {"data": {"ai_tech_tree": {}}}
	var profile := {"aiTechLevels": {}, "aiTechActive": "", "aiTechInput": {"1": 0, "2": 0}, "resources": {"1": 0.0, "2": 0.0}, "aiTechProgress": {}, "aiIncomePeak": {}}
	var enhancement := false
	func enhancement_unlocked() -> bool: return enhancement
	func tech_tree_snapshot() -> Dictionary: return MODEL.snapshot(self)

class FakeBranch:
	extends Control
	var flow_offset := 0.0
	var network_length := 0.0

func ids(snapshot: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for row in snapshot.technologies:result.append(str(row.id))
	return result

func _initialize() -> void:
	var game := FakeGame.new()
	game.db.data.ai_tech_tree = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_tech_tree.json"))
	var initial := ids(VIEW.snapshot(game))
	game.enhancement = true
	var enhancement_visible := ids(VIEW.snapshot(game))
	game.profile.aiTechLevels.weapon_accuracy = 11
	game.profile.aiTechLevels.equipment_reinforcement = 11
	var core_visible := ids(VIEW.snapshot(game))
	game.profile.aiTechLevels.equipment_finishing = 1
	game.profile.aiTechProgress.equipment_finishing = 42.0
	var earned_visible := ids(VIEW.snapshot(game))
	game.profile.aiTechLevels.resource_refining = 11
	game.profile.aiTechLevels.equipment_finishing = 10
	game.profile.aiTechLevels.uranium_extraction = 10
	var final_visible := ids(VIEW.snapshot(game))
	var ok := not initial.has("fragment_condensation") and not initial.has("equipment_precision") and not initial.has("joint_integration")
	ok = ok and enhancement_visible.has("fragment_condensation") and not enhancement_visible.has("equipment_precision")
	ok = ok and core_visible.has("equipment_precision") and earned_visible.has("equipment_precision")
	ok = ok and final_visible.has("joint_integration")
	ok = ok and game.profile.aiTechProgress.equipment_finishing == 42.0
	ok = ok and VIEW.requirement(game, "fragment_condensation", 0) == "解锁条件：强化系统"
	var battle = GAME.new(DB.new(), false)
	var before_modules: PackedStringArray = battle.reactor_available_modules()
	battle.profile.cleared.append(15)
	var after_modules: PackedStringArray = battle.reactor_available_modules()
	ok = ok and not before_modules.has("condensation") and after_modules.has("condensation")
	var panel = REACTOR_PANEL.new()
	panel.module_scroll = REACTOR_SCROLL.new()
	panel.allocation_scroll = REACTOR_SCROLL.new()
	panel.module_content = Control.new()
	panel.allocation_content = Control.new()
	panel.add_child(panel.module_scroll)
	panel.add_child(panel.allocation_scroll)
	panel.module_scroll.add_child(panel.module_content)
	panel.allocation_scroll.add_child(panel.allocation_content)
	for key in battle.reactor_modules():
		var row := Control.new()
		var allocation_row := Control.new()
		var branch := FakeBranch.new()
		var scene_fx := FakeBranch.new()
		panel.module_content.add_child(row)
		panel.allocation_content.add_child(allocation_row)
		row.add_child(branch)
		row.add_child(scene_fx)
		panel.module_controls[key] = {"row": row, "allocation_row": allocation_row, "branch": branch, "scene_fx": scene_fx, "index": 0}
	battle.profile.cleared.erase(15)
	panel.sync_module_visibility(battle)
	ok = ok and panel.module_scroll.module_count == 3 and not panel.module_controls.condensation.row.visible
	battle.profile.cleared.append(15)
	panel.sync_module_visibility(battle)
	ok = ok and panel.module_scroll.module_count == 4 and panel.module_controls.condensation.row.visible
	ok = ok and panel.module_controls.condensation.row.position.y == 3 * panel.BAY_HEIGHT
	panel.free()
	if not ok:
		printerr("GATE_CHECK_FAIL ", initial, " | ", enhancement_visible, " | ", core_visible, " | ", earned_visible, " | ", final_visible)
		quit(1)
		return
	print("GATE_CHECK_OK initial=", initial, " enhancement=", enhancement_visible, " core=", core_visible, " earned=", earned_visible, " final=", final_visible, " reactor_before=", before_modules, " reactor_after=", after_modules)
	quit()
