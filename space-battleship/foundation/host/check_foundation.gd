extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func drain(store) -> void:
	for i in range(20000):
		store.poll()
		if not store.busy(): return
		await process_frame
	check(false, "SaveWriterTimeout")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {}
	for i in range(0, args.size() - 1, 2): options[args[i]] = args[i + 1]
	var extension := GDExtensionManager.load_extension("res://space_native.gdextension")
	if extension != GDExtensionManager.LOAD_STATUS_OK and extension != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("MissingNativeDependency")
		quit(2)
		return
	for name in ["FoundationAmount", "FoundationDisk", "SpaceCombatKernel"]:
		if not ClassDB.class_exists(name):
			printerr("MissingNativeDependency: ", name)
			quit(2)
			return
	var opened: Dictionary = load("res://host/config_bundle.gd").open(options["--bundle"])
	if not opened.ok:
		printerr(opened)
		quit(2)
		return
	var bundle = opened.bundle
	var numbers = ClassDB.instantiate("FoundationAmount")
	var amount_cases := 0
	for row in bundle.rows("amount_case"):
		var operation: String = row.operation
		var operands := []
		var left: Dictionary = numbers.apply("from_decimal", [row.left]).value
		if operation == "sum_geometric": operands = [row.scalar, row.count]
		elif operation == "pow": operands = [left, row.scalar]
		elif operation == "round_significant": operands = [left, row.count]
		elif row.right != null: operands = [left, numbers.apply("from_decimal", [row.right]).value]
		else: operands = [left]
		var actual: Dictionary = numbers.apply(operation, operands)
		var diagnostic := "%s %s expected=%s actual=%s" % [row.id, bundle.origin("amount_case", [row.id], "expected"), row.expected, actual]
		if row.error != null:
			check(not actual.ok and actual.get("error") == row.error, diagnostic)
		else:
			check(actual.ok, diagnostic)
			if actual.ok:
				var expected: Dictionary = numbers.apply("from_decimal", [row.expected]).value
				if expected.m == "0": check(actual.value == expected, diagnostic)
				else:
					var observed: float = numbers.apply("log10", [actual.value]).scalar
					var wanted: float = numbers.apply("log10", [expected]).scalar
					check(absf(observed - wanted) <= row.log_tolerance, diagnostic)
		amount_cases += 1
	check(not numbers.apply("decode", [{"m": "1.0", "e": "500"}]).ok, "Reject noncanonical Amount")
	check(not numbers.apply("decode", [{"m": "1", "e": 500}]).ok, "Reject numeric exponent")
	check(not numbers.apply("unsupported", []).ok, "Reject unknown operation")
	check(not numbers.apply("normalize", [-1.0, "0"]).ok, "Reject negative magnitude")
	var immutable: Array = bundle.rows("res")
	immutable[0].name = "mutated"
	check(bundle.lookup("res", [71]).name == "fixture_iron", "Immutable configuration query")
	var native_cases := 0
	for row in bundle.rows("native_fixture"):
		var kernel = ClassDB.instantiate("SpaceCombatKernel")
		var descriptor := {"player": {"armour": row.player_armour, "shield": row.player_shield, "x": row.player_x, "y": row.player_y},
			"enemies": [{"uid": int(row.enemy_id), "hp": row.enemy_hp, "max_hp": row.enemy_hp, "x": row.enemy_x, "y": row.enemy_y}],
			"weapons": [], "rng_state": int(row.seed)}
		check(kernel.configure(descriptor), row.id + " actual native configure")
		check(kernel.can_advance(row.duration) and kernel.advance(row.duration), row.id + " actual native advance")
		check(kernel.enemy_views().size() == 1 and kernel.enemy_views()[0].hp == row.enemy_hp, row.id + " retained native actor")
		check(kernel.take_feedback().is_empty(), row.id + " no invented combat event")
		native_cases += 1
	var save_script = load("res://host/save_files.gd")
	if save_script == null or not save_script.can_instantiate():
		printerr("SaveFilesScriptUnavailable")
		quit(2)
		return
	var save_cases := 0
	for row in bundle.rows("save_case"):
		var directory: String = options["--saves"].path_join(row.id)
		var store = save_script.new(directory, bundle.semantic_hash)
		var payload := {"wallet": numbers.apply("from_decimal", [row.initial]).value}
		check(store.request(payload, "1", "fixture-session", "1234").ok, row.id + " request first")
		payload.wallet = numbers.apply("from_decimal", [row.updated]).value
		await drain(store)
		check(store.last_result.ok, row.id + " write first")
		check(store.load_latest().envelope.payload.wallet == numbers.apply("from_decimal", [row.initial]).value, row.id + " immutable writer snapshot")
		if row.mode == "coalesce":
			for change in ["2", "3", "4"]: check(store.request(payload, change, "fixture-session", "1235").ok, row.id + " serial request")
			await drain(store)
		elif row.mode == "recovery":
			check(store.request(payload, "2", "fixture-session", "1235").ok, row.id + " second")
			await drain(store)
			var published: Dictionary = store.load_latest()
			var file := FileAccess.open(directory.path_join(published.pointer.file), FileAccess.WRITE)
			file.store_string("corrupt")
			file.close()
			check(store.load_latest().ok, row.id + " recover backup")
			store.fault_boundary = row.fault
			check(store.request(payload, "3", "fixture-session", "1236").ok, row.id + " recovery request")
			await drain(store)
			check(not store.last_result.ok, row.id + " injected publication failure")
		else:
			store.fault_boundary = "" if row.fault == null else row.fault
			check(store.request(payload, "2", "fixture-session", "1235").ok, row.id + " second request")
			await drain(store)
			check(store.last_result.ok == (row.fault == null), row.id + " failure boundary")
		var restored: Dictionary = store.load_latest()
		check(restored.ok, row.id + " valid retained save")
		if restored.ok:
			check(restored.envelope.generation == row.generation, row.id + " generation")
			check(restored.envelope.payload.wallet == numbers.apply("from_decimal", [row.expected]).value, row.id + " wallet")
			check(store.dirty("999"), row.id + " later changes stay dirty")
		var incompatible = save_script.new(directory, "different-config")
		check(not incompatible.load_latest().ok and not incompatible.request(payload, "9", "fixture-session", "1237").ok, row.id + " refuse incompatible store overwrite")
		check(store.close().ok, row.id + " nonblocking close after drain")
		save_cases += 1
	var report := {"ok": failures.is_empty(), "checks": checks, "amountCases": amount_cases,
		"nativeCases": native_cases, "saveCases": save_cases, "configHash": bundle.semantic_hash, "failures": failures}
	var file := FileAccess.open(options["--result"], FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
