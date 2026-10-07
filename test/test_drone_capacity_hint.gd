extends SceneTree
const UI=preload("res://scripts/hyperspace_equipment_ui.gd")
var checks=0
var failures=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
 var g=BattleGame.new(ShipDatabase.new(),false)
 g.profile.cleared=[];g.profile.grantedUnlocks=[];g.profile.highestLevel=34
 var hint=UI.next_hull(g,1)
 check(hint.id=="Destroyer" and not hint.available and hint.level==10,"Highest level alone does not unlock a cleared-mode hull")
 g.profile.cleared=[10]
 hint=UI.next_hull(g,1)
 check(hint.id=="Destroyer" and hint.available and hint.capacity==2,"Already unlocked larger hull recommends switching")
 g.profile.cleared=[10,20]
 hint=UI.next_hull(g,1)
 check(hint.id=="Cruiser" and hint.available and hint.capacity==3,"Recommend largest usable unlocked capacity")
 g.profile.cleared=[];g.profile.grantedUnlocks=[g.db.unlock_id("ship","Battleship")]
 hint=UI.next_hull(g,1)
 check(hint.id=="Battleship" and hint.available,"Retained earned unlocks also recommend switching")
 g.hyperspace.config.maximum_equipped=1
 check(UI.next_hull(g,1).is_empty(),"Global cap never promises unusable extra slots")
 g.hyperspace.config.maximum_equipped=5;g.profile.grantedUnlocks=[]
 var id=g.db.unlock_id("ship","Destroyer")
 g.db.data.unlock[id].mode="reached";g.profile.highestLevel=10
 hint=UI.next_hull(g,1)
 check(not hint.available and hint.mode=="reached" and hint.level==10,"Locked hint retains the actual reached-mode condition")
 g.profile.highestLevel=11
 check(UI.next_hull(g,1).available,"Reached-mode availability follows its strict authoritative threshold")
 check(UI.next_hull(g,5).is_empty(),"Maximum current capacity has no misleading next-unlock hint")
 print("Drone capacity hint: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
