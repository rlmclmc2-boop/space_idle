extends RefCounted
static var enabled:=false
static var counts:Dictionary={}
static var targets:Dictionary={}
static func add(key:String,n:int=1)->void:counts[key]=int(counts.get(key,0))+n
static func legacy_call(name:String)->void:
 if enabled:add("legacy_"+name)
static func root(snapshot:Dictionary)->void:
 if not enabled:return
 add("missile_attacks")
 if snapshot.combat_context.get("wild_missile",false):add("wild_substitutions")
static func target(uid)->Dictionary:
 if not targets.has(uid):targets[uid]={"uid":uid,"cache_firsts":0,"cache_hits":0,"effective_layer_growth":0,"first_factor":0.0,"last_factor":0.0,"min_factor":0.0,"max_factor":0.0,"missile_hits":0,"derived_hits":0}
 return targets[uid]
static func guidance(enemy:Dictionary,c:Dictionary,cached:bool,before:int)->void:
 if not enabled:return
 var row=target(enemy.uid);var factor=float(c.guidance_factors[str(enemy.uid)])
 var key="cache_hits" if cached else "cache_firsts"
 add(key);row[key]=int(row[key])+1
 if not cached:
  if row.cache_firsts==1:row.first_factor=factor;row.min_factor=factor;row.max_factor=factor
  row.last_factor=factor;row.min_factor=minf(row.min_factor,factor);row.max_factor=maxf(row.max_factor,factor)
 var growth=maxi(0,int(enemy.get("guidance_layers",0))-before)
 add("effective_layer_growth",growth);row.effective_layer_growth+=growth;row.layers=int(enemy.get("guidance_layers",0))
static func hit(enemy:Dictionary,c:Dictionary)->void:
 if not enabled or c.get("weapon","")!="missile":return
 add("missile_hits");var row=target(enemy.uid);row.missile_hits+=1
 if int(c.get("trigger_depth",0))>0:add("derived_hits");row.derived_hits+=1
 if c.get("wild_used",false):add("recursion_blocked_entries")
static func blast()->void:
 if enabled:add("wild_blasts")
static func snapshot()->Dictionary:
 return {"counts":counts.duplicate(true),"targets":targets.values().duplicate(true)}
