extends SceneTree
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const Game=preload("res://scripts/game.gd")
var checks:=0
var failures:=0
var raw:Dictionary={}
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func fresh()->Dictionary:
 var g=Game.new(ShipDatabase.new());var save:Dictionary=raw.duplicate(true);save.chronoSavedAt=Time.get_unix_time_from_system();g.load_progress_data(save)
 return {"g":g,"p":Policy.new()}
func funded_fixture()->Dictionary:
 var f:Dictionary=fresh();var g=f.g
 # Explicit prospective UNIT fixture only. Never exported as campaign evidence.
 g.profile.hyperspace.history.alpha["60"]=60.0
 var c:Dictionary=g.hyperspace.config
 var price:int=roundi((1.0+float(60-int(c.material_reward_start_level))/float(c.modernization_level_step)))*int(c.modernization_cost_base)
 g.profile.hyperspace.materials.degenerate_matter=price;g.profile.hyperspace.ultimate_cores=2
 return f
func _initialize()->void:
 var path:String=OS.get_environment("QA_ULTIMATE_SOURCE");var original_sha:String=FileAccess.get_sha256(path)
 var loaded:Dictionary=CP.read_one(path);assert(loaded.error.is_empty());raw=loaded.payload.save
 var f:Dictionary=fresh();var g=f.g;var p=f.p;var id:String="space:1:2"
 var before:String=CP.digest(var_to_bytes(g.profile));var offer:Dictionary=p.ultimate_upgrade_offer(g,id)
 check(int(offer.target_level)==60 and int(offer.recorded_target)==20 and offer.get("record_prerequisite",false),"Real beta60 is not an alpha60 record; actual alpha20 requires earned alpha60")
 check(p.ultimate_chain_action(g,100).is_empty() and g.profile.hyperspace.inventory.drones[id].ultimate,"Real insufficient-record/material source remains ultimate while funding")
 check(CP.digest(var_to_bytes(g.profile))==before,"Planning and native clone quotes do not alter actual source profile")
 check(not p.forge_preserves_ultimate_reservation(g,{"degenerate_matter":1}) and not p.forge_preserves_ultimate_reservation(g,{"ultimate_cores":2}),"Pending record plan reserves actual materials and two cores")
 var resumed=Policy.new();CP.apply_fields(resumed,CP.fields(p,CP.POLICY),CP.POLICY)
 check(resumed.ultimate_upgrade_chain.phase=="funding" and int(resumed.ultimate_upgrade_chain.target_level)==60,"QA checkpoint preserves actual funding prerequisite and reservation")
 f=funded_fixture();g=f.g;p=f.p
 g.profile.hyperspace.ultimate_cores=1
 check(not p.ultimate_upgrade_offer(g,id).ready and p.ultimate_chain_action(g,200).is_empty(),"One core cannot start a chain needing restore and reultimate")
 g.profile.hyperspace.ultimate_cores=2
 var materials:int=int(g.profile.hyperspace.materials.degenerate_matter);var extra:Dictionary=g.profile.hyperspace.inventory.drones[id].ultimate_affix.duplicate(true)
 var ordinary_resources:String=CP.digest(var_to_bytes(g.profile.resources))
 var choice:Dictionary=p.ultimate_chain_action(g,201)
 check(choice.get("ultimate_chain",false) and choice.request.operation=="restore_ultimate","Funded actual eligible target selects restore as finite first action")
 check(p.execute(g,choice,201.3) and int(g.profile.hyperspace.ultimate_cores)==1 and not g.profile.hyperspace.inventory.drones[id].ultimate,"Native restore pays one actual fixture core")
 check(g.profile.hyperspace.inventory.drones[id].ultimate_affix==extra and p.ultimate_upgrade_chain.phase=="modernize","Restore preserves original extra affix and persists next phase")
 resumed=Policy.new();CP.apply_fields(resumed,CP.fields(p,CP.POLICY),CP.POLICY);p=resumed
 choice=p.space_action(g,201.6)
 check(choice.get("ultimate_chain",false) and choice.request.operation=="modernize","Restored unit upgrades before score-based unequip/salvage/other forge")
 check(p.execute(g,choice,201.9) and int(g.profile.hyperspace.inventory.drones[id].level)==60 and int(g.profile.hyperspace.materials.degenerate_matter)==0,"Native modernization pays the exact real-table prospective price")
 check(int(p.ultimate_upgrade_chain.receipts[1].cost.degenerate_matter)==materials and p.ultimate_upgrade_chain.phase=="reultimate","Paid receipt and next phase match actual debit")
 resumed=Policy.new();CP.apply_fields(resumed,CP.fields(p,CP.POLICY),CP.POLICY);p=resumed
 choice=p.ultimate_chain_action(g,202.2)
 check(choice.request.operation=="ultimate" and p.execute(g,choice,202.5),"Finite final native reultimate executes after checkpoint restoration")
 check(g.profile.hyperspace.inventory.drones[id].ultimate and int(g.profile.hyperspace.ultimate_cores)==0 and g.profile.hyperspace.inventory.drones[id].ultimate_affix==extra,"Final state preserves extra affix and consumes exactly second core")
 check(p.ultimate_upgrade_chain.phase=="complete" and p.ultimate_upgrade_chain.receipts.size()==3 and CP.digest(var_to_bytes(g.profile.resources))==ordinary_resources,"Three receipts close the chain without ordinary-resource changes")
 check(p.ultimate_chain_action(g,203).is_empty(),"Completed target does not restart restore payments")
 f=funded_fixture();g=f.g;p=f.p;choice=p.ultimate_chain_action(g,300)
 g.profile.hyperspace.materials.degenerate_matter=0
 check(not p.execute(g,choice,300.3) and g.profile.hyperspace.inventory.drones[id].ultimate and int(g.profile.hyperspace.ultimate_cores)==2,"Material loss during input delay blocks first restore without debit")
 f=funded_fixture();g=f.g;p=f.p;choice=p.ultimate_chain_action(g,400);check(p.execute(g,choice,400.3),"Recovery fixture enters through paid legal restore")
 choice=p.ultimate_chain_action(g,400.6);g.profile.hyperspace.materials.degenerate_matter=0
 check(not p.execute(g,choice,400.9) and p.ultimate_upgrade_chain.phase=="reultimate","Changed material prerequisite schedules protected reultimate rather than waiting ordinary")
 choice=p.ultimate_chain_action(g,401.2)
 check(choice.request.operation=="ultimate" and p.execute(g,choice,401.5) and g.profile.hyperspace.inventory.drones[id].ultimate,"Reserved recovery core lawfully restores ultimate state")
 check(p.ultimate_upgrade_chain.phase=="recovered" and int(g.profile.hyperspace.inventory.drones[id].level)==10,"Recovery is labelled partial, never a completed modernization")
 f=funded_fixture();g=f.g;p=f.p
 var alternate:Dictionary=g.hyperspace.config.duplicate(true);alternate.forge_costs.restore_ultimate.ultimate_cores=2;alternate.forge_costs.ultimate.ultimate_cores=3
 check(g.hyperspace.configure(alternate),"Distinct authored-valid lifecycle core costs accepted in unit fixture")
 g.profile.hyperspace.ultimate_cores=4
 check(int(p.ultimate_upgrade_offer(g,id).required_cores)==5 and not p.ultimate_upgrade_offer(g,id).ready,"Complete reservation derives from real cost table, not hardcoded two")
 g.profile.hyperspace.ultimate_cores=5
 check(p.ultimate_upgrade_offer(g,id).ready,"Exact summed alternate core balance allows planning")
 check(FileAccess.get_sha256(path)==original_sha,"Real source checkpoint bytes remain unchanged by all unit fixtures")
 print("ULTIMATE_CHAIN checks=",checks," failures=",failures," scope=Prospective unit fixtures are not real campaign progress");quit(1 if failures else 0)
