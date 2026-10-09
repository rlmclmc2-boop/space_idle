extends RefCounted
## Saved preferences/ratio targets; the crew scheduler alone executes automatic work.
const I=preload("res://scripts/reactor_integer.gd")
const G=preload("res://scripts/reactor_allocation_growth.gd")
static func fresh() -> Dictionary:return {"upgrade":true,"allocate":false,"ratio":{},"presets":[{},{},{}]}
static func ratio_schema() -> Dictionary:return {"total":"reactor_integer","weights":{"*":"reactor_integer"}}
static func schema() -> Dictionary:return {"upgrade":"b","allocate":"b","ratio":ratio_schema(),"presets":[ratio_schema()]}
static func valid_ratio(g,ratio) -> bool:
 if not ratio is Dictionary:return false
 if ratio.is_empty():return true
 if ratio.keys().size()!=2 or not I.valid(ratio.get("total")) or I.compare(ratio.total,0)<=0 or not ratio.get("weights") is Dictionary:return false
 var sum=0
 for key in ratio.weights:
  if key not in g.reactor_modules() or not I.valid(ratio.weights[key]):return false
  sum=I.add(sum,I.normalize(ratio.weights[key]))
 return I.compare(sum,I.normalize(ratio.total))<=0
static func valid_state(g,state) -> bool:
 return state is Dictionary and state.size()==4 and state.get("upgrade") is bool and state.get("allocate") is bool and valid_ratio(g,state.get("ratio")) and state.get("presets") is Array and state.presets.size()==3 and state.presets.all(func(r):return valid_ratio(g,r))
static func capture(g) -> Dictionary:return {"total":g.reactor_capacity(),"weights":g.reactor_active_allocation().duplicate(true)}
static func balanced(g) -> Dictionary:
 var weights:Dictionary={}
 for key in g.reactor_available_modules():weights[key]=1
 return capture(g) if weights.is_empty() else {"total":weights.size(),"weights":weights}
static func allocation(g,ratio:Dictionary) -> Dictionary:
 var modules:Array=Array(g.reactor_modules());var weights:Array=[];var sum=0
 for key in modules:
  var value=I.normalize(ratio.weights.get(key,0)) if g.reactor_module_unlocked(key) else 0
  weights.append(value);sum=I.add(sum,value)
 weights.append(I.subtract(I.normalize(ratio.total),sum)) # Unallocated/locked shares stay idle.
 var shares:=G.distribute(g.reactor_capacity(),weights,I.normalize(ratio.total))
 var result:Dictionary={}
 for index in modules.size():result[modules[index]]=shares[index]
 return result
static func notify(g,payload:Dictionary={}) -> void:
 g.save_dirty=true;g.event.emit("reactor_changed",payload)
static func set_enabled(g,key:String,enabled:bool) -> bool:
 if key not in ["upgrade","allocate"]:return false
 var state:Dictionary=g.profile.reactorAutomation
 if state[key]==enabled:return false
 if key=="allocate" and enabled and state.ratio.is_empty():state.ratio=capture(g)
 state[key]=enabled
 notify(g,{"auto_upgrade":enabled} if key=="upgrade" else {"auto_allocate":enabled})
 return true
static func apply(g,ratio:Dictionary,remember:bool=true) -> bool:
 if ratio.is_empty() or not valid_ratio(g,ratio) or not g.reactor_unlocked():return false
 if remember:g.profile.reactorAutomation.ratio=ratio.duplicate(true)
 var next:=allocation(g,ratio)
 if next==g.profile.reactorAllocation:
  if remember:notify(g,{"ratio":true})
  return true
 g.profile.reactorAllocation=next;g.invalidate_stat_cache()
 g.player.armour=GrowthNumber.minimum(g.player.armour,g.stat("armour"));g.player.shield=GrowthNumber.minimum(g.player.shield,g.max_shield())
 g.event.emit("equipment_stats",{"category":"weapons"});g.event.emit("equipment_stats",{"category":"defence"})
 notify(g,{"ratio":true});return true
static func maintain(g) -> void:
 if g.profile.reactorAutomation.allocate and not g.profile.reactorAutomation.ratio.is_empty():apply(g,g.profile.reactorAutomation.ratio,false)
static func save_slot(g,index:int,ratio:Dictionary) -> bool:
 if index<0 or index>=3 or ratio.is_empty() or not valid_ratio(g,ratio):return false
 g.profile.reactorAutomation.presets[index]=ratio.duplicate(true);notify(g,{"preset":index});return true
static func apply_slot(g,index:int) -> bool:
 if index<0 or index>=3:return false
 return apply(g,g.profile.reactorAutomation.presets[index])
static func encode_state(state:Dictionary) -> Dictionary:
 var result:=state.duplicate(true)
 for ratio in [result.ratio]+result.presets:
  if ratio.is_empty():continue
  ratio.total=I.encode(I.normalize(ratio.total))
  for key in ratio.weights:ratio.weights[key]=I.encode(I.normalize(ratio.weights[key]))
 return result
static func normalize_state(state:Dictionary) -> Dictionary:
 var result:=state.duplicate(true)
 for ratio in [result.ratio]+result.presets:
  if ratio.is_empty():continue
  ratio.total=I.normalize(ratio.total)
  for key in ratio.weights:ratio.weights[key]=I.normalize(ratio.weights[key])
 return result
