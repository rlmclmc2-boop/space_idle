extends SceneTree
const S=preload("res://scripts/hyperspace_state.gd")
const P=preload("res://scripts/hyperspace_permissions.gd")
const Return=preload("res://scripts/hyperspace_main_return.gd")
const Writer=preload("res://scripts/progress_writer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func verify(raw:Dictionary,db:ShipDatabase,label:String)->void:
	var before:Dictionary=raw.duplicate(true)
	var g:=BattleGame.new(db,false);g.load_progress_data(raw)
	check(g.profile.highestLevel==int(raw.highestLevel),label+" keeps actual saved stage")
	check(g.profile.resources==raw.resources,label+" keeps exact saved resource balances")
	check(raw==before,label+" source save remains read-only")
	if raw.has("hyperspace"):
		check(g.hyperspace.last_error.is_empty() and g.profile.hyperspace.version==5,label+" accepted and migrated subsystem")
		check(g.profile.hyperspace.history==raw.hyperspace.history,label+" keeps only actual historical wins")
func _initialize()->void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	# Optional paths are existing full files, read-only: no player save is embedded here.
	for path in OS.get_cmdline_user_args():
		var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary and raw.get("save") is Dictionary:raw=raw.save
		check(raw is Dictionary and raw.has("highestLevel"),"historical full save parsed "+path.get_file())
		if not raw is Dictionary or not raw.has("highestLevel"):continue
		verify(raw,db,"historical "+path.get_file())
		if raw.has("hyperspace"):
			var from_disk:Variant=Writer.read_progress(path)
			check(from_disk is Dictionary,"real ProgressWriter accepts historical disk file "+path.get_file())
	var g:=BattleGame.new(db,false);g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.load_hyperspace_routes()
	var saved:Dictionary=JSON.parse_string(JSON.stringify(g.portable_save_data()))
	check(saved.hyperspace.version is float,"real JSON number decoding regression fixture")
	check(S.valid(saved.hyperspace,g.hyperspace.config,db.levels.size()),"v5 serialized namespace accepts integral float version")
	verify(saved,db,"serialized v5")
	var invalid:Dictionary=saved.hyperspace.duplicate(true);invalid.version=4.5
	check(not S.valid(invalid,g.hyperspace.config,db.levels.size()),"fractional version still rejected")
	var point:=Return.journey(g);var frozen:=Return.capture(g)
	check(Return.valid(JSON.parse_string(JSON.stringify(frozen)),JSON.parse_string(JSON.stringify(point)),db.levels.size()),"v2 return validates real JSON-decoded versions")
	frozen.erase("battle_json");frozen.version=1
	check(Return.valid(JSON.parse_string(JSON.stringify(frozen)),JSON.parse_string(JSON.stringify(point)),db.levels.size()),"legacy v1 return validates real JSON-decoded versions and state")
	point.stage=5;point.groupIndex=db.levels[4].groups.size();point.distance=db.levels[4].length;point.state=4
	check(Return.binding_valid(JSON.parse_string(JSON.stringify(point)),saved,db.data),"cleared main return binds decoded numeric history")
	print("DISK_MIGRATION: ",checks," checks ",failures," failures; historical optional files read-only, no game playthrough")
	quit(1 if failures else 0)
