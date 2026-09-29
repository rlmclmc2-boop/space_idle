extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr(label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var db := ShipDatabase.new()
 var g := BattleGame.new(db, false)
 var planets: Array = db.data.planet.keys()
 planets.sort_custom(func(a,b):return int(a)<int(b))
 g.profile.cleared = range(1, 101)
 g.rebuild_unlocks()
 check(g.planet_unlocked(str(planets[0])), "First planet needs only its normal gate")
 for i in range(1, planets.size()):
  var id := str(planets[i])
  g.profile.planets[id].unlocked = true
  check(not g.planet_unlocked(id), "Old unlocked flag cannot bypass conquest: " + id)
  check(not g.unlock_available(str(db.data.planet[id].unlockId)), "No premature unlock notification: " + id)
  g.profile.planets[str(planets[i-1])].conquered = true
  check(g.planet_unlocked(id), "Conquest plus earned gate unlocks: " + id)
 var restricted := BattleGame.new(db, false)
 restricted.profile.planets["1"].conquered = true
 check(not restricted.planet_unlocked("2"), "Conquest alone does not bypass level gate")
 var gate: Dictionary = db.data.unlock[db.data.planet["2"].unlockId]
 restricted.profile.cleared = range(1, int(gate.level)+1)
 restricted.rebuild_unlocks()
 check(restricted.planet_unlocked("2"), "Normal threshold completes both requirements")
 # A different mapping proves this is driven by target ID, not planet index arithmetic.
 var alt := ShipDatabase.new()
 for row in alt.data.planet_buff.values():
  if row.buff_type != "planet_unlock":continue
  if int(row.planet_id)==1:row.value=3
  elif int(row.planet_id)==2:row.planet_id=3;row.value=2
 var alternate := BattleGame.new(alt,false)
 alternate.profile.cleared=range(1,101)
 alternate.rebuild_unlocks()
 alternate.profile.planets["1"].conquered=true
 check(alternate.planet_unlocked("3") and not alternate.planet_unlocked("2"), "Changed target ID controls unlock")
 var fresh := BattleGame.new(db,false)
 fresh.profile.cleared=range(1,101);fresh.rebuild_unlocks()
 fresh.profile.planets["1"].degree=1000
 fresh.planet_buildings.sync(fresh,"1")
 for row in fresh.planet_buildings.rows(fresh,"1"):
  var item: Dictionary=fresh.planet_buildings.state(fresh,"1",str(row.id))
  item.build_progress=row.build_explore
 fresh.planet_buildings.sync(fresh,"1")
 check(fresh.planet_buildings.has_ready(fresh), "Ready facilities generate notification")
 check(fresh.planet_equipment_multiplier()==1 and fresh.planet_resource_multiplier()==1, "Ready facilities provide no effects")
 check(not fresh.can_reforge_planet("1") and not fresh.set_planet_auto("1",true), "Ready station and shipyard cannot be used")
 var saved: Dictionary=fresh.profile.planets.duplicate(true)
 fresh.load_planets(saved)
 check(fresh.planet_buildings.state(fresh,"1","shipyard").status=="ready", "Pending activation survives reload")
 for row in fresh.planet_buildings.rows(fresh,"1"):
  check(fresh.planet_buildings.activate(fresh,"1",str(row.id)), "Activate "+str(row.id))
  check(not fresh.planet_buildings.activate(fresh,"1",str(row.id)), "Activation is one-use "+str(row.id))
 check(not fresh.planet_buildings.has_ready(fresh), "Last activation removes notification")
 check(fresh.planet_equipment_multiplier()>1 and fresh.planet_resource_multiplier()>1, "Activated facilities provide effects")
 check(fresh.reforge_planet("1"), "Actual reforge succeeds")
 check(fresh.planet_unlocked("2") and not fresh.planet_unlocked("3"), "Actual reforge opens only configured successor")
 fresh.save_enabled=true;fresh.save_progress();fresh.save_enabled=false
 var loaded := BattleGame.new(db,false)
 loaded.load_progress()
 check(loaded.planet_unlocked("2") and not loaded.planet_unlocked("3"), "Reforge gates persist through disk save/load")
 # UI: completion off-page shows the badge; button activation clears it locally.
 var viewport := SubViewport.new()
 viewport.size=Vector2i(1952,1256);viewport.gui_embed_subwindows=true
 root.add_child(viewport)
 var scene=load("res://scripts/main.gd").new()
 scene.automation_args=["--capture"]
 viewport.add_child(scene)
 scene.automation_args=[];scene.set_process(false);scene.game.save_enabled=false
 var ui_game=scene.game
 ui_game.profile=ui_game.fresh_profile();ui_game.load_planets({})
 ui_game.profile.cleared=range(1,101);ui_game.rebuild_unlocks()
 scene.refresh_structure();scene.select_system(0)
 ui_game.profile.planets["1"].degree=1000
 ui_game.planet_buildings.sync(ui_game,"1")
 ui_game.profile.planets["1"].buildings.station.build_progress=db.data.planet_build.station.build_explore
 ui_game.planet_buildings.sync(ui_game,"1")
 ui_game.event.emit("planet_changed",{"id":"1"})
 var dot: Control=scene.system_nav_buttons[6].get_node("ActivationBadge")
 check(dot.visible,"Hidden planet page still updates badge")
 scene.select_system(6);scene.planet_panel.refresh()
 var card: Dictionary=scene.planet_panel.cards["1"]
 var button: Button=card.facility_buttons.station.assign
 check(button.visible and button.text==UIText.t("planet.activate"),"Completed card offers activation")
 await process_frame
 check(scene.system_nav_buttons[6].get_global_rect().encloses(dot.get_global_rect()),"Badge stays within tab")
 button.pressed.emit()
 check(ui_game.planet_buildings.built(ui_game,"1","auto_explore") and not dot.visible,"Activation button enables and clears badge")
 check(scene.planet_panel.cards["1"].root==card.root,"Activation preserves existing card instance")
 await process_frame
 await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png("res://.runtime/activation.png")
 print("PLANET GATES: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
