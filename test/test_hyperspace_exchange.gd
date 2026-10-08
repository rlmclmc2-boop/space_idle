extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
	var db:=ShipDatabase.new();var g:=BattleGame.new(db,false)
	var keys:Array=g.profile.hyperspace.materials.keys()
	var source:String=keys[0];var target:String=keys[1]
	g.profile.hyperspace.materials[source]=100;g.profile.hyperspace.materials[target]=3
	var before:Dictionary=g.profile.hyperspace.duplicate(true)
	var quote:=g.hyperspace_material_exchange_quote(source,target,20)
	check(quote.error=="" and quote.cost[source]==40 and quote.received[target]==20 and quote.max_receive==50,"exact 2:1 quotation")
	check(g.profile.hyperspace==before,"quote changes no state or RNG")
	var result:=g.exchange_hyperspace_materials(quote.request)
	check(result.error=="" and g.profile.hyperspace.materials[source]==60 and g.profile.hyperspace.materials[target]==23,"atomic debit and credit")
	var applied:Dictionary=g.profile.hyperspace.duplicate(true)
	check(g.exchange_hyperspace_materials(quote.request)==result and g.profile.hyperspace==applied,"duplicate confirmation returns cached result without debit")
	check(applied.random_state==before.random_state and applied.inventory==before.inventory,"exchange consumes no exploration or private forge random state")
	var conflict:Dictionary=quote.request.duplicate();conflict.amount=21
	check(g.exchange_hyperspace_materials(conflict).error=="command_conflict" and g.profile.hyperspace==applied,"reused token with different amount rejected")
	for amount in [0,-1,0.5,"2",9000000000000000]:check(g.hyperspace_material_exchange_quote(source,target,amount).error!="","invalid amount rejected "+str(amount))
	check(g.hyperspace_material_exchange_quote(source,source,1).error=="same_material","same material rejected")
	check(g.hyperspace_material_exchange_quote("ultimate_cores",target,1).error=="invalid_material","core not exchangeable")
	check(g.hyperspace_material_exchange_quote(source,target,31).error=="insufficient_materials","insufficient funds rejected")
	g.profile.hyperspace.materials[target]=9000000000000000
	check(g.hyperspace_material_exchange_quote(source,target,1).error=="material_limit","overflow rejected")
	print("MATERIAL_EXCHANGE: ",checks," checks ",failures," failures; isolated domain regression")
	quit(1 if failures else 0)
