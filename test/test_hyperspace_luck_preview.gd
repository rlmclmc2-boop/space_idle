extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=BattleGame.new(db,false);g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear()
	g.crew.entry(g,"navigator").level=40;g.profile.planets["1"].conquered=true
	var before:Dictionary=g.profile.hyperspace.duplicate(true)
	var selected:Dictionary=g.hyperspace_route_view("beta","navigator")
	check(selected.crew_luck==40.0 and selected.permanent_luck==100.0 and selected.total_luck==140.0,"unconfigured route previews selected crew plus permanent luck")
	check(g.hyperspace_route_view("beta").total_luck==100.0,"unconfigured default preview includes permanent luck only")
	check(g.profile.hyperspace==before,"selection preview leaves config and random state untouched")
	var receipt:Dictionary=g.hyperspace.start(g,"beta",1,"manual")
	check(receipt.crew_snapshot=="" and receipt.crew_luck==0.0 and receipt.luck==100.0,"real start does not adopt merely previewed crew")
	var frozen:Dictionary=receipt.duplicate(true)
	g.hyperspace_route_view("beta","navigator")
	check(g.profile.hyperspace.active==frozen,"preview cannot change existing receipt snapshot")
	g.hyperspace.complete(g,receipt.round_id,receipt.run_id,false)
	g.profile.hyperspace.auto={"enabled":false,"route":"alpha","level":0,"crew_id":"navigator"}
	var other:=""
	for item in g.profile.crew:
		if item.crewId!="navigator" and g.crew.unlocked(g,str(item.crewId)):other=str(item.crewId);break
	check(not other.is_empty(),"distinct unlocked crew fixture exists")
	if other.is_empty():quit(1);return
	g.crew.entry(g,other).level=7
	selected=g.hyperspace_route_view("alpha",other)
	check(selected.crew_luck==7.0 and selected.total_luck==107.0,"selected different crew overrides configured crew in preview")
	check(g.hyperspace_route_view("alpha").crew_luck==40.0,"omitted preview crew retains configured crew")
	receipt=g.hyperspace.start(g,"alpha",1,"manual")
	check(receipt.crew_snapshot=="navigator" and receipt.crew_luck==40.0 and receipt.luck==140.0,"real start still freezes configured crew")
	print("LUCK_PREVIEW: ",checks," checks ",failures," failures; isolated core regression, not UI acceptance")
	quit(1 if failures else 0)
