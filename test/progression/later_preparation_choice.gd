extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
func _initialize():call_deferred("run")
func run():
	var g=Game.new(ShipDatabase.new())
	var p=Policy.new()
	var rows:Array=[]
	g.stage=35;g.profile.highestLevel=37;g.profile.cleared=[35,36]
	p.later_preparation_stages=2
	assert(not p.reforge_progress_ready(g,2))
	g.profile.highestLevel=38;g.profile.cleared.append(37)
	assert(p.reforge_progress_ready(g,2))
	rows.append({"strategy":2,"actual_stage":35,"cleared":[35,36,37],"progress_ready":true,"scope":"two actual further clears suffice while farming; native readiness is still separately required"})
	p.later_preparation_stages=3
	assert(not p.reforge_progress_ready(g,2))
	g.stage=38;assert(not p.reforge_progress_ready(g,2))
	g.stage=39;assert(p.reforge_progress_ready(g,2))
	rows.append({"strategy":3,"actual_stage":39,"progress_ready":true,"scope":"historical policy retained"})
	g.stage=30;g.profile.highestLevel=32;assert(not p.reforge_progress_ready(g,1))
	g.profile.highestLevel=33;assert(p.reforge_progress_ready(g,1))
	rows.append({"planet":1,"strategy":2,"frontier":33,"progress_ready":true,"scope":"first preparation unchanged"})
	var out:={"pass":true,"policy":Policy.VERSION,"cases":rows,"scope":"Controlled strategy predicate, no simulated progress or forge injected; production forge eligibility remains mandatory in act"}
	var dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");assert(not dir.is_empty())
	FileAccess.open(dir.path_join("later-preparation-choice.json"),FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("LATER_PREPARATION_CHOICE_PASS ",JSON.stringify(out));quit()
