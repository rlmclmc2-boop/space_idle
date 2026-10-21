extends SceneTree

const I=preload("res://scripts/reactor_integer.gd")
const S=preload("res://scripts/sparse_wallet.gd")
const Q=preload("res://scripts/equipment_quote.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:
	for case in [[150.0,0.2,4001],[125.0,0.11,5000],[75.0,0.07,10000],[245.0,0.2,7000],[35.0,0.03,4100],[105.0,0.15,4200],[305.0,0.09,6000],[555.0,0.23,4500]]:
		var base:float=case[0]
		var growth:float=case[1]
		var level:int=case[2]
		var bounded=Q._bounded_large_growth(base,growth,level)
		var reference=Q._large_growth(base,growth,level)
		check(bounded!=null and I.compare(bounded,reference)==0,"bounded quote matches exact decimal oracle "+str(case))
	var db:=ShipDatabase.new()
	var started:=Time.get_ticks_msec()
	var high=db.equipment_quote("laser",1000000000)
	var elapsed:=Time.get_ticks_msec()-started
	check(high.ok and high.costs.values().any(func(v):return S.is_sparse(v)),"billion-level quote uses exact sparse price")
	check(elapsed<250,"billion-level single quote responds within frame-scale budget")
	print("S12_QUOTE_BOUNDS checks=",checks," failures=",failures," high_ms=",elapsed)
	quit(1 if failures else 0)
