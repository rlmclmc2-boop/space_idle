extends SceneTree
const Original = preload("res://original_game.gd")
var checks := 0
var failures := 0
var hashes: Array = []
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func snapshot(game) -> Dictionary:
	return {"profile":game.profile,"stage":game.stage,"distance":game.distance,"group":game.group_index,"state":game.state,"enemies":game.enemies,"projectiles":game.projectiles,"drops":game.drops,"player":game.player,"cooldowns":game.cooldowns,"rng":game.rng.state,"crew":game.profile.crew}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	var original = Original.new(db,true)
	var candidate := BattleGame.new(db,true)
	check(original.profile==candidate.profile,"Loaded input profiles match field by field")
	original.rng.seed=1701
	candidate.rng.seed=1701
	original.resume_progress()
	candidate.resume_progress()
	candidate.ordinary_save_async_enabled=true
	for i in 1800:
		original.begin_frame_save_batch()
		candidate.begin_frame_save_batch()
		for step in 2:
			original.tick(1.0/60.0)
			candidate.tick(1.0/60.0)
		original.end_frame_save_batch()
		candidate.end_frame_save_batch()
		if snapshot(original)!=snapshot(candidate):
			check(false,"Frame %d profile/combat/drops/RNG match" % i)
			break
		checks+=1
		if i%120==119:
			original.save_progress()
			candidate.save_progress()
			var a := FileAccess.get_file_as_bytes(Original.SAVE_PATH)
			var b := FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
			check(a==b,"Checkpoint %d saved bytes and every JSON field match" % i)
			hashes.append({"frame":i,"original":digest(a),"candidate":digest(b)})
	original.save_progress()
	candidate.save_progress()
	var loaded_original = Original.new(db,true)
	var loaded_candidate := BattleGame.new(db,true)
	loaded_original.rng.seed=1701
	loaded_candidate.rng.seed=1701
	loaded_original.resume_progress()
	loaded_candidate.resume_progress()
	check(snapshot(loaded_original)==snapshot(loaded_candidate),"Reload/resume profile, journey, fresh encounter and RNG match")
	FileAccess.open("res://.runtime/tail-equivalence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"hashes":hashes}))
	print("Tail save equivalence: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
