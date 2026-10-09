extends SceneTree
const A=preload("res://scripts/reactor_automation.gd")
const I=preload("res://scripts/reactor_integer.gd")
const G=preload("res://scripts/reactor_allocation_growth.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture():
 var g=BattleGame.new(ShipDatabase.new(),false);g.save_enabled=false;g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear()
 g.set_reactor_allocation("weapons",70);g.set_reactor_allocation("defence",20)
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for upgrading in [false,true]:
  for allocating in [false,true]:
   var g=fixture();var c=g.crew
   check(g.profile.reactorAutomation.upgrade and not g.profile.reactorAutomation.allocate and g.profile.reactorAutomation.presets==[{},{},{}],"Default upgrade-on/allocation-off and three empty slots")
   check(c.assign(g,"navigator","reactor_upgrade","reactor") and not c.assign(g,"engineer","reactor_upgrade","reactor"),"Original single-crew assignment gate retained")
   var old=g.profile.reactorAllocation.duplicate(true);var capacity=g.reactor_capacity();var level=g.profile.reactorLevel
   A.set_enabled(g,"upgrade",upgrading);A.set_enabled(g,"allocate",allocating)
   check(g.profile.reactorAllocation==old,"Changing preferences does not suddenly equalize or allocate")
   g.profile.resources["2"]=g.reactor_upgrade_cost();c.invalidate_resources(g,["2"])
   c.advance(g,0.9);check(g.profile.reactorLevel==level and g.profile.reactorAllocation==old,"Both jobs retain original one-second clock")
   c.advance(g,0.1)
   var expected=A.allocation(g,g.profile.reactorAutomation.ratio) if allocating else G.expand(Array(g.reactor_modules()),old,capacity,g.reactor_capacity())
   check(g.profile.reactorLevel==level+(1 if upgrading else 0) and g.profile.reactorAllocation==expected,"Four switch combinations buy independently and preserve current/target shares")
   check(I.compare(g.reactor_allocated(),g.reactor_capacity())<=0 and g.profile.reactorAllocation.values().all(func(v):return I.valid(v)),"All combinations retain integer energy and idle capacity")
   var target=expected.duplicate(true);g.set_reactor_allocation("weapons",0);var edited=g.profile.reactorAllocation.duplicate(true)
   g.profile.resources["2"]=0;c.invalidate_resources(g,["2"]);c.advance(g,1)
   check(g.profile.reactorAllocation==edited,"Unaffordable upgrade preserves the latest user target in either allocation mode")
   A.set_enabled(g,"allocate",false);var stopped=g.profile.reactorAllocation.duplicate(true);c.advance(g,1)
   check(g.profile.reactorAllocation==stopped,"Disabling allocation retains current distribution without restoring an older one")
   A.set_enabled(g,"allocate",allocating);c.assign(g,"navigator","","");g.set_reactor_allocation("weapons",1);var idle=g.profile.reactorAllocation.duplicate(true)
   g.profile.resources["2"]=g.reactor_upgrade_cost();var before_level=g.profile.reactorLevel;c.advance(g,2)
   check(g.profile.reactorLevel==before_level and g.profile.reactorAllocation==idle,"No dispatched crew means neither automatic function runs")
   c.assign(g,"navigator","reactor_upgrade","reactor");c.advance(g,0.9)
   check(g.profile.reactorLevel==before_level and g.profile.reactorAllocation==idle,"Redispatch uses saved preferences with a fresh clock")
   c.advance(g,0.1)
   check(g.profile.reactorLevel==before_level+(1 if upgrading else 0) and (not allocating or g.profile.reactorAllocation==A.allocation(g,g.profile.reactorAutomation.ratio)),"Redispatch restores both independent preferences and stored target")
 var g=fixture();var current=g.profile.reactorAllocation.duplicate(true);var ratio=A.capture(g);var rng=g.rng.state;var remembered=g.profile.reactorAutomation.ratio.duplicate(true)
 check(A.save_slot(g,0,ratio) and g.profile.reactorAllocation==current and g.profile.reactorAutomation.ratio==remembered and g.rng.state==rng,"Saving current ratio to a slot never applies it or changes target/RNG")
 check(not A.apply_slot(g,1) and g.profile.reactorAllocation==current,"Empty preset cannot apply or overwrite anything")
 A.set_enabled(g,"upgrade",false);A.save_slot(g,1,A.balanced(g));g.equalize_reactor_allocation()
 check(A.apply_slot(g,0) and g.profile.reactorAllocation==current and not g.profile.reactorAutomation.upgrade and not g.profile.reactorAutomation.allocate,"Manual preset application needs no crew and changes no automation switches")
 check(g.equalize_reactor_allocation() and I.compare(g.reactor_allocated(),g.reactor_capacity())==0,"Original manual equalize button ability remains independent")
 var saved=JSON.parse_string(JSON.stringify(g.portable_save_data()));var transfer=Transfer.new();var prepared=transfer.prepare_data(saved,g.db)
 check(prepared.error=="","Portable save accepts preference/three-slot ratio schema")
 var loaded=BattleGame.new(g.db,false);loaded.save_enabled=false;loaded.load_progress_data(prepared.data)
 check(loaded.profile.reactorAutomation==g.profile.reactorAutomation and loaded.profile.reactorAllocation==g.profile.reactorAllocation,"Actual JSON save/load retains switches, target and all three presets")
 saved.erase("reactorAutomation");loaded.load_progress_data(saved)
 check(loaded.profile.reactorAutomation==A.fresh(),"Existing saves without new preferences default upgrade-on/allocation-off")
 var bad=g.portable_save_data();bad.reactorAutomation.presets.append({})
 check(transfer.prepare_data(bad,g.db).error=="format","Malformed preset count is rejected by formal import")
 var uneven={"total":7,"weights":{"weapons":2,"defence":3}}
 var projected=A.allocation(g,uneven);var parts=G.distribute(g.reactor_capacity(),[2,3,2],7)
 check(projected.weapons==parts[0] and projected.defence==parts[1] and I.compare(g.reactor_allocated(),g.reactor_capacity())<=0,"Non-divisible target conserves integer module and idle shares")
 var huge={"total":"100000000000000000000","weights":{"weapons":"70000000000000000000","defence":"20000000000000000000"}}
 check(A.save_slot(g,2,huge) and A.encode_state(g.profile.reactorAutomation).presets[2].total is String,"Large exact ratio weights persist without JSON integer precision loss")
 var raw=g.portable_save_data();var restored=BattleGame.new(g.db,false);restored.save_enabled=false;restored.load_progress_data(JSON.parse_string(JSON.stringify(raw)))
 check(restored.profile.reactorAutomation.presets[2]==huge,"Canonical large integer ratio survives real serialization and loader")
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
 scene.game.profile.cleared=range(1,41);scene.game.profile.highestLevel=41;scene.game.rebuild_unlocks();scene.game.pending_unlocks.clear();scene.refresh_tab_visibility();scene.select_system(3);await process_frame
 var ui=scene.reactor_panel.automation_ui
 check(ui.upgrade.button_pressed and not ui.allocate.button_pressed and ui.presets.all(func(b):return b.disabled),"Native compact controls expose defaults and distinct empty slots")
 ui.show_settings();check(ui.sliders.size()==scene.game.reactor_modules().size() and ui.dialog.visible,"Custom ratio controls exist only in secondary settings")
 var old=scene.game.profile.reactorAllocation.duplicate(true);ui.edit_ratio("weapons",80);ui.edit_ratio("defence",50)
 check(ui.draft.weights.weapons+ui.draft.weights.defence<=100 and scene.game.profile.reactorAllocation==old,"Editing a secondary draft clamps totals and does not apply before confirmation")
 A.save_slot(scene.game,0,ui.draft);ui.refresh();ui.dialog.hide();ui.presets[0].pressed.emit()
 check(scene.game.profile.reactorAllocation==A.allocation(scene.game,ui.draft) and scene.game.profile.reactorAutomation.upgrade and not scene.game.profile.reactorAutomation.allocate,"Native main preset applies manually without changing switches")
 ui.allocate.button_pressed=true;ui.upgrade.button_pressed=false
 check(scene.game.profile.reactorAutomation.allocate and not scene.game.profile.reactorAutomation.upgrade,"Native switches persist independent preferences")
 scene.queue_free();await process_frame
 print("CREW REACTOR: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
