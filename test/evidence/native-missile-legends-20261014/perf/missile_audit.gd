extends RefCounted
static var enabled:=false
static var game
static var step:=0
static var observer_us:=0
static var counts:Dictionary={}
static var roots:Array=[]
static var hits:Array=[]
static var first_values:Array=[]
static var cancelled_repeats:Array=[]
static var cancelled_ejections:Array=[]
static var fires:Array=[]
static var fired_serials:Dictionary={}
static var errors:Array=[]
static var contexts:Dictionary={}
static var flights:Dictionary={}
static var root_ids:Dictionary={}
static var hit_pairs:Dictionary={}
static var factors:Dictionary={}
static var layers:Dictionary={}
static var after_layers:Dictionary={}
static var after_contexts:Dictionary={}
static var impact:Dictionary={}
static var blast_hits:=0
static var root_count:=0
static var native_counter=-1
static var native_after_counter=-1
static var guidance:=false
static var multiplier:=1.0
static var limit_enabled:=false
static var layer_limit:=0
static var period:=0
static var wild_enabled:=false
static var legacy_context_serial:=0
static func count(key:String,n:int=1)->void:counts[key]=int(counts.get(key,0))+n
static func problem(message:String)->void:
 if errors.size()<100:errors.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"message":message})
static func tick()->void:
 if enabled:step+=1
static func legacy_call(name:String)->void:
 if enabled:count("legacy_"+name)
static func id_for(c:Dictionary)->String:
 if not c.has("_qa_id"):
  legacy_context_serial+=1;c._qa_id=legacy_context_serial
 return "L"+str(c._qa_id)
static func settings(g)->void:
 var legends:Dictionary=g.hyperspace_totals().legendary
 guidance=legends.has("precise_guidance");wild_enabled=legends.has("wild_missile")
 if guidance:
  var c:Dictionary=legends.precise_guidance.constants
  multiplier=float(c.stack_multiplier);limit_enabled=c.stack_limit_enabled;layer_limit=int(c.stack_limit)
 if wild_enabled:period=int(legends.wild_missile.constants.attack_period)
static func legacy_root(g,snapshot:Dictionary)->void:
 if not enabled:return
 var t=Time.get_ticks_usec();settings(g)
 var c:Dictionary=snapshot.combat_context;var wild=bool(c.get("wild_missile",false));var ordinal=int(g.drone_combat.missile_attacks)-1
 roots.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"root":snapshot.id,"source":c.source_id,"ordinal":ordinal,"wild":wild,"salvo":snapshot.weapon.para1,"damage":snapshot.damage,"critical":snapshot.critical})
 count("roots");root_count+=1
 if wild:count("wild_substitutions")
 if wild!=(wild_enabled and ordinal%(period+1)==period):problem("legacy wild period")
 if wild and int(snapshot.weapon.para1)!=1:problem("legacy wild not single")
 observer_us+=Time.get_ticks_usec()-t
static func legacy_guidance(enemy:Dictionary,c:Dictionary,was_cached:bool,old_layer:int)->void:
 if not enabled:return
 var t=Time.get_ticks_usec();var id=id_for(c);var uid=str(enemy.uid);var factor=float(c.guidance_factors[uid])
 count("cache_hits" if was_cached else "cache_firsts")
 if not was_cached:first_values.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"uid":enemy.uid,"context":id,"layer":old_layer,"factor":factor,"published":true,"derived":int(c.trigger_depth)>0})
 var delta=int(enemy.get("guidance_layers",0))-old_layer
 if delta>0:count("effective_layer_growth",delta)
 if int(c.trigger_depth)>0 and delta!=0:problem("legacy derived layer growth")
 observer_us+=Time.get_ticks_usec()-t
static func legacy_hit(enemy:Dictionary,raw,c:Dictionary)->void:
 if not enabled or c.get("weapon","")!="missile":return
 var t=Time.get_ticks_usec();var derived=int(c.get("trigger_depth",0))>0
 hits.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"uid":enemy.uid,"context":id_for(c),"root":c.root_id,"source":c.source_id,"raw":raw,"derived":derived,"wild":c.get("wild_missile",false),"blast":c.get("wild_used",false)})
 count("missile_hits")
 if derived:count("derived_hits")
 if c.get("wild_used",false):count("wild_blast_hits");count("recursion_blocked_entries")
 observer_us+=Time.get_ticks_usec()-t
static func legacy_blast()->void:
 if enabled:count("wild_blasts")
static func cancelled_packet(g,packet:Dictionary)->void:
 if enabled:cancelled_ejections.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"mount":packet.mount,"source":packet.entry.get("drone_id","module:"+str(packet.mount)),"root":packet.attack.main_attack_id,"instance":packet.attack.attack_instance_id,"old_level":packet.entry.level,"new_level":g.combat_entry(int(packet.mount)).get("level"),"ordinal":packet.ordinal,"damage":packet.attack.damage,"derived":int(packet.attack.get("combat_context",{}).get("trigger_depth",0))>0})
static func cancelled(g,pending:Dictionary,entry:Dictionary)->void:
 if enabled:cancelled_repeats.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"index":pending.index,"source":pending.entry.get("drone_id","module:"+str(pending.index)),"old_level":pending.entry.level,"new_level":entry.get("level"),"damage":pending.snapshot.damage,"root":pending.snapshot.id,"salvo":pending.snapshot.weapon.para1})
static func read_state(state:Dictionary,collect_roots:bool)->void:
 var new_roots:Dictionary={}
 for row in state.get("flights",[])+state.get("ejections",[]):
  var view:Dictionary=row.get("view",{})
  if view.get("hostile",false):continue
  var snapshot:Dictionary=row.snapshot
  var root_c:Dictionary=snapshot.get("native_context",{})
  var own:Dictionary=row.get("native_context",{})
  var value:Dictionary=own.get("value",{})
  if value.is_empty():value={"root_id":snapshot.id,"source_id":view.get("combat_context",{}).get("source_id","unknown"),"trigger_depth":1 if row.get("instance_derived",false) or row.get("chain",false) else 0,"guidance_factors":{}}
  var cid=str(own.get("id","old:"+str(snapshot.id)+":"+str(row.instance.id)))
  for record in [root_c,own]:
   if not record.is_empty():after_contexts[str(record.id)]=record.value.duplicate(true)
  if not view.is_empty():flights[int(view.serial)]={"root":snapshot.id,"instance":row.instance.id,"context":cid,"value":value.duplicate(true),"raw":row.damage,"chain":row.get("chain",false),"source":value.get("source_id","unknown"),"type":view.type}
  if collect_roots and not root_ids.has(int(snapshot.id)):
   new_roots[int(snapshot.id)]={"clock":game.production_time() if game!=null else 0.0,"step":step,"root":snapshot.id,"source":root_c.get("value",{}).get("source_id",value.get("source_id","unknown")),"wild":root_c.get("value",{}).get("wild_missile",false),"salvo":snapshot.weapon.get("para1",0),"damage":snapshot.damage,"critical":snapshot.critical}
 var ids=new_roots.keys();ids.sort()
 for id in ids:
  var row:Dictionary=new_roots[id];row.ordinal=root_count;root_ids[id]=true;root_count+=1;roots.append(row);count("roots")
  if row.wild:count("wild_substitutions")
  if row.wild!=(wild_enabled and int(row.ordinal)%(period+1)==period):problem("native wild period")
  if row.wild and int(row.salvo)!=1:problem("native wild not single")
static func before_native(g,k)->void:
 if not enabled:return
 var t=Time.get_ticks_usec();game=g;settings(g);count("native_steps")
 var state:Dictionary=k.export_handoff();native_counter=state.get("missile_attacks",-1)
 flights.clear();after_contexts.clear();read_state(state,false)
 contexts=after_contexts.duplicate(true);layers.clear()
 for enemy in state.enemies:layers[str(enemy.uid)]=int(enemy.get("guidance_layers",0))
 impact.clear();blast_hits=0
 observer_us+=Time.get_ticks_usec()-t
static func after_native(k)->void:
 if not enabled:return
 var t=Time.get_ticks_usec();var state:Dictionary=k.export_handoff();native_after_counter=state.get("missile_attacks",-1)
 read_state(state,true);after_layers.clear()
 for enemy in state.enemies:after_layers[str(enemy.uid)]=int(enemy.get("guidance_layers",0))
 if native_after_counter>=0 and root_count!=native_after_counter:problem("native missile root/counter mismatch")
 observer_us+=Time.get_ticks_usec()-t
static func finish_impact()->void:
 if impact.is_empty():return
 if impact.value.get("wild_missile",false):
  if blast_hits!=game.enemies.size():problem("wild AoE cardinality or recursion: "+str(blast_hits))
  count("recursion_blocked_entries",blast_hits)
 impact.clear();blast_hits=0
static func native_row(row:Dictionary)->void:
 if not enabled:return
 var t=Time.get_ticks_usec()
 if int(row.kind)==1:
  finish_impact()
  var shot:Dictionary=row.shot
  if not shot.get("hostile",false):
   impact=flights.get(int(shot.serial),{}).duplicate(true)
   if impact.is_empty():problem("missing native impact context "+str(shot.serial))
   else:impact.hit_index=0
 elif int(row.kind)==2 and not row.player and not impact.is_empty():
  var uid=str(row.uid);var c:Dictionary=impact.value;var cid=str(impact.context);var derived=int(c.get("trigger_depth",0))>0
  var is_blast=int(impact.hit_index)>0;var wild=bool(c.get("wild_missile",false));var raw=float(impact.raw)*(float(c.get("blast_fraction",0.0)) if is_blast else 1.0)
  if is_blast:
   blast_hits+=1;count("wild_blast_hits")
   if not wild:problem("extra hit without wild context")
  elif wild:count("wild_blasts")
  count("missile_hits")
  if derived:count("derived_hits")
  var pair=cid+":"+uid
  if guidance:
   var cached=hit_pairs.has(pair) or contexts.get(cid,{}).get("guidance_factors",{}).has(uid)
   var before=int(layers.get(uid,0));var actual=after_contexts.get(cid,{}).get("guidance_factors",{}).get(uid,null)
   var expected=float(factors.get(pair,pow(multiplier,before)))
   if cached:count("cache_hits")
   else:
    count("cache_firsts");factors[pair]=expected
    first_values.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"uid":row.uid,"context":cid,"layer":before,"factor":actual if actual!=null else expected,"published":actual!=null,"derived":derived,"chain":impact.chain})
    if actual!=null and not is_equal_approx(float(actual),expected):problem("native published first factor mismatch")
    if not derived:
     var next=mini(before+1,layer_limit) if limit_enabled else before+1
     layers[uid]=next
     if next>before:count("effective_layer_growth",next-before)
   hit_pairs[pair]=true
  hits.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"uid":row.uid,"context":cid,"root":impact.root,"source":impact.source,"raw":raw,"derived":derived,"wild":wild,"blast":is_blast,"amount":row.amount,"type":row.type})
  impact.hit_index+=1
 observer_us+=Time.get_ticks_usec()-t
static func end_native()->void:
 if not enabled:return
 var t=Time.get_ticks_usec();finish_impact()
 if guidance:
  for uid in after_layers:
   if int(layers.get(uid,0))!=int(after_layers[uid]):problem("native layer accounting "+uid)
 observer_us+=Time.get_ticks_usec()-t
static func event(kind:String,info:Dictionary)->void:
 if not enabled:return
 if kind in ["explode","native_execution_handoff"]:count(kind)
 if kind in ["fire","enhancement_chain"] and info.has("shot"):
  var t=Time.get_ticks_usec();var shot:Dictionary=info.shot
  if shot.get("hostile",false) or fired_serials.has(shot.serial):return
  fired_serials[shot.serial]=true
  var meta:Dictionary=flights.get(int(shot.serial),{}) if game.native_execution!=null else {}
  var c:Dictionary=meta.get("value",shot.get("combat_context",{}))
  fires.append({"clock":game.production_time() if game!=null else 0.0,"step":step,"serial":shot.serial,"root":meta.get("root",shot.get("main_attack_id",c.get("root_id",0))),"instance":meta.get("instance",shot.get("attack_instance_id",0)),"source":c.get("source_id","unknown"),"derived":int(c.get("trigger_depth",0))>0,"chain":shot.get("chain_hop",false),"wild":c.get("wild_missile",false),"damage":shot.damage,"critical":shot.get("critical",false)})
  observer_us+=Time.get_ticks_usec()-t
static func totals()->Dictionary:
 return {"counts":counts.duplicate(true),"observer_us":observer_us,"roots":roots.size(),"hits":hits.size(),"step":step}
static func report()->Dictionary:
 return {"totals":totals(),"roots":roots,"hits":hits,"first_values":first_values,"cancelled_repeats":cancelled_repeats,"cancelled_ejections":cancelled_ejections,"fires":fires,"errors":errors,"native_counter":native_after_counter,"first_factor_scope":"published=true read directly from production handoff; published=false transient context released before export, value is accounting expectation (not an observed native scalar)","recursion_scope":"legacy hook sees blocked entries; native count is contiguous actual AoE hits with no additional impact, checked against all live held-health targets","observer_scope":"read-only production DLL exports and feedback; GDS hooks in isolated source only; wall cost included in full frame and separately timed"}
