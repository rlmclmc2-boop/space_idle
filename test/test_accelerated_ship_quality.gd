extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; printerr("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view = load("res://scripts/presented_ship_view.gd").new()
 view.size = BattleGame.BATTLE_SIZE
 root.add_child(view)
 check(view.set_hull("Heavy_Battleship"),"live hull exists")
 var entries: Array = []
 for i in 8: entries.append({"key":"missile","level":150})
 view.set_loadout(entries,8)
 view.set_pose(Vector2(286,520),180,0,Vector2(286,100),1,false,false,0)
 view.set_rendering(true)
 var points: Array = []
 for i in 8:
  for ordinal in 5:points.append(view.screen_muzzle_for_slot(i,ordinal))
 var original_size = view.viewport.size
 for accelerated in [true,false,true,false]:
  view.set_accelerated_quality(accelerated)
  check(view.viewport.msaa_3d == (Viewport.MSAA_DISABLED if accelerated else Viewport.MSAA_4X),"quality transitions restore MSAA")
  check(view.world.get_node("KeyLight").shadow_enabled == not accelerated,"quality transitions restore live shadows")
  check(view.visible and view.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,"battlefield continues rendering every frame")
  check(view.viewport.size == original_size,"canonical viewport resolution unchanged")
  for i in 8:
   for ordinal in 5:check(view.screen_muzzle_for_slot(i,ordinal) == points[i*5+ordinal],"every slot/tube launch coordinate unchanged")
 view.set_rendering(true,true)
 view.set_accelerated_quality(true)
 check(view.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,"paused redraw policy preserved")
 view.set_rendering(false)
 view.set_accelerated_quality(false)
 check(not view.visible and view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden rendering policy preserved")
 view.free()
 print("ACCELERATED SHIP QUALITY: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
