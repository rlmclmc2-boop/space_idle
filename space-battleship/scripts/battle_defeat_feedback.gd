extends RefCounted
## Two transient wave projections; never save player history or consume combat RNG.
const N=preload("res://scripts/growth_number.gd")
var main:Dictionary={}
var manual:Dictionary={}
func wave(g)->Array:
 return [g.stage,g.group_index,g.manual_hyperspace.run_id if g.manual_hyperspace.active else 0]
func record(g,kind:String,info:Dictionary)->void:
 if kind!="encounter" and (kind!="hit" or not info.get("player",false)):return
 var data:Dictionary=manual if g.manual_hyperspace.active else main
 var identity=wave(g)
 if kind=="encounter" or data.get("wave",[])!=identity:
  data.clear();data.wave=identity;data.loss=[0.0,0.0,0.0]
 if kind=="hit" and N.compare(info.get("amount",0),0)>0:
  var damage_type=int(info.get("type",0))
  if damage_type not in [1,2]:damage_type=0
  data.loss[damage_type]=N.add(data.loss[damage_type],info.amount)
func cause(g)->String:
 var data:Dictionary=manual if g.manual_hyperspace.active else main
 if data.get("wave",[])!=wave(g):return "unknown"
 var loss:Array=data.loss
 # Unknown/deferred loss can change which known type dominates; never guess.
 if N.compare(loss[2],N.add(loss[1],loss[0]))>0:return "physical"
 if N.compare(loss[1],N.add(loss[2],loss[0]))>0:return "energy"
 if N.compare(loss[0],0)==0 and N.compare(loss[1],0)>0 and N.compare(loss[1],loss[2])==0:return "mixed"
 return "unknown"
func text(g,info:Dictionary)->String:
 return UIText.t("battle.defeat.manual" if info.manual else "battle.defeat.main",{"cause":UIText.t("battle.defeat.cause."+cause(g)),"remaining":str(info.remaining)})
