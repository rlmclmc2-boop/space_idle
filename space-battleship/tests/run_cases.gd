extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var options := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size(), 2):
		if i + 1 < args.size():
			options[args[i]] = args[i + 1]
	for required in ["--fixture", "--compiler", "--python", "--output"]:
		if not options.has(required):
			printerr("missing " + required)
			quit(2)
			return
	var extension_status := GDExtensionManager.load_extension("res://space_native.gdextension")
	if extension_status != GDExtensionManager.LOAD_STATUS_OK and extension_status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("MissingNativeDependency: extension load status ", extension_status)
		quit(2)
		return
	var compiler_output := []
	var code := OS.execute(options["--python"], [options["--compiler"], "--manifest", options["--fixture"], "--output", options["--output"]], compiler_output, true)
	if code != 0:
		printerr(compiler_output)
		quit(2)
		return
	for required_class in ["SpaceAmount", "SpaceCombatKernel", "SpaceSaveIO"]:
		if not ClassDB.class_exists(required_class):
			printerr("MissingNativeDependency: " + required_class)
			quit(2)
			return
	var active = JSON.parse_string(FileAccess.get_file_as_string(options["--output"].path_join("active-manifest.json")))
	var bundle_text := FileAccess.get_file_as_string(options["--output"].path_join(active.bundle))
	check(bundle_text.sha256_text() == active.checksum, "ConfigBundle checksum")
	var bundle = JSON.parse_string(bundle_text)
	var bundle_script = load("res://runtime/config_bundle.gd")
	if bundle_script == null or not bundle_script.can_instantiate():
		check(false, "ConfigBundleScriptLoad")
	else:
		var opened = bundle_script.open_active(options["--output"])
		check(opened.get("ok", false), "ConfigBundleOpen")
		if opened.get("ok", false):
			var copied = opened.bundle.rows("res")
			copied[0].name = "changed"
			check(opened.bundle.lookup("res", [71]).name == "test_iron", "ImmutableConfigBundle")
	var amount = ClassDB.instantiate("SpaceAmount")
	var count := 0
	for row in bundle.tables.amount_case:
		if options.has("--case") and options["--case"] != row.case_id:
			continue
		count += 1
		var left = amount.calculate("from_decimal", {"text": row.left})
		var right := {}
		if row.right != null:
			right = amount.calculate("from_decimal", {"text": row.right}).value
		var result = amount.calculate(row.operation, left.value, right, row.parameter, int(row.count))
		var coordinates = bundle.provenance.amount_case[JSON.stringify([row.case_id])]
		var diagnostic := "%s %s input=%s expected=%s actual=%s" % [row.case_id, coordinates, row.left, row.expected, result]
		if row.error != null:
			check(not result.ok and result.get("error") == row.error, diagnostic)
		else:
			check(result.ok, diagnostic)
			if not result.ok:
				continue
			var expected = amount.calculate("from_decimal", {"text": row.expected}).value
			if expected.m == "0":
				check(result.value == expected, diagnostic)
			else:
				var observed_log = amount.calculate("log10", result.value).scalar
				var expected_log = amount.calculate("log10", expected).scalar
				check(abs(observed_log - expected_log) <= row.tolerance, diagnostic)
	var native_count := verify_kernel_cases(bundle, amount, options)
	var wave_count := verify_wave_cases(bundle, amount, options)
	var session_count := verify_session_cases(options)
	var clock_count := verify_clock_cases(options)
	var journey_count := verify_journey_cases(options)
	var income_count := verify_income_cases(options)
	var ratio_count := verify_ratio_cases(options)
	check(count + native_count + wave_count + session_count + clock_count + journey_count + income_count + ratio_count > 0, "UnknownOrEmptyCaseSelection")
	# Stage-1 admission/advance smoke uses the actual existing kernel, no game
	# scene, GPU object, old Game adapter, or alternative battle implementation.
	var kernel = ClassDB.instantiate("SpaceCombatKernel")
	var enemy: Dictionary = bundle.tables.mon[0]
	var player: Dictionary = bundle.tables.equipment[0]
	var descriptor := {"player": {"armour": player.para1, "shield": 0.0},
		"enemies": [{"uid": int(enemy.id), "hp": enemy.health, "max_hp": enemy.health, "x": 100.0, "y": 100.0}],
		"weapons": [], "rng_state": 17}
	check(kernel.configure(descriptor), "NativeAdmission")
	check(kernel.can_advance(1.0 / 60.0), "NativeAdvanceAdmission")
	kernel.advance(1.0 / 60.0)
	check(kernel.enemy_views().size() == 1, "NativeEnemyRetention")
	check(kernel.take_feedback().is_empty(), "NativeEmptyFeedback")
	await verify_saves(options["--output"].path_join("isolated_saves"), bundle.semanticHash)
	var report := JSON.stringify({"ok": failures.is_empty(), "amountCases": count, "nativeCases": native_count, "waveCases": wave_count, "sessionCases": session_count, "clockCases": clock_count, "journeyCases": journey_count, "incomeCases": income_count, "ratioCases": ratio_count, "nativeKernel": true, "saveProtocol": true, "failures": failures})
	var report_file := FileAccess.open(options["--output"].path_join("result.json"), FileAccess.WRITE)
	if report_file == null:
		quit(2)
		return
	report_file.store_string(report)
	report_file.close()
	print(report)
	quit(0 if failures.is_empty() else 1)

func verify_kernel_cases(bundle: Dictionary, amount, options: Dictionary) -> int:
	var count := 0
	for row in bundle.tables.get("kernel_case", []):
		if options.has("--case") and options["--case"] != row.case_id:
			continue
		count += 1
		var kernel = ClassDB.instantiate("SpaceCombatKernel")
		var enemy_hp = amount.calculate("from_decimal", {"text": row.enemy_hp}).value
		var enemy_shield = amount.calculate("from_decimal", {"text": row.enemy_shield}).value
		var damage = amount.calculate("from_decimal", {"text": row.damage}).value
		var descriptor := {"player": {"armour": enemy_hp, "shield": enemy_shield, "x": row.player_x, "y": row.player_y},
			"enemies": [{"uid": 1, "hp": enemy_hp, "max_hp": enemy_hp, "shield": enemy_shield, "max_shield": enemy_shield,
				"x": row.enemy_x, "y": row.enemy_y, "armourType": 0, "shieldType": int(row.shield_type)}],
			"weapons": [{"kind": int(row.kind), "damage": damage, "type": 1, "interval": row.interval,
				"remaining": row.initial_delay, "speed": row.speed, "charge": row.charge, "maximum": row.maximum, "ramp": row.ramp,
				"muzzle": Vector2(row.player_x, row.player_y)}], "attack_counter": row.history_start.to_int(), "rng_state": 17,
			"resistance": row.resistance, "counter_level": int(row.history_level), "counter_growth": row.history_growth, "counter_round_scale": row.round_scale}
		if not kernel.configure(descriptor):
			check(false, row.case_id + " native admission " + kernel.last_error())
			continue
		var elapsed := 0.0
		while elapsed + 1e-10 < row.duration:
			var dt: float = min(1.0 / 60.0, row.duration - elapsed)
			if not kernel.advance(dt):
				check(false, row.case_id + " native advance " + kernel.last_error())
				break
			elapsed += dt
		var view = kernel.enemy_views()[0]
		check(view.hp == amount.calculate("from_decimal", {"text": row.expected_hp}).value, row.case_id + " hp " + str(view.hp))
		check(view.shield == amount.calculate("from_decimal", {"text": row.expected_shield}).value, row.case_id + " shield " + str(view.shield))
		check(str(kernel.metrics().attack_counter) == row.expected_attacks, row.case_id + " exact history " + str(kernel.metrics().attack_counter))
	return count

func verify_session_cases(options: Dictionary) -> int:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var session_script = load("res://runtime/game_session.gd")
	if session_script == null or not session_script.can_instantiate():
		check(false, "GameSession load")
		return 0
	var count := 0
	for row in opened.bundle.rows("session_case"):
		if options.has("--case") and options["--case"] != row.case_id: continue
		for frame_size in [1.0 / 60.0, 0.1, 1.0]:
			var created: Dictionary = session_script.create(opened.bundle)
			check(created.get("ok", false), "Session create " + str(created.get("reason")))
			if not created.get("ok", false): continue
			var session = created.session
			check(session.depart().ok, "Session depart")
			for i in range(roundi(row.duration / frame_size)): session.frame(frame_size)
			check(session.stopped_error.is_empty(), "Session error " + session.stopped_error)
			check(session.campaign.clearedStageIds.has(str(int(row.expected_stage))), "Session clear at frame " + str(frame_size))
			check(session.economy.wallet[str(int(row.resource))] == session.amount(row.expected_auto), "Session auto income " + str(session.economy.wallet))
			check(session.depart().ok, "Session re-depart")
			check(session.kernel.player_view().armour == session.amount(opened.bundle.lookup("equipment", ["armour"]).para1), "Session re-depart full armour")
			count += 1
		var manual: Dictionary = session_script.create(opened.bundle)
		if not manual.ok: continue
		manual.session.depart()
		var collected := false
		for i in range(roundi(row.duration * 60)):
			manual.session.frame(1.0 / 60.0)
			if not collected and not manual.session.economy.drops.is_empty():
				var id: String = manual.session.economy.drops.keys()[0]
				check(manual.session.collect_drop(id).ok, "Session manual collect")
				check(manual.session.collect_drop(id).reason == "NoChange", "Session duplicate collect")
				collected = true
		check(manual.session.economy.wallet[str(int(row.resource))] == manual.session.amount(row.expected_manual), "Session manual income")
		count += 1
	return count

func verify_clock_cases(options: Dictionary) -> int:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var session_script = load("res://runtime/game_session.gd")
	if session_script == null or not session_script.can_instantiate(): return 0
	var count := 0
	for row in opened.bundle.rows("clock_case"):
		if options.has("--case") and options["--case"] != row.case_id: continue
		var created: Dictionary = session_script.create(opened.bundle)
		if not created.ok:
			check(false, row.case_id + " create")
			continue
		var session = created.session
		session.economy.wallet[session.profile.chrono_id] = session.amount(row.balance)
		session.set_speed(int(row.speed))
		match row.mode:
			"pause":
				session.set_pause("user", true)
				session.set_pause("guide", true)
				session.frame(row.real_dt)
				session.set_pause("guide", false)
				session.frame(row.real_dt)
				check(session.time.game == 0, row.case_id + " user pause retained")
				check(session.economy.wallet[session.profile.chrono_id] == session.amount(row.balance), row.case_id + " paused balance")
				session.set_pause("user", false)
				session.frame(row.real_dt)
			"focus":
				session.frame(row.real_dt, false)
				session.frame(float(row.balance), true)
				check(session.time.speed == 1, row.case_id + " focus resets speed")
			"budget":
				session.frame(row.real_dt, true, 1)
				var pending: float = session.time.pending
				session.set_pause("user", true)
				session.frame(0.0)
				check(session.time.pending == pending, row.case_id + " paused pending retained")
				session.set_pause("user", false)
				session.frame(0.0)
			_:
				session.frame(row.real_dt)
		check(session.stopped_error.is_empty(), row.case_id + " error " + session.stopped_error)
		check(abs(session.time.game - row.expected_game) < 1e-9, row.case_id + " game " + str(session.time.game))
		check(session.economy.wallet[session.profile.chrono_id] == session.amount(row.expected_balance), row.case_id + " balance")
		count += 1
	return count

func fixture_session(options: Dictionary) -> Dictionary:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var session_script = load("res://runtime/game_session.gd")
	if session_script == null or not session_script.can_instantiate(): return {"ok": false}
	return session_script.create(opened.bundle)

func verify_journey_cases(options: Dictionary) -> int:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var count := 0
	for row in opened.bundle.rows("journey_case"):
		if options.has("--case") and options["--case"] != row.case_id: continue
		var created := fixture_session(options)
		if not created.ok:
			check(false, row.case_id + " create")
			continue
		var session = created.session
		check(session.depart().ok, row.case_id + " depart")
		session.set_death_option(int(row.death_option))
		if row.mode == "garrison_timer":
			check(session.set_garrison(true).ok, row.case_id + " garrison")
			for i in range(roundi(row.duration * 60)): session.frame(1.0 / 60.0)
			check(session.campaign.clearedStageIds.is_empty(), row.case_id + " remains at nonfinal point")
			check(session.economy.wallet[str(int(row.resource))] == session.amount(row.expected_amount), row.case_id + " timed uranium " + str(session.economy.wallet))
			session.set_garrison(false)
			check(session.campaign.garrison.is_empty(), row.case_id + " cancel garrison")
		else:
			for i in range(60):
				if session.campaign.phase == "combat": break
				session.frame(1.0 / 60.0)
			var origin: float = session.campaign.distance
			check(session.begin_retreat().ok and session.campaign.distance == origin, row.case_id + " retreat does not teleport")
			for i in range(roundi(row.duration * 60)): session.frame(1.0 / 60.0)
			check(session.campaign.phase == "combat", row.case_id + " retreat and return")
			check(session.kernel.player_view().armour == session.amount(opened.bundle.lookup("equipment", ["armour"]).para1), row.case_id + " full defence")
		check(session.stopped_error.is_empty(), row.case_id + " error " + session.stopped_error)
		count += 1
	return count

func verify_income_cases(options: Dictionary) -> int:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var count := 0
	for row in opened.bundle.rows("income_case"):
		if options.has("--case") and options["--case"] != row.case_id: continue
		var created := fixture_session(options)
		if not created.ok: continue
		var session = created.session
		session.time.wall = row.now_wall
		session.time.game = row.now_game
		session.time.ticks = roundi(row.now_game * 60)
		session.economy.income = [{"resource": str(int(row.resource)), "source": "enemy_drop", "actual": session.amount(row.amount),
			"production_base": session.amount(row.production_base), "wall": row.sample_wall, "game": row.sample_game}]
		check(session.income_per_second(str(int(row.resource)), "wall") == session.amount(row.expected_wall), row.case_id + " wall window")
		check(session.income_per_second(str(int(row.resource)), "game") == session.amount(row.expected_game), row.case_id + " game window")
		check(session.income_per_second(str(int(row.resource)), "game", true) == session.amount(row.expected_production), row.case_id + " native base")
		count += 1
	return count

func verify_ratio_cases(options: Dictionary) -> int:
	var config_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = config_script.open_active(options["--output"])
	var setup = load("res://runtime/combat_setup.gd")
	var count := 0
	for row in opened.bundle.rows("ratio_case"):
		if options.has("--case") and options["--case"] != row.case_id: continue
		var created := fixture_session(options)
		if not created.ok: continue
		var session = created.session
		session.campaign.point = int(row.point)
		var stage := {"length": row.length, "monGroup": row.mon_group}
		stage[row.field] = row.end
		stage[row.entry_field] = row.entry
		check(setup.stage_ratio(session, stage, row.field, row.entry_field) == session.amount(row.expected), row.case_id + " shared Amount ratio")
		check(session.stopped_error.is_empty(), row.case_id + " ratio error")
		count += 1
	return count

func verify_wave_cases(bundle: Dictionary, amount, options: Dictionary) -> int:
	var count := 0
	for row in bundle.tables.get("wave_case", []):
		if options.has("--case") and options["--case"] != row.case_id:
			continue
		count += 1
		var kernel = ClassDB.instantiate("SpaceCombatKernel")
		var zero = amount.calculate("zero").value
		var hp = amount.calculate("from_decimal", {"text": row.player_hp}).value
		var damage = amount.calculate("from_decimal", {"text": row.player_damage}).value
		check(kernel.configure({"player": {"armour": hp, "shield": zero, "x": 0.0, "y": row.distance}, "enemies": [],
			"weapons": [{"kind": 1, "damage": damage, "interval": row.player_interval, "muzzle": Vector2(0, row.distance)}],
			"drop_rules_compiled": true, "rng_state": 17}), "W01 initialize")
		var enemy_hp = amount.calculate("from_decimal", {"text": row.enemy_hp}).value
		var enemy_damage = amount.calculate("from_decimal", {"text": row.enemy_damage}).value
		var drop_amount = amount.calculate("from_decimal", {"text": row.drop_amount}).value
		var wave := {"final": false, "enemies": [{"uid": 1, "hp": enemy_hp, "max_hp": enemy_hp, "x": 0.0, "y": 0.0,
			"compiled_drops": [{"chance": 1.0, "resource": int(row.resource), "amount": drop_amount, "base": drop_amount}]}],
			"weapons": [{"kind": 0, "hostile": true, "source": 0, "damage": enemy_damage, "speed": row.enemy_speed,
				"interval": row.enemy_interval, "remaining": 0.0, "muzzle": Vector2.ZERO}]}
		check(kernel.start_wave(wave), "W01 start " + kernel.last_error())
		var cleared := false
		var drop_count := 0
		for i in range(60):
			check(kernel.advance(1.0 / 60.0), "W01 advance")
			var result: Dictionary = kernel.take_results()
			drop_count += result.drops.size()
			if result.wave_cleared:
				cleared = true
				break
		check(cleared and drop_count == 1, "W01 clear/drop exactly once")
		check(kernel.finish_wave(false), "W01 finish nonfinal")
		check(kernel.take_results().drops.is_empty() and not kernel.take_results().wave_cleared, "W01 result drain")
		var before: Dictionary = kernel.player_view().armour
		for i in range(int(row.travel_seconds * 60)):
			check(kernel.advance(1.0 / 60.0), "W01 travel")
		check(amount.calculate("compare", kernel.player_view().armour, before).scalar < 0, "W01 enemy flight survives nonfinal clear")
		var history: int = kernel.read_history().attacks
		wave.final = true
		check(kernel.start_wave(wave), "W01 next wave")
		for i in range(60):
			check(kernel.advance(1.0 / 60.0), "W01 final advance")
			var result: Dictionary = kernel.take_results()
			if result.final_cleared:
				break
		check(kernel.finish_wave(true), "W01 final finish")
		check(kernel.read_history().attacks > history, "W01 cross-wave history retained")
		before = kernel.player_view().armour
		for i in range(int(row.travel_seconds * 60)):
			check(kernel.advance(1.0 / 60.0), "W01 final travel")
		check(kernel.player_view().armour == before, "W01 final clears enemy flights")
	return count

func wait_save(files) -> void:
	for i in range(10000):
		files.poll()
		if not files._worker.is_started() and files._pending.is_empty():
			return
		await process_frame
	check(false, "SaveWriterTimeout")

func verify_saves(path: String, hash_value: String) -> void:
	var save_script = load("res://runtime/save_files.gd")
	if save_script == null or not save_script.can_instantiate():
		check(false, "SaveFilesScriptLoad")
		return
	var files = save_script.new(path, hash_value)
	var snapshot := {"wallet": {"m": "1", "e": "500"}}
	files.request(snapshot, 1, "fixture-session", 1234)
	snapshot.wallet.m = "9"
	await wait_save(files)
	check(files.last_result.get("ok", false), "SaveFirstWrite")
	var first = files.load_latest()
	check(first.get("ok", false) and first.get("envelope", {}).get("payload", {}).get("wallet", {}).get("m") == "1", "ImmutableSaveSnapshot")
	check(files.dirty(2) and not files.dirty(1), "SavedChangeDirty")
	for fault in ["snapshot_write", "snapshot_readback", "backup_write", "manifest_write"]:
		files.fault_boundary = fault
		files.request(snapshot, 2, "fixture-session", 1235)
		await wait_save(files)
		check(not files.last_result.get("ok", false), "ExpectedDiskFailure " + fault)
		var retained = files.load_latest()
		check(retained.get("ok", false) and retained.envelope.generation == first.envelope.generation, "RetainedPreviousGeneration " + fault)
	files.fault_boundary = ""
	files.request(snapshot, 3, "fixture-session", 1236)
	files.request(snapshot, 4, "fixture-session", 1237)
	await wait_save(files)
	check(files.saved_change == 4 and not files.dirty(4), "SerializedHighestGeneration")
	# Recovery through backup must survive a subsequent failed publication.
	var active_before: Dictionary = files.load_latest()
	var corrupt_file := FileAccess.open(path.path_join(active_before.pointer.file), FileAccess.WRITE)
	corrupt_file.store_string("corrupt")
	corrupt_file.close()
	var recovered: Dictionary = files.load_latest()
	check(recovered.get("ok", false), "RecoverPreviousGeneration")
	files.fault_boundary = "manifest_write"
	files.request(snapshot, 5, "fixture-session", 1238)
	await wait_save(files)
	var retained: Dictionary = files.load_latest()
	check(not files.last_result.get("ok", false) and retained.get("ok", false) and retained.envelope.generation == recovered.envelope.generation, "KeepValidBackupAfterBadActive")
	files.close()
