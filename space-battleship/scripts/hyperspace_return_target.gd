extends RefCounted
## A destination for a fresh sortie. No actor, health, cooldown or wave progress.
const C=preload("res://scripts/hyperspace_config.gd")
static func schema()->Dictionary:
	return {"stage":"i","loop":"b","guard_index":"i"}
static func valid(point:Dictionary,max_stage:int)->bool:
	return point.size()==3 and C.integer(point.get("stage")) and point.stage>=1 and point.stage<=max_stage and point.get("loop") is bool and C.integer(point.get("guard_index")) and point.guard_index>=0 and (point.loop or point.guard_index==0)
static func binding_valid(point:Dictionary,profile:Dictionary,data:Dictionary)->bool:
	var levels:Array=data.get("levels",[])
	if not valid(point,levels.size()) or point.stage>int(profile.get("highestLevel",1)):return false
	return not point.loop or point.guard_index<levels[int(point.stage)-1].groups.size()
static func destination(g)->Dictionary:
	return {"stage":int(g.profile.guardStage) if g.profile.loop else g.stage,"loop":bool(g.profile.loop),"guard_index":int(g.profile.guardIndex) if g.profile.loop else 0}
static func checkpoint(point:Dictionary,db)->Dictionary:
	# Use the ordinary journey loader, with zero unfinished progress.
	var selected:float=float(db.levels[int(point.stage)-1].groups[int(point.guard_index)].position)*float(db.levels[int(point.stage)-1].length) if point.loop else 0.0
	return {"stage":int(point.stage),"distance":selected,"groupIndex":int(point.guard_index)+1 if point.loop else 0,"state":3 if point.loop else 2,"guardArrived":bool(point.loop),"retreatBossPending":false,"pendingUnlocks":[]}
