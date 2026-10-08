extends SceneTree
const Main = preload("res://scripts/main.gd")
## In-memory eligibility, persistence, unrelated-event and quote invalidation checks.
class Badges extends "res://scripts/system_upgrade_badges.gd":
	var builds: Dictionary = {}
	func build_quotes(index: int) -> Array:
		builds[index] = int(builds.get(index,0))+1
		return super.build_quotes(index)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game := BattleGame.new(ShipDatabase.new(),false)
	var buttons: Array[Button] = []
	for index in 11:
		var button := Button.new()
		root.add_child(button)
		buttons.append(button)
	var old_badge := Control.new()
	old_badge.name = "ActivationBadge"
	buttons[9].add_child(old_badge)
	var original_listeners := game.event.get_connections().size()
	var badge := Badges.new()
	root.add_child(badge)
	badge.setup(game,buttons)
	await process_frame
	for index in [3,5,6,7,8,10]:assert(not buttons[index].has_node("UpgradeBadge"))
	game.profile.cleared = [1]
	game.rebuild_unlocks()
	game.event.emit("unlocks_changed",{})
	await process_frame
	var scientist_cost: Dictionary = game.scientist_cost(0)
	for id in scientist_cost:game.profile.resources[id] = scientist_cost[id]
	game.resources_changed(scientist_cost.keys())
	await process_frame
	assert(badge.badges[1].visible == game.can_generate_scientist(1))
	var quote_builds := int(badge.builds[0])
	for _i in 20:game.event.emit("upgrade",{})
	await process_frame
	assert(int(badge.builds[0]) == quote_builds+1,"price invalidations coalesce")
	var cost: Dictionary = game.slot_upgrade_cost("weapons",0,1)
	for id in game.profile.resources:game.profile.resources[id] = 0
	game.resources_changed(cost.keys())
	await process_frame
	assert(not badge.badges[0].visible)
	for id in cost:game.profile.resources[id] = cost[id]
	var builds := badge.builds.duplicate()
	for _i in 20:game.resources_changed(cost.keys())
	await process_frame
	assert(badge.badges[0].visible)
	assert(builds == badge.builds,"currency bursts must not rebuild prices")
	buttons[0].pressed.emit()
	await process_frame
	assert(badge.badges[0].visible,"opening never dismisses an upgrade")
	for id in cost:game.profile.resources[id] = 0
	game.resources_changed(cost.keys())
	await process_frame
	assert(not badge.badges[0].visible)
	game.profile.resources[str(int(game.db.config.reactorUraniumId))] = game.reactor_upgrade_cost()
	game.resources_changed([str(int(game.db.config.reactorUraniumId))])
	await process_frame
	assert(badge.badges[2].visible == game.reactor_unlocked())
	buttons[2].hide()
	await process_frame
	assert(not badge.badges[2].visible)
	buttons[2].show()
	await process_frame
	assert(badge.badges[2].visible == game.reactor_unlocked())
	builds = badge.builds.duplicate()
	for _i in 10:
		game.event.emit("hit",{})
		game.event.emit("state",{})
		game.resources_changed(["not-used"])
	await process_frame
	assert(builds == badge.builds and not badge.queued)
	game.profile.cleared = range(1,31)
	game.rebuild_unlocks()
	game.event.emit("unlocks_changed",{})
	await process_frame
	assert(game.enhancement_unlocked())
	game.profile.jewelFragments = game.enhancement_cost()
	game.event.emit("enhancement_currency",{})
	await process_frame
	assert(badge.badges[4].visible and game.can_upgrade_enhancement())
	assert(game.upgrade_enhancement(1) == 1)
	await process_frame
	assert(not badge.badges[4].visible and not game.can_upgrade_enhancement())
	game.profile.hyperspace.unlocked_drones = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var drone: Dictionary = preload("res://scripts/drone_rewards.gd").create_drone(rng,game.hyperspace.config,"badge-drone","blue","laser",1,"1")
	game.profile.hyperspace.inventory.drones[drone.id] = drone
	game.profile.hyperspace.inventory.warehouse.append(drone.id)
	for id in game.profile.hyperspace.materials:game.profile.hyperspace.materials[id] = 1000000000
	game.profile.hyperspace.ultimate_cores = 0
	var before := JSON.stringify(game.profile)
	game.event.emit("hyperspace_changed",{"reason":"claimed"})
	await process_frame
	assert(before == JSON.stringify(game.profile),"quotes must not mutate profile or RNG")
	assert(badge.badges[9].visible)
	builds = badge.builds.duplicate()
	for id in game.profile.hyperspace.materials:game.profile.hyperspace.materials[id] = 0
	game.event.emit("hyperspace_changed",{"reason":"materials_exchanged"})
	await process_frame
	assert(not badge.badges[9].visible and builds == badge.builds)
	assert(old_badge.visible and buttons[9].get_node("ActivationBadge") == old_badge)
	game.profile.hyperspace.inventory.sealed[drone.id] = 1
	game.event.emit("hyperspace_changed",{"reason":"unsealed"})
	await process_frame
	assert(badge.quotes[9].is_empty())
	# Leave the owner alive outside the tree while its already-deferred flush runs.
	game.event.emit("upgrade",{})
	assert(badge.queued)
	root.remove_child(badge)
	await process_frame
	assert(game.event.get_connections().size() == original_listeners,"owner teardown disconnects its listener")
	assert(not badge.active and not badge.queued and badge.price_dirty.is_empty() and badge.balance_dirty.is_empty())
	badge.free()
	var empty := Badges.new()
	root.add_child(empty)
	empty.setup(game,[])
	await process_frame
	assert(empty.builds.is_empty(),"missing navigation cannot build quotes or index buttons")
	empty.free()
	var partial := Badges.new()
	root.add_child(partial)
	var one_button: Array[Button] = [Button.new()]
	root.add_child(one_button[0])
	partial.setup(game,one_button)
	one_button[0].free()
	await process_frame
	assert(partial.builds.is_empty(),"navigation freed before flush is ignored")
	partial.free()
	print("PASS system upgrade badges: exact affordability, hidden/reveal, read persistence, cached/coalesced currency, drone side effects and old badge")
	quit()
