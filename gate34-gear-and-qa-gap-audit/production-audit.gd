extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const Game=preload("res://scripts/game.gd")
const Forge=preload("res://scripts/drone_forge.gd")
func _initialize()->void:
 var rows:Array=[]
 for path in ["/workspace/sol-validation/gate34-source-audit/gear-audit/checkpoint.bin","/workspace/sol-validation/unified-e528-post60-qa/diagnostics/sol-e528-hold60-extension300x1/checkpoint.bin"]:
  var read:Dictionary=CP.read_one(path);assert(read.error.is_empty());var p:Dictionary=read.payload
  var g=Game.new(ShipDatabase.new());var save:Dictionary=p.save.duplicate(true);save.chronoSavedAt=Time.get_unix_time_from_system()
  g.load_progress_data(save)
  assert(g.hyperspace.last_error.is_empty())
  assert(CP.digest(var_to_bytes(g.profile.resources))==CP.digest(var_to_bytes(p.save.resources)))
  assert(CP.digest(var_to_bytes(g.profile.hyperspace.inventory))==CP.digest(var_to_bytes(p.save.hyperspace.inventory)))
  var before:String=CP.digest(var_to_bytes(g.profile));var rng:int=g.rng.state
  var quotes:Array=[]
  for id in g.profile.hyperspace.inventory.equipped:
   var d:Dictionary=g.profile.hyperspace.inventory.drones[id];var entry:Dictionary={"id":id,"level":d.level,"ultimate":d.ultimate}
   if d.ultimate:
    var request:Dictionary={"drone_id":id,"operation":"modernize","expected_revision":d.forge_revision,"args":{}}
    entry.direct_modernize=g.hyperspace.preview_forge(g,request)
    var private:Dictionary=g.profile.hyperspace.duplicate(true);request.operation="restore_ultimate"
    entry.restore_quote=Forge.plan(private,g.hyperspace.config,request,g)
    if str(entry.restore_quote.error).is_empty():
     request.operation="modernize";request.expected_revision=private.inventory.drones[id].forge_revision
     entry.after_restore_modernize_quote=Forge.plan(private,g.hyperspace.config,request,g)
     entry.quoted_target_level=private.inventory.drones[id].level
     entry.quote_target_is_not_paid_progress=true
    entry.reultimate_cost=g.hyperspace.config.forge_costs.ultimate.duplicate(true)
    entry.current_materials=g.profile.hyperspace.materials.duplicate(true);entry.current_cores=g.profile.hyperspace.ultimate_cores
   else:entry.direct_modernize=g.hyperspace.preview_forge(g,{"drone_id":id,"operation":"modernize","expected_revision":d.forge_revision,"args":{}})
   quotes.append(entry)
  var equipment:Array=[]
  for category in ["weapons","defence"]:
   for index in g.active_slot_count(category):
    var d:Dictionary=g.slot_entry(category,index)
    equipment.append({"category":category,"index":index,"key":d.key,"actual_level":d.level,"effective_level":g.effective_equipment_level(int(d.level)),"current_stat":g.jewel_equipment_stat(d),"next10_cost":g.slot_upgrade_cost(category,index,10),"can_buy_next10":g.can_upgrade_slot(category,index,10),"max_affordable_now":g.max_upgrade_amount_slot(category,index)})
  var totals:Dictionary=g.hyperspace_totals().duplicate(true)
  assert(before==CP.digest(var_to_bytes(g.profile)) and rng==g.rng.state)
  rows.append({"path":path,"sha256":FileAccess.get_sha256(path),"x1_seconds":p.x1_seconds,"readonly_profile_and_rng_preserved":true,"equipment":equipment,"reactor_max_affordable_now":g.reactor_max_upgrades(),"effective_hyperspace_totals":totals,"ultimate_chain_quotes":quotes,"materials":g.profile.hyperspace.materials,"ultimate_cores":g.profile.hyperspace.ultimate_cores,"history":g.profile.hyperspace.history,"dmgReduce":g.db.config.dmgReduce})
 FileAccess.open("/workspace/sol-validation/gate34-source-audit/gear-audit/production-quotes.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("READONLY_PRODUCTION_GEAR_QUOTES_OK");quit()
