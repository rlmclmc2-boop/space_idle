extends RefCounted
## UI-only projection. Public BattleGame tutorial queries remain immediate.
var ids: Array[String]=[]
var unread: Array[String]=[]
var rows: Dictionary={}
var grouped: Dictionary={}
var unread_ids: Dictionary={}
var unread_systems: Dictionary={}
var eligibility_dirty:=true
var reads_dirty:=true
var builds:=0
var read_builds:=0
var owner: Variant
var database: Variant
var profile: Variant
var definitions: Variant
var planets: Variant
var planet_buffs: Variant
var galaxies: Variant
var hyperspace_config: Variant
var cleared: Variant
var granted: Variant
var seen: Variant
var read_flags: Variant
var highest:=-1
var hyperspace_gate:=-1
var completed_galaxies: Dictionary={}

func invalidate() -> void:
 eligibility_dirty=true
 reads_dirty=true

func on_event(g,kind:String,_info:Dictionary)->void:
 if kind=="tutorial_read":reads_dirty=true;return
 if kind=="galaxy_changed":
  var key:=str(_info.get("key",""))
  var region=g.galaxy.regions.get(key)
  var complete:bool=region!=null and region.state.status=="complete"
  if completed_galaxies.get(key,false)!=complete:invalidate()
  completed_galaxies[key]=complete
  return
 if kind in ["unlocks_changed","tutorial_changed","planet_reforged","progress_loaded","configuration_changed","planet_changed","galaxy_unlocked"]:invalidate()

func sync(g)->void:
 # Constant-size identity/scalar guards cover object/table replacement, loads,
 # route database swaps and the live configured hyperspace gate. In-place progress
 # mutations use owner events; no per-frame profile hash or eligibility walk.
 var data:Dictionary=g.db.data
 if not is_same(owner,g) or not is_same(database,g.db) or not is_same(profile,g.profile) or not is_same(definitions,data.get("unlock")) or not is_same(planets,data.get("planet")) or not is_same(planet_buffs,data.get("planet_buff")) or not is_same(galaxies,data.get("galaxy")) or not is_same(hyperspace_config,g.hyperspace.config) or not is_same(cleared,g.profile.get("cleared")) or not is_same(granted,g.profile.get("grantedUnlocks")) or not is_same(seen,g.profile.get("seenUnlocks")) or highest!=int(g.profile.highestLevel) or hyperspace_gate!=int(g.hyperspace.config.unlock_stage):invalidate()
 if not is_same(read_flags,g.profile.get("readUnlocks")):reads_dirty=true
 if eligibility_dirty:
  owner=g;database=g.db;profile=g.profile
  definitions=data.get("unlock");planets=data.get("planet");planet_buffs=data.get("planet_buff");galaxies=data.get("galaxy");hyperspace_config=g.hyperspace.config
  cleared=g.profile.get("cleared");granted=g.profile.get("grantedUnlocks");seen=g.profile.get("seenUnlocks")
  highest=int(g.profile.highestLevel);hyperspace_gate=int(g.hyperspace.config.unlock_stage)
  ids=g.tutorial_unlocks()
  ids.make_read_only()
  rows={};grouped={};completed_galaxies={}
  for key in g.galaxy.regions:completed_galaxies[key]=g.galaxy.regions[key].state.status=="complete"
  for id in ids:
   var row:Dictionary={"type":"feature","target":"hyperspace","title":UIText.t("hyperspace.title"),"desc":UIText.t("tutorial.hyperspace.description")} if id=="hyperspace" else definitions.get(id,{})
   rows[id]=row
   var category:=row_system(row)
   if not grouped.has(category):grouped[category]=[]
   grouped[category].append(id)
  for bucket in grouped.values():bucket.make_read_only()
  builds+=1;eligibility_dirty=false;reads_dirty=true
 if reads_dirty:
  read_flags=g.profile.get("readUnlocks")
  unread=[];unread_ids={};unread_systems={}
  for id in ids:
   if not read_flags.has(id):
    unread.append(id);unread_ids[id]=true;unread_systems[row_system(rows[id])]=true
  unread.make_read_only()
  read_builds+=1;reads_dirty=false

func row_system(row:Dictionary)->String:
 match str(row.get("type","")):
  "equipment":return "equipment"
  "ship":return "ships"
  "hightech":return "hightech"
  "reactor_module":return "reactor"
  "crew":return "crew"
  "planet":return "planets"
  "feature":
   match str(row.get("target","")):
    "reactor":return "reactor"
    "jewels":return "enhancement"
    "crew_level":return "crew"
    "galaxy":return "galaxy"
    "hyperspace":return "hyperspace"
 return "other"
