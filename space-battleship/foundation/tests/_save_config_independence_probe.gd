extends SceneTree
const Session = preload("res://src/game_session.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)
func put(path: String,text: String) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text);file.close()
func folder(name: String) -> String:
	var path: String=fixture_root.path_join(name)
	DirAccess.make_dir_recursive_absolute(path)
	return path
func store_envelope(path: String,envelope: Dictionary,valid_checksum: bool=true) -> void:
	var raw: String=JSON.stringify(envelope)
	put(path.path_join("slot-0.json"),raw)
	put(path.path_join("active.json"),JSON.stringify({"file":"slot-0.json","generation":envelope.generation,"checksum":raw.sha256_text() if valid_checksum else "0".repeat(64)}))
func _initialize() -> void:
	var loaded=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("extension ",loaded);quit(1);return
	call_deferred("run")
func run() -> void:
	fixture_root=OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if fixture_root.is_empty(): printerr("missing explicit disposable test fixture_root");quit(1);return
	var config_path: String=OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config_path))
	# A compatible actual parameter change, not just different whitespace.
	var changed: Dictionary=config.duplicate(true)
	for row in changed.config.config:
		if str(row.name)=="autoGenRes": row.para_1="31,2,5,40"
	var changed_path: String=fixture_root.path_join("changed-config.json")
	put(changed_path,JSON.stringify(changed,"  "))
	check(FileAccess.get_file_as_string(changed_path).sha256_text()!=FileAccess.get_file_as_string(config_path).sha256_text(),"fixture configuration bytes differ")
	var game=Session.new()
	check(game.initialize(config_path,987654).ok,"real original configuration initialization")
	check(game.campaign_system.start_sortie(1,game.equipment.clear_switch_locks).ok,"resumable original campaign checkpoint")
	var save_dir: String=folder("new-save")
	check(game.configure_save_directory(save_dir).ok,"explicit disposable save directory")
	check(game.request_save().ok and game.save_files.close(2000).ok,"real Session request and native writer publish")
	var stored: Dictionary=SaveFiles.read_pointer(save_dir,"active.json")
	check(stored.ok and not stored.envelope.has("configHash") and stored.envelope.has("payloadHash"),"new envelope omits identity and retains payload integrity")
	var original: Dictionary=stored.envelope.duplicate(true)
	var resumed: Dictionary=Session.load_candidate(changed_path,save_dir)
	check(resumed.ok,"new no-hash save loads with compatible changed configuration")
	if resumed.ok:
		check(resumed.session.economy._spec[0]=="31","candidate reads changed configuration directly")
		resumed.session.save_files.close(2000)
	for value in ["0".repeat(64),"f".repeat(64)]:
		var legacy: Dictionary=original.duplicate(true);legacy.configHash=value
		var legacy_dir: String=folder("legacy-"+value.substr(0,1))
		store_envelope(legacy_dir,legacy)
		check(SaveFiles.valid_envelope_shape(legacy) and SaveFiles.read_pointer(legacy_dir,"active.json").ok,"legacy envelope and pointer remain compatible")
		var slot: String=legacy_dir.path_join("slot-0.json")
		var before: String=FileAccess.get_file_as_string(slot)
		var loaded: Dictionary=Session.load_candidate(changed_path,legacy_dir)
		check(loaded.ok,"mismatched legacy fingerprint is not a loading gate")
		if loaded.ok: loaded.session.save_files.close(2000)
		check(FileAccess.get_file_as_string(slot)==before,"legacy user-format fixture is not rewritten on load")
		var imported: Dictionary=Session.import_candidate(changed_path,folder("import-"+value.substr(0,1)),slot)
		check(imported.ok,"legacy mismatched fingerprint imports through real candidate path")
		if imported.ok: imported.session.save_files.close(2000)
		check(FileAccess.get_file_as_string(slot)==before,"import preserves source bytes")
	var bad_payload: Dictionary=original.duplicate(true)
	bad_payload.payload["tampered"]=true
	var corrupt_dir: String=folder("bad-payload")
	store_envelope(corrupt_dir,bad_payload)
	check(not SaveFiles.read_pointer(corrupt_dir,"active.json").ok,"payload hash rejects tampering even with valid pointer checksum")
	check(not Session.import_candidate(changed_path,folder("bad-import"),corrupt_dir.path_join("slot-0.json")).ok,"import payload integrity remains enforced")
	var bad_pointer: String=folder("bad-pointer")
	store_envelope(bad_pointer,original,false)
	check(not SaveFiles.read_pointer(bad_pointer,"active.json").ok,"raw slot checksum remains enforced")
	var bad_shape: Dictionary=original.duplicate(true);bad_shape.erase("payloadHash")
	check(not SaveFiles.valid_envelope_shape(bad_shape),"payload hash remains required")
	bad_shape=original.duplicate(true);bad_shape.formatVersion=999
	check(not SaveFiles.valid_envelope_shape(bad_shape),"envelope version remains enforced")
	var invalid_config: Dictionary=changed.duplicate(true)
	invalid_config.erase("hyperspace_config")
	var invalid_path: String=fixture_root.path_join("invalid-config.json")
	put(invalid_path,JSON.stringify(invalid_config))
	check(not Session.load_candidate(invalid_path,save_dir).ok,"necessary configuration validity still rejects invalid configuration")
	# Old source callers may still pass a fifth argument; it is ignored, never written.
	var old_caller=SaveFiles.new(folder("old-call"))
	check(old_caller.request({"fixture":true},"1","caller","1","not-a-configuration-identity").ok and old_caller.close(2000).ok,"legacy request calling convention has no identity gate")
	check(not old_caller.load_latest().envelope.has("configHash"),"legacy caller cannot reintroduce config metadata")
	check(not old_caller.request({},"invalid","caller","1").ok,"request metadata validation remains")
	await process_frame
	print("SAVE_CONFIG_INDEPENDENCE checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
