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
	check(count > 0, "UnknownOrEmptyCaseSelection")
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
	var report := JSON.stringify({"ok": failures.is_empty(), "amountCases": count, "nativeKernel": true, "saveProtocol": true, "failures": failures})
	var report_file := FileAccess.open(options["--output"].path_join("result.json"), FileAccess.WRITE)
	if report_file == null:
		quit(2)
		return
	report_file.store_string(report)
	report_file.close()
	print(report)
	quit(0 if failures.is_empty() else 1)

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
