extends SceneTree
## Actual viewport mouse events with synthetic drops; no player save.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func show_qa_tools() -> void:pass
var scene
var checks := 0
var failures := 0
var serial := 9000
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func drop(id: String,point := Vector2(300,350),furnace := false) -> Dictionary:
 serial+=1
 var entry := {"uid":serial,"id":id,"x":point.x,"y":point.y,"age":0.0,"amount":17.0}
 if furnace:entry.hightech=true
 if id=="jewel":entry.jewel=true;entry.jewelRatio=1.0
 scene.game.drops.append(entry)
 return entry
func screen(point: Vector2) -> Vector2:
 return root.get_final_transform()*scene.battle_layer.get_global_transform()*scene.battle_point(point)
func motion_render(point: Vector2,from: Variant = null) -> void:
 var transform: Transform2D=root.get_final_transform()*scene.battle_layer.get_global_transform()
 var event:=InputEventMouseMotion.new();event.position=transform*point;event.global_position=event.position
 event.relative=event.position-transform*from if from is Vector2 else Vector2.ZERO
 Input.parse_input_event(event);await process_frame;await process_frame
func motion(point: Vector2,from: Variant = null) -> void:
 await motion_render(scene.battle_point(point),scene.battle_point(from) if from is Vector2 else null)
func capture(name: String) -> void:
 var folder:=OS.get_environment("RESOURCE_HOVER_EVIDENCE")
 if folder.is_empty():return
 scene.drop_layer.queue_redraw();scene.resource_layer.queue_redraw();scene.overlay_layer.queue_redraw()
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run() -> void:
 root.size=Vector2i(1373,883);root.position=Vector2i.ZERO
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.pending_unlocks.clear();g.profile.highestLevel=90;g.profile.cleared=range(1,90);g.rebuild_unlocks()
 g.profile.onboarding.completed=true;g.profile.resources={"1":0.0,"2":0.0};g.profile.jewelFragments=0.0;g.drops.clear();g.paused=false
 scene.refresh_navigation()
 await process_frame;await process_frame
 # All live entry categories share collection, including configured auto generation.
 for kind in ["iron","uranium","auto","iron-furnace","fragment","fragment-furnace"]:
  var id: String="jewel" if kind.contains("fragment") else ("2" if kind=="uranium" or kind=="auto" else "1")
  var entry:=drop(id,Vector2(300,350),kind.contains("furnace"))
  if kind=="auto":entry.auto_gen=true;entry.speed=40.0
  var before: float=float(g.profile.jewelFragments if id=="jewel" else g.profile.resources[id])
  await motion(Vector2(300,350))
  var after: float=float(g.profile.jewelFragments if id=="jewel" else g.profile.resources[id])
  check(not g.drops.has(entry) and after==before+17,"Hover credits full "+kind)
  await motion(Vector2(300,350));await motion(Vector2(100,350));await motion(Vector2(300,350));g.collect(entry,true)
  check(float(g.profile.jewelFragments if id=="jewel" else g.profile.resources[id])==after,"Stay/reentry/stale collection cannot credit twice: "+kind)
 var first:=drop("1",Vector2(200,350),true);var second:=drop("2",Vector2(400,350))
 var iron: float=float(g.profile.resources["1"]);var uranium: float=float(g.profile.resources["2"])
 await capture("before-hover")
 await motion(Vector2(510,350),Vector2(90,350))
 check(not g.drops.has(first) and not g.drops.has(second) and g.profile.resources["1"]==iron+17 and g.profile.resources["2"]==uranium+17,"One fast motion collects multiple crossed drops")
 await capture("after-hover")
 var entering:=drop("1",Vector2(80,350))
 await motion(Vector2(500,350),Vector2(-100,350))
 check(not g.drops.has(entering),"Outside-to-inside motion collects crossed edge resource")
 var leaving:=drop("1",Vector2(500,350))
 await motion(Vector2(700,350),Vector2(100,350))
 check(not g.drops.has(leaving),"Inside-to-outside motion collects crossed edge resource")
 var crossing:=drop("2",Vector2(300,350))
 await motion(Vector2(700,350),Vector2(-100,350))
 check(not g.drops.has(crossing),"Two outside endpoints still sweep the clipped battlefield")
 var diagonal:=drop("1",Vector2(341.2,420))
 await motion_render(Vector2(562,900),Vector2(10,250))
 check(not g.drops.has(diagonal),"Rendered diagonal picks the nonlinear-map regression resource without radius inflation")
 var partial:=ColorRect.new();partial.color=Color(0.15,0.3,0.4);partial.mouse_filter=Control.MOUSE_FILTER_STOP;partial.z_index=100
 partial.position=scene.battle_layer.get_global_transform()*scene.battle_point(Vector2(300,350))-Vector2(60,60);partial.size=Vector2(120,120)
 scene.add_child(partial);await process_frame
 var under:=drop("1",Vector2(300,350));var before_cover:=drop("1",Vector2(100,350));var after_cover:=drop("2",Vector2(500,350))
 await capture("partial-cover-before")
 await motion(Vector2(560,350),Vector2(10,350))
 check(g.drops.has(under) and not g.drops.has(before_cover) and not g.drops.has(after_cover),"Uncovered endpoints cannot collect through partial GUI cover; exposed drops still collect")
 await capture("partial-cover-after")
 var ending_on_gui:=drop("1",Vector2(100,350))
 await motion(Vector2(300,350),Vector2(10,350))
 check(g.drops.has(under) and not g.drops.has(ending_on_gui),"Motion ending on GUI retains its exposed path")
 var starting_on_gui:=drop("1",Vector2(500,350))
 await motion(Vector2(560,350),Vector2(300,350))
 check(g.drops.has(under) and not g.drops.has(starting_on_gui),"Motion starting on GUI retains its exposed path")
 partial.queue_free();await process_frame;g.drops.erase(under)
 var blocked:=drop("1")
 scene.help_open=true;scene.refresh_navigation();await motion(Vector2(300,350))
 check(g.drops.has(blocked),"Help overlay blocks hover")
 scene.help_open=false;g.pending_unlocks.append("laser");await motion(Vector2(300,350))
 check(g.drops.has(blocked),"Unlock overlay blocks hover")
 g.pending_unlocks.clear();scene.refresh_navigation()
 var cover:=ColorRect.new();cover.position=scene.battle_clip.position;cover.size=scene.battle_clip.size;cover.mouse_filter=Control.MOUSE_FILTER_STOP;cover.z_index=100
 scene.add_child(cover);await process_frame
 await motion(Vector2(300,350))
 check(g.drops.has(blocked),"GUI-consumed mouse motion cannot collect through a control")
 cover.queue_free();await process_frame
 var dialog:=AcceptDialog.new();scene.add_child(dialog);dialog.exclusive=true;dialog.popup_centered(Vector2i(800,600));await process_frame
 await motion(Vector2(300,350))
 check(g.drops.has(blocked),"Exclusive native dialog blocks battlefield hover")
 dialog.hide();dialog.queue_free();await process_frame
 g.paused=true;await motion(Vector2(300,350));check(g.drops.has(blocked),"Paused collection remains blocked")
 g.paused=false
 for down in [true,false]:
  var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.position=screen(Vector2(300,350));Input.parse_input_event(click);await process_frame
 check(not g.drops.has(blocked),"Existing click/touch-emulated click collection still works")
 var core:=drop("jewel",Vector2(300,350),true)
 var fragments: float=float(g.profile.jewelFragments)
 g.collect(core,false)
 check(g.drops.has(core) and g.profile.jewelFragments==fragments,"Fragment furnace keeps its pre-expiry automatic collection guard")
 core.age=10.0;g.collect(core,false)
 var recycled:=ceilf(17.0*(1.0-float(g.db.config.autoCollectReduce)))
 check(not g.drops.has(core) and g.profile.jewelFragments==fragments+recycled,"Fragment furnace expiry retains configured automatic loss")
 g.collect(core,true)
 check(g.profile.jewelFragments==fragments+recycled,"Expired fragment furnace cannot credit twice")
 check(not g.save_enabled,"Fixture writes no player save")
 print("RESOURCE HOVER: %d checks, %d failures" % [checks,failures])
 scene.queue_free();await process_frame;quit(1 if failures else 0)
