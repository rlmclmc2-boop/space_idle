extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _initialize()->void:
	var db:=ShipDatabase.new()
	var generator=preload("res://scripts/player_loadout_generator.gd").new(db)
	var options:Dictionary=generator.default_options()
	options.module_level=100
	options.count=1
	var generated:Dictionary=generator.generate_canonical(options,1)
	print("CONSUMER_PROBE generated_count=",generated.results.size())
	var quote:=db.equipment_cost("laser",220)
	print("CONSUMER_PROBE target=220 quote_type=",type_string(typeof(quote.get("1")))," quote_valid=",ReactorInteger.valid(quote.get("1")))
	if not generated.results.is_empty():
		var result=preload("res://scripts/player_loadout_generator.gd").upgraded_profile(db,generated.results[0],generator.rules.profile,120)
		print("CONSUMER_PROBE generator_error=",result.get("error",""))
		check(not result.has("error"),"generator supports encoded quote")
		if not result.has("error"):
			check(int(result.loadout.weapons[0].level)==220,"generator advances requested levels")
			check(not result.resources.has(db.evolution_material_id()),"generator keeps material in hyperspace wallet")
		var distant_profile=generator.rules.profile.duplicate(true)
		distant_profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
		var distant_result=preload("res://scripts/player_loadout_generator.gd").upgraded_profile(db,generated.results[0],distant_profile,120)
		check(not distant_result.has("error"),"generator continues across compact wallet purchases")
	var auto:=BattleGame.new(db,false)
	auto.state=BattleGame.State.RETREAT
	auto.profile.highestLevel=999
	auto.profile.loadout.weapons[0].level=219
	auto.profile.resources={"1":{"m":1.0,"e":30.0},"2":{"m":1.0,"e":30.0}}
	auto.profile.hyperspace.materials[db.evolution_material_id()]=1000000
	print("CONSUMER_PROBE autoplayer_affordable=",auto.can_upgrade_slot("weapons",0))
	var policy=preload("res://scripts/balance_autoplayer.gd").new()
	policy.act(auto,0.0)
	check(policy.numeric_error.is_empty(),"autoplayer projects encoded quote")
	var metrics=preload("res://scripts/balance_metrics.gd").new()
	metrics.spending={"1":0.0}
	metrics.spending_by_system={"weapons":{"1":0.0}}
	metrics.spend("weapons",quote)
	print("CONSUMER_PROBE metrics_spending=",metrics.spending.get("1"))
	check(metrics.numeric_error.is_empty() and float(metrics.spending.get("1",0))>0,"metrics project encoded spending")
	var unsupported=preload("res://scripts/balance_numeric_projection.gd").finite({"v":1,"i":"1"+"0".repeat(400)})
	check(unsupported==null,"reporting rejects unrepresentable exponent")
	print("S12_CONSUMERS failures=",failures)
	quit(1 if failures else 0)
