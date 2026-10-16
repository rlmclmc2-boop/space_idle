extends SceneTree
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate()
 scene.automation_args=["--capture"]
 root.add_child(scene)
 scene.set_process(false)
 var g=scene.game
 g.save_enabled=false
 g.profile.cleared=[1]
 g.profile.highestLevel=2
 g.rebuild_unlocks()
 check(g.reactor_unlocked(),"fixture reactor unlocked")
 check(g.reactor_upgrade_cost(1)==10,"first cost unchanged")
 check(g.reactor_upgrade_cost(2)==14,"13.5 rounds up to14")
 check(g.reactor_upgrade_cost(3)==19,"18.225 rounds up to19")
 for level in range(1,101):
  var c:float=g.reactor_upgrade_cost(level)
  check(c==ceilf(c),"integer quote at level "+str(level))
 g.profile.reactorLevel=2
 g.profile.resources["2"]=13
 check(not g.upgrade_reactor(1),"13 cannot buy cost14")
 g.profile.resources["2"]=50
 check(g.reactor_max_upgrades()==2,"max quote agrees with per-level rounding")
 check(g.upgrade_reactor(2),"batch upgrade accepted")
 check(GrowthNumber.compare(g.profile.resources["2"],17)==0,"batch debits14+19 leaving17")
 check(g.profile.reactorLevel==4,"batch raises two levels")
 print("reactor integer cost: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
