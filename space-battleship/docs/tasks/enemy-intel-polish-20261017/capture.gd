extends SceneTree

const MAIN = preload("res://main.tscn")
var viewport: SubViewport
var host: Node
var page: Control

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var out := ProjectSettings.globalize_path("res://docs/tasks/enemy-intel-polish-20261017/evidence")
 DirAccess.make_dir_recursive_absolute(out)
 viewport=SubViewport.new()
 viewport.size=Vector2i(1440,900)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 host=MAIN.instantiate()
 viewport.add_child(host)
 for i in 8:await _frame()
 page=host.enemy_intel_page
 assert(page!=null)
 host.equipment_tabs.current_tab=11
 page.refresh_if_needed()
 await _frame()
 assert(page.route_builds==1)
 assert(page.selected_point==page.current_point)
 _capture(out+"/overview.png")
 if page.point_buttons.size()>1:
  page.point_buttons[1].pressed.emit()
  await _frame()
  assert(not page.follow_current)
  _capture(out+"/alternate-point.png")
  page.follow_button.pressed.emit()
  await _frame()
  assert(page.follow_current)
 if page.visible_entry_indices.size()>1:
  page.list.select(1)
  page.list.item_selected.emit(1)
  await _frame()
  _capture(out+"/alternate-ship.png")
 page.details_button.button_pressed=true
 await _frame()
 assert(page.detail_scroll.visible)
 _capture(out+"/details.png")
 var builds:int=page.route_builds
 page.refresh_if_needed()
 assert(page.route_builds==builds)
 var report:=FileAccess.open(out+"/checks.txt",FileAccess.WRITE)
 report.store_string("stage=%d\npoints=%d\nentries=%d\nroute_builds=%d\ndetail_builds=%d\n" % [host.game.stage,page.point_buttons.size(),page.entries.size(),page.route_builds,page.detail_builds])
 report.close()
 quit()

func _frame() -> void:
 await process_frame
 await RenderingServer.frame_post_draw

func _capture(path: String) -> void:
 viewport.get_texture().get_image().save_png(path)
