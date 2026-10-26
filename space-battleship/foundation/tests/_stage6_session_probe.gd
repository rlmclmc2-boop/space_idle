extends SceneTree

const Session = preload("res://src/game_session.gd")
const StateCodec = preload("res://foundation/host/state_codec.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")
const Notifications = preload("res://src/systems/notifications.gd")

func _initialize() -> void:
	var extension: String = OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION")
	var loaded = GDExtensionManager.load_extension(extension)
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var notices = Notifications.new()
	notices.record("unlock", "ship:starter")
	notices.record("research", "laser:1")
	notices.mark_seen("unlock:ship:starter")
	var archive: Array = notices.entries()
	if archive.size() != 2 or notices.unread() != 2:
		printerr("archive display cleared unread")
		quit(1)
		return
	notices.mark_read("unlock:ship:starter")
	var restored_notices = Notifications.new()
	var notice_ready: Dictionary = restored_notices.restore_state(notices.save_state())
	if not notice_ready.ok or restored_notices.unread() != 1 or restored_notices.unread("research") != 1:
		printerr("notice topic read state failed")
		quit(1)
		return
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var frozen_directory: String = directory.path_join("frozen-config")
	DirAccess.make_dir_recursive_absolute(frozen_directory)
	var copied_config: String = frozen_directory.path_join("config.json")
	var initial_config: String = FileAccess.get_file_as_string("res://generated/config.json")
	var copied_file: FileAccess = FileAccess.open(copied_config, FileAccess.WRITE)
	copied_file.store_string(initial_config)
	copied_file.close()
	var frozen = Session.new()
	if not frozen.initialize(copied_config, 100).ok or not frozen.configure_save_directory(frozen_directory).ok:
		printerr("frozen config fixture failed")
		quit(1)
		return
	copied_file = FileAccess.open(copied_config, FileAccess.WRITE)
	copied_file.store_string("{}")
	copied_file.close()
	var frozen_save: Dictionary = frozen.request_save()
	if not frozen_save.ok or not frozen.save_files.close(2000).ok or SaveFiles.read_pointer(frozen_directory, "active.json").envelope.configHash != initial_config.sha256_text():
		printerr("save used modified disk config instead of initialized bytes: ", frozen_save)
		quit(1)
		return
	var original = Session.new()
	var ready: Dictionary = original.initialize("res://generated/config.json", 101)
	if not ready.ok:
		printerr("initialize: ", ready)
		quit(1)
		return
	ready = original.campaign_system.start_sortie(1, original.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("sortie: ", ready)
		quit(1)
		return
	ready = original.configure_save_directory(directory)
	if ready.ok: ready = original.request_save()
	if not ready.ok:
		printerr("save: ", ready)
		quit(1)
		return
	ready = original.save_files.close(2000)
	if not ready.ok:
		printerr("close: ", ready)
		quit(1)
		return
	if original.dirty_since_save().get("dirty", true):
		printerr("newly saved session reported dirty")
		quit(1)
		return
	var restored: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not restored.ok:
		printerr("load: ", restored)
		quit(1)
		return
	if restored.session.campaign_system.restore_checkpoint() != "departing":
		printerr("checkpoint changed")
		quit(1)
		return
	restored.session.save_files.close(2000)
	original._start_wave()
	if not original.dirty_since_save().get("dirty", false):
		printerr("business change not detected as dirty")
		quit(1)
		return
	if not original.run_state.is_running():
		printerr("wave start failed: ", original.run_state.reason())
		quit(1)
		return
	ready = original.request_save()
	if ready.ok: ready = original.save_files.close(2000)
	if not ready.ok:
		printerr("combat save: ", ready)
		quit(1)
		return
	restored = Session.load_candidate("res://generated/config.json", directory)
	if not restored.ok or restored.session.campaign_system.restore_checkpoint() != "combat":
		printerr("combat load: ", restored)
		quit(1)
		return
	var retreated: bool = restored.session.campaign_system.observe_battle(
		{"player_dead": true, "wave_cleared": false, "final_cleared": false},
		restored.session.equipment.clear_switch_locks, restored.session.settle_final_collection)
	if not retreated or restored.session.campaign_system.restore_checkpoint() != "retreat" or not restored.session.tutorial.completed("retreat"):
		printerr("retreat transition did not record tutorial event")
		quit(1)
		return
	var cleared_session: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not cleared_session.ok:
		printerr("clear guidance fixture: ", cleared_session)
		quit(1)
		return
	var cleared: bool = cleared_session.session.campaign_system.observe_battle(
		{"player_dead": false, "wave_cleared": true, "final_cleared": true},
		cleared_session.session.equipment.clear_switch_locks, cleared_session.session.settle_final_collection)
	if not cleared or cleared_session.session.tutorial.completed("clear"):
		printerr("clear guidance was emitted before settlement")
		quit(1)
		return
	cleared_session.session._step(1.0 / 60.0)
	if not cleared_session.session.run_state.is_running() or not cleared_session.session.tutorial.completed("clear"):
		printerr("settled stage clear did not record tutorial event: ", cleared_session.session.run_state.reason())
		quit(1)
		return
	var snapshot: Dictionary = original.save_payload()
	var decoded: Dictionary = StateCodec.unpack(snapshot.payload)
	var damaged: Dictionary = decoded.value
	damaged.modules.equipment.slots[0].equipment_id = "missing-equipment-id"
	var rejected = Session.new()
	var attempted: Dictionary = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or not original.run_state.is_running():
		printerr("semantic candidate rejection failed: ", attempted)
		quit(1)
		return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	damaged.modules.tutorial.completed.unknown_event = true
	rejected = Session.new()
	attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or not original.run_state.is_running():
		printerr("invalid tutorial candidate admitted: ", attempted)
		quit(1)
		return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	damaged.modules.hyperspace.filter = {"version": 2, "enabled": true, "mode": "all", "action": "keep_matches", "conditions": []}
	rejected = Session.new()
	attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or attempted.reason != "InvalidFilter" or not original.run_state.is_running():
		printerr("invalid restored hyperspace filter admitted: ", attempted)
		quit(1)
		return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	damaged.pause_reasons.tutorial = true
	rejected = Session.new()
	attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or not original.run_state.is_running():
		printerr("orphan tutorial pause admitted: ", attempted)
		quit(1)
		return
	var candidate_drone: Dictionary = {"id": "space:1:fixture", "weapon": "laser", "planet_id": "1", "level": 1,
		"legendary": true, "ultimate": false, "hangings": [], "affixes": [], "hanging_slots": 0,
		"forge_revision": 0, "forge_rng_state": "1",
		"legendary_effect": {"effect_id": "drone_master", "parameters": {"maximum_reduction": 0.55}},
		"ultimate_affix": {}}
	for value in [0.55, 0.85, 0.7]:
		snapshot = original.save_payload()
		decoded = StateCodec.unpack(snapshot.payload)
		damaged = decoded.value
		candidate_drone.legendary_effect.parameters.maximum_reduction = value
		damaged.modules.hyperspace.warehouse.append(candidate_drone.duplicate(true))
		rejected = Session.new()
		attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
		if attempted.ok != (value != 0.7) or not original.run_state.is_running():
			printerr("legendary current/history validation: ", value, " ", attempted)
			quit(1)
			return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	damaged.modules.campaign.state.state = "hyperspace"
	damaged.modules.hyperspace.next_run = 2
	damaged.modules.hyperspace.manual = {"status": "Started", "round_id": 1, "run_id": 1,
		"mode": "manual", "level": 1, "work": 0.0, "wave": 0, "reward": {},
		"route": original.hyperspace_system.routes()[0].route,
		"return_target": {"stage": 1, "point": 0, "guard": false, "guard_point": 0}}
	damaged.modules.hyperspace.receipts[1] = damaged.modules.hyperspace.manual.duplicate(true)
	var interrupted = Session.new()
	attempted = interrupted.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if not attempted.ok or interrupted.campaign_system.restore_checkpoint() != "travel" or interrupted.hyperspace_system.manual_receipt().status != "Failed":
		printerr("manual interruption restore: ", attempted)
		quit(1)
		return
	var pointer: Dictionary = SaveFiles.read_pointer(directory, "active.json")
	var imported: Dictionary = Session.import_candidate("res://generated/config.json", directory,
		directory.path_join(pointer.pointer.file))
	if not imported.ok:
		printerr("import: ", imported)
		quit(1)
		return
	var offline: Dictionary = original.economy.credit_offline(100000, 12, "1")
	var cap: Dictionary = original.amount_api.apply("from_decimal", ["43200"])
	if not offline.ok or original.amount_api.apply("compare", [
		original.economy.budget().get("chrono", {}), cap.value]).scalar != 0:
		printerr("offline cap failed: ", offline)
		quit(1)
		return
	offline = original.economy.credit_offline(100000, 12, "1")
	if not offline.ok or offline.credited:
		printerr("offline capacity replayed: ", offline)
		quit(1)
		return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	damaged.modules.economy.wallet.chrono = {"m": "broken", "e": "0"}
	rejected = Session.new()
	attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or not original.run_state.is_running():
		printerr("invalid amount accepted: ", attempted)
		quit(1)
		return
	for fault in ["economy_cursor", "economy_cursor_watermark", "economy_sample", "economy_drop", "planet_timer", "planet_work", "galaxy_node", "research_id", "hyperspace_receipt", "hyperspace_drone"]:
		snapshot = original.save_payload()
		decoded = StateCodec.unpack(snapshot.payload)
		damaged = decoded.value
		match fault:
			"economy_cursor": damaged.modules.economy.cursor.registered_through = "1"
			"economy_cursor_watermark": damaged.modules.economy.cursor.registered_through = int(damaged.native.next_ids.drop) + 1
			"economy_sample": damaged.modules.economy.samples.append({"resource": "1", "source": "enemy_drop", "wall": -1.0})
			"economy_drop": damaged.modules.economy.drops["timed:1"] = {"id": "1", "amount": {"m": "-1", "e": "0"}}
			"planet_timer": damaged.modules.planet.planets["1"].elapsed = 7.0
			"planet_work": damaged.modules.planet.planets["1"].buildings.shipyard.work = 9223372036854775807
			"galaxy_node":
				var region: Dictionary = damaged.modules.galaxy.regions.values()[0]
				region.nodes.values()[0].parent_id = 999
			"research_id": damaged.modules.research.levels["missing-research-id"] = 1
			"hyperspace_receipt": damaged.modules.hyperspace.receipts[1] = {"status": "CompletedPending"}
			"hyperspace_drone": damaged.modules.hyperspace.warehouse.append({"id": "broken-drone"})
		rejected = Session.new()
		attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
		if attempted.ok or not original.run_state.is_running():
			printerr("invalid candidate accepted: ", fault, " ", attempted)
			quit(1)
			return
	ready = original.campaign_system.accept_reforge(original.campaign_system.save_state(), 5)
	original.planet_system.refresh_availability(original.campaign_system.available, false)
	var planets: Dictionary = original.planet_system.save_state()
	planets.planets["1"].buildings.shipyard.state = "built"
	for row in original.planet_system.building_options("1"):
		if row.id == "shipyard":
			planets.planets["1"].buildings.shipyard.work = int(row.name.get_slice("/", 1))
	ready = original.planet_system.restore_state(planets)
	if not ready.ok:
		printerr("reforge fixture: ", ready)
		quit(1)
		return
	snapshot = original.save_payload()
	decoded = StateCodec.unpack(snapshot.payload)
	damaged = decoded.value
	var crew_ids: Array = damaged.modules.crew.members.keys()
	if crew_ids.size() >= 2:
		for id in crew_ids.slice(0, 2):
			damaged.modules.crew.members[id].kind = "planet_explore"
			damaged.modules.crew.members[id].target = "1"
		rejected = Session.new()
		attempted = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
		if attempted.ok or not original.run_state.is_running():
			printerr("duplicate crew occupancy accepted: ", attempted)
			quit(1)
			return
	original.economy.credit_yield("1", original.amount_api.apply("from_decimal", ["100"]).value, 0.0, 0.0, false)
	original.economy.credit_yield("jewel", original.amount_api.apply("from_decimal", ["9"]).value, 0.0, 0.0, false)
	var reforge: Dictionary = original.prepare_reforge("1", [], directory)
	if not reforge.ok or reforge.session.campaign_system.restore_checkpoint() != "departing" or reforge.session.hyperspace_system.warehouse().reforge_count != 1 or reforge.session.economy.budget().has("jewel") or not reforge.session.economy.budget().has("1"):
		printerr("reforge: ", reforge)
		quit(1)
		return
	if original.planet_system.save_state().planets["1"].conquered:
		printerr("reforge preview mutated original")
		quit(1)
		return
	var denied_reforge: Dictionary = original.prepare_reforge("1", ["missing-drone"], directory)
	if denied_reforge.ok or original.planet_system.save_state().planets["1"].conquered:
		printerr("reforge rejection mutated original")
		quit(1)
		return
	var hyperspace: Dictionary = original.hyperspace_system.save_state()
	hyperspace.next_run = 100
	hyperspace.receipts[99] = {"status": "Claimed", "round_id": 1, "run_id": 99,
		"mode": "manual", "route": original.hyperspace_system.routes()[0].route,
		"level": 1, "wave": 10, "work": 1.0, "return_target": {},
		"reward": {"drone": {}, "materials": {}, "ultimate_cores": 0, "hanging_rewards": {}}}
	hyperspace.warehouse.append({"id": "space:1:99", "origin_quality": "white",
		"weapon": "laser", "level": 5, "planet_id": "1", "legendary": false,
		"ultimate": false, "blue_source_bonus": false, "affixes": [], "hangings": [],
		"hanging_slots": 0, "preserved_hanging_slots": 0, "legendary_effect": {},
		"ultimate_affix": {}, "omen": false, "forge_revision": 0,
		"weapon_generation": 1, "forge_rng_state": "1"})
	ready = original.hyperspace_system.restore_state(hyperspace)
	if not ready.ok:
		printerr("retained drone fixture: ", ready)
		quit(1)
		return
	var retained_reforge: Dictionary = original.prepare_reforge("1", ["space:1:99"], directory)
	if not retained_reforge.ok or not retained_reforge.session.hyperspace_system.warehouse().sealed.has("space:1:99") or not retained_reforge.session.hyperspace_system.save_state().receipts.is_empty():
		printerr("retained drone reforge: ", retained_reforge)
		quit(1)
		return
	if retained_reforge.session.hyperspace_system.prepare_claim(99).ok:
		printerr("old round receipt remained claimable")
		quit(1)
		return
	var blocked_seal: Dictionary = retained_reforge.session.hyperspace_system.release_sealed("space:1:99", [1, 2, 3, 4])
	if blocked_seal.ok:
		printerr("sealed drone released before gate")
		quit(1)
		return
	var sealed_level: int = int(retained_reforge.session.hyperspace_system.warehouse().sealed["space:1:99"])
	ready = retained_reforge.session.hyperspace_system.release_sealed("space:1:99", [sealed_level])
	if not ready.ok or retained_reforge.session.hyperspace_system.warehouse().sealed.has("space:1:99"):
		printerr("sealed drone did not release at claim gate")
		quit(1)
		return
	var second_session = retained_reforge.session
	if not second_session.planet_system.is_available("2"):
		printerr("next planet did not open after conquest")
		quit(1)
		return
	var second_planets: Dictionary = second_session.planet_system.save_state()
	second_planets.planets["2"].buildings.shipyard_later.state = "built"
	for row in second_session.planet_system.building_options("2"):
		if row.id == "shipyard_later":
			second_planets.planets["2"].buildings.shipyard_later.work = int(row.name.get_slice("/", 1))
	ready = second_session.planet_system.restore_state(second_planets)
	if not ready.ok:
		printerr("second round shipyard fixture: ", ready)
		quit(1)
		return
	var second_reforge: Dictionary = second_session.prepare_reforge("2", ["space:1:99"], directory)
	if not second_reforge.ok or second_reforge.session.hyperspace_system.warehouse().reforge_count != 2 or second_reforge.session.hyperspace_system.warehouse().retention_capacity != retained_reforge.session.hyperspace_system.warehouse().retention_capacity + 10:
		printerr("second round reforge: ", second_reforge)
		quit(1)
		return
	ready = reforge.session.request_save()
	if ready.ok: ready = reforge.session.save_files.close(2000)
	if not ready.ok:
		printerr("reforge save: ", ready)
		quit(1)
		return
	var resumed: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not resumed.ok or resumed.session.campaign_system.restore_checkpoint() != "departing" or not resumed.session.planet_system.save_state().planets["1"].conquered:
		printerr("reforge resume: ", resumed)
		quit(1)
		return
	pointer = SaveFiles.read_pointer(directory, "active.json")
	var envelope: Dictionary = pointer.envelope.duplicate(true)
	decoded = StateCodec.unpack(envelope.payload)
	damaged = decoded.value
	damaged.modules.economy.wallet.erase("chrono")
	var packed: Dictionary = StateCodec.pack(damaged)
	envelope.payload = packed.value
	envelope.payloadHash = JSON.stringify(envelope.payload).sha256_text()
	envelope.savedUtc = "0"
	var late: Dictionary = Session._candidate_from_envelope("res://generated/config.json", directory, envelope)
	if not late.ok or late.session.amount_api.apply("compare", [
		late.session.economy.budget().get("chrono", {}), cap.value]).scalar != 0:
		printerr("offline load cap: ", late)
		quit(1)
		return
	var offline_directory: String = directory.path_join("offline-import")
	DirAccess.make_dir_recursive_absolute(offline_directory)
	var import_file: String = offline_directory.path_join("source.json")
	var stream: FileAccess = FileAccess.open(import_file, FileAccess.WRITE)
	stream.store_string(JSON.stringify(envelope))
	stream.close()
	var imported_offline: Dictionary = Session.import_candidate("res://generated/config.json", offline_directory, import_file)
	if not imported_offline.ok or imported_offline.session.amount_api.apply("compare", [
		imported_offline.session.economy.budget().get("chrono", {}), cap.value]).scalar != 0:
		printerr("offline import cap: ", imported_offline)
		quit(1)
		return
	ready = imported_offline.session.request_save()
	if ready.ok: ready = imported_offline.session.save_files.close(2000)
	var reloaded_offline: Dictionary = Session.load_candidate("res://generated/config.json", offline_directory)
	if not ready.ok or not reloaded_offline.ok or reloaded_offline.session.amount_api.apply("compare", [
		reloaded_offline.session.economy.budget().get("chrono", {}), cap.value]).scalar != 0:
		printerr("offline import replay: ", ready, " ", reloaded_offline)
		quit(1)
		return
	envelope.savedUtc = str(int(Time.get_unix_time_from_system()) + 100)
	var future: Dictionary = Session._candidate_from_envelope("res://generated/config.json", directory, envelope)
	if not future.ok or future.session.economy.budget().has("chrono"):
		printerr("future clock credit: ", future)
		quit(1)
		return
	stream = FileAccess.open(import_file, FileAccess.WRITE)
	stream.store_string(JSON.stringify(envelope))
	stream.close()
	var future_import: Dictionary = Session.import_candidate("res://generated/config.json", offline_directory, import_file)
	if not future_import.ok or future_import.session.economy.budget().has("chrono"):
		printerr("future clock import credit: ", future_import)
		quit(1)
		return
	# The same persisted timestamp is tested against successive device-clock readings.
	# A rollback grants nothing; a later crossing grants only the elapsed positive span.
	if Session.offline_elapsed(100000, 99999) != 0 or Session.offline_elapsed(100000, 100000) != 0 or Session.offline_elapsed(100000, 100005) != 5:
		printerr("offline clock rollback boundary")
		quit(1)
		return
	var accelerated = Session.new()
	ready = accelerated.initialize("res://generated/config.json", 202)
	if not ready.ok:
		printerr("chrono session: ", ready)
		quit(1)
		return
	accelerated.economy.credit_offline(5, 12, "1")
	accelerated.set_chrono_speed(10)
	ready = accelerated.campaign_system.start_sortie(1, accelerated.equipment.clear_switch_locks)
	accelerated.frame(2.6, true)
	var zero: Dictionary = accelerated.amount_api.apply("zero", []).value
	if not ready.ok or not accelerated.run_state.is_running() or accelerated.amount_api.apply("compare", [
		accelerated.economy.budget().get("chrono", zero), zero]).scalar != 0 or accelerated.pending_seconds <= 0.0:
		printerr("chrono time acceptance failed")
		quit(1)
		return
	var chrono_directory: String = directory.path_join("chrono")
	DirAccess.make_dir_recursive_absolute(chrono_directory)
	ready = accelerated.configure_save_directory(chrono_directory)
	if ready.ok: ready = accelerated.request_save()
	if ready.ok: ready = accelerated.save_files.close(2000)
	if not ready.ok:
		printerr("chrono save: ", ready)
		quit(1)
		return
	var resumed_chrono: Dictionary = Session.load_candidate("res://generated/config.json", chrono_directory)
	if not resumed_chrono.ok or resumed_chrono.session.current_chrono_speed() != 10 or absf(resumed_chrono.session.pending_seconds - accelerated.pending_seconds) > 0.001:
		printerr("paid time resume: ", resumed_chrono)
		quit(1)
		return
	printerr("STAGE6_SESSION_PROBE_OK")
	quit(0)
