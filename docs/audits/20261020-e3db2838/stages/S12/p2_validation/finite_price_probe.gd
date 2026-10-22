extends SceneTree
const P=preload("res://scripts/equipment_price.gd")
class Fixture extends RefCounted:
	var equipment:Dictionary={"laser":[{"level":1,"cost_1":50,"cost_multi_1":0.2,"res_1":1,"cost_2":null,"res_2":null}]}
	var data:Dictionary={"equipment_evolution":{"interval":20,"material_cost_per_tier":10}}
	func evolution_material_id()->String:return "degenerate_matter"
func _initialize()->void:
	var db:=Fixture.new()
	for row in [[1,257],[1,47959],[1000000000,1000],[10000000000000000,1000]]:
		var start:int=Time.get_ticks_usec()
		var result=P.new().sum_costs(db,"laser",int(row[0]),int(row[1]))
		print("P2_PRICE_RESULT ",JSON.stringify({"current":row[0],"count":row[1],"status":result.status,"amounts":result.amounts,"elapsed_us":Time.get_ticks_usec()-start}))
		if result.status!="ok":quit(1);return
	print("P2_PRICE_COMPLETE")
	quit(0)
