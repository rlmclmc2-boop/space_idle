extends SceneTree
const S=preload("res://scripts/sparse_wallet.gd")
const C=preload("res://scripts/compact_wallet.gd")
const N=preload("res://scripts/growth_number.gd")
const T=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	game.profile.highestLevel=999
	game.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	check(game.upgrade_slot("weapons",0),"legacy distant wallet purchases into v3")
	check(S.valid(game.profile.resources["1"]),"purchased wallet canonical sparse")
	var projected=S.parts(S.add(4999,1))
	check(is_equal_approx(projected[0],5.0) and projected[1]==3.0,"balanced carry display projection")
	var giant_position={"v":3,"blocks":[{"p":"1"+"0".repeat(1000),"d":1}]}
	check(S.valid(giant_position) and not N.text(giant_position).contains("INF"),"sparse display keeps exact exponent string")
	var before=game.profile.resources["1"]
	var first={"id":"1","amount":{"m":1.0,"e":1000000100.0},"age":100.0}
	game.drops.append(first)
	game.collect(first,true)
	check(not game.drops.has(first) and N.compare(game.profile.resources["1"],S.add(before,first.amount))==0,"real remote pickup exact")
	var reverse:=BattleGame.new(db,false)
	reverse.profile.resources["1"]={"m":1.0,"e":1000000100.0}
	var low_minus_one=C.change({"m":1.0,"e":1000000000.0},1,-1)
	var reverse_drop={"id":"1","amount":low_minus_one,"age":100.0}
	reverse.drops.append(reverse_drop)
	reverse.collect(reverse_drop,true)
	check(not reverse.drops.has(reverse_drop) and N.compare(reverse.profile.resources["1"],S.add(first.amount,low_minus_one))==0,"swapped actual pickup preserves low debit")
	var remote_balance=game.profile.resources["1"]
	var sparse_drop=S.add({"m":1.0,"e":300.0},1)
	var second={"id":"1","amount":sparse_drop,"production_base":sparse_drop,"age":100.0}
	game.drops.append(second)
	game.collect(second,false)
	check(not game.drops.has(second) and N.compare(game.profile.resources["1"],remote_balance)>0,"auto collection factor accepts sparse drop")
	var furnace_key:=BattleGame.FURNACE
	game.profile.grantedUnlocks=game.profile.get("grantedUnlocks",[])
	game.profile.grantedUnlocks.append(db.unlock_id("hightech",furnace_key))
	game.profile.aiTechLevels[furnace_key]=1
	var interval:=float(db.data.hightech[furnace_key].para1)
	game.profile.furnaceElapsed=interval-0.01
	var before_furnace:=game.drops.size()
	game.advance_furnace(0.02,game.economy_time(),1.0)
	check(game.drops.size()>before_furnace and N.valid(game.drops[-1].amount),"furnace local factors produce sparse amount")
	if game.drops.size()>before_furnace:
		var furnace_drop:Dictionary=game.drops[-1]
		var before_furnace_wallet=game.profile.resources["1"]
		game.collect(furnace_drop,true)
		check(not game.drops.has(furnace_drop) and N.compare(game.profile.resources["1"],before_furnace_wallet)>0,"furnace sparse cashflow credits exact wallet")
	var snapshot=JSON.parse_string(JSON.stringify(game.portable_save_data()))
	check(T.new().prepare_data(snapshot,db).error=="" and T.new().prepare_disk_data(snapshot,db).error=="","sparse portable and disk/backup validation")
	var restored:=BattleGame.new(db,false)
	restored.load_progress_data(snapshot)
	check(N.compare(restored.profile.resources["1"],game.profile.resources["1"])==0,"sparse wallet survives reload")
	check(N.compare(restored.profile.furnaceIncomePeak,game.profile.furnaceIncomePeak)==0,"sparse income peak survives reload")
	check(restored.resource_samples.size()==game.resource_samples.size(),"income samples survive reload")
	var malformed=snapshot.duplicate(true)
	malformed.resources["1"].blocks.append(malformed.resources["1"].blocks[-1].duplicate())
	check(T.new().prepare_data(malformed,db).error=="format" and T.new().prepare_disk_data(malformed,db).error=="format","duplicate sparse block rejected by portable and disk")
	var refused:=BattleGame.new(db,false)
	var refused_wallet=refused.profile.resources.duplicate(true)
	refused.load_progress_data(malformed)
	check(refused.startup_error=="invalid_compact_wallet_save" and refused.profile.resources==refused_wallet,"direct malformed sparse load is atomic")
	var max_db:=ShipDatabase.new()
	max_db.data.equipment_evolution.interval=1000000000
	var huge:=BattleGame.new(max_db,false)
	huge.profile.highestLevel=999
	huge.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	var untouched=huge.profile.duplicate(true)
	var events:Array=[]
	huge.event.connect(func(kind,payload):events.append(kind))
	var max_count:=huge.max_upgrade_amount_slot("weapons",0)
	check(max_count==-1,"extreme MAX reports incomplete work instead of partial amount")
	check(huge.max_upgrade_quote_cache.values().any(func(row):return row.get("status")=="pending"),"MAX cache records resumable cursor")
	check(huge.profile==untouched and not huge.save_dirty and events.is_empty(),"MAX quote budget has no game effects")
	check(not huge.upgrade_equipment_batch("max") and huge.profile==untouched and events.is_empty(),"MAX batch budget rejects before purchase")
	check(huge.reactor_max_upgrades()==-1 and huge.profile==untouched,"reactor MAX reports work budget without spending sparse wallet")
	var blocks:Array=[]
	for index in 600:blocks.append({"p":str(index),"d":1})
	var costly_sparse={"v":3,"blocks":blocks}
	var partial=S.scale_result(costly_sparse,0.1)
	var factor_pending:bool=partial.status=="pending"
	for attempt in 30:
		if partial.status!="pending":break
		partial=S.scale_result(costly_sparse,0.1,partial.cursor)
	check(S.valid(costly_sparse) and factor_pending and partial.status=="ok","cashflow factor work limit resumes actual block products")
	var limited_db:=ShipDatabase.new()
	limited_db.config.autoCollectReduce=0.9
	var limited:=BattleGame.new(limited_db,false)
	var uncredited=limited.profile.resources.duplicate(true)
	var over_budget_drop={"id":"1","amount":costly_sparse,"age":100.0}
	limited.drops.append(over_budget_drop)
	limited.collect(over_budget_drop,false)
	check(limited.drops.has(over_budget_drop) and limited.profile.resources==uncredited and not limited.save_dirty,"pending factor leaves actual pickup unchanged")
	for attempt in 30:
		if not limited.drops.has(over_budget_drop):break
		limited.collect(over_budget_drop,false)
	check(not limited.drops.has(over_budget_drop) and N.compare(limited.profile.resources["1"],uncredited["1"])>0,"factor pickup resumes and credits exact wallet")
	var limited_furnace:=BattleGame.new(ShipDatabase.new(),false)
	var limited_key:=BattleGame.FURNACE
	limited_furnace.profile.grantedUnlocks=[limited_furnace.db.unlock_id("hightech",limited_key)]
	limited_furnace.profile.aiTechLevels[limited_key]=1
	limited_furnace.profile.furnaceIncomePeak=costly_sparse
	limited_furnace.profile.furnaceElapsed=float(limited_furnace.db.data.hightech[limited_key].para1)-0.01
	var prior_furnace=limited_furnace.profile.duplicate(true)
	var prior_uid:=limited_furnace.uid
	limited_furnace.advance_furnace(0.02,limited_furnace.economy_time(),1.0)
	check(limited_furnace.profile==prior_furnace and limited_furnace.uid==prior_uid and limited_furnace.drops.is_empty(),"pending furnace factor leaves planned blocks unchanged")
	for attempt in 30:
		if not limited_furnace.drops.is_empty():break
		limited_furnace.advance_furnace(0.02,limited_furnace.economy_time(),1.0)
	check(not limited_furnace.drops.is_empty(),"furnace factor resumes planned block")
	print("S12_SPARSE_RUNTIME checks=",checks," failures=",failures)
	quit(1 if failures else 0)
