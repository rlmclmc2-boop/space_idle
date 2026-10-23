extends RefCounted
## Bind only the disposable registry; reference-only fleets never become playable waves.
const Validator=preload("res://scripts/candidate_rewards.gd")
const C=preload("res://scripts/hyperspace_config.gd")
const EARLY_FROZEN_SHA256="98cd28eff0860449fabaee6c5b8b9e705ec076da49181726e593b1cac0e2b64a"
var last_error:=""
var catalog:Dictionary={}
var recipes:Dictionary={}
var sources:Array=[]
var early_frozen:Dictionary={}
func load_contract()->bool:
 for pair in [["catalog","res://data/space_enemy_reward_catalog.json"],["recipes","res://data/space_enemy_reward_recipes.json"],["sources","res://data/space_enemy_reward_sources.json"],["early_frozen","res://data/space_enemy_reward_early_frozen.json"]]:
  if not preload("res://scripts/configuration_snapshot.gd").active().has(pair[1]):last_error="space_reward_contract_missing";return false
  if pair[0]=="early_frozen" and preload("res://scripts/configuration_snapshot.gd").sha256(preload("res://scripts/configuration_snapshot.gd").active().read_bytes(pair[1]))!=EARLY_FROZEN_SHA256:last_error="space_reward_early_source_digest_invalid";return false
  var data=JSON.parse_string(preload("res://scripts/configuration_snapshot.gd").text(pair[1]))
  if not data is Dictionary or data.get("schema_version")!=1:last_error="space_reward_contract_invalid";return false
  match pair[0]:
   "catalog":catalog=data.get("references",{})
   "recipes":recipes=data.get("groups",{})
   "sources":sources=data.get("waves",[])
   "early_frozen":early_frozen=data
 return not catalog.is_empty() and recipes.size()==40 and not sources.is_empty() and not early_frozen.is_empty()
func fail(code:String)->Dictionary:
 last_error=code;return {}
func early_sources_valid(base:ShipDatabase)->bool:
 var waves:Array=early_frozen.get("waves",[])
 if waves.size()!=25 or sources.size()<waves.size():return false
 for index in waves.size():
  if sources[index]!=waves[index]:return false
  var wave:Dictionary=waves[index]
  var stage:int=int(wave.stage);var node:int=int(wave.node)
  if stage<1 or stage>base.levels.size() or node<1:return false
  var row:Dictionary=base.levels[stage-1]
  var mounted:Array=row.groups;var references:Array=row.get("rewardReferenceGroups",[])
  if not ((node<=mounted.size() and int(mounted[node-1].id)==int(wave.group)) or (node<=references.size() and int(references[node-1].id)==int(wave.group))):return false
 for gid in early_frozen.get("groups",{}):
  if base.groups.get(gid,{})!=early_frozen.groups[gid]:return false
 for eid in early_frozen.get("enemies",{}):
  if base.enemies.get(eid,{})!=early_frozen.enemies[eid]:return false
 return true
static func latest_cleared_level(g)->int:
 var latest:=1
 for value in g.profile.cleared:
  if C.integer(value) and int(value)>=1 and int(value)<=g.db.levels.size():latest=maxi(latest,int(value))
 return latest
func bind(base:ShipDatabase,registry:Dictionary,level:int,resource_level:int=-1)->Dictionary:
 if resource_level<0:resource_level=level
 if level<1 or level>base.levels.size() or resource_level<1 or resource_level>base.levels.size():return fail("space_reward_level_invalid")
 if not early_sources_valid(base):return fail("space_reward_early_source_invalid")
 var selected:Dictionary=base.levels[level-1]
 var resource_reference:Dictionary=base.levels[resource_level-1]
 for pair in [[resource_reference,"resRatio"],[resource_reference,"jewelRatio"]]:
  var row:Dictionary=pair[0];var key:String=pair[1]
  if typeof(row.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row.get(key,0))) or row[key]<0:return fail("space_reward_multiplier_invalid")
 var result:Dictionary=registry.duplicate(true)
 result.resource_reference_level=resource_level
 var validation_row:Dictionary=selected.duplicate(true);validation_row.resRatio=float(resource_reference.resRatio);validation_row.jewelRatio=float(resource_reference.jewelRatio);validation_row.rewardReferenceGroups=[]
 var next_group:=900000000;var next_enemy:=900000000
 for gid in registry.groups:
  var group:Dictionary=result.groups[gid]
  var ref_key:String=str(group.get("rewardBinding",{}).get("rewardReferenceDesignId",""))
  var reference:Dictionary=catalog.get(ref_key,{})
  var recipe:Array=recipes.get(gid,[])
  if reference.is_empty() or recipe.is_empty():return fail("space_reward_reference_missing")
  var count:int=int(reference.reference_member_count)
  var blocks:Array=reference.early_drop_blocks if resource_level<=5 else reference.late_drop_blocks
  if blocks.size()!=count:return fail("space_reward_budget_invalid")
  var ref_id:=-1
  for wave in sources:
   if int(wave.stage)!=resource_level or int(wave.source_group)!=int(reference.source_design_group_id):continue
   var actual_id:String=str(int(wave.group))
   var node:int=int(wave.node)
   var mounted:Array=resource_reference.groups;var references:Array=resource_reference.get("rewardReferenceGroups",[])
   if node<1 or not ((node<=mounted.size() and int(mounted[node-1].id)==int(wave.group)) or (node<=references.size() and int(references[node-1].id)==int(wave.group))) or not base.groups.has(actual_id):return fail("space_reward_source_node_invalid")
   var actual:Dictionary=base.groups[actual_id]
   var actual_blocks:Array=[]
   for id in actual.slots:
    if id!=null:
     if not base.enemies.has(str(int(id))):return fail("space_reward_mainline_reference_invalid")
     actual_blocks.append(base.enemies[str(int(id))].drops)
   if actual_blocks.size()!=count:return fail("space_reward_mainline_budget_invalid")
   blocks=actual_blocks;ref_id=int(wave.group)
   result.groups[actual_id]=actual.duplicate(true)
   for id in actual.slots:
    if id!=null:result.enemies[str(int(id))]=base.enemies[str(int(id))].duplicate(true)
   break
  if ref_id<0:
   while result.groups.has(str(next_group)) or base.groups.has(str(next_group)):next_group+=1
   ref_id=next_group;next_group+=1
   var slots:Array=[]
   for block in blocks:
    while result.enemies.has(str(next_enemy)) or base.enemies.has(str(next_enemy)):next_enemy+=1
    slots.append(next_enemy)
    result.enemies[str(next_enemy)]={"drops":block.duplicate(true)};next_enemy+=1
   result.groups[str(ref_id)]={"slots":slots,"reward_reference_only":true}
  validation_row.rewardReferenceGroups.append({"id":ref_id})
  var seen:Array=[];var assigned_slots:Array=[];var total_rolls:=0
  for member in recipe:
   if not C.integer(member.get("slot")) or not C.integer(member.get("enemy_id")) or not C.integer(member.get("jewelDropRolls")):return fail("space_reward_recipe_invalid")
   var slot:int=int(member.slot);var id:String=str(int(member.enemy_id))
   if slot<0 or slot>=group.slots.size() or group.slots[slot]!=member.enemy_id or assigned_slots.has(slot) or not result.enemies.has(id):return fail("space_reward_recipe_invalid")
   assigned_slots.append(slot)
   var drops:Array=[]
   for ordinal in member.reference_member_ordinals_for_resource_blocks:
    if not C.integer(ordinal) or ordinal<0 or ordinal>=blocks.size() or seen.has(ordinal):return fail("space_reward_recipe_invalid")
    seen.append(ordinal);drops.append_array(blocks[ordinal].duplicate(true))
   if int(member.jewelDropRolls)!=member.reference_member_ordinals_for_resource_blocks.size():return fail("space_reward_roll_budget_invalid")
   var enemy:Dictionary=result.enemies[id]
   enemy.drops=drops;enemy.rewardDrops=drops.duplicate(true);enemy.res="";enemy.jewelDropRolls=int(member.jewelDropRolls)
   total_rolls+=int(member.jewelDropRolls)
  if seen.size()!=count or total_rolls!=count or assigned_slots.size()!=group.slots.filter(func(id):return id!=null).size():return fail("space_reward_roll_budget_invalid")
  group.rewardBinding={"status":"BOUND","rewardReferenceDesignId":ref_key,"referenceGroupId":ref_id,"levelId":level,"resourceReferenceLevel":resource_level,"resRatio":float(resource_reference.resRatio),"jewelRatio":float(resource_reference.jewelRatio)}
 result.rewardReferenceGroups=validation_row.rewardReferenceGroups
 var validation_levels:Array=base.levels.duplicate();validation_levels[level-1]=validation_row
 for gid in registry.groups:
  var error:String=Validator.binding_error(gid,result.groups,result.enemies,validation_levels,level,float(resource_reference.resRatio),float(resource_reference.jewelRatio))
  if not error.is_empty():return fail("space_reward_binding_invalid: "+error)
 last_error="";return result
