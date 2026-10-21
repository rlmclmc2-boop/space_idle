extends SceneTree

const I := preload("res://scripts/reactor_integer.gd")
const Q := preload("res://scripts/equipment_quote.gd")
const F := preload("res://scripts/number_format.gd")
const N := preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func fixture(db: ShipDatabase, level: int) -> BattleGame:
	var game := BattleGame.new(db,false)
	game.profile.highestLevel=999
	game.profile.loadout.weapons[0].level=level
	game.profile.resources={"1":{"m":1.0,"e":400.0},"2":{"m":1.0,"e":400.0}}
	game.profile.hyperspace.materials[db.evolution_material_id()]=1000000
	return game

func same_money(a: Variant,b: Variant) -> bool:
	return I.compare(a,b)==0

func _initialize() -> void:
	var db := ShipDatabase.new()
	var high := fixture(db,3872)
	var price := high.slot_upgrade_cost("weapons",0)
	check(not price.is_empty(),"3873 quote exists")
	for id in price:
		check(I.valid(price[id]),"3873 exact quote "+id)
		check(not F.compact(price[id]).contains("INF"),"finite price text "+id)
	var saved_wallet:Dictionary=high.profile.resources.duplicate(true)
	var before_level:=int(high.slot_entry("weapons",0).level)
	for id in price:high.profile.resources[id]=I.subtract(price[id],1) if I.compare(price[id],0)>0 else 0
	var refused_wallet:Dictionary=high.profile.resources.duplicate(true)
	var before_dirty:=high.save_dirty
	var events:Array=[]
	high.event.connect(func(kind,payload):events.append(kind))
	check(not high.upgrade_slot("weapons",0),"insufficient high quote rejects")
	check(high.profile.resources==refused_wallet and int(high.slot_entry("weapons",0).level)==before_level,"insufficient quote has no wallet/level side effect")
	check(high.save_dirty==before_dirty and events.is_empty(),"insufficient quote has no dirty/event side effect")
	high.profile.resources=saved_wallet.duplicate(true)
	check(high.upgrade_slot("weapons",0),"sufficient 3873 purchase")
	for id in price:
		check(same_money(high.profile.resources[id],I.subtract(I.legacy_integer(saved_wallet[id],16000000),price[id])),"exact high debit "+id)
	check(int(high.slot_entry("weapons",0).level)==3873,"high level advanced once")
	check(events.count("upgrade")==1 and high.save_dirty,"successful quote emits one upgrade and marks save")
	var saved:=high.portable_save_data()
	var parsed=JSON.parse_string(JSON.stringify(saved))
	check(preload("res://scripts/save_transfer.gd").new().prepare_data(parsed,db).error=="","exact tagged wallet passes portable validation")
	var restored:=BattleGame.new(db,false)
	restored.load_progress_data(parsed)
	for id in price:
		check(same_money(restored.profile.resources[id],high.profile.resources[id]),"exact save round trip "+id)
	check(int(restored.slot_entry("weapons",0).level)==3873,"level save round trip")
	var old:=fixture(db,2)
	var old_saved=JSON.parse_string(JSON.stringify(old.portable_save_data()))
	check(preload("res://scripts/save_transfer.gd").new().prepare_data(old_saved,db).error=="","legacy wallet passes portable validation")
	var old_restored:=BattleGame.new(db,false)
	old_restored.load_progress_data(old_saved)
	check(old_restored.profile.resources==old.profile.resources,"legal legacy wallet round trip")
	var exact_after_debit=I.make("9007199254740993")
	check(I.compare(N.add(exact_after_debit,1),I.make("9007199254740994"))==0,"exact int wallet keeps next income unit")
	check(I.compare(N.subtract(exact_after_debit,1),I.make("9007199254740992"))==0,"exact int wallet keeps next subtraction unit")
	var material_game:=fixture(db,19)
	var material_id:=db.evolution_material_id()
	var material_costs:=material_game.slot_upgrade_cost("weapons",0)
	check(material_costs.has(material_id),"evolution purchase has material cost")
	var material_before=I.make("9007199254741003")
	material_game.profile.hyperspace.materials[material_id]=material_before
	check(material_game.upgrade_slot("weapons",0),"material purchase succeeds")
	var material_after=I.subtract(material_before,material_costs[material_id])
	check(I.compare(material_game.profile.hyperspace.materials[material_id],material_after)==0,"material exact debit")
	var material_portable=material_game.portable_save_data()
	check(I.valid(material_portable.hyperspace.materials[material_id]) and material_portable.hyperspace.materials[material_id] is Dictionary,"material save has exact tagged integer")
	var material_json=JSON.parse_string(JSON.stringify(material_portable))
	check(preload("res://scripts/save_transfer.gd").new().prepare_data(material_json,db).error=="","material tagged import validation")
	var material_restored:=BattleGame.new(db,false)
	material_restored.load_progress_data(material_json)
	check(I.compare(material_restored.profile.hyperspace.materials[material_id],material_after)==0,"material units survive JSON and reload")
	material_restored.profile.hyperspace.materials[material_id]=I.MAX_INT.to_int()
	var material_refund_before=material_restored.profile.hyperspace.materials.duplicate(true)
	material_restored.refund_equipment("laser",20)
	check(material_restored.profile.hyperspace.materials==material_refund_before,"material int64 overflow refund rejects before credit")
	var bulk:=fixture(db,3870)
	var singles:=fixture(db,3870)
	var ten:=bulk.slot_upgrade_cost("weapons",0,10)
	check(not ten.is_empty(),"ten-level quote exists")
	var sum:Dictionary={}
	for level in range(3871,3881):
		var one:=db.equipment_cost("laser",level)
		for id in one:sum[id]=I.add(sum.get(id,0),one[id])
	check(ten==sum,"ten-level quote is sum of rounded singles")
	check(bulk.upgrade_slot("weapons",0,10),"ten-level purchase")
	var singles_ok:=true
	for ignored in 10:
		if not singles.upgrade_slot("weapons",0):singles_ok=false;break
	check(singles_ok,"ten single purchases")
	check(bulk.profile.resources==singles.profile.resources and bulk.profile.hyperspace.materials==singles.profile.hyperspace.materials,"ten and singles settle equally")
	var cache:=fixture(db,1)
	var three:=cache.slot_upgrade_cost("weapons",0,3)
	for id in three:cache.profile.resources[id]=three[id]
	cache.profile.hyperspace.materials[db.evolution_material_id()]=0
	var maximum:=cache.max_upgrade_amount_slot("weapons",0)
	check(maximum==3,"MAX stops at first unaffordable level")
	check(cache.slot_upgrade_cost("weapons",0,maximum)==three,"MAX cache and batch quote agree")
	check(cache.upgrade_slot("weapons",0,maximum),"MAX cached purchase")
	for id in three:check(same_money(cache.profile.resources[id],0),"MAX exact debit "+id)
	check(cache.max_upgrade_amount_slot("weapons",0)==0,"MAX cache invalidated by purchase")
	var unsupported:=fixture(db,1)
	unsupported.profile.resources={"1":{"m":1.0,"e":8000001.0},"2":{"m":1.0,"e":8000001.0}}
	var unsupported_before:Dictionary=unsupported.profile.duplicate(true)
	check(not unsupported.upgrade_slot("weapons",0),"unrepresentable exact debit rejects")
	check(unsupported.profile.resources==unsupported_before.resources and unsupported.profile.loadout==unsupported_before.loadout,"technical reject has no wallet/level side effect")
	var refund:=fixture(db,1)
	refund.profile.resources={"1":0,"2":0}
	refund.profile.hyperspace.materials[db.evolution_material_id()]=0
	var refund_quote:=db.equipment_cost("laser",20)
	refund.refund_equipment("laser",20)
	check(I.compare(refund.profile.hyperspace.materials[db.evolution_material_id()],refund_quote[db.evolution_material_id()])==0,"refund includes tier material")
	print("S12_TRANSACTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
