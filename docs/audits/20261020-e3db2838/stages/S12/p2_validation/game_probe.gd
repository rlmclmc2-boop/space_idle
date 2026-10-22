extends SceneTree
const L=preload("res://scripts/currency_ledger.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		printerr("P2_FAIL ",label)
		quit(1)
		assert(false,label)
func balance(game,id:String)->L.Value:
	var result:L.Outcome=game.currency_balance(id)
	check(result.status=="ok","balance decoded")
	return result.value
func val(amount:Variant)->L.Value:
	var result:L.Outcome=L.decode(amount)
	check(result.status=="ok","expected decoded")
	return result.value
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")

func _run()->void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	check(game.startup_error.is_empty(),"game init")
	game.profile.resources["1"]=100000.0
	game.profile.loadout.weapons[0].key="laser"
	game.profile.loadout.weapons[0].level=1
	game.state=game.State.RETREAT
	var expected:=0.0
	for level in range(2,12):expected+=float(db.equipment_cost("laser",level)["1"])
	var events:Array=[]
	game.event.connect(func(kind,payload):events.append({"kind":kind,"payload":payload.duplicate(true)}))
	check(game.upgrade_slot("weapons",0,10),"ordinary x10")
	check(game.profile.loadout.weapons[0].level==11,"ordinary level")
	check(L.compare(balance(game,"1"),val(100000.0-expected)).order==0,"ordinary old price debit")
	check(events[-1].kind=="upgrade" and events[-1].payload.levels==10,"upgrade receipt event")
	var before:Dictionary=game.profile.duplicate(true)
	game.profile.resources["1"]=0.5
	check(not game.upgrade_slot("weapons",0,10),"insufficient zero buy")
	check(game.profile.resources["1"]==0.5 and game.profile.loadout.weapons[0].level==11,"insufficient unchanged")
	game.profile=before
	check(game.refund_equipment("laser",11).status=="committed","refund committed")
	check(L.compare(balance(game,"1"),val(100000)).order==0,"refund original costs")
	game.profile.resources["1"]={"m":1.0,"e":1e308}
	check(game.currency_income("1",1).status=="committed","actual game income boundary")
	var delta:L.Outcome=L.subtract(balance(game,"1"),val({"m":1.0,"e":1e308}))
	check(L.compare(delta.value,val(1)).order==0,"game source low unit")
	var portable:Dictionary=game.portable_save_data()
	var json_source:String=JSON.stringify(portable)
	var parsed=preload("res://scripts/currency_storage.gd").parse_source(json_source)
	check(parsed.status=="ok","portable token parse")
	var restored:=BattleGame.new(db,false)
	restored.load_progress_data(parsed.data)
	check(L.compare(balance(restored,"1"),balance(game,"1")).order==0,"actual load preserves CW1")
	var material_id:String=db.evolution_material_id()
	game.profile.hyperspace.materials[material_id]=9223372036854775807
	var refund_before:Dictionary=game.profile.duplicate(true)
	var event_before:int=events.size()
	check(game.refund_equipment("laser",20).status=="material_transport","whole refund material overflow")
	check(game.profile==refund_before and events.size()==event_before,"refund final material failure zero write")
	game.profile.hyperspace.materials[material_id]=0
	var drop:Dictionary={"id":"1","amount":3.0,"production_base":3.0,"age":12.0}
	game.drops.append(drop)
	var collected_before:L.Value=balance(game,"1")
	var source_samples:int=game.resource_samples.size()
	game.collect(drop,true)
	check(not game.drops.has(drop) and game.resource_samples.size()==source_samples+1,"collect source consumed once")
	var collected_delta:L.Outcome=L.subtract(balance(game,"1"),collected_before)
	check(L.compare(collected_delta.value,val(3)).order==0 and game.resource_samples[-1].amount==3,"collect source amount independent of balance")
	var bad_drop:Dictionary={"id":"1","amount":2.0,"age":12.0}
	game.drops.append(bad_drop)
	game.profile.resources["1"]={"currency_version":1,"blocks":[{"p":"-0","d":1}]}
	source_samples=game.resource_samples.size()
	game.collect(bad_drop,true)
	check(game.drops.has(bad_drop) and game.resource_samples.size()==source_samples,"failed income preserves drop")
	var research:=BattleGame.new(db,false)
	research.profile.grantedUnlocks=[db.unlock_id("hightech",research.FURNACE)]
	check(research.select_tech("singularity"),"real research select")
	research.profile.aiTechInput={"1":1,"2":0}
	research.profile.resources["1"]=0.5
	research.profile.aiTechProgress["singularity"]=0.0
	research.AITech.advance(research,1.0)
	check(L.compare(balance(research,"1"),val(0)).order==0,"research fractional shortage pays remainder")
	check(research.profile.aiTechProgress.singularity==1.0,"research shortage retains basic interval")
	research.profile.resources["1"]=100.0
	research.profile.aiTechProgress["singularity"]=0.0
	research.save_dirty=false
	var no_op:Dictionary=research.profile.duplicate(true)
	research.AITech.advance(research,1e-12)
	check(research.profile==no_op and not research.save_dirty,"real dt micro no-op")
	research.profile.resources["1"]=1e-10
	no_op=research.profile.duplicate(true)
	research.AITech.advance(research,1.0)
	check(research.profile==no_op and not research.save_dirty,"real equal micro threshold no-op")
	research.profile.resources["1"]=5e-11
	research.AITech.advance(research,1.0)
	check(L.compare(balance(research,"1"),val(0)).order==0 and research.profile.aiTechProgress.singularity==1.0,"real below micro threshold clears then base")
	var income_game:=BattleGame.new(db,false)
	income_game.profile.resources["1"]=0.0
	income_game.profile.resources["2"]={"currency_version":1,"blocks":[{"p":"-0","d":1}]}
	income_game.galaxy._income_due=[{"id":"1","amount":3.0,"time":1.0,"production_time":1.0},{"id":"2","amount":5.0,"time":1.0,"production_time":1.0}]
	check(not income_game.galaxy.deliver_income(income_game),"galaxy later credit failure")
	check(L.compare(balance(income_game,"1"),val(3)).order==0 and income_game.galaxy._income_due.size()==1,"galaxy successful source retained once")
	income_game.profile.resources["2"]=0.0
	check(income_game.galaxy.deliver_income(income_game),"galaxy retry remaining source")
	check(L.compare(balance(income_game,"1"),val(3)).order==0 and L.compare(balance(income_game,"2"),val(5)).order==0,"galaxy retry does not duplicate earlier income")
	var max_game:=BattleGame.new(db,false)
	max_game.state=max_game.State.RETREAT
	max_game.profile.highestLevel=int(max_game.hyperspace.config.unlock_stage)
	max_game.profile.resources["1"]={"m":1.0,"e":3800.0}
	max_game.profile.hyperspace.materials[material_id]=9007199254740991
	max_game.profile.loadout.weapons[0].key="laser"
	max_game.profile.loadout.weapons[0].level=1
	var request=max_game.request_max_upgrade_slot("weapons",0)
	var credits:=0
	while request.status=="pending":
		await process_frame
		check(max_game.currency_income("1",1).status=="committed","income during active real MAX")
		credits+=1
		request=max_game.poll_max_upgrade(request.request_id)
	check(request.status=="complete" and request.quote.count==47959 and credits>0,"real MAX finishes during continuous income")
	var max_before:L.Value=balance(max_game,"1")
	var actual_fee:L.Outcome=L.decode(request.quote.resource_debit["1"])
	var confirmed=max_game.confirm_max_upgrade(request.request_id,request.fingerprint)
	check(confirmed.status=="committed" and max_game.profile.loadout.weapons[0].level==47960,"real MAX same-content fresh ticket")
	var spent:L.Outcome=L.subtract(max_before,balance(max_game,"1"))
	check(L.compare(spent.value,actual_fee.value).order==0,"real MAX debit equals shown fee")
	check(max_game.confirm_max_upgrade(request.request_id,request.fingerprint).status!="committed","real MAX duplicate confirm refused")
	var batch_game:=BattleGame.new(db,false)
	for ship in db.ships:
		if int(db.ships[ship].weaponSlots)>=3:
			batch_game.profile.selectedShip=ship
			break
	var slots:Array=[]
	for index in 3:
		var entry:Dictionary=batch_game.profile.loadout.weapons[0].duplicate(true)
		entry.key="laser";entry.level=50 if index==1 else 1
		slots.append(entry)
	batch_game.profile.loadout.weapons=slots
	batch_game.state=batch_game.State.RETREAT
	batch_game.profile.resources["1"]=180.0
	var batch_events:Array=[]
	batch_game.event.connect(func(kind,payload):batch_events.append({"kind":kind,"payload":payload.duplicate(true)}))
	var bought=batch_game.upgrade_equipment_batch("1")
	check(bought.status=="committed" and bought.changed_slots==["weapons_0","weapons_2"],"ordered ordinary batch skips middle and continues")
	check(L.compare(balance(batch_game,"1"),val(50)).order==0,"batch exact sequential remaining budget")
	check(batch_events[-1].kind=="upgrades_completed" and batch_events[-1].payload.slots==bought.changed_slots,"batch final event actual slots")
	var batch_before:Dictionary=batch_game.profile.duplicate(true)
	check(batch_game.upgrade_equipment_batch("10").status=="rejected" and batch_game.profile==batch_before,"ordinary batch no success returns rejected")
	batch_game.profile.resources["1"]=1000.0
	for entry in batch_game.profile.loadout.weapons:entry.level=1
	var batch_request=batch_game.upgrade_equipment_batch("max")
	check(batch_request.status=="pending","MAX batch typed pending")
	var pending_snapshot:Dictionary=batch_game.profile.duplicate(true)
	while batch_request.status=="pending":
		await process_frame
		batch_request=batch_game.poll_upgrade_batch(batch_request.request_id)
		check(batch_game.profile==pending_snapshot,"MAX batch calculation readonly")
	check(batch_request.status=="complete" and batch_request.planned_slots.size()==1 and batch_request.planned_slots[0].levels==8,"MAX batch fixed sequential snapshot remainder")
	var batch_receipt=batch_game.confirm_upgrade_batch(batch_request.request_id,batch_request.quote_fingerprint)
	check(batch_receipt.status=="committed" and batch_receipt.changed_slots==["weapons_0"],"MAX batch one shared completed plan")
	check(L.compare(balance(batch_game,"1"),val(15)).order==0,"MAX batch same quoted debit")
	print("P2_GAME_COMPLETE checks=",checks)
	quit(0)

