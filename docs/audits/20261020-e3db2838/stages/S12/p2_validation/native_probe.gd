extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const L=preload("res://scripts/currency_ledger.gd")
const PlayerGame=preload("res://scripts/presented_battle_game.gd")
var checks:=0
class RejectSaveGame extends "res://scripts/presented_battle_game.gd":
	func purchase_save_preflight(_resources:Dictionary,_material:int,_weapons:Dictionary,_defence:Dictionary)->bool:
		return false
class ObservedSession extends "res://scripts/native_execution_session.gd":
	var installs:=0
	var singles:=0
	var force_handoff_failure:=false
	func commit_numeric_batch(game,batch:Dictionary)->bool:
		installs+=1
		return super.commit_numeric_batch(game,batch)
	func upgrade_numeric_configuration(game,category:String,index:int,levels:int)->bool:
		singles+=1
		return super.upgrade_numeric_configuration(game,category,index,levels)
	func handoff_to_legacy(game:RefCounted,reason:String)->bool:
		if force_handoff_failure:return false
		return super.handoff_to_legacy(game,reason)
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		printerr("P2_FAIL ",label)
		quit(1)
		assert(false,label)
func make_game(db:ShipDatabase)->BattleGame:
	var g:=PlayerGame.new(db,false)
	g.profile.loadout.weapons[0].key="laser"
	g.profile.loadout.weapons[0].level=1
	g.profile.resources["1"]=100000.0
	g.state=g.State.COMBAT
	g.reset_player()
	return g
func attach(g:BattleGame)->ObservedSession:
	var descriptor:Dictionary=Compiler.new().compile(g,"native_low_contract")
	check(not descriptor.has("error"),"actual native descriptor "+str(descriptor.get("error","")))
	var session:=ObservedSession.new()
	check(session.admit(g,descriptor),"actual DLL admits")
	g.native_execution=session
	return session
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")

func _run()->void:
	var loaded:int=GDExtensionManager.load_extension("res://space_native.gdextension")
	check(loaded in [0,2] and ClassDB.class_exists("SpaceCombatKernel") and ClassDB.class_exists("SpaceSaveLock"),"pinned DLL loaded")
	var db:=ShipDatabase.new()
	var g:BattleGame=make_game(db)
	var session:ObservedSession=attach(g)
	var receipt=g.upgrade_equipment_batch("1")
	check(receipt.status=="committed" and not receipt.changed_slots.is_empty(),"actual native batch purchases")
	check(g.native_execution==session and not session.handed_off,"aggregate native owner retained")
	check(session.installs==1 and session.singles==0,"one aggregate DLL install")
	var expected:Dictionary=Compiler.new().compile(g,"native_low_contract")
	check(not expected.has("error") and session.weapons==expected.weapons,"installed descriptor matches actual levels")
	var lock=g.progress_writer
	lock.path=ProjectSettings.globalize_path("user://p2-native-progress.json")
	check(lock.acquire_owner(),"isolated save writer native owner")
	g.save_enabled=true
	g.save_progress()
	check(g.last_save_error==OK,"CW1 actual native writer save")
	var disk=preload("res://scripts/progress_writer.gd").read_progress_result(lock.path,db)
	check(disk.status=="loaded","CW1 actual full disk validation")
	var restored:=BattleGame.new(db,false)
	restored.load_progress_data(disk.data)
	check(L.compare(g.currency_balance("1").value,restored.currency_balance("1").value).order==0,"CW1 ordinary disk reload")
	g.profile.resources["1"]=1000.0
	var pending=g.upgrade_equipment_batch("max")
	check(pending.status=="pending","actual native MAX batch pending")
	while pending.status=="pending":
		await process_frame
		pending=g.poll_upgrade_batch(pending.request_id)
	check(pending.status=="complete","actual native MAX plan complete")
	var prior_installs:int=session.installs
	var max_receipt=g.confirm_upgrade_batch(pending.request_id,pending.quote_fingerprint)
	check(max_receipt.status=="committed" and session.installs==prior_installs+1 and session.singles==0,"actual native MAX one aggregate install")
	var failing:BattleGame=make_game(ShipDatabase.new())
	var late:ObservedSession=attach(failing)
	late.force_handoff_failure=true
	var triggered:Dictionary={"once":false}
	var failing_ref:WeakRef=weakref(failing)
	failing.event.connect(func(kind,_payload):
		if kind=="upgrade" and not triggered.once:
			triggered.once=true
			var actual=failing_ref.get_ref()
			if actual!=null:actual.db.equipment.armour[0].cost_1=51
	)
	var partial=failing.upgrade_equipment_batch("1")
	check(partial.status=="committed" and partial.changed_slots.size()>=1 and partial.reason=="native_handoff_failed","late handoff failure retains successful prefix")
	check(late.installs==0,"late failure installs no stale descriptor")
	check(late.advance_blocked and failing.paused,"late failure blocks old kernel advancement")
	check(failing.profile.loadout.defence[0].level==1,"late failure stops defence slot")
	var rejected:=RejectSaveGame.new(ShipDatabase.new(),false)
	rejected.profile.resources["1"]=100000.0
	rejected.state=rejected.State.COMBAT
	rejected.reset_player()
	var refused_session:ObservedSession=attach(rejected)
	var unchanged:Dictionary=rejected.profile.duplicate(true)
	var refused=rejected.upgrade_equipment_batch("1")
	check(refused.status=="rejected" and refused.reason=="save_preflight","save preflight batch refusal")
	check(rejected.profile==unchanged and refused_session.installs==0 and refused_session.singles==0 and not refused_session.handed_off,"save refusal before live or native effects")
	check(not rejected.upgrade_slot("weapons",0,1) and rejected.profile==unchanged and refused_session.singles==0,"single save refusal before native effects")
	print("P2_NATIVE_COMPLETE checks=",checks," installs=",session.installs," source_DLL=4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f")
	quit(0)
