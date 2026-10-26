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
	damaged.modules.campaign.state.state = "hyperspace"
	damaged.modules.hyperspace.manual = {"status": "Started",
		"route": original.hyperspace_system.routes()[0].route,
		"return_target": {"stage": 1, "point": 0, "guard": false, "guard_point": 0}}
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
	ready = original.campaign_system.accept_reforge(original.campaign_system.save_state(), 5)
	original.planet_system.refresh_availability(original.campaign_system.available, false)
	var planets: Dictionary = original.planet_system.save_state()
	planets.planets["1"].buildings.shipyard.state = "built"
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
	hyperspace.receipts[99] = {"status": "CompletedPending", "round_id": 1,
		"run_id": 99, "reward": {"drone": {}, "materials": {}, "ultimate_cores": 0}}
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
	var blocked_seal: Dictionary = retained_reforge.session.hyperspace_system.release_sealed("space:1:99", [1, 2, 3, 4])
	if blocked_seal.ok:
		printerr("sealed drone released before gate")
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
	envelope.savedUtc = str(int(Time.get_unix_time_from_system()) + 100)
	var future: Dictionary = Session._candidate_from_envelope("res://generated/config.json", directory, envelope)
	if not future.ok or future.session.economy.budget().has("chrono"):
		printerr("future clock credit: ", future)
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
