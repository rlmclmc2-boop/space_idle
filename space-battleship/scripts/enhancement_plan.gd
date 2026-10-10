extends RefCounted
## Qualification and authored recipes only. No attack/counter/timer/health state.
var dirty := true
var config_revision := 0
var revision := 0
var builds := 0
var count := 0
var level := 0
var recipes: Dictionary = {}
var ranks: Dictionary = {}
var branches: Dictionary = {}
var signature: Array = []
var owner_profile: Dictionary = {}
var owner_db: Object
var config: Dictionary = {}
var unlocks: Dictionary = {}
var planet_buffs: Dictionary = {}
var planets: Dictionary = {}
var granted: Array = []
var cleared: Array = []
var orders: Dictionary = {}
var weapon_order: Array = []
var defense_order: Array = []
var selected: Dictionary = {}
var actual_level := -1
var highest := -1

func invalidate() -> void:
 dirty=true

func configuration_changed() -> void:
 config_revision+=1
 dirty=true

func sync(g) -> void:
 var p: Dictionary=g.profile
 var next_config: Dictionary=g.db.data.get("enhance_config",{})
 var next_unlocks: Dictionary=g.db.data.get("unlock",{})
 var next_buffs: Dictionary=g.db.data.get("planet_buff",{})
 var next_planets: Dictionary=p.get("planets",{})
 var replaced_config: bool=not is_same(config,next_config) or not is_same(unlocks,next_unlocks) or owner_db!=g.db or not is_same(planet_buffs,next_buffs)
 var next_orders: Dictionary=p.get("enhancementOrder",{})
 var next_selected: Dictionary=p.get("enhancementBranches",{})
 var next_weapon: Array=next_orders.get("weapons",[])
 var next_defense: Array=next_orders.get("defence",[])
 if not is_same(owner_profile,p) or owner_db!=g.db or not is_same(config,next_config) or not is_same(unlocks,next_unlocks) or not is_same(granted,p.get("grantedUnlocks",[])) or not is_same(cleared,p.get("cleared",[])) or not is_same(orders,next_orders) or not is_same(weapon_order,next_weapon) or not is_same(defense_order,next_defense) or not is_same(selected,next_selected) or not is_same(planets,next_planets) or replaced_config or actual_level!=int(p.get("enhancementLevel",0)) or highest!=int(p.get("highestLevel",1)):
  dirty=true
 if not dirty:return
 if replaced_config:
  config_revision+=1
  g.stat_cache.clear();g.jewel_defence_capacity_cache.clear()
 owner_profile=p;owner_db=g.db;config=next_config;unlocks=next_unlocks
 planet_buffs=next_buffs;planets=next_planets
 granted=p.get("grantedUnlocks",[]);cleared=p.get("cleared",[])
 orders=next_orders;weapon_order=next_weapon;defense_order=next_defense;selected=next_selected
 actual_level=int(p.get("enhancementLevel",0));highest=int(p.get("highestLevel",1))
 var enabled: bool=g.enhancement_unlocked()
 var effective: int=g.enhancement_effective_level()
 var next_signature: Array=[enabled,effective,weapon_order.duplicate(),defense_order.duplicate(),selected.duplicate(true),config_revision]
 # A replaced table is a configuration revision even if qualification is equal.
 # Identity replacements above advance the revision before dependent reads.
 if next_signature==signature and revision>0:
  dirty=false;return
 signature=next_signature;count=0;level=effective;recipes={};ranks={};branches={}
 if enabled:
  for i in 3:
   if level>=g.enhancement_effect_threshold(i):count+=1
 for category in ["weapons","defence"]:
  var order: Array=orders.get(category,[])
  var effects: Array=[];var indexes: Dictionary={};var choices: Dictionary={}
  for i in count:
   var kind:=str(order[i])
   if not kind.is_empty():
    var effect: Dictionary=g._enhancement_effect(kind,i,level)
    effect.make_read_only();effects.append(effect);indexes[kind]=i
  for kind in g.default_enhancement_order()[category]:
   var nodes: Dictionary={}
   for node in [1,2,3]:
    nodes[node]=str(selected.get(category,{}).get(kind,{}).get(str(node),"")) if enabled and level>=g.enhancement_branch_threshold(node,category,kind) else ""
   nodes.make_read_only();choices[kind]=nodes
  effects.make_read_only();indexes.make_read_only();choices.make_read_only()
  recipes[category]=effects;ranks[category]=indexes;branches[category]=choices
 recipes.make_read_only();ranks.make_read_only();branches.make_read_only()
 dirty=false;revision+=1;builds+=1

func category(g,entry: Dictionary) -> String:
 var key:=str(entry.get("key",""))
 if key in g.WEAPON_KEYS:return "weapons"
 if key in g.DEFENSE_KEYS:return "defence"
 return ""

func effects(g,entry: Dictionary) -> Array:
 var kind:=category(g,entry)
 return recipes.get(kind,[])

func index(g,entry: Dictionary,effect: String) -> int:
 return int(ranks.get(category(g,entry),{}).get(effect,-1))

func active(g,entry: Dictionary,effect: String,node: int,choice: String) -> bool:
 var kind:=category(g,entry)
 return ranks.get(kind,{}).has(effect) and branches.get(kind,{}).get(effect,{}).get(node,"")==choice
