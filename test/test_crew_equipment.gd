extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func make_game() -> BattleGame:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear();g.paused=false
 g.profile.resources={"1":1e12,"2":1e12}
 return g
func slots(g) -> Array:
 var result:Array=[]
 for category in ["weapons","defence"]:
  for index in g.loadout_entries(category).size():result.append([category,index])
 return result
func levels(g) -> Array:
 return slots(g).map(func(s):return int(g.slot_entry(s[0],s[1]).level))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g=make_game();var list=slots(g)
 check(list.size()>1,"Fixture has multiple enabled slots")
 var before=levels(g);g.crew.advance(g,1)
 check(levels(g)==before,"No equipment purchases without assigned crew")
 check(g.assign_crew("navigator","equipment_upgrade","equipment"),"Existing crew gate enables equipment job")
 check(g.crew.upgrade_modes(g,"equipment_upgrade")==["1"] and g.crew.upgrade_modes(g,"hightech_scientists")==["1","10","max"],"Automatic equipment batch options retired, scientist modes preserved")
 # Simulate retained legacy mode; the equipment handler must always buy +1.
 g.crew.entry(g,"navigator").upgradeMode="max"
 for s in list:g.slot_entry(s[0],s[1]).level=5
 var target=list[-1];g.slot_entry(target[0],target[1]).level=1;g.invalidate_stat_cache()
 var reference=make_game();reference.profile.loadout=g.profile.loadout.duplicate(true);reference.profile.resources=g.profile.resources.duplicate(true);reference.invalidate_stat_cache()
 reference.upgrade_slot(target[0],target[1],1)
 before=levels(g);g.crew.advance(g,0.99)
 check(levels(g)==before,"Normal game clock waits until full second")
 g.paused=true;g.crew.advance(g,20)
 check(levels(g)==before,"Pause freezes pending purchase time")
 g.paused=false;g.crew.advance(g,0.01)
 check(g.profile.loadout==reference.profile.loadout and g.profile.resources==reference.profile.resources,"Unequal levels purchase only lowest +1 at exact original cost")
 # Equal-level ties rotate even if a later manual edit makes all levels equal again.
 g.crew.equipment_last_slot="";var purchased:Array=[]
 var calls:Array=[]
 g.event.connect(func(kind,info):
  if kind=="upgrade":calls.append(info))
 for i in list.size():
  for s in list:g.slot_entry(s[0],s[1]).level=3
  g.invalidate_stat_cache();calls.clear();g.crew.advance(g,1)
  check(calls.size()==1 and int(calls[0].levels)==1,"Each equal-level beat purchases exactly one level")
  if not calls.is_empty():purchased.append(str(calls[0].slot))
 check(purchased.size()==list.size() and purchased.all(func(id):return purchased.count(id)==1),"All equal-level slots receive one fair turn")
 # An enabled empty equipment slot stays eligible; inactive tails stay excluded.
 var empty=list[-1];g.slot_entry(empty[0],empty[1]).key="";g.slot_entry(empty[0],empty[1]).level=1
 for s in list.slice(0,list.size()-1):g.slot_entry(s[0],s[1]).level=8
 g.profile.loadout.weapons.append({"key":"laser","level":0});var tail=g.profile.loadout.weapons[-1]
 g.invalidate_stat_cache();g.crew.advance(g,1)
 check(g.slot_entry(empty[0],empty[1]).level==2 and tail.level==0,"Enabled uninstalled slot participates; inactive tail does not")
 # No resource event after direct fixture balance edit: waiting must still retry next beat.
 g.profile.resources={"1":0.0,"2":0.0};before=levels(g);calls.clear();g.crew.advance(g,1)
 check(levels(g)==before and calls.is_empty(),"Unaffordable lowest slot waits without upgrading any other slot")
 g.profile.resources={"1":1e12,"2":1e12};g.crew.advance(g,0.99)
 check(levels(g)==before,"Waiting retry still needs one second")
 g.crew.advance(g,0.01)
 check(g.slot_entry(empty[0],empty[1]).level==3,"Selected lowest slot retries at the next second")
 calls.clear();g.crew.advance(g,100)
 check(calls.size()==1 and int(calls[0].levels)==1,"Large game-time step makes one purchase, no missed-beat replay")
 before=levels(g);g.crew.advance(g,0.99)
 check(levels(g)==before,"Large-step overrun is discarded")
 var raw=g.profile.crew.duplicate(true);before=levels(g);g.crew.load_state(g,raw)
 check(levels(g)==before,"Loading crew creates no offline purchases")
 g.crew.advance(g,0.99);check(levels(g)==before,"Reload restarts an unsaved one-second clock")
 g.assign_crew("navigator","","");before=levels(g);g.crew.advance(g,1)
 check(levels(g)==before,"Unassigned crew cannot continue auto purchases")
 for mode in ["1","10","max"]:
  var manual=make_game();var old=int(manual.slot_entry("weapons",0).level)
  var amount:int=manual.max_upgrade_amount_slot("weapons",0) if mode=="max" else int(mode)
  var costs=manual.slot_upgrade_cost("weapons",0,amount);var balance=manual.profile.resources.duplicate(true)
  check(manual.upgrade_slot("weapons",0,amount) and int(manual.slot_entry("weapons",0).level)==old+amount,"Manual "+mode+" keeps its selected amount")
  check(costs.keys().all(func(id):return manual.profile.resources[id]==manual.N.subtract(balance[id],costs[id])),"Manual "+mode+" keeps normal deduction")
 # Actual crew controls verify automatic options without touching a player save.
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var ui_game=scene.game;ui_game.save_enabled=false;ui_game.paused=true;ui_game.profile.cleared=range(1,101);ui_game.profile.highestLevel=101;ui_game.rebuild_unlocks();ui_game.pending_unlocks.clear();ui_game.profile.onboarding.completed=true
 for key in ui_game.db.data.hightech:ui_game.profile.hightechLevels[key]=1
 scene.refresh_structure();scene.select_system(5);await process_frame
 var panel=scene.crew_panel;panel.select("navigator")
 panel.jobs.select(panel.job_ids.find("equipment_upgrade"));panel.jobs.item_selected.emit(panel.jobs.selected)
 check(not panel.parameter_column.visible and not panel.upgrade_picker.visible and panel.assignment_preview.text.contains("最低等级的一槽"),"Equipment draft hides batch selector and explains one lowest slot")
 panel.assign_button.pressed.emit();ui_game.crew.entry(ui_game,"navigator").upgradeMode="10";panel.refresh_detail()
 check(panel.description.text.contains("最低等级的一槽") and not panel.description.text.contains("10"),"Legacy automatic mode cannot leak into current equipment explanation")
 panel.jobs.select(panel.job_ids.find("hightech_scientists"));panel.jobs.item_selected.emit(panel.jobs.selected)
 check(panel.upgrade_picker.visible and panel.mode_ids==["1","10","max"],"Scientist automatic amount selector retains its existing choices")
 scene.queue_free();await process_frame
 print("CREW LOWEST EQUIPMENT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
