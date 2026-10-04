extends RefCounted
## Bind only the disposable registry; reference-only fleets never become playable waves.
const Validator=preload("res://scripts/candidate_rewards.gd")
const C=preload("res://scripts/hyperspace_config.gd")
var last_error:=""
var catalog:Dictionary={}
var recipes:Dictionary={}
var sources:Array=[]
func load_contract()->bool:
 for pair in [["catalog","res://data/space_enemy_reward_catalog.json"],["recipes","res://data/space_enemy_reward_recipes.json"],["sources","res://data/space_enemy_reward_sources.json"]]:
  if not FileAccess.file_exists(pair[1]):last_error="space_reward_contract_missing";return false
  var data=JSON.parse_string(FileAccess.get_file_as_string(pair[1]))
  if not data is Dictionary or data.get("schema_version")!=1:last_error="space_reward_contract_invalid";return false
  match pair[0]:
   "catalog":catalog=data.get("references",{})
   "recipes":recipes=data.get("groups",{})
   "sources":sources=data.get("waves",[])
 return not catalog.is_empty() and recipes.size()==40 and not sources.is_empty()
func fail(code:String)->Dictionary:
 last_error=code;return {}
func bind(base:ShipDatabase,registry:Dictionary,level:int)->Dictionary:
 if level<1 or level>base.levels.size():return fail("space_reward_level_invalid")
 var selected:Dictionary=base.levels[level-1]
 for key in ["resRatio","jewelRatio"]:
  if typeof(selected.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(selected.get(key,0))) or selected[key]<0:return fail("space_reward_multiplier_invalid")
 var result:Dictionary=registry.duplicate(true)
 var validation_row:Dictionary=selected.duplicate(true);validation_row.rewardReferenceGroups=[]
 var next_group:=900000000;var next_enemy:=900000000
 for gid in registry.groups:
  var group:Dictionary=result.groups[gid]
  var ref_key:String=str(group.get("rewardBinding",{}).get("rewardReferenceDesignId",""))
  var reference:Dictionary=catalog.get(ref_key,{})
  var recipe:Array=recipes.get(gid,[])
  if reference.is_empty() or recipe.is_empty():return fail("space_reward_reference_missing")
  var count:int=int(reference.reference_member_count)
  var blocks:Array=reference.early_drop_blocks if level<=5 else reference.late_drop_blocks
  if blocks.size()!=count:return fail("space_reward_budget_invalid")
  var ref_id:=-1
  for wave in sources:
   if int(wave.stage)!=level or int(wave.source_group)!=int(reference.source_design_group_id):continue
   var actual_id:String=str(int(wave.group))
   if not base.groups.has(actual_id) or not selected.groups.any(func(point):return int(point.id)==int(wave.group)):continue
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
  group.rewardBinding={"status":"BOUND","rewardReferenceDesignId":ref_key,"referenceGroupId":ref_id,"levelId":level,"resRatio":float(selected.resRatio),"jewelRatio":float(selected.jewelRatio)}
 result.rewardReferenceGroups=validation_row.rewardReferenceGroups
 var validation_levels:Array=base.levels.duplicate();validation_levels[level-1]=validation_row
 for gid in registry.groups:
  var error:String=Validator.binding_error(gid,result.groups,result.enemies,validation_levels,level,float(selected.resRatio),float(selected.jewelRatio))
  if not error.is_empty():return fail("space_reward_binding_invalid: "+error)
 last_error="";return result
