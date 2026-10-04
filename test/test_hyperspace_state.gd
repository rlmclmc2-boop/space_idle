extends SceneTree
const Bag=preload("res://scripts/drone_inventory.gd")
const State=preload("res://scripts/hyperspace_state.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
var reward_calls:=0
class FailedWriter extends "res://scripts/progress_writer.gd":
	func write_progress(_bytes: PackedByteArray) -> Error:return ERR_FILE_CANT_WRITE

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func drone(id: String="stub",quality: String="white",legendary: bool=false,ultimate: bool=false) -> Dictionary:
	return {"id":id,"origin_quality":quality,"weapon":"laser","level":5,"legendary":legendary,"ultimate":ultimate,"blue_source_bonus":quality=="blue","legendary_effect":{},"ultimate_affix":{},"affixes":[],"hangings":[]}

func reward(_request: Dictionary={}) -> Dictionary:
	reward_calls+=1
	return {"drone":drone(),"materials":{"degenerate_matter":1}}

func opened(db: ShipDatabase):
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,7);g.rebuild_unlocks()
	return g

func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var locked:=BattleGame.new(db,false)
	var before: Dictionary=locked.profile.hyperspace.duplicate(true)
	locked.hyperspace.advance(locked,100000)
	check(locked.profile.hyperspace==before,"unopened old/fresh game remains unchanged")
	var g=opened(db);var h=g.hyperspace
	check(State.valid(g.profile.hyperspace,h.config,db.levels.size()),"fresh versioned state is valid")
	var a: Dictionary=h.start(g,"alpha",5,"manual")
	check(not a.is_empty() and g.profile.hyperspace.energy==108000,"actual manual ticket paid once")
	check(h.start(g,"alpha",5,"manual").is_empty(),"only one active receipt")
	check(h.complete(g,a.round_id,a.run_id,true,reward(),40,true),"successful completion freezes reward and best X1")
	var pending: Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(pending,db).error=="","pending receipt passes portable schema")
	var restored:=BattleGame.new(db,false);restored.load_progress_data(pending)
	check(restored.hyperspace.claim(restored,a.round_id,a.run_id),"same saved pending receipt can be claimed")
	check(not restored.hyperspace.claim(restored,a.round_id,a.run_id) and restored.profile.hyperspace.materials.degenerate_matter==1,"repeated claim cannot mint reward")
	check(restored.profile.hyperspace.inventory.warehouse==["space:1:1"],"stable deterministic drone identity")
	check(not h.complete(g,a.round_id,a.run_id,true,reward(),10,true),"completion cannot reroll frozen result")
	check(h.claim(g,a.round_id,a.run_id) and h.best_x1(g,"alpha",5)==40,"best X1 and reward remain consistent")
	var saved: Dictionary=g.portable_save_data()
	check(Transfer.new().prepare_data(saved,db).data.hyperspace==saved.hyperspace,"claim snapshot import/export preserves full namespace")
	var roundtrip:=BattleGame.new(db,false);roundtrip.load_progress_data(JSON.parse_string(JSON.stringify(saved)))
	check(not roundtrip.hyperspace.claim(roundtrip,a.round_id,a.run_id),"saved claimed receipt remains settled after JSON reload")
	var legacy: Dictionary=saved.duplicate(true);legacy.version=4;legacy.erase("hyperspace")
	var migrated:=BattleGame.new(db,false);migrated.load_progress_data(legacy)
	check(migrated.profile.hyperspace==migrated.hyperspace.fresh() and migrated.profile.resources==g.profile.resources,"v4 missing namespace migrates without changing old balances")
	check(migrated.profile.version==5,"v4 migration writes guarded v5 container")
	var corrupt: Dictionary=saved.duplicate(true);corrupt.hyperspace.version=2
	check(Transfer.new().prepare_data(corrupt,db).error=="format","future subsystem version safely rejected")
	var baseline: Dictionary=g.profile.duplicate(true);g.load_progress_data(corrupt)
	check(g.profile==baseline,"invalid load leaves live authoritative state untouched")
	g.profile.hyperspace.energy=216000
	a=h.start(g,"alpha",5,"manual")
	h.advance(g,10800)
	check(h.complete(g,a.round_id,a.run_id,false) and g.profile.hyperspace.energy==324000,"refund actual paid ticket may exceed cap")
	h.advance(g,1000)
	check(g.profile.hyperspace.energy==324000 and not h.complete(g,a.round_id,a.run_id,false),"over-cap energy stops accrual; duplicate refund rejected")
	check(not h.set_auto(g,true,"beta",5,50),"automatic exploration requires matching route-level X1 history")
	check(h.set_auto(g,true,"alpha",5,500),"automatic route-level preference accepted")
	var auto_before: Dictionary=g.profile.hyperspace.duplicate(true);h.advance(g,100)
	check(g.profile.hyperspace.active.is_empty() and g.profile.hyperspace.energy==auto_before.energy,"missing reward adapter cannot consume auto tickets")
	h.reward_provider=Callable(self,"reward")
	check(h.start_auto(g),"auto creates progress transaction without BattleGame scene")
	check(g.profile.hyperspace.active.duration==10 and is_equal_approx(g.profile.hyperspace.active.ticket,108000.0*20.0/520.0),"crew duration floor and ticket formula")
	h.advance(g,10)
	check(g.profile.hyperspace.materials.degenerate_matter==2,"auto finishes using frozen claim path")
	# Use a separate compact time configuration to test bounded batch processing.
	var fast=opened(db);var fc: Dictionary=fast.hyperspace.config.duplicate(true)
	fc.energy_cap=1.0;fc.energy_rate=1.0;fc.ticket=0.5
	check(fast.hyperspace.configure(fc),"valid alternative independent config")
	fast.profile.hyperspace=fast.hyperspace.fresh();fast.profile.hyperspace.history={"alpha":{"5":10.0}}
	fast.hyperspace.reward_provider=Callable(self,"reward");fast.hyperspace.set_auto(fast,true,"alpha",5,0)
	fast.hyperspace.advance(fast,1000)
	check(fast.profile.hyperspace.materials.degenerate_matter==8,"large online step respects completion budget")
	check(fast.profile.hyperspace.pending_time>0,"legal work remains pending at budget yield")
	check(Transfer.new().prepare_data(fast.portable_save_data(),db).data.hyperspace.pending_time==fast.profile.hyperspace.pending_time,"budget remainder belongs to the saved snapshot")
	# Saturation retains one completed pending receipt, then pauses without debt.
	var full=opened(db);var fh=full.hyperspace;var bag: Dictionary=full.profile.hyperspace.inventory
	for i in 210:check(Bag.insert(bag,drone("bulk:%d"%i),fh.config),"fill warehouse and ten fixed overflow slots")
	check(not Bag.insert(bag,drone("excess"),fh.config),"full inventory insertion rejects excess")
	a=fh.start(full,"alpha",5,"manual")
	check(fh.complete(full,a.round_id,a.run_id,true,reward(),30,true) and not fh.claim(full,a.round_id,a.run_id),"completed reward retained when both stores full")
	fh.reward_provider=Callable(self,"reward");fh.set_auto(full,true,"alpha",5,100)
	var count_before:=reward_calls;fh.advance(full,100000)
	check(full.profile.hyperspace.blocked and full.profile.hyperspace.active.status=="completed_pending" and reward_calls==count_before and full.profile.hyperspace.pending_time==0,"full inventory neither draws new rewards nor accumulates replay debt")
	check(fh.remove_unprotected(full,"bulk:0"),"organizing releases one safe slot and drains overflow")
	fh.advance(full,0.1)
	check(full.profile.hyperspace.active.is_empty() and full.profile.hyperspace.inventory.drones.has("space:1:1") and full.profile.hyperspace.blocked,"pending receipt claims first, subsequent auto remains stopped when full again")
	# Independent legendary/ultimate flags count against both budgets.
	var limits=opened(db);var lh=limits.hyperspace
	for d in [drone("both","blue",true,true),drone("legend","legendary",true),drone("third","gold",true),drone("other_ultimate","white",false,true)]:
		check(Bag.insert(limits.profile.hyperspace.inventory,d,lh.config),"separate origin/legendary/ultimate model accepted")
	check(lh.set_equipped(limits,["both","legend"],5),"one drone may occupy both independent budgets")
	check(not lh.set_equipped(limits,["both","legend","third"],5) and not lh.set_equipped(limits,["both","other_ultimate"],5),"legendary two and ultimate one hard limits")
	check(not lh.remove_unprotected(limits,"both"),"equipped protected from clearing")
	lh.set_favorites(limits,["third"])
	check(not lh.remove_unprotected(limits,"third"),"favorite protected from clearing")
	lh.set_preset(limits,0,"test",["other_ultimate"])
	check(not lh.remove_unprotected(limits,"other_ultimate"),"preset reference protected from clearing")
	var bad:=drone("duplicate_hanging","blue");bad.hangings=["collector","collector"]
	check(not Bag.insert(limits.profile.hyperspace.inventory,bad,lh.config),"same drone cannot repeat hanging")
	# Reforge retains only explicit sealed IDs/history; ordinary systems untouched.
	g.profile.hyperspace.history.alpha["10"]=20.0
	var planet_gate:=int(db.unlock_row("planet","1").level)
	g.profile.cleared=range(1,planet_gate+1);g.rebuild_unlocks()
	g.profile.planets["1"].degree=400;g.planet_buildings.sync(g,"1");g.profile.planets["1"].buildings.shipyard.status="built"
	var ordinary: Dictionary=g.profile.resources.duplicate(true)
	check(g.reforge_planet("1",["space:1:1"],{"space:1:1":10}),"authorized reforge creates explicit sealed selection")
	check(g.profile.hyperspace.round_id==2 and g.profile.hyperspace.inventory.reforge_count==1 and Bag.capacity(g.profile.hyperspace.inventory,h.config)==210,"reforge advances epoch and capacity by ten")
	check(g.profile.hyperspace.materials.degenerate_matter==0 and g.profile.hyperspace.active.is_empty() and g.profile.resources==ordinary,"new resources/receipts reset without clearing ordinary permanent balances")
	check(h.best_x1(g,"alpha",10)==0 and g.profile.hyperspace.history.alpha["10"]==20,"history retained but cannot use lifetime stage to bypass current round")
	check(not h.claim_sealed(g,"space:1:1") and not h.claim(g,1,1),"sealed and stale previous-round callbacks rejected")
	g.profile.highestLevel=10
	check(h.claim_sealed(g,"space:1:1") and not h.claim_sealed(g,"space:1:1") and h.best_x1(g,"alpha",10)==20,"returning to corresponding stage unseals once and enables record")
	check(State.valid(g.profile.hyperspace,h.config,db.levels.size()),"final state maintains persisted invariants")
	# A manual-save failure leaves the previous complete namespace recoverable.
	var disk=opened(db);disk.save_enabled=true
	a=disk.hyperspace.start(disk,"alpha",5,"manual")
	disk.hyperspace.complete(disk,a.round_id,a.run_id,true,reward(),50,true)
	disk.save_progress()
	var disk_before: Dictionary=preload("res://scripts/progress_writer.gd").read_progress(BattleGame.SAVE_PATH)
	disk.hyperspace.claim(disk,a.round_id,a.run_id)
	disk.progress_writer=FailedWriter.new();disk.save_progress()
	check(disk.last_save_error==ERR_FILE_CANT_WRITE and disk.save_dirty,"failed IO does not claim durable commit")
	check(preload("res://scripts/progress_writer.gd").read_progress(BattleGame.SAVE_PATH).hyperspace==disk_before.hyperspace,"failed save preserves previous full receipt/inventory/material snapshot")
	var recovered:=BattleGame.new(db,true)
	check(recovered.hyperspace.claim(recovered,a.round_id,a.run_id) and not recovered.hyperspace.claim(recovered,a.round_id,a.run_id),"recovered previous pending snapshot grants exactly once")
	check(recovered.profile.hyperspace.materials.degenerate_matter==1,"recovery restores balances with receipt, never mixes two commits")
	var reload_input: Dictionary=recovered.portable_save_data();reload_input.chronoSavedAt=Time.get_unix_time_from_system()-100000
	var offline_copy:=BattleGame.new(db,false);offline_copy.load_progress_data(reload_input)
	check(offline_copy.profile.hyperspace==reload_input.hyperspace,"offline reload contributes zero hyperspace energy or work")
	var invalid_disk: Dictionary=reload_input.duplicate(true);invalid_disk.hyperspace.version=2
	var f:=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE);f.store_string(JSON.stringify(invalid_disk));f.close()
	check(preload("res://scripts/progress_writer.gd")._read_progress_file(BattleGame.SAVE_PATH)==null,"safe reader rejects future namespace, allowing existing backup fallback")
	# Short CPU-only micro-baseline: 6000 idle online ticks with 200 stored drones.
	var bench=opened(db)
	for i in 200:Bag.insert(bench.profile.hyperspace.inventory,drone("bench:%d"%i),bench.hyperspace.config)
	var begun:=Time.get_ticks_usec();var generation: int=bench.profile.hyperspace.inventory.generation
	for _i in 6000:bench.hyperspace.advance(bench,1.0/60.0)
	var elapsed:=Time.get_ticks_usec()-begun
	check(bench.profile.hyperspace.inventory.generation==generation and bench.profile.hyperspace.inventory.drones.size()==200,"idle scheduler never scans/rebuilds warehouse projection")
	print("HYPERSPACE MICRO: ",JSON.stringify({"ticks":6000,"warehouse":200,"elapsed_us":elapsed,"mean_us":float(elapsed)/6000.0,"snapshot_bytes":JSON.stringify(bench.profile.hyperspace).to_utf8_buffer().size()}))
	print("HYPERSPACE STATE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
