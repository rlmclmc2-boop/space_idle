extends SceneTree
const TutorialProjection=preload("res://scripts/tutorial_ui_projection.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func equal(g,p,label:String)->void:
 p.sync(g);check(p.ids==g.tutorial_unlocks() and p.unread==g.unread_tutorial_unlocks(),label)
func _initialize()->void:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g:=BattleGame.new(db,false);g.save_enabled=false
 var p=TutorialProjection.new()
 g.event.connect(func(kind,info):p.on_event(g,kind,info))
 equal(g,p,"initial immediate query equality")
 var builds:int=p.builds;var reads:int=p.read_builds
 for _i in 120:p.sync(g)
 check(p.builds==builds and p.read_builds==reads,"steady hidden projection zero rebuild")
 g.profile.cleared=range(1,21);g.rebuild_unlocks();equal(g,p,"reached/cleared/granted owner event")
 var id:String=p.unread[0];builds=p.builds
 check(g.read_tutorial_unlock(id),"public read accepted")
 equal(g,p,"read flag event matches immediate unread")
 check(p.builds==builds,"reading performs no qualification scan")
 g.pending_unlocks=[id];g.acknowledge_unlocks();equal(g,p,"notice acknowledgment seen event")
 var gate:int=int(g.hyperspace.config.unlock_stage)
 g.profile.highestLevel=gate;p.sync(g);check(p.ids.has("hyperspace"),"live highest gate guard")
 g.hyperspace.config.unlock_stage=gate+1;equal(g,p,"in-place hyperspace gate edit")
 var old:Dictionary=db.data.unlock
 db.data.unlock=old.duplicate(true);equal(g,p,"configuration table replacement identity invalidation")
 builds=p.builds
 var target:String=str(db.data.unlock.keys()[0]);db.data.unlock[target].level=999
 g.event.emit("configuration_changed",{});equal(g,p,"explicit in-place configuration update invalidation")
 check(p.builds==builds+1,"configuration rebuild once")
 var key:String=str(g.galaxy.regions.keys()[0]);var region=g.galaxy.regions[key]
 p.sync(g);builds=p.builds
 region.state.status="exploring";g.event.emit("galaxy_changed",{"key":key});p.sync(g)
 check(p.builds==builds,"ordinary galaxy activity keeps static eligibility")
 region.state.status="complete";g.event.emit("galaxy_changed",{"key":key});equal(g,p,"galaxy completion invalidates eligibility")
 builds=p.builds;g.event.emit("galaxy_changed",{"key":key});p.sync(g);check(p.builds==builds,"unchanged complete status does not rebuild")
 g.profile.planets["1"].conquered=true;g.event.emit("planet_changed",{"id":"1"});equal(g,p,"planet conquest/next planet qualification")
 var saved:Dictionary=g.profile.duplicate(true)
 var canonical:=BattleGame.new(db,false)
 canonical.load_progress_data(saved)
 var expected_status:String=canonical.galaxy.regions[key].state.status
 region.state.status="locked" if expected_status!="locked" else "exploring"
 var loaded_status:Array=[]
 g.event.connect(func(kind,_info):
  if kind=="progress_loaded":loaded_status.append(g.galaxy.regions[key].state.status))
 g.load_progress_data(saved);equal(g,p,"load completion invalidates reads and eligibility")
 check(loaded_status==[expected_status],"load event observes canonical restored galaxies, not intermediate hightech state")
 check(p.ids.is_read_only() and p.unread.is_read_only(),"UI shared arrays cannot be changed by consumers")
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
 print("TUTORIAL_PROJECTION %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)

