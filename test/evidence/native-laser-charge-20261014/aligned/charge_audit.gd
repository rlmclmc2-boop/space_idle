extends RefCounted
static var step:=0
static var dropped:Array=[]
static var events:Dictionary={}
static var groups:Dictionary={}
static var impacts:Dictionary={}
static var steps:Array=[]
static func observe(kind:String,info:Dictionary)->void:
 events[kind]=int(events.get(kind,0))+1
 if kind not in ["fire","projectile_impact"]:return
 var shot:Dictionary=info.get("shot",{})
 var context:Dictionary=shot.get("combat_context",{})
 var source:String=str(context.get("source_id","unknown"))
 var chain:bool=shot.get("chain_hop",false)
 var derived:bool=bool(shot.get("repeated",false)) or bool(context.get("derived",false)) or int(context.get("trigger_depth",0))>0
 if kind=="projectile_impact":
  var key=source+":"+("chain" if chain else "derived" if derived else "primary")
  impacts[key]=int(impacts.get(key,0))+1
  return
 var key=str(step)+":"+source+":"+str(shot.get("main_attack_id",0))+":"+str(shot.get("attack_instance_id",0))
 if not groups.has(key):groups[key]={"step":step,"source":source,"id":shot.get("main_attack_id",0),"instance":shot.get("attack_instance_id",0),"derived":derived,"count":0,"damage":shot.get("damage"),"critical":shot.get("critical",false),"fixed_hull":shot.has("fixed_screen_step"),"targets":[]}
 groups[key].count+=1;groups[key].targets.append(shot.get("target",{}).get("uid",-1))
