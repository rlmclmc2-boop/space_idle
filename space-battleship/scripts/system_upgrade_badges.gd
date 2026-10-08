extends Node
## Navigation-owned quotes: rebuild only on price/eligibility changes; currency events
## compare cached prices. No process loop, profile mutation, or read-to-dismiss state.
const SUPPORTED = [0,1,2,4,9]
const Bag = preload("res://scripts/drone_inventory.gd")
const Forge = preload("res://scripts/drone_forge.gd")
const UIText = preload("res://scripts/ui_text.gd")
const PAID_MODIFICATIONS = ["add_affix","replace_affix","add_hanging_slot","lock_affix","promote_affix","reroll_values","enable_omen","legendary","modernize","ultimate"]
var game
var buttons: Array[Button] = []
var badges: Dictionary = {}
var quotes: Dictionary = {}
var price_dirty: Dictionary = {}
var balance_dirty: Dictionary = {}
var queued := false
var active := false

class UpgradeBadge extends Control:
	func _draw() -> void:
		draw_circle(Vector2(6,6),6,Color("f05261"))
		draw_line(Vector2(3,6),Vector2(9,6),Color.WHITE,1.5)
		draw_line(Vector2(6,3),Vector2(6,9),Color.WHITE,1.5)

func setup(source, navigation: Array[Button]) -> void:
	game = source
	buttons = navigation.duplicate()
	active = true
	for index in SUPPORTED:
		if index>=buttons.size() or not is_instance_valid(buttons[index]):continue
		var badge := UpgradeBadge.new()
		badge.name = "UpgradeBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.tooltip_text = UIText.t("navigation.upgrade_available")
		buttons[index].add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		badge.position = Vector2(8,8)
		badge.size = Vector2(12,12)
		badge.visible = false
		badges[index] = badge
		buttons[index].visibility_changed.connect(_visibility_changed.bind(index))
	game.event.connect(on_event)
	invalidate(SUPPORTED,true)

func _exit_tree() -> void:
	active = false
	if is_instance_valid(game) and game.event.is_connected(on_event):game.event.disconnect(on_event)
	game = null
	queued = false
	price_dirty.clear()
	balance_dirty.clear()
	quotes.clear()
	buttons.clear()
	badges.clear()

func _visibility_changed(index: int) -> void:
	invalidate([index],true)

func invalidate(indices: Array, prices: bool) -> void:
	if not active or indices.is_empty():return
	for index in indices:
		balance_dirty[index] = true
		if prices:price_dirty[index] = true
	if not queued:
		queued = true
		call_deferred("flush")

func on_event(kind: String, info: Dictionary) -> void:
	if not active:return
	match kind:
		"resources_changed":
			var affected: Array = []
			for index in [0,1,2]:
				for cost in quotes.get(index,[]):
					if info.get("ids",[]).any(func(id):return cost.has(str(id))):
						affected.append(index)
						break
			invalidate(affected,false)
		"upgrade","upgrades_completed","module_changed","equipment_changed":invalidate([0],true)
		"scientists_changed":
			if info.has("purchased"):invalidate([1],true)
		"reactor_changed":
			if info.has("level"):invalidate([2],true)
		"enhancement_currency","jewels_changed":invalidate([4],false)
		"enhancement_changed":invalidate([4],true)
		"unlock","unlocks_changed","planet_reforged","ship_changed":invalidate(SUPPORTED,true)
		"hyperspace_changed":
			var reason := str(info.get("reason",""))
			if reason == "materials_exchanged":invalidate([9],false)
			elif reason in ["claimed","completed_pending","unsealed","equipment_changed","hangings_changed","preset_applied","hull_capacity_changed"] or reason.begins_with("forge_"):
				invalidate([9],true)

func flush() -> void:
	queued = false
	if not active or not is_instance_valid(game):return
	var prices := price_dirty.keys()
	var balances := balance_dirty.keys()
	price_dirty.clear()
	balance_dirty.clear()
	for index in prices:
		if not valid_navigation(index):
			quotes.erase(index)
			continue
		quotes[index] = build_quotes(index) if buttons[index].visible else []
	for index in balances:
		if not valid_navigation(index):continue
		var available := buttons[index].visible and affordable(index)
		if badges[index].visible != available:badges[index].visible = available

func valid_navigation(index: int) -> bool:
	return index>=0 and index<buttons.size() and is_instance_valid(buttons[index]) and is_instance_valid(badges.get(index))

func build_quotes(index: int) -> Array:
	var result: Array = []
	match index:
		0:
			for category in ["weapons","defence"]:
				for slot in game.active_slot_count(category):
					var cost: Dictionary = game.slot_upgrade_cost(category,slot,1)
					if not cost.is_empty():result.append(cost)
		1:
			if game.db.data.hightech.keys().any(func(key):return game.hightech_unlocked(key)):
				result.append(game.scientist_cost(0))
		2:
			if game.reactor_unlocked():
				var cost: float = game.reactor_upgrade_cost()
				if is_finite(cost) and cost > 0:result.append({str(int(game.db.config.reactorUraniumId)):cost})
		4:
			if game.enhancement_unlocked() and not game.enhancement_at_limit():result.append({"fragments":game.enhancement_cost()})
		9:result = drone_quotes()
	return result

func affordable(index: int) -> bool:
	for cost in quotes.get(index,[]):
		var enough := true
		for id in cost:
			var owned = game.profile.resources.get(id,0)
			if index == 4:owned = game.profile.jewelFragments
			elif index == 9:
				owned = game.profile.hyperspace.ultimate_cores if id == "ultimate_cores" else game.profile.hyperspace.materials.get(id,0)
			if not GrowthNumber.valid(cost[id]) or GrowthNumber.compare(owned,cost[id]) < 0:
				enough = false
				break
		if enough:return true
	return false

func drone_quotes() -> Array:
	var result: Array = []
	var state: Dictionary = game.profile.hyperspace
	if not state.unlocked_drones:return result
	for id in state.inventory.drones:
		if state.inventory.sealed.has(id):continue
		for operation in PAID_MODIFICATIONS:
			# Exact domain validation and pricing, with only the mutated drone copied.
			# Local restored RNG cannot consume the player's forge RNG or command seq.
			var preview: Dictionary = state.duplicate()
			preview.materials = state.materials.duplicate()
			preview.legendary_seen = state.legendary_seen.duplicate()
			preview.inventory = state.inventory.duplicate()
			preview.inventory.drones = state.inventory.drones.duplicate()
			preview.inventory.drones[id] = state.inventory.drones[id].duplicate(true)
			var plan: Dictionary = Forge.plan(preview,game.hyperspace.config,{"operation":operation,"drone_id":id,"args":{}},game)
			if plan.error not in ["","insufficient_materials"]:continue
			var cost: Dictionary = plan.get("cost",{})
			if cost.is_empty() or not cost.values().any(func(value):return float(value)>0):continue
			if not Bag.valid_drone(preview.inventory.drones[id],game.hyperspace.config):continue
			if not Bag.equipment_valid(preview.inventory,preview.inventory.equipped,int(game.hyperspace.config.maximum_equipped),game.hyperspace.config):continue
			if not game.hyperspace.equipment_constraints(game,preview.inventory.equipped,preview.inventory):continue
			if not result.has(cost):result.append(cost)
	return result
