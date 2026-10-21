extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
var failures:=0
func check(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=[1];g.profile.reactorLevel=97
 var cap97=g.reactor_capacity();var price=g.reactor_upgrade_cost()
 g.profile.resources["2"]=R.subtract(R.from_growth(price),1)
 var before=g.profile.resources["2"]
 check(not g.upgrade_reactor(1) and g.profile.resources["2"]==before and g.profile.reactorLevel==97,"insufficient atomic")
 g.profile.resources["2"]=R.from_growth(price)
 check(g.upgrade_reactor(1),"purchase")
 check(g.profile.reactorLevel==98 and R.compare(g.reactor_capacity(),cap97)>0,"growth")
 check(N.compare(g.profile.resources["2"],0)==0,"exact debit")
 var cap=g.reactor_capacity();var shares=R.div_small(cap,3)
 check(R.compare(R.add(R.multiply(shares[0],3),shares[1]),cap)==0,"quotient remainder")
 print("TRANSACTION CHECKS ",failures," price ",N.text(price))
 quit(1 if failures else 0)
