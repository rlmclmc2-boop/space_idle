extends SceneTree
const Bag=preload("res://scripts/drone_inventory.gd")
const Config=preload("res://scripts/hyperspace_config.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
const SOURCE_FP="3a78ea1595662c820cfe7265932129dbade62566153f72158eabea1593305ae1"
const SOURCE_BODY_SHA="100c4dc5a6ddb318144cf55a7f4dd2263d565d4bc7313a5a419062d12f08a138"
func _initialize()->void:
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_AUDIT_SOURCE32")))
 var packet:Dictionary=CP.read_one(r.source)
 assert(packet.error.is_empty() and packet.header.code_fingerprint==SOURCE_FP and packet.header.sha256==SOURCE_BODY_SHA)
 var p:Dictionary=packet.payload;var c:Dictionary=Config.load_config();var s:Dictionary=p.save.hyperspace;var bag:Dictionary=s.inventory
 assert(absf(float(p.x1_seconds)-116796.449994348)<0.000001)
 var generatable:bool=true;var inventory_report:Array=[]
 for id in bag.drones:
  var d:Dictionary=bag.drones[id];var legacy_only:Array=[]
  if d.legendary:
   var effect:Dictionary=d.legendary_effect
   for key in effect.parameters:
    var bounds:Array=c.legendary_effects[effect.effect_id].parameters[key]
    if float(effect.parameters[key])<float(bounds[0])-0.0000001 or float(effect.parameters[key])>float(bounds[1])+0.0000001:legacy_only.append(key);generatable=false
  inventory_report.append({"id":id,"quality":d.origin_quality,"level":d.level,"ultimate":d.ultimate,"equipped":id in bag.equipped,"current_drone_valid":Bag.valid_drone(d,c),"affixes":d.affixes,"ultimate_affix":d.ultimate_affix,"legendary_effect":d.legendary_effect,"legacy_only_effect_parameters":legacy_only,"hangings":d.hangings})
 var report={"source_full_sha256":FileAccess.get_sha256(r.source),"source_body_sha256":packet.header.sha256,"source_fingerprint":packet.header.code_fingerprint,"x1_seconds":p.x1_seconds,"round":s.round_id,"reforge_count":bag.reforge_count,"source_resources":p.save.resources,"source_loadout":p.save.loadout,"source_journey":p.save.journey,"source_equipped_ids":bag.equipped,"current_inventory_valid":Bag.valid(bag,c),"all_stored_legendary_parameters_currently_generatable":generatable,"module_progress":s.hanging_modules,"drones":inventory_report,"policy_members":p.space_policy.keys(),"controller_members":p.controller.keys(),"preserved_old_top_level_members":p.keys(),"no_ticks_or_business_transactions":true,"benchmark_limit":"Runtime validity and generation bounds only. Equipment payment provenance/retention history must be tied to original native action trace, not inferred from a legal dictionary."}
 CP.atomic_json(r.output,report);print("SOURCE32_AUDIT valid=",report.current_inventory_valid," current_generation=",generatable);quit(0 if report.current_inventory_valid and generatable else 1)
