extends SceneTree
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const PlayerInput=preload("res://qa/player_input.gd")
var checks:=0
var failures:=0
var driver
var game
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var g=Game.new(ShipDatabase.new());game=g
 check(g.load_hyperspace_routes(),"Production routes accepted")
 # Explicit isolated fixtures, never a real player save or a production config edit.
 g.profile.cleared=range(1,33);g.profile.highestLevel=33;g.rebuild_unlocks()
 g.profile.loadout.defence=[{"key":"armour","level":10},{"key":"armour","level":10},{"key":"armour","level":10}]
 var p=Policy.new();var baseline:Dictionary=Policy.manual_growth(g.profile)
 p.manual_started(g,"beta",32,0);p.manual_finished(g,false,10)
 check(not p.manual_retry_allowed(g,"beta",32,2000),"Elapsed cooldown alone does not retry a real failure")
 var old_key:String=str(g.profile.loadout.weapons[0].key)
 g.profile.loadout.weapons[0].key="cannon"
 check(not p.manual_retry_allowed(g,"beta",32,2000),"Refit alone is not earned growth")
 g.profile.loadout.weapons[0].key=old_key
 g.profile.loadout.weapons[0].level+=4
 check(not p.manual_retry_allowed(g,"beta",32,2000),"Four earned module levels below retry gate")
 g.profile.loadout.weapons[0].level+=1
 check(p.manual_retry_allowed(g,"beta",32,2000),"Five earned module levels unlock retry")
 var tech:Dictionary=baseline.duplicate(true);tech.scientists+=1
 check(Policy.earned_manual_growth(baseline,tech),"Paid scientist growth qualifies")
 tech=baseline.duplicate(true);tech.reactorLevel+=1
 check(Policy.earned_manual_growth(baseline,tech),"Real reactor growth qualifies")
 tech=baseline.duplicate(true);tech.enhancementLevel+=1
 check(Policy.earned_manual_growth(baseline,tech),"Real shared enhancement growth qualifies")
 g.stage=32;g.group_index=8;g.profile.loop=false;g.state=g.State.COMBAT
 g.enemies.assign([{"hp":1.0}])
 check(not p.safe_main_boundary(g),"Never interrupt main COMBAT")
 g.state=g.State.TRAVEL
 check(not p.safe_main_boundary(g),"Live actors still prevent a boundary dispatch")
 g.enemies.clear();g.pending_unlocks.clear()
 check(p.safe_main_boundary(g),"Travel after cleared battle point is safe")
 g.group_index=0
 check(not p.safe_main_boundary(g),"Fresh stage before any ended point is not a boundary")
 g.group_index=8;g.profile.loop=true
 check(not p.safe_main_boundary(g),"Do not interrupt guarded farming")
 g.profile.loop=false;p.last_manual_boundary=p.main_boundary(g)
 check(not p.safe_main_boundary(g),"At most one manual attempt per main boundary")
 p.last_manual_boundary=""
 # Real manual start/exit through production API and the original visible exit button.
 driver=Driver.new();driver.ui_refresh_seconds=0.0;driver.production_ui_ticks=true;driver.setup(self,g)
 root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 g.profile.hyperspace.active={};g.profile.hyperspace.auto.enabled=false
 p.manual_pending={"domain":true,"kind":"space_manual","route":"alpha","level":5,"round":1,"frontier":33}
 var choice:Dictionary=p.pending_manual_action(g,2000)
 check(not choice.is_empty(),"Queued legal request becomes eligible at ended point")
 var resources:Dictionary=g.profile.resources.duplicate(true)
 check(p.execute(g,choice,2000) and g.manual_hyperspace.active,"Queued dispatch uses real production manual start")
 check(g.profile.resources==resources,"Manual start injects no resources")
 p.manual_started(g,"alpha",5,2000)
 g.group_index=1
 var bars:Dictionary={"visible":{"hp":1.0,"shield":1.0}}
 p.check_manual_budget(g,bars,2300)
 p.check_manual_budget(g,bars,2600)
 check(str(p.manual_watch.exit_reason).is_empty(),"Retain attempt below stall/budget thresholds")
 var feedback:=p.check_manual_budget(g,bars,2900)
 check(not str(feedback.exit_reason).is_empty(),"Single manual attempt cannot exceed 900 seconds budget")
 driver.scene.equipment_tabs.current_tab=9;driver.scene.refresh_navigation();driver.scene.hyperspace_panel.refresh()
 await process_frame;await process_frame
 var input=PlayerInput.new();input.setup(driver.scene,self)
 check(await input.press(driver.scene.hyperspace_panel.exit_button),"Original visible exit button accepts native input")
 check(not g.manual_hyperspace.active and g.stage==32 and g.group_index==8,"Native exit returns to suspended main boundary")
 p.manual_finished(g,false,2900)
 check(not p.manual_retry_allowed(g,"alpha",5,5000),"Voluntary exit records failure-time earned-growth gate")
 # Distinct stall/progress samples, independent of the total-time limit.
 g.manual_hyperspace.active=true;g.group_index=2
 p.manual_started(g,"beta",32,0);p.manual_watch.group=2;p.manual_watch.bars=bars.duplicate(true)
 p.check_manual_budget(g,bars,300)
 p.check_manual_budget(g,bars,600)
 check(not str(p.manual_watch.exit_reason).is_empty(),"Visible wave/bars stalled for 600 seconds triggers retreat")
 p.manual_started(g,"beta",32,0);p.manual_watch.group=2;p.manual_watch.bars=bars.duplicate(true)
 p.check_manual_budget(g,{"visible":{"hp":0.5,"shield":1.0}},300)
 p.check_manual_budget(g,{"visible":{"hp":0.4,"shield":1.0}},600)
 check(str(p.manual_watch.exit_reason).is_empty(),"Observed damage keeps the attempt within its budget")
 g.manual_hyperspace.active=false
 driver.close()
 print("MANUAL_POLICY ",checks," checks ",failures," failures");quit(1 if failures else 0)
