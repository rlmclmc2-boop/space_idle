extends SceneTree
## Narrow regression definitions for turret resets after a geometry publication.
## No scene, native executor, combat advance or player save is required.
const Geometry = preload("res://scripts/simulation_geometry_authority.gd")
class FleetProbe extends RefCounted:
	var configuration_dirty := false
	var angles: Array = []
	var syncs := 0
	func set_slot_angles(values: Array) -> void:
		angles = values.duplicate()
		syncs += 1
	func screen_muzzle_for_slot(slot: int, _ordinal: int) -> Vector2:
		return Vector2(100.0+float(angles[slot])*10.0,700.0)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func fixture():
	var g := BattleGame.new(ShipDatabase.new(),false)
	g.stat_cache_enabled = true
	g.profile.loadout = g.empty_loadout(str(g.profile.selectedShip))
	g.profile.loadout.weapons[0] = {"key":"laser","level":1}
	var geometry = Geometry.new()
	geometry.game = g
	geometry.fleet_pose = FleetProbe.new()
	geometry.turret_pose(0).angle = 0.5
	geometry.sync_fleet_angles()
	return geometry
func launch_x(geometry) -> float:
	return geometry.launch_pose(0,Vector2(100,0),0).position.x
func check_reset(mode: String, kind: String) -> void:
	var geometry = fixture()
	check(is_equal_approx(launch_x(geometry),105.0),mode+": initial angled muzzle")
	var g = geometry.game
	match mode:
		"entry_identity":
			g.profile.loadout.weapons[0] = {"key":"laser","level":1}
		"entry_key":
			g.profile.loadout.weapons[0].key = "cannon"
		"missing_pose":
			geometry.turret_visuals.erase(0)
		"ship_owner":
			geometry.turret_ship = "previous_owner"
		"beam_entry":
			g.profile.loadout.weapons[0] = {"key":"longLaser","level":1}
	var entry: Dictionary = g.slot_entry("weapons",0)
	geometry.on_simulation_event(kind,{"shot":{"hostile":false,"mount":0,"key":entry.key,"entry":entry,"target":{}}})
	check(geometry.fleet_angles_dirty,mode+": actual reset invalidates publication")
	check(is_equal_approx(launch_x(geometry),100.0),mode+": same-step launch reads reset angle")
	check(not geometry.fleet_angles_dirty,mode+": completed synchronization clears dirty")
	var syncs: int = geometry.fleet_pose.syncs
	geometry.turret_pose(0)
	geometry.on_simulation_event(kind,{"shot":{"hostile":false,"mount":0,"key":entry.key,"entry":entry,"target":{}}})
	launch_x(geometry)
	check(geometry.fleet_pose.syncs==syncs,mode+": unchanged pose and fire reuse publication")
	geometry.game = null
	geometry.fleet_pose = null
func check_launch_before_fire() -> void:
	var geometry = fixture()
	geometry.game.profile.loadout.weapons[0] = {"key":"laser","level":1}
	check(is_equal_approx(launch_x(geometry),100.0),"provider before fire reads replaced entry angle")
	check(not geometry.fleet_angles_dirty,"provider before fire completes synchronization")
	var syncs: int = geometry.fleet_pose.syncs
	launch_x(geometry)
	check(geometry.fleet_pose.syncs==syncs,"provider repeated read does not scan all angles again")
	geometry.game = null
	geometry.fleet_pose = null
func run() -> void:
	check_launch_before_fire()
	for mode in ["entry_identity","entry_key","missing_pose","ship_owner"]:
		check_reset(mode,"fire")
	check_reset("beam_entry","beam_started")
	print("fleet_pose_cache checks=",checks," failures=",failures)
	quit(1 if failures else 0)
