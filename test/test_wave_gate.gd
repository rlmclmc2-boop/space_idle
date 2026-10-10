extends SceneTree
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:printerr(label);quit(1);assert(ok)
func _initialize()->void:
 var db=ShipDatabase.new()
 for stage in range(1,23):
  for i in db.levels[stage-1].groups.size():
   for kind in ["atkRatio","lifeRatio","resRatio","jewelRatio"]:
    var level:Dictionary=db.levels[stage-1];var previous:float=1.0 if stage==1 else float(db.levels[stage-2][kind])
    var entry_key="entryAtkRatio" if kind=="atkRatio" else "entryLifeRatio" if kind=="lifeRatio" else ""
    if level.has(entry_key):previous=float(level[entry_key])
    var base=lerpf(previous,float(level[kind]),float(i)/float(level.groups.size()-1))
    var group:Dictionary=db.groups[str(int(level.groups[i].id))]
    var multiplier=float(group.get("atkMultiplier" if kind=="atkRatio" else "lifeMultiplier" if kind=="lifeRatio" else "",1))
    check(is_equal_approx(db.ratio(stage,i,kind),base*multiplier),"Wave-only multiplier/entry boundary mismatch")
    if multiplier==1.0:check(is_equal_approx(db.ratio(stage,i,kind),base),"Unrelated wave/reward polluted")
 var fixture_group:Dictionary=db.groups[str(int(db.levels[10].groups[0].id))]
 var old:float=db.ratio(11,0,"lifeRatio");var following:float=db.ratio(12,0,"lifeRatio")
 fixture_group.lifeMultiplier=8
 check(is_equal_approx(db.ratio(11,0,"lifeRatio"),old*8) and is_equal_approx(db.ratio(12,0,"lifeRatio"),following),"Distinct local fixture must not alter following stage anchor")
 fixture_group.erase("lifeMultiplier")
 var tail=db.ratio(20,8,"lifeRatio");var head=db.ratio(21,0,"lifeRatio")
 print("GATE_BOUNDARY20to21 life=",tail/head," attack=",db.ratio(20,8,"atkRatio")/db.ratio(21,0,"atkRatio"))
 print("WAVE_GATE ",checks," checks passed");quit()
