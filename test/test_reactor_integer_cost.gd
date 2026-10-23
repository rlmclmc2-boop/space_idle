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
 var reactor:Dictionary=g.reactor.save_data();reactor.reactorLevel=2;check(g.reactor.install_snapshot(reactor,g.db.config),"reactor price fixture installs")
 g.economy.credit("2",13)
 check(not g.upgrade_reactor(1),"13 cannot buy cost14")
 g.economy.credit("2",37)
 check(g.reactor_max_upgrades()==2,"max quote agrees with per-level rounding")
 check(g.upgrade_reactor(2),"batch upgrade accepted")
 check(GrowthNumber.compare(g.economy.balance("2"),17)==0,"batch debits14+19 leaving17")
 check(g.reactor.level()==4,"batch raises two levels")
 scene.refresh_tab_visibility();scene.select_system(2)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/reactor-finite-cost.png")
 reactor=g.reactor.save_data();reactor.reactorLevel=2400
 check(g.reactor.install_snapshot(reactor,g.db.config),"high-price reactor fixture installs")
 g.economy.credit("2",GrowthNumber.multiply(g.reactor_upgrade_cost(),10.0))
 var huge_cost=g.reactor_upgrade_cost();var huge_before=g.economy.balance("2")
 check(huge_cost is Dictionary and GrowthNumber.valid(huge_cost),"overflowing ordinary power has finite single-level price")
 check(g.upgrade_reactor(1) and g.reactor.level()==2401 and GrowthNumber.compare(g.economy.balance("2"),GrowthNumber.subtract(huge_before,huge_cost))==0,"real high-price purchase debits the quoted representation")
 scene.reactor_panel.refresh();scene._process(0.0)
 check(GrowthNumber.valid(g.reactor_multiplier("weapons")),"finite large capacity supplies finite effects")
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/reactor-high-cost.png")
 print("reactor integer cost: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
