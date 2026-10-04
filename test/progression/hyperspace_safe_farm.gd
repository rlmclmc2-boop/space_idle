extends RefCounted
## QA only: current-round wins, real UI navigation, earned five-level growth.
const VERSION="safe-first-normal-v2-from-four-earned-five-levels"
var round_seen:=-1
var known:Dictionary={}
var failed:Dictionary={}
var attempted_stage:=0
var phase:="idle"
var plan:Dictionary={}
var records:Array=[]
func growth(g)->Dictionary:
 var modules:=0
 for category in ["weapons","defence"]:
  for entry in g.loadout_entries(category):modules+=int(entry.level)
 var research:=0
 for value in g.profile.hightechLevels.values():research+=int(value)
 return {"modules":modules,"reactor":int(g.profile.reactorLevel),"research":research,"enhancement":int(g.profile.get("enhancementLevel",0)),"ship":str(g.profile.selectedShip)}
func note(kind:String,now:float,extra:Dictionary={})->Dictionary:
 var row:Dictionary={"kind":kind,"x1_seconds":now,"phase":phase,"plan":plan.duplicate(true)}
 row.merge(extra,true);records.append(row.duplicate(true));return row
func observe(g,kind:String,payload:Dictionary,now:float)->Dictionary:
 var round_id:int=int(g.profile.hyperspace.round_id)
 if round_id!=round_seen:
  round_seen=round_id;known={};failed={};attempted_stage=0;phase="idle";plan={}
 if g.manual_hyperspace.active:return {}
 if kind=="state":
  if g.state==g.State.COMBAT:attempted_stage=int(g.stage)
  elif g.state==g.State.LEVEL_CLEAR:failed[int(g.stage)]=0
 if kind=="wave_clear" and int(g.group_index)==1:
  # The finished group alone is inspected; never rank unseen groups/income.
  var actual_id:String=str(int(g.db.levels[g.stage-1].groups[0].id))
  var tier:String=str(g.db.groups[actual_id].get("combatTier",""))
  if tier=="normal" and not known.has(int(g.stage)):
   known[int(g.stage)]={"node":0,"tier":tier,"won_at":now,"round":round_id}
   return note("safe_point_won",now,{"stage":g.stage,"node":0,"actual_group":actual_id})
 if kind=="retreat":
  failed[attempted_stage]=int(failed.get(attempted_stage,0))+1
  if phase in ["farm","resume"]:
   var old:Dictionary=plan.duplicate(true);phase="idle";plan={}
   return note("farm_point_failed",now,{"abandoned":old,"actual_failed_stage":attempted_stage})
 if kind=="explode" and phase=="farm" and g.profile.loop and not bool(payload.get("player",false)) and not g.has_alive_enemy():
  plan.cycles=int(plan.get("cycles",0))+1
  return note("farm_cycle_won",now,{"current_growth":growth(g)})
 return {}
func consider(g,now:float)->Dictionary:
 if g.manual_hyperspace.active:return {}
 if phase=="idle" and attempted_stage>=4 and int(failed.get(attempted_stage,0))>=2:
  var chosen:=0
  if known.has(attempted_stage) and (g.stage==attempted_stage or g.profile.cleared.has(attempted_stage)):chosen=attempted_stage
  elif known.has(attempted_stage-1) and g.profile.cleared.has(attempted_stage-1):chosen=attempted_stage-1
  if chosen>0:
   plan={"stage":chosen,"push_stage":attempted_stage,"node":0,"since":now,"baseline":growth(g),"cycles":0,"reason":"Two actual defeats; return to an already won first normal point, no unseen-income ranking"}
   phase="warp";return note("farm_requested",now)
 if phase=="farm" and int(growth(g).modules)>=int(plan.baseline.modules)+5:
  phase="resume";return note("farm_growth_ready",now,{"current_growth":growth(g),"criterion":"Old sparse policy's five earned module levels; no timed forced release"})
 return {}
func next_command(g)->Dictionary:
 if g.manual_hyperspace.active:return {}
 if phase=="warp":return {"kind":"farm_warp_open","stage":int(plan.stage)}
 if phase=="guard" and g.stage==int(plan.stage) and not g.profile.loop and ((g.state==g.State.TRAVEL and g.group_index==0) or (g.state==g.State.COMBAT and g.group_index==1)):
  return {"kind":"farm_guard_on"}
 if phase=="resume" and g.profile.loop:return {"kind":"farm_guard_off"}
 return {}
func native_completed(g,choice:Dictionary,now:float)->Dictionary:
 if choice.kind=="option_select" and choice.get("origin","")=="farm_warp_open":
  if g.stage!=int(plan.stage) or g.state!=g.State.TRAVEL or g.group_index!=0 or int(g.profile.loopLevel)!=int(plan.stage):return {"error":"Native warp did not start the requested real first-point journey"}
  phase="guard";return note("farm_real_departure",now)
 if choice.kind=="farm_guard_on":
  if not g.profile.loop or int(g.profile.guardStage)!=int(plan.stage) or int(g.profile.guardIndex)!=0:return {"error":"Native guard did not select the already won first normal point"}
  phase="farm";plan.baseline=growth(g);return note("farm_guard_started",now)
 if choice.kind=="farm_guard_off":
  if g.profile.loop:return {"error":"Native guard-off did not resume normal progression"}
  var done:Dictionary=plan.duplicate(true)
  failed[int(plan.push_stage)]=0;phase="idle";plan={}
  return note("farm_resume_progression",now,{"completed_farm":done,"current_growth":growth(g),"navigation":"Continue normally from this actual point; previous-stage farming replays its remaining real points before returning to frontier"})
 return {}
func snapshot()->Dictionary:
 return {"version":VERSION,"round":round_seen,"phase":phase,"plan":plan.duplicate(true),"known_wins":known.duplicate(true),"actual_defeats":failed.duplicate(true),"records":records.duplicate(true)}
