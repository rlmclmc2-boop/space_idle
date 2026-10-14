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

static var triggers:Array=[]
static var packets:Array=[]
static var due:Array=[]
static var derived_hits:Array=[]
static var before_rows:Array=[]
static var new_by_root:Dictionary={}
static var new_by_source:Dictionary={}
static var due_expected:Array=[]
static var due_cursor:=0
static var current_game
static func trigger(g,enemy:Dictionary,raw,context:Dictionary,count:int)->void:
 var effect:Dictionary=g.hyperspace_totals().legendary.strange_matter
 triggers.append({"step":step,"root":context.root_id,"source":context.source_id,"killed":float(enemy.hp)<=0,"raw":raw,"multiplier":effect.parameters.damage_multiplier,"probability":effect.constants.spawn_probability,"count":count})
static func packet(row:Dictionary)->void:
 packets.append({"step":step,"row":row.duplicate(true)})
static func due_packet(row:Dictionary)->void:
 due.append({"step":step,"row":row.duplicate(true)})
static func legacy_hit(enemy:Dictionary,raw,context:Dictionary)->void:
 if context.get("trigger","")=="strange_matter":
  assert(context.trigger_depth==1 and not context.get("chain_allowance",false))
  derived_hits.append({"step":step,"uid":enemy.uid,"raw":raw,"root":context.root_id})
static func before_native(g,k,dt:float)->void:
 assert(new_by_source.is_empty(),"all newborn packets matched primary source hit")
 assert(due_cursor==due_expected.size())
 current_game=g;new_by_root.clear();new_by_source.clear();due_expected.clear();due_cursor=0
 before_rows=k.export_handoff().strange_pending.duplicate(true)
 for row in before_rows:
  if float(row.remaining)-dt<=1e-9:
   due_packet(row)
   for enemy in g.enemies:
    if float(enemy.hp)>0:due_expected.append({"root":row.context.root_id,"uid":enemy.uid,"raw":row.damage,"clock":k.metrics().clock})
static func after_native(k)->void:
 var old_roots={}
 for row in before_rows:old_roots[row.context.root_id]=true
 for row in k.export_handoff().strange_pending:
  if not old_roots.has(row.context.root_id):
   assert(row.context.trigger_depth==1 and not row.context.has("chain_allowance"))
   packet(row);new_by_root[row.context.root_id]=int(new_by_root.get(row.context.root_id,0))+1
   assert(not new_by_source.has(row.context.source_id),"fixture has at most one primary packet per source per step")
   new_by_source[row.context.source_id]=row
static func native_row(row:Dictionary)->void:
 if due_cursor<due_expected.size():
  var expected:Dictionary=due_expected[due_cursor]
  assert(row.kind==2 and not row.player and row.uid==expected.uid and is_equal_approx(row.clock,expected.clock),"due AoE must be first ordered native hit feedback")
  derived_hits.append({"step":step,"uid":row.uid,"raw":expected.raw,"root":expected.root,"actual_amount":row.amount,"critical":row.critical})
  assert(not row.critical);due_cursor+=1
  return
 if row.kind!=1:return
 var shot:Dictionary=row.shot;var context:Dictionary=shot.get("combat_context",{})
 if shot.get("hostile",false) or shot.get("key","")!="cannon" or shot.get("chain_hop",false) or shot.get("repeated",false) or context.get("derived",false) or int(context.get("trigger_depth",0))>0:return
 context=context.duplicate()
 var queued:Dictionary=new_by_source.get(context.source_id,{})
 context.root_id=queued.get("context",{}).get("root_id",0) # Display omits attack IDs; failed attempts have unknown root.
 if not queued.is_empty():
  assert(is_equal_approx(queued.damage,shot.damage*float(current_game.hyperspace_totals().legendary.strange_matter.parameters.damage_multiplier)))
  new_by_source.erase(context.source_id)
 trigger(current_game,shot.target,shot.damage,context,0 if queued.is_empty() else 1)
static func report(g)->Dictionary:
 assert(due_cursor==due_expected.size() and new_by_source.is_empty())
 var remaining=g.native_execution.kernel.export_handoff().strange_pending if g.native_execution!=null else g.drone_combat.delayed
 return {"triggers":triggers,"packets":packets,"due":due,"hits":derived_hits,"remaining":remaining.duplicate(true),"native_due_feedback_fully_matched":due_cursor==due_expected.size()}
