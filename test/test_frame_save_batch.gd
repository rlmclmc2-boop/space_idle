extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func saved_iron() -> float:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	return float(data.resources["1"])

func _initialize() -> void:
	var game := BattleGame.new(ShipDatabase.new(),false)
	game.save_enabled=true
	game.profile.resources["1"]=101.0
	game.save_progress()
	game.begin_frame_save_batch()
	game.profile.resources["1"]=102.0
	game.save_progress()
	game.profile.resources["1"]=103.0
	game.save_progress()
	check(saved_iron()==101.0,"Pending frame saves retain the prior committed state")
	game.end_frame_save_batch()
	check(saved_iron()==103.0 and not game.save_dirty,"Frame flush commits the final state")
	game.profile.resources["1"]=104.0
	game.save_progress()
	check(saved_iron()==104.0,"Calls outside the frame batch save immediately")
	var errors := [0]
	game.event.connect(func(kind: String,_info: Dictionary):
		if kind=="save_error":errors[0]+=1)
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
	game.begin_frame_save_batch()
	game.profile.resources["1"]=105.0
	game.save_progress()
	game.end_frame_save_batch()
	check(errors[0]==1 and game.save_dirty and saved_iron()==104.0,"Failed frame flush preserves the prior save and reports failure")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
	game.save_progress()
	check(saved_iron()==105.0 and not game.save_dirty,"Failed flush can be retried immediately")
	print("Frame save batch: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
