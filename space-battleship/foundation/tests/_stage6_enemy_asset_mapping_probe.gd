extends SceneTree
const Session = preload("res://src/game_session.gd")
const Identity = preload("res://scripts/enemy_visual_identity.gd")
func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(1); return
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("ENEMY_ASSET_MAPPING_FAILED " + reason)
	quit(1)
	return false
func _run() -> void:
	var session = Session.new()
	if not _check(session.initialize("res://generated/config.json", 701).ok and session.start_campaign_sortie(1).ok, "initialize"): return
	var count: int = 0
	for archetype in Identity.ARCHETYPES:
		for tier in ["normal", "elite", "boss", "ultimate"]:
			for leader in [false, true]:
				session.battle.reset_for_sortie()
				var inputs: Dictionary = session.battle.wave_inputs()
				var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
				var actor: Dictionary = setup.wave.enemies[0]
				actor.archetype_id = archetype
				actor.armourType = int(Identity.ARCHETYPES[archetype][1])
				actor.combat_tier = tier
				actor.encounter_leader = leader
				if not _check(session.battle.start_wave(setup).ok, "start " + archetype): return
				var expected: String = str(Identity.ARCHETYPES[archetype][0])
				if archetype in Identity.RANKED_ARCHETYPES:
					if tier == "elite": expected += "_elite"
					elif tier in ["boss", "ultimate"] and leader: expected += "_boss"
				var actual: Dictionary = session.battle._kernel.enemy_views()[0]
				if not _check(actual.visual_key == expected and session.battle._models.has(expected), archetype + " " + tier + " leader=" + str(leader)): return
				var intel: Dictionary = session.battle.enemy_intelligence()[0]
				var native: Dictionary = session.battle._kernel.geometry_details()
				if not _check(intel.visual_key == expected and intel.texture == session.battle._models[expected].texture and native.actors[0].visual_key == expected and native.actors[0].collision_hull == session.battle._enemy_hulls[0], "texture/hull/intel split " + expected): return
				var packet: Dictionary = preload("res://scripts/ship_geometry_convention.gd").battle_geometry(session.battle._kernel.enemy_views(), session.battle._models, session.battle._ship_key, session.battle._player_art, session.battle._player_dimensions, session.battle._player_geometry_height, session.battle._geometry, session.battle._parameters)
				var dimensions: Vector2 = packet.poses[0].dimensions
				var size: Vector2 = session.battle._models[expected].size
				if not _check(absf(dimensions.x / size.x - dimensions.y / size.y) < 0.000001 and absf(float(packet.poses[0].angle) - PI) < 0.5, "enemy aspect/direction " + expected): return
				count += 1
	session.battle.reset_for_sortie()
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	setup.wave.enemies[0].archetype_id = null
	if not _check(session.battle.start_wave(setup).ok, "untyped compatibility"): return
	if not _check(session.battle._kernel.enemy_views()[0].visual_key == Identity.legacy_key(setup.wave.enemies[0]), "authorized generic compatibility mapping"): return
	print("STAGE6_APPROVED_ENEMY_IDENTITY_RANK_MAPPING_OK cases=", count, " explicit_legacy_migration=true")
	quit(0)
