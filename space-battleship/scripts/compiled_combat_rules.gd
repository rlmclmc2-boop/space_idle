extends RefCounted
## Prototype combat configuration compiler. Runtime counters/health remain in Game.
## Compilation occurs at explicit configuration changes, never identity-polling reads.
var compiling:=false
var builds:int=0
var rows:Dictionary={}
var parameters:Dictionary={}
var recipes:Dictionary={}
var masks:Dictionary={}
var a_counts:Dictionary={}
var effect_count:int=0
var instance_payload_builds:int=0
var target_priority_prepares:int=0
func compile(g)->void:
 if compiling:return
 compiling=true
 g.enhancement_plan.sync(g)
 parameters={}
 for key in g.db.data.enhance_config:parameters[key]=float(g.db.data.enhance_config[key].value)
 recipes=g.enhancement_plan.recipes
 effect_count=g.enhancement_plan.count
 masks={};a_counts={}
 for category in ["weapons","defence"]:
  var flags:Dictionary={};var counts:Dictionary={}
  for effect in g.default_enhancement_order()[category]:
   var bits:int=0;var count:int=0
   for node in [1,2,3]:
    if g.enhancement_plan.active(g,{"key":"laser" if category=="weapons" else "armour"},effect,node,"A"):
     bits|=1<<((node-1)*2);count+=1
    if g.enhancement_plan.active(g,{"key":"laser" if category=="weapons" else "armour"},effect,node,"B"):bits|=1<<((node-1)*2+1)
   flags[effect]=bits;counts[effect]=count
  flags.make_read_only();counts.make_read_only();masks[category]=flags;a_counts[category]=counts
 rows={}
 for entry in g.combat_weapon_entries()+g.defense_entries():
  if str(entry.get("key",""))=="":continue
  add_row(g,str(entry.key),int(entry.level));add_row(g,str(entry.key),g.effective_equipment_level(int(entry.level)))
 add_row(g,"shield",1)
 rows.make_read_only();parameters.make_read_only();masks.make_read_only();a_counts.make_read_only()
 builds+=1;compiling=false
func add_row(g,key:String,level:int)->void:
 var identity=key+":"+str(level)
 if rows.has(identity):return
 var source:Dictionary=g.db.equip(key,level)
 var row:Dictionary={}
 for field in source:
  if str(field).begins_with("cost") or str(field).begins_with("res_") or field in ["des","name"]:continue
  row[field]=source[field]
 row.make_read_only();rows[identity]=row
func row(key:String,level:int)->Dictionary:
 return rows.get(key+":"+str(level),{})
func category(entry:Dictionary)->String:
 return "weapons" if str(entry.get("key","")) in ["laser","missile","cannon","longLaser"] else "defence" if str(entry.get("key","")) in ["shield","armour"] else ""
func active(entry:Dictionary,effect:String,node:int,choice:String)->bool:
 var values:Dictionary=masks.get(category(entry),{})
 return (int(values.get(effect,0))&(1<<((node-1)*2+(1 if choice=="B" else 0))))!=0
func count_a(entry:Dictionary,effect:String)->int:
 return int(a_counts.get(category(entry),{}).get(effect,0))
func effects(entry:Dictionary)->Array:
 return recipes.get(category(entry),[])
func effect_index(entry:Dictionary,effect:String)->int:
 for index in effects(entry).size():
  if str(effects(entry)[index].kind)==effect:return index
 return -1
func bind_instance(snapshot:Dictionary,instance:Dictionary)->void:
 if instance.has("effects"):return
 var bound:Array=[];var continued:Array=[]
 for source in snapshot.effects:
  # Once per attack instance, not once per carrier/period. Only chain state is mutable.
  var effect:Dictionary=source.duplicate()
  var follow:Dictionary=source.duplicate()
  follow.erase("chain_state");follow.chain=false;follow.chain_used=true;follow.make_read_only();continued.append(follow)
  if effect.get("chain",false):effect.chain_state=instance.chain
  effect.make_read_only();bound.append(effect)
 bound.make_read_only();continued.make_read_only()
 instance.effects=bound;instance.chain.continued_effects=continued
 instance_payload_builds+=1
func metrics()->Dictionary:
 return {"configuration_builds":builds,"instance_payload_builds":instance_payload_builds,"target_priority_prepares":target_priority_prepares,"compiled_rows":rows.size()}
