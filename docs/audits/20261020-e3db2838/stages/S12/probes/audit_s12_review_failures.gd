extends SceneTree

const N=preload("res://scripts/growth_number.gd")
const I=preload("res://scripts/reactor_integer.gd")
const S=preload("res://scripts/sparse_wallet.gd")
const T=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func game_with_db(db:ShipDatabase)->BattleGame:
	var g:=BattleGame.new(db,false)
	g.profile.highestLevel=999
	return g

func _initialize()->void:
	var db:=ShipDatabase.new()
	var uranium:=str(int(db.config.reactorUraniumId))
	var wallet=S.add(0,I.make("10000000000000000000000000"))
	var batch:=game_with_db(db)
	var singles:=game_with_db(db)
	for game in [batch,singles]:
		game.profile.grantedUnlocks=game.profile.get("grantedUnlocks",[])
		game.profile.grantedUnlocks.append(db.unlock_id("feature","reactor"))
		game.profile.reactorLevel=140
		game.profile.resources[uranium]=wallet.duplicate(true)
	check(batch.upgrade_reactor(10),"reactor v3 x10 succeeds")
	var all_single:=true
	for unused in 10:all_single=singles.upgrade_reactor(1) and all_single
	check(all_single,"reactor v3 ten singles succeed")
	check(N.compare(batch.profile.resources[uranium],singles.profile.resources[uranium])==0,"reactor v3 x10 equals ten singles")
	var refund:=game_with_db(db)
	refund.profile.loadout.weapons[0].key="laser"
	refund.profile.loadout.weapons[0].level=2
	refund.profile.loadout.defence[0].key="armour"
	refund.profile.loadout.defence[0].level=20
	refund.profile.hyperspace.materials[db.evolution_material_id()]=I.MAX_INT.to_int()
	var before_refund=refund.profile.duplicate(true)
	var refund_events:Array=[]
	refund.event.connect(func(kind,payload):refund_events.append(kind))
	check(not refund.refund_all_equipment(),"batch refund rejects material overflow")
	check(refund.profile==before_refund and refund_events.is_empty(),"batch refund failure has no wallet or event effect")
	var refund_success:=game_with_db(db)
	refund_success.profile.loadout.weapons[0].key="laser"
	refund_success.profile.loadout.weapons[0].level=2
	refund_success.profile.loadout.defence[0].key="armour"
	refund_success.profile.loadout.defence[0].level=20
	var refund_singles:=game_with_db(db)
	refund_singles.profile=refund_success.profile.duplicate(true)
	check(refund_success.refund_all_equipment(),"batch refund succeeds within material domain")
	check(refund_singles.refund_equipment("laser",2) and refund_singles.refund_equipment("armour",20),"individual refund reference succeeds")
	check(refund_success.profile.resources==refund_singles.profile.resources and refund_success.profile.hyperspace.materials==refund_singles.profile.hyperspace.materials,"batch refund credits equal individual totals")
	var jewels:=game_with_db(db)
	jewels.profile.grantedUnlocks=jewels.profile.get("grantedUnlocks",[])
	jewels.profile.grantedUnlocks.append(db.unlock_id("feature","jewels"))
	jewels.profile.jewelFurnaceIncomePeak=1e308
	var jewel_drop:Dictionary={"jewel":true,"hightech":true,"age":11.0,"amount":{"m":2.0,"e":308.0},"id":"jewel"}
	jewels.drops.append(jewel_drop)
	jewels.collect(jewel_drop,true)
	check(not jewels.drops.has(jewel_drop),"overflow jewel drop collected")
	check(N.compare(jewels.profile.jewelFragments,0)>0,"overflow jewel fragment credited")
	var natural_jewel:Dictionary={"jewel":true,"age":11.0,"amount":{"m":2.0,"e":308.0},"id":"jewel","jewelRatio":1.0}
	jewels.drops.append(natural_jewel)
	jewels.collect(natural_jewel,true)
	check(not jewels.drops.has(natural_jewel),"overflow natural jewel income collected")
	var jewel_key:=BattleGame.JEWEL_FURNACE
	jewels.profile.grantedUnlocks.append(db.unlock_id("hightech",jewel_key))
	jewels.profile.aiTechLevels[jewel_key]=1
	jewels.profile.jewelFurnaceElapsed=float(db.data.hightech[jewel_key].para1)-0.01
	jewels.advance_furnace(0.02,jewels.economy_time()+0.02,1.0)
	check(N.valid(jewels.profile.jewelFurnaceIncomePeak) and N.compare(jewels.furnace_income_peak(-1,true),1e308)>0,"overflow jewel income remains valid for next furnace cycle")
	var save=JSON.parse_string(JSON.stringify(jewels.portable_save_data()))
	check(T.new().prepare_data(save,db).error=="" and T.new().prepare_disk_data(save,db).error=="","overflow jewel portable and disk schemas accept earned value")
	var restored:=game_with_db(db)
	restored.load_progress_data(save)
	check(N.compare(restored.profile.jewelFragments,jewels.profile.jewelFragments)==0,"overflow jewel fragment saved and restored")
	check(N.compare(restored.profile.jewelFurnaceIncomePeak,jewels.profile.jewelFurnaceIncomePeak)==0,"overflow jewel furnace peak saved and restored")
	var max_db:=ShipDatabase.new()
	max_db.data.equipment_evolution.interval=1000000000
	var max_game:=game_with_db(max_db)
	max_game.profile.resources={"1":1e100,"2":1e100}
	var max_before=max_game.profile.duplicate(true)
	var max_amount:=-1
	for attempt in 500:
		max_amount=max_game.max_upgrade_amount_slot("weapons",0)
		if max_amount>=0:break
	check(max_amount>0,"ordinary MAX resumes to an exact result")
	check(max_game.profile==max_before,"MAX continuation has no game effects")
	check(max_game.max_upgrade_amount_slot("weapons",0)==max_amount,"completed MAX cache agrees")
	var pending_batch:=false
	var batch_done:=false
	for attempt in 500:
		batch_done=max_game.upgrade_equipment_batch("max")
		if batch_done:break
		pending_batch=true
		if max_game.profile!=max_before:break
	check(pending_batch and batch_done,"projected MAX batch resumes to purchase")
	var reactor_game:=game_with_db(max_db)
	reactor_game.profile.resources[uranium]=1e100
	var reactor_before=reactor_game.profile.duplicate(true)
	var reactor_count:=-1
	for attempt in 500:
		reactor_count=reactor_game.reactor_max_upgrades()
		if reactor_count>=0:break
	check(reactor_count>0 and reactor_game.profile==reactor_before,"reactor MAX resumes without game effects")
	var x:Array=[];var y:Array=[]
	for index in 80:
		x.append({"p":str(index),"d":1})
		y.append({"p":str(index),"d":1})
	var left:Dictionary={"v":3,"blocks":x}
	var right:Dictionary={"v":3,"blocks":y}
	var cursor:Dictionary={}
	var product:Dictionary={}
	var saw_pending:=false
	for attempt in 30:
		product=S.scale_result(left,right,cursor)
		if product.status=="ok":break
		if product.status!="pending":break
		saw_pending=true
		cursor=product.cursor
	check(saw_pending and product.status=="ok" and N.valid(product.value),"sparse factor work resumes across actual block products")
	var dense_oracle=I.make("1"+"0001".repeat(79))
	check(product.status=="ok" and N.compare(product.value,I.multiply(dense_oracle,dense_oracle))==0,"resumed sparse product matches independent decimal multiplication")
	var cashflow:=game_with_db(db)
	var cash_result:Variant=null
	var initial_wallet=cashflow.profile.resources.duplicate(true)
	for attempt in 30:
		cash_result=cashflow.cashflow_multiply(left,right)
		if cash_result!=null:break
		check(cashflow.profile.resources==initial_wallet,"cashflow pending leaves wallet unchanged")
	check(cash_result!=null and N.compare(cash_result,product.value)==0,"cashflow continuation matches direct sparse product")
	var concurrent:=game_with_db(db)
	var simultaneous:Array=[]
	for index in 9:simultaneous.append(S.add(left,index+1))
	var finished:Dictionary={}
	for pass_index in 30:
		for index in simultaneous.size():
			if finished.has(index):continue
			var result=concurrent.cashflow_multiply(simultaneous[index],right)
			if result!=null:finished[index]=result
		if finished.size()==simultaneous.size():break
	check(finished.size()==simultaneous.size(),"nine independent cashflow jobs all resume without cache starvation")
	var giant_db:=ShipDatabase.new()
	giant_db.data.equipment_evolution.interval=1000000001
	var giant:=game_with_db(giant_db)
	giant.profile.loadout.weapons[0].level=999999999
	giant.profile.resources={"1":{"m":1.0,"e":100000000.0},"2":{"m":1.0,"e":100000000.0}}
	var giant_before=giant.profile.resources.duplicate(true)
	var giant_cost=giant.slot_upgrade_cost("weapons",0)
	check(not giant_cost.is_empty() and giant_cost.values().any(func(v):return S.is_sparse(v)),"billion-level quote stays compact and exact")
	check(giant.upgrade_slot("weapons",0),"billion-level single purchase completes")
	for id in giant_cost:check(N.compare(S.add(giant.profile.resources[id],giant_cost[id]),giant_before[id])==0,"billion-level exact debit "+id)
	var giant_save=JSON.parse_string(JSON.stringify(giant.portable_save_data()))
	check(T.new().prepare_data(giant_save,giant_db).error=="","billion-level result passes portable schema")
	print("S12_REVIEW_FAILURES checks=",checks," failures=",failures)
	quit(1 if failures else 0)
