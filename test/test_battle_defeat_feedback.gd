extends SceneTree
const Feedback=preload("res://scripts/battle_defeat_feedback.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func opened():
 var g=BattleGame.new(ShipDatabase.new(),false);g.stat_cache_enabled=true
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.load_hyperspace_routes()
 g.start(8,false);g.group_index=3;g.spawn_group();return g
func _initialize()->void:
 var g=opened();var f=Feedback.new();var reports:Array=[]
 g.event.connect(func(kind,info):
  f.record(g,kind,info)
  if kind=="battle_defeated":reports.append({"info":info.duplicate(),"cause":f.cause(g),"text":f.text(g,info)}))
 g.hit_player(1,2)
 check(reports.is_empty() and N.compare(g.player.armour,0)>0,"nonlethal hit never reports defeat")
 check(f.cause(g)=="physical","physical actual body loss recorded")
 g.hit_player(N.subtract(g.player.armour,1),1)
 check(reports.is_empty() and N.compare(g.player.armour,1)==0,"one remaining HP is near death, not defeat")
 var known=f.main.duplicate(true)
 g.event.emit("hit",{"player":false,"type":1,"amount":1e100})
 check(f.main==known,"outgoing enemy damage ignored")
 # Unknown delayed damage cannot manufacture its former incoming type.
 g.event.emit("hit",{"player":true,"type":0,"deferred":true,"amount":1e100})
 check(f.cause(g)=="unknown","unattributed delay masks uncertain dominant type")
 g.event.emit("encounter",{})
 check(f.cause(g)=="unknown","new wave resets old damage")
 var rng=g.rng.state
 g.enemies[0].hp=0
 var alive=g.enemies.filter(func(e):return N.compare(e.hp,0)>0).size()
 g.hit_player(N.multiply(N.add(g.player.armour,g.player.shield),1000),1)
 check(reports.size()==1 and reports[0].info.remaining==alive,"full death snapshots only live enemies before clearing")
 check(reports[0].cause=="energy" and reports[0].text.begins_with("主线战败"),"main defeat has truthful energy loss context")
 check(g.state==g.State.RETREAT and g.enemies.is_empty() and g.rng.state==rng,"feedback leaves retreat and combat RNG unchanged")
 g.begin_retreat()
 check(reports.size()==1,"already retreating does not duplicate defeat feedback")
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
 # Use the real challenge/return entry rather than a fabricated active flag.
 g=opened();f=Feedback.new();reports=[]
 g.event.connect(func(kind,info):
  f.record(g,kind,info)
  if kind=="battle_defeated":reports.append({"info":info.duplicate(),"text":f.text(g,info)}))
 g.hit_player(1,2);var main_record=f.main.duplicate(true);var main_hp=g.player.armour
 check(g.start_hyperspace_challenge("alpha"),"real manual challenge starts")
 g.spawn_group();var manual_alive=g.enemies.filter(func(e):return N.compare(e.hp,0)>0).size()
 g.hit_player(N.multiply(N.add(g.player.armour,g.player.shield),1000),1)
 check(reports.size()==1 and reports[0].info.manual and reports[0].info.remaining==manual_alive and reports[0].text.begins_with("异空间战败"),"manual death snapshots its own fleet before main restoration")
 check(not g.manual_hyperspace.active and g.stage==8 and g.player.armour==main_hp and f.main==main_record,"manual return restores main without contaminating its feedback")
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
 # A real rebuild consumes a drone and revives the carrier, rather than defeating it.
 g=opened();reports=[]
 g.event.connect(func(kind,info):
  if kind=="battle_defeated":reports.append(info))
 var random=RandomNumberGenerator.new();random.seed=7
 var d=preload("res://scripts/drone_rewards.gd").create_drone(random,g.hyperspace.config,"feedback-rebuild","blue","laser",1,"1")
 preload("res://scripts/drone_inventory.gd").insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 g.profile.hyperspace.inventory.equipped=[d.id];g.invalidate_stat_cache()
 g.hyperspace_totals().legendary.drone_rebuild={"constants":{"maximum_stacks":1},"parameters":{"damage_and_defence_bonus":0.0}}
 g.hit_player(N.multiply(N.add(g.player.armour,g.player.shield),1000),2)
 check(reports.is_empty() and g.state==g.State.COMBAT and N.compare(g.player.armour,0)>0 and g.drone_combat.rebuild_stacks==1,"successful drone rebuild never reports defeat")
 # The ordinary notification path must remain usable without replacing the result.
 var ui=preload("res://scripts/main.gd").new();ui.game=g;ui.help_open=false;g.pending_unlocks.clear()
 ui.defeat_recall=Label.new();ui.add_child(ui.defeat_recall)
 ui.on_event("battle_defeated",{"manual":false,"remaining":5});var result=ui.defeat_notice
 ui.on_event("retreat",{"to":100})
 ui.on_event("save_success",{})
 ui.on_event("collect",{"id":"1","amount":10})
 var notices=ui.battle_notices()
 check(notices.size()==3 and notices[0].text==result and notices[1].text==UIText.t("save.success") and notices[2].resources==["1"],"defeat, save and ordinary resource notices coexist")
 ui.toast("ordinary later notice");ui.advance_defeat_notice(3.0)
 check(ui.battle_notices()[0].text==result and ui.defeat_notice_time==0.5,"ordinary toast cannot replace important result during readable interval")
 ui.help_open=true;ui.advance_defeat_notice(10);ui.help_open=false
 check(ui.defeat_notice_time==0.5,"help does not consume hidden result readable time")
 g.pending_unlocks.append("fixture");ui.advance_defeat_notice(10);g.pending_unlocks.clear()
 check(ui.defeat_notice_time==0.5,"unlock overlay does not consume hidden result readable time")
 ui.advance_defeat_notice(0.5)
 check(ui.defeat_notice_time==0 and ui.battle_notices()[0].text=="ordinary later notice","result expires independently after3.5seconds")
 check(ui.defeat_recall.tooltip_text.contains(result),"last defeat remains available by hover after toast expiry")
 var recall=ui.defeat_recall
 ui.on_event("battle_defeated",{"manual":true,"remaining":3});ui.toast("ordinary return notice")
 check(ui.battle_notices()[0].text.begins_with("异空间战败"),"manual result also survives ordinary return toast")
 check(ui.defeat_recall==recall and ui.defeat_recall.tooltip_text.contains("异空间战败") and not ui.defeat_recall.tooltip_text.contains("主线战败"),"latest defeat replaces single recall entry without rebuilding control")
 ui.free()
 print("Battle defeat feedback: %d checks, %d failures"%[checks,failures]);call_deferred("quit",1 if failures else 0)
