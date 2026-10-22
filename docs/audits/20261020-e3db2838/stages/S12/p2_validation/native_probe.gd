extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const L=preload("res://scripts/currency_ledger.gd")
const PlayerGame=preload("res://scripts/presented_battle_game.gd")
var checks:=0
class ObservedGame extends "res://scripts/presented_battle_game.gd":
	var preflight_us:=0
	func purchase_save_preflight(resources:Dictionary,material:int,weapons:Dictionary,defence:Dictionary)->bool:
		var started:int=Time.get_ticks_usec()
		var result:bool=super.purchase_save_preflight(resources,material,weapons,defence)
		preflight_us+=Time.get_ticks_usec()-started
		return result

class RejectSaveGame extends "res://scripts/presented_battle_game.gd":
	func purchase_save_preflight(_resources:Dictionary,_material:int,_weapons:Dictionary,_defence:Dictionary)->bool:
		return false
class ObservedSession extends "res://scripts/native_execution_session.gd":
	var installs:=0
	var prepare_us:=0
	var install_us:=0
	func prepare_numeric_batch(game,mode:String,completed_plan:Array=[])->Dictionary:
		var started:int=Time.get_ticks_usec()
		var result:Dictionary=super.prepare_numeric_batch(game,mode,completed_plan)
		prepare_us+=Time.get_ticks_usec()-started
		return result

	var singles:=0
	var force_handoff_failure:=false
	func commit_numeric_batch(game,batch:Dictionary)->bool:
		installs+=1
		var started:int=Time.get_ticks_usec()
		var result:bool=super.commit_numeric_batch(game,batch)
		install_us+=Time.get_ticks_usec()-started
		return result
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
	var g:=ObservedGame.new(db,false)
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
	var purchase_started:int=Time.get_ticks_usec()
	var receipt=g.upgrade_equipment_batch("1")
	var normal_batch_us:int=Time.get_ticks_usec()-purchase_started
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
	purchase_started=Time.get_ticks_usec()
	var max_receipt=g.confirm_upgrade_batch(pending.request_id,pending.quote_fingerprint)
	var max_commit_us:int=Time.get_ticks_usec()-purchase_started
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
	var recovered:BattleGame=make_game(ShipDatabase.new())
	var recovering:ObservedSession=attach(recovered)
	var prefix:Dictionary={"armour":null,"triggered":false}
	var recovered_ref:WeakRef=weakref(recovered)
	recovered.event.connect(func(kind,payload):
		if kind=="upgrade" and payload.key=="armour" and not prefix.triggered:
			prefix.triggered=true
			var actual=recovered_ref.get_ref()
			prefix.armour=actual.player.armour
			actual.db.equipment.armour[0].cost_1=51
	)
	var recovery=recovered.upgrade_equipment_batch("1")
	print("P2_DEFENCE_DIAGNOSTIC ",recovery.status," slots=",recovery.changed_slots," prefix=",prefix," handoff=",recovering.handed_off," player=",recovered.player.armour)
	check(recovery.status=="committed" and prefix.triggered and recovering.handed_off and recovered.native_execution==null,"defence prefix transfers on callback invalidation")
	check(recovered.N.compare(recovered.player.armour,prefix.armour)==0,"successful handoff preserves committed defence delta")
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

	var observed_context:Dictionary=g._pack_context()
	var differences:Array=[]
	for key in observed_context:
		if g._validated_pack_context.get(key)!=observed_context[key]:differences.append(key)
	if not differences.is_empty():print("P2_PACK_CONTEXT_DIFF ",differences)
	check(g._validated_pack_context==g._pack_context(),"same-content validation proof bound")
	var original_cost:Variant=g.db.equipment.laser[0].cost_1
	g.db.equipment.laser[0].cost_1=original_cost+1
	check(g._validated_pack_context!=g._pack_context(),"in-place database edit invalidates pack proof")
	g.db.equipment.laser[0].cost_1=original_cost
	var config_path:String="res://data/hyperspace_config.json"
	var original_bytes:PackedByteArray=FileAccess.get_file_as_bytes(config_path)
	var file:=FileAccess.open(config_path,FileAccess.WRITE)
	file.store_buffer(original_bytes);file.store_string(" ");file.close()
	check(g._validated_pack_context!=g._pack_context(),"changed data bytes invalidate pack proof")
	file=FileAccess.open(config_path,FileAccess.WRITE);file.store_buffer(original_bytes);file.close()
	check(g._validated_pack_context==g._pack_context(),"restored identical validation inputs match")

	var transfer=preload("res://scripts/save_transfer.gd").new()
	var invalid_save:Dictionary=g.portable_save_data()
	invalid_save.resources["1"]={"currency_version":2,"main":{"c":1,"e":"0"},"residual":{"c":0,"e":"0"}}
	check(not transfer.prepare_data(invalid_save,g.db,g,true).error.is_empty(),"cached pack still rejects malformed resource")
	invalid_save=g.portable_save_data()
	invalid_save.hyperspace.materials[g.db.evolution_material_id()]=9223372036854775808.0
	check(not transfer.prepare_data(invalid_save,g.db,g,true).error.is_empty(),"cached pack still rejects material overflow")
	invalid_save=g.portable_save_data()
	invalid_save.loadout.weapons[0].level=-1
	check(not transfer.prepare_data(invalid_save,g.db,g,true).error.is_empty(),"cached pack still rejects invalid level")
	check(normal_batch_us<=50000 and max_commit_us<=50000,"native command heartbeat budget")
	print("P2_NATIVE_TIMING ",JSON.stringify({"normal_batch_us":normal_batch_us,"max_commit_us":max_commit_us,"preflight_total_us":g.preflight_us,"prepare_total_us":session.prepare_us,"install_total_us":session.install_us}))
	print("P2_NATIVE_COMPLETE checks=",checks," installs=",session.installs," source_DLL=4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f")
	quit(0)

