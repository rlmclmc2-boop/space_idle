extends SceneTree

const MAIN = preload("res://main.tscn")
var viewport: SubViewport
var host: Node
var page: Control

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var compact:=OS.get_cmdline_user_args().has("small")
 var out := ProjectSettings.globalize_path("res://docs/tasks/enemy-intel-polish-20261017/evidence")
 if compact:out=out.path_join("1440x900")
 DirAccess.make_dir_recursive_absolute(out)
 viewport=SubViewport.new()
 viewport.size=Vector2i(1440,900) if compact else Vector2i(1920,1080)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 host=MAIN.instantiate()
 viewport.add_child(host)
 for i in 8:await _frame()
 page=host.enemy_intel_page
 assert(page!=null)
 var baseline_tab_size:Vector2=host.equipment_tabs.size
 host.equipment_tabs.current_tab=11
 page.refresh_if_needed()
 await _frame()
 assert(page.route_builds==1)
 assert(page.selected_point==page.current_point)
 assert(page.get_global_rect().end.x<=viewport.size.x)
 assert(page.get_global_rect().end.y<=viewport.size.y)
 assert(page.follow_button.get_global_rect().end.x<=viewport.size.x)
 _capture(out+"/overview.png")
 var page_rect:=page.get_global_rect()
 var follow_rect:Rect2=page.follow_button.get_global_rect()
 if page.point_buttons.size()>1:
  _click(page.point_buttons[1].get_global_rect().get_center())
  await _frame()
  assert(not page.follow_current)
  _capture(out+"/alternate-point.png")
  host.game.group_index=3
  page.refresh_if_needed()
  assert(page.selected_point==1)
  assert(page.current_point==2)
  _click(page.follow_button.get_global_rect().get_center())
  await _frame()
  assert(page.follow_current)
  assert(page.selected_point==2)
 if page.visible_entry_indices.size()>1:
  _click(page.list.get_global_transform_with_canvas()*page.list.get_item_rect(1).get_center())
  await _frame()
  _capture(out+"/alternate-ship.png")
 _click(page.details_button.get_global_rect().get_center())
 await _frame()
 assert(page.detail_scroll.visible)
 assert(page.detail_scroll.get_global_rect().end.y<=viewport.size.y)
 _capture(out+"/details.png")
 _click(page.details_button.get_global_rect().get_center())
 await _frame()
 assert(not page.detail_scroll.visible)
 var builds:int=page.route_builds
 page.refresh_if_needed()
 assert(page.route_builds==builds)
 host.equipment_tabs.current_tab=0
 assert(host.equipment_tabs.size==baseline_tab_size)
 host.game.stage=2
 host.game.group_index=1
 page.refresh_if_needed()
 assert(page.route_builds==builds)
 host.equipment_tabs.current_tab=11
 page.refresh_if_needed()
 await _frame()
 assert(page.route_stage==2)
 assert(page.route_builds==builds+1)
 _capture(out+"/stage-2.png")
 var report:=FileAccess.open(out+"/checks.txt",FileAccess.WRITE)
 report.store_string("stage=%d\npoints=%d\nentries=%d\nroute_builds=%d\ndetail_builds=%d\nmanual_browse_preserved=true\nhidden_skipped=true\npage_rect=%s\nfollow_rect=%s\n" % [host.game.stage,page.point_buttons.size(),page.entries.size(),page.route_builds,page.detail_builds,str(page_rect),str(follow_rect)])
 report.close()
 quit()

func _frame() -> void:
 await process_frame
 await RenderingServer.frame_post_draw

func _capture(path: String) -> void:
 viewport.get_texture().get_image().save_png(path)

func _click(position: Vector2) -> void:
 for is_pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=position
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=is_pressed
  viewport.push_input(event,true)
