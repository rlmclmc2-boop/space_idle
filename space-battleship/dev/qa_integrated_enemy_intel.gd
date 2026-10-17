extends SceneTree
const MAIN=preload("res://main.tscn")
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1440,900)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var host=MAIN.instantiate()
 viewport.add_child(host)
 for i in 8:await process_frame
 host.equipment_tabs.current_tab=11
 var page=host.enemy_intel_page
 assert(page!=null)
 var expected=[8,9,9,9]
 for stage in range(4,8):
  host.game.stage=stage
  host.game.group_index=1
  page.refresh_if_needed()
  await process_frame
  assert(page.route_stage==stage)
  assert(page.point_buttons.size()==expected[stage-4])
  var names=[]
  for point in range(expected[stage-4]):
   page.show_point(point)
   await process_frame
   assert(page.selected_point==point)
   for index in page.visible_entry_indices:
    var row=host.db.enemies[page.entries[index].id]
    names.append(str(row.get("intelName",row.des)))
   assert(page.get_global_rect().end.x<=viewport.size.x)
   assert(page.get_global_rect().end.y<=viewport.size.y)
  print("QA_INTEL_INTEGRATED ",JSON.stringify({"stage":stage,"points":page.point_buttons.size(),"entries":names.size(),"page_end":page.get_global_rect().end}))
 quit()