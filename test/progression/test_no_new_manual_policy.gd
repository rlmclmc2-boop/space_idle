extends "res://qa/hyperspace_longrun.gd"
const Bag=preload("res://scripts/drone_inventory.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
var tested:=0
var failed:=0
func check(ok:bool,label:String)->void:
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 game=Game.new(ShipDatabase.new());var g=game
 check(g.load_hyperspace_routes(),"Formal routes accepted")
 # Isolated legal-domain fixtures, not an earned timing/balance source.
 g.profile.highestLevel=33;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.hyperspace.energy=g.hyperspace.config.energy_cap
 g.stage=20;g.group_index=1;g.state=g.State.TRAVEL;g.enemies.clear();g.profile.loop=false
 options={};configure_manual_policy()
 check(space_policy.get_script()==SpacePolicy,"Default retains original policy")
 var base=SpacePolicy.new();var request={"domain":true,"kind":"space_manual","route":"alpha","level":5,"round":1,"frontier":int(g.profile.highestLevel)}
 base.manual_pending=request.duplicate(true)
 check(not base.pending_manual_action(g,2000).is_empty(),"Baseline fixture really dispatches new manual request")
 var memory=Checkpoint.fields(base,Checkpoint.POLICY)
 options={"allow_new_manual":false};configure_manual_policy();Checkpoint.apply_fields(space_policy,memory,Checkpoint.POLICY)
 var before=JSON.stringify(g.profile);var pending=space_policy.manual_pending.duplicate(true)
 check(not space_policy.manual_retry_allowed(g,"alpha",5,2000) and space_policy.pending_manual_action(g,2000).is_empty(),"Modifier blocks new retry and existing queued dispatch")
 check(not space_policy.execute(g,request,2000) and JSON.stringify(g.profile)==before,"Stale manual command cannot debit or start")
 check(space_policy.manual_pending==pending and Checkpoint.fields(space_policy,Checkpoint.POLICY)==memory,"Disabling dispatch preserves policy memory and queued request")
 # Original watchdog keeps handling an attempt already in progress.
 space_policy.manual_started(g,"alpha",5,0);g.manual_hyperspace.active=true;g.group_index=1
 var report=space_policy.check_manual_budget(g,{"actor":{"hp":1.0,"shield":1.0}},900)
 check(not str(report.exit_reason).is_empty(),"Existing manual attempt still has original finite exit budget")
 g.manual_hyperspace.active=false;space_policy.manual_finished(g,false,900)
 # A genuine recorded history fixture keeps its auto eligibility and earned rewards.
 g.profile.hyperspace.history={"alpha":{"5":10.0}};g.crew.load_state(g,[])
 for member in g.profile.crew:g.crew.assign(g,str(member.crewId),"","")
 var auto=space_policy.space_action(g,2000)
 check(auto.get("kind","")=="space_auto","History automation remains selected")
 check(space_policy.execute(g,auto,2000),"Automation uses unchanged domain transaction")
 check(g.hyperspace.start_auto(g),"Actual recorded auto run can start")
 g.profile.hyperspace.active.work=g.profile.hyperspace.active.duration
 check(g.hyperspace.complete_auto(g),"Actual recorded auto run completes through production rewards")
 var claim=space_policy.space_action(g,2000)
 check(claim.get("kind","")=="space_claim" and space_policy.execute(g,claim,2000),"Pending earned reward is still claimed")
 var claimed=JSON.stringify(g.profile.hyperspace)
 check(not space_policy.execute(g,claim,2000) and JSON.stringify(g.profile.hyperspace)==claimed,"Duplicate claim remains atomic rejection")
 # Compare the actual base and modifier equipment/forge decisions with equal state and RNG.
 var bag=g.profile.hyperspace.inventory
 # Always supply a lawful affixed gold candidate; an earned white reward may have no values to reroll.
 var rng=RandomNumberGenerator.new();rng.seed=915
 var fixture_id:="modifier:test"
 check(Bag.insert(bag,Rewards.create_drone(rng,g.hyperspace.config,fixture_id,"gold","laser",5,"1"),g.hyperspace.config),"Explicit legal affixed drone fixture")
 var equip=space_policy.space_action(g,3000)
 check(equip.get("kind","")=="space_equip" and equip==SpacePolicy.new().space_action(g,3000),"Equipment decision identical to base")
 check(space_policy.execute(g,equip,3000),"Equipment still commits through domain")
 var drone_id=fixture_id;var cost=g.hyperspace.config.forge_costs.reroll_values
 for key in cost:g.profile.hyperspace.materials[key]=int(cost[key])+7
 var forge=space_policy.forge_choice(g,drone_id,"reroll_values")
 check(not forge.is_empty() and forge==SpacePolicy.new().forge_choice(g,drone_id,"reroll_values"),"Paid forge preview identical to base")
 if forge.is_empty():
  printerr("Paid forge fixture produced no request; stop before accessing kind/request");quit(1);return
 var balances=g.profile.hyperspace.materials.duplicate(true)
 check(space_policy.execute(g,forge,3000),"Paid forge remains an actual transaction")
 for key in cost:check(int(g.profile.hyperspace.materials[key])==int(balances[key])-int(cost[key]),"Actual forge cost debited: "+str(key))
 var forged=JSON.stringify(g.profile.hyperspace)
 check(space_policy.execute(g,forge,3000) and JSON.stringify(g.profile.hyperspace)==forged,"Exact transaction replay acknowledges once without duplicate payment")
 forge.request.command_seq=g.profile.hyperspace.command_seq
 check(not space_policy.execute(g,forge,3000) and JSON.stringify(g.profile.hyperspace)==forged,"New transaction with stale drone revision is rejected without payment")
 # Full checkpoint serialization preserves explicit option and base memory.
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"));wall_started=Time.get_ticks_usec()
 trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
 var payload=Checkpoint.capture(self,manifest);var path=output+"/no-new-manual.bin"
 check(Checkpoint.write(path,payload,manifest)==OK,"Modifier full checkpoint written atomically")
 var restored=Checkpoint.read_valid(path)
 check(restored.error.is_empty() and restored.payload.options.allow_new_manual==false,"Modifier option survives checksum-validated checkpoint")
 var stored=restored.payload.space_policy;options=restored.payload.options;configure_manual_policy();Checkpoint.apply_fields(space_policy,stored,Checkpoint.POLICY)
 check(space_policy.get_script()==NoNewManualPolicy and Checkpoint.fields(space_policy,Checkpoint.POLICY)==stored,"Restored option selects modifier before applying unchanged base memory")
 options={"allow_new_manual":true};configure_manual_policy()
 check(space_policy.get_script()==SpacePolicy,"Explicit true restores base policy implementation")
 trace.close();print("NO_NEW_MANUAL_POLICY ",tested," checks ",failed," failures");quit(1 if failed else 0)
