extends SceneTree
const L=preload("res://scripts/currency_ledger.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
const Writer=preload("res://scripts/progress_writer.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		printerr("P2_FAIL ",label)
		quit(1)
		assert(false,label)
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")
func _run()->void:
	check(GDExtensionManager.load_extension("res://space_native.gdextension") in [0,2],"chain native save lock loaded")
	var db:=ShipDatabase.new()
	var g:=BattleGame.new(db,false)
	g.state=g.State.RETREAT
	g.profile.resources["1"]={"m":1.0,"e":3800.0}
	g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)
	g.profile.hyperspace.materials[db.evolution_material_id()]=9007199254740993
	check(g.currency_income("1",0.5).status=="committed","chain sparse fractional credit")
	var original:Dictionary=g.profile.resources.duplicate(true)
	var writer=g.progress_writer
	writer.path=ProjectSettings.globalize_path("user://p2-chain-progress.json")
	check(writer.acquire_owner(),"chain owns isolated progress")
	g.save_enabled=true
	g.save_progress()
	check(g.last_save_error==OK,"full sparse ordinary save")
	var disk:Dictionary=Writer.read_progress_result(writer.path,db)
	check(disk.status=="loaded" and disk.data.hyperspace.materials[db.evolution_material_id()]==9007199254740993,"ordinary high-int64 material token")
	check(L.compare(L.decode(original["1"]).value,L.decode(disk.data.resources["1"]).value).order==0,"ordinary distant fractional low bit")
	var restored:=BattleGame.new(db,false)
	restored.load_progress_data(disk.data)
	check(restored.profile.hyperspace.materials[db.evolution_material_id()]==9007199254740993,"real Game high material reload")
	for invalid_material in [-1,0.5,9223372036854775808.0,"9007199254740993",{"currency_version":1,"blocks":[]}]:
		var invalid_state:Dictionary=g.profile.hyperspace.duplicate(true)
		invalid_state.materials[db.evolution_material_id()]=invalid_material
		check(not preload("res://scripts/hyperspace_state.gd").valid(invalid_state,g.hyperspace.config,db.levels.size()),"material invalid type/range rejected")
	g.profile.hyperspace.materials[db.evolution_material_id()]=9223372036854775807
	g.save_progress()
	var endpoint:Dictionary=Writer.read_progress_result(writer.path,db)
	check(g.last_save_error==OK and endpoint.status=="loaded" and endpoint.data.hyperspace.materials[db.evolution_material_id()]==9223372036854775807,"int64 maximum material disk roundtrip")
	g.profile.hyperspace.materials[db.evolution_material_id()]=9007199254740993

	var transfer:=Transfer.new()
	var portable_path:String=ProjectSettings.globalize_path("user://p2-portable.json")
	check(transfer.export_progress(g,portable_path)==OK,"portable export")
	var candidate:Dictionary=transfer.prepare(portable_path,db)
	check(candidate.error.is_empty() and candidate.data.hyperspace.materials[db.evolution_material_id()]==9007199254740993,"portable candidate exact material")
	check(L.compare(L.decode(original["1"]).value,L.decode(candidate.data.resources["1"]).value).order==0,"portable sparse low bit")
	check(g.currency_initialize_resource("1",123),"controlled change before import")
	g.save_progress()
	var transaction:Dictionary=transfer.commit_import(g,candidate.data)
	check(transaction.error==OK,"real import install")
	disk=Writer.read_progress_result(writer.path,db)
	check(disk.status=="loaded" and L.compare(L.decode(disk.data.resources["1"]).value,L.decode(original["1"]).value).order==0,"installed import reload")
	var previous:Dictionary=transfer.prepare(str(transaction.backup)+"/current-progress.json",db)
	check(previous.error.is_empty() and L.compare(L.decode(previous.data.resources["1"]).value,L.decode(123).value).order==0,"import backup retains old live")
	check(transfer.rollback(transaction)==OK,"real import rollback")
	disk=Writer.read_progress_result(writer.path,db)
	check(disk.status=="loaded" and L.compare(L.decode(disk.data.resources["1"]).value,L.decode(123).value).order==0,"rollback old primary")
	# Recovery must prefer a complete backup over a structurally empty primary.
	var valid_bytes:PackedByteArray=FileAccess.get_file_as_bytes(writer.path)
	var recovery_path:String=ProjectSettings.globalize_path("user://p2-recovery.json")
	var file:=FileAccess.open(recovery_path+".bak",FileAccess.WRITE)
	file.store_buffer(valid_bytes);file.close()
	file=FileAccess.open(recovery_path,FileAccess.WRITE);file.store_string('{"version":5}');file.close()
	var recovered:Dictionary=Writer.read_progress_result(recovery_path,db)
	check(recovered.status=="loaded" and recovered.source==".bak","complete exact backup selected")
	check(FileAccess.get_file_as_string(recovery_path)=='{"version":5}',"recovery selection readonly")
	var invalid:Dictionary=candidate.data.duplicate(true)
	invalid.resources["1"]={"currency_version":1,"blocks":[{"p":"-0","d":1}]}
	var primary_before:PackedByteArray=FileAccess.get_file_as_bytes(writer.path)
	check(transfer.commit_import(g,invalid).error!=OK and FileAccess.get_file_as_bytes(writer.path)==primary_before,"bad import preserves primary")
	# Real scheduler: one due intent, fixed budget while income arrives, one receipt.
	var crew_game:=BattleGame.new(ShipDatabase.new(),false)
	crew_game.state=crew_game.State.RETREAT
	crew_game.profile.resources["1"]=1000.0
	crew_game.profile.grantedUnlocks=["crew/engineer"]
	check(crew_game.crew.assign(crew_game,"engineer","equipment_upgrade","equipment","max"),"actual crew MAX assignment")
	crew_game.crew.advance(crew_game,10.0)
	check(crew_game.crew._pending_upgrades.has("engineer"),"crew records typed pending intent")
	var completed_events:Array=[]
	crew_game.event.connect(func(kind,payload):
		if kind=="upgrades_completed":completed_events.append(payload.duplicate(true))
	)
	var request_count:int=crew_game._next_batch_request
	while not crew_game.crew._pending_upgrades.is_empty():
		await process_frame
		crew_game.currency_income("1",1)
		crew_game.process_equipment_queries()
		crew_game.crew.advance(crew_game,0.0001)
	check(completed_events.size()==1 and crew_game._next_batch_request==request_count,"crew completes once without requeue under income")
	check(crew_game.crew.timers.has("engineer") and crew_game.profile.loadout.weapons[0].level==9,"crew reschedules only after final successful receipt")
	# Explicit projection and synthetic generator use the resource boundary.
	check(L.analysis_value({"m":1.0,"e":3800.0}).status=="out_of_domain","analysis overflow explicit")
	check(L.analysis_value(0.5).status=="ok" and L.analysis_value(0.5).amount==0.5,"analysis finite unchanged")
	var generated:Dictionary=preload("res://scripts/player_loadout_generator.gd").upgraded_profile(db,{"ship":g.profile.selectedShip,"equipment":g.profile.loadout.duplicate(true)},g.profile,1)
	check(not generated.has("error") and generated.loadout.weapons[0].level==g.profile.loadout.weapons[0].level+1,"generator exact funded upgrade")
	generated.resources.clear()
	check(not g.profile.resources.is_empty(),"generator result independent")
	print("P2_CHAIN_COMPLETE checks=",checks)
	quit(0)
