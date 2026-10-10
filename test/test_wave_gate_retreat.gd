extends SceneTree
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:printerr(label);quit(1);assert(ok)
func _initialize():
 var db=ShipDatabase.new()
 var g=BattleGame.new(db,false)
 var original=float(db.config.backRange)
 for stage in range(1,23):
  g.stage=stage;g.state=BattleGame.State.COMBAT
  var level:Dictionary=db.levels[stage-1]
  for wave in range(2,level.groups.size()+1):
   g.group_index=wave
   var i=wave-1
   var gap:float=maxf(db.ratio(stage,i,"atkRatio")/db.ratio(stage,i-1,"atkRatio"),db.ratio(stage,i,"lifeRatio")/db.ratio(stage,i-1,"lifeRatio"))
   var spacing:float=(level.groups[i].position-level.groups[i-1].position)*level.length
   var expected=minf(original,spacing) if stage>=14 and stage<=20 and gap>=2.5 and spacing>0 else original
   check(is_equal_approx(g.main_retreat_range(),expected),"Source steep-band retreat scope")
 g.stage=14;g.group_index=6;g.distance=600;g.state=BattleGame.State.COMBAT
 check(is_equal_approx(g.main_retreat_range(),100),"Live steep14 band selects one wave")
 g.begin_retreat()
 check(g.state==BattleGame.State.RETREAT and is_equal_approx(g.retreat_target,500) and g.group_index==4,"One-wave retreat replays wave5 after wave6 defeat")
 g.stage=15;g.group_index=6;g.distance=600;g.state=BattleGame.State.COMBAT
 check(is_equal_approx(g.main_retreat_range(),original),"Gentler15 band keeps normal range")
 g.begin_retreat()
 check(is_equal_approx(g.retreat_target,400) and g.group_index==3,"Gentler band replays wave4")
 g.stage=14;g.group_index=1;g.state=BattleGame.State.COMBAT
 check(g.main_retreat_range()==original,"First wave keeps cross-stage retreat")
 g.group_index=6;g.state=BattleGame.State.TRAVEL
 check(g.main_retreat_range()==original,"Travel cursor is not a combat wave")
 g.state=BattleGame.State.COMBAT;g.manual_hyperspace.active=true
 check(g.main_retreat_range()==original,"Manual exploration excludes main gate policy")
 g.manual_hyperspace.active=false;db.config.backRange=30
 check(g.main_retreat_range()==30,"Configured shorter retreat is not extended")
 db.config.backRange=original;g.stage=15
 var group:Dictionary=db.groups[str(int(db.levels[14].groups[5].id))]
 for key in ["lifeMultiplier","atkMultiplier"]:
  var saved=group[key];group[key]=float(saved)*20
  check(is_equal_approx(g.main_retreat_range(),100),"Either independent combat scale can select one wave")
  group[key]=saved
 print("WAVE_RETREAT ",checks," checks passed");quit()
