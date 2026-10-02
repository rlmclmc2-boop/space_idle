extends SceneTree
## Real button and picker/confirmation input with isolated synthetic progress.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func show_qa_tools() -> void:pass
 func create_save_file_picker() -> FileDialog:
  var picker:=super.create_save_file_picker();picker.use_native_dialog=false;return picker
var checks:=0
var failures:=0
var scene
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func activate(control: BaseButton) -> void:
 await click(control,control.size*.5)
func click(control: Control,local: Vector2) -> void:
 var point:=root.get_final_transform()*(control.get_screen_transform()*local)
 DisplayServer.warp_mouse(point)
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
 Input.parse_input_event(motion)
 await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
  Input.parse_input_event(event)
  await process_frame
 await process_frame
func open_settings() -> void:
 await activate(scene.system_nav_buttons.back())
 check(scene.save_panel.is_visible_in_tree() and scene.equipment_tabs.current_tab==scene.equipment_tabs.get_tab_count()-1,"Real last navigation button opens Save page")
func item_lists(node: Node) -> Array:
 var result: Array=[]
 if node is ItemList:result.append(node)
 for child in node.get_children(true):result.append_array(item_lists(child))
 return result
func choose(path: String) -> void:
 if scene.save_file_dialog.file_mode==FileDialog.FILE_MODE_OPEN_FILE:
  scene.save_file_dialog.current_dir=ProjectSettings.globalize_path(path).get_base_dir()
  scene.save_file_dialog.current_file=""
 else:scene.save_file_dialog.current_path=ProjectSettings.globalize_path(path)
 await process_frame;await process_frame
 if scene.save_file_dialog.file_mode==FileDialog.FILE_MODE_OPEN_FILE:
  for list in item_lists(scene.save_file_dialog):
   for i in list.item_count:
    if list.get_item_tooltip(i)==path.get_file() or list.get_item_text(i)==path.get_file():
     list.ensure_current_is_visible()
     await click(list,list.get_item_rect(i).get_center())
 await capture("picker")
 await activate(scene.save_file_dialog.get_ok_button())
func capture(name: String) -> void:
 var folder:=OS.get_environment("SAVE_TRANSFER_EVIDENCE")
 if folder.is_empty():return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+name+".png")
func freeze() -> void:
 scene=current_scene;scene.set_process(false);scene.game.paused=true
 scene.refresh_navigation()
func run() -> void:
 for path in ["user://ui-export.json","user://ui-galaxy-roundtrip.json"]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 root.size=Vector2i(1373,883);root.position=Vector2i.ZERO
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
 root.add_child(scene);current_scene=scene;scene.automation_args=[];freeze()
 var g=scene.game;g.profile.onboarding.completed=true;g.pending_unlocks.clear();scene.refresh_navigation();g.progress_writer.clear_files();g.save_enabled=true;g.profile.resources={"1":99.0,"2":88.0};g.save_progress();g.profile.resources={"1":789.0,"2":456.0}
 var original:=FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH);var before: Dictionary=g.profile.duplicate(true);var scene_id: int=scene.get_instance_id()
 await process_frame;await process_frame
 await open_settings()
 check(scene.system_nav_buttons.back().text==UIText.t("save.tab") and scene.system_nav_buttons.back().get_index()==scene.system_nav_buttons.back().get_parent().get_child_count()-1,"Save remains the final navigation item with locked systems")
 check(scene.guard_settings.get_popup().get_item_index(30)==-1,"Old save settings menu entry is removed")
 var page_id: int=scene.save_panel.get_instance_id()
 scene.save_interval_input.text="unfinished"
 scene.save_interval_input.grab_focus()
 scene.refresh_tab_visibility();scene.refresh_save_status();scene.refresh_navigation()
 check(scene.save_interval_input.text=="unfinished" and scene.save_interval_input.has_focus() and scene.save_panel.get_instance_id()==page_id,"Refresh retains save page, input focus and unfinished interval draft")
 await activate(scene.system_nav_buttons[7]);await open_settings()
 check(scene.save_interval_input.text=="unfinished" and scene.save_panel.get_instance_id()==page_id,"Switching tabs retains interval draft and existing page")
 check(g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Navigation and refresh do not save or modify progress")
 scene.save_interval_input.text=str(g.save_interval_minutes)
 check(scene.save_panel.find_child("ExportSave",true,false)!=null and scene.save_panel.find_child("ImportSave",true,false)!=null,"Transfer actions are visible on the Save page")
 await capture("save-page-locked")
 await activate(scene.save_panel.find_child("ExportSave",true,false))
 check(scene.save_file_dialog.visible and scene.save_file_dialog.file_mode==FileDialog.FILE_MODE_SAVE_FILE,"Export button opens save-file picker")
 await activate(scene.save_file_dialog.get_cancel_button())
 check(g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Export picker cancellation has no progress/file side effects")
 await activate(scene.save_panel.find_child("ExportSave",true,false))
 await choose("user://ui-export.json")
 check(FileAccess.file_exists("user://ui-export.json") and scene.save_transfer_feedback.text.contains("ui-export.json"),"Actual export selection produces portable file and visible success")
 check(g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Export preserves actual primary and unsaved runtime")
 var bad:=FileAccess.open("user://ui-future.json",FileAccess.WRITE);bad.store_string('{"version":999,"highestLevel":1,"resources":{"1":1,"2":2}}');bad.close()
 await activate(scene.save_panel.find_child("ImportSave",true,false));await choose("user://ui-future.json")
 check(scene.save_transfer_feedback.text==UIText.t("save.import_invalid_version") and scene.pending_import.is_empty(),"Future version is rejected before replacement confirmation")
 check(g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Rejected file leaves disk/runtime unchanged")
 var demo:=OS.get_environment("SAVE_TRANSFER_DEMO")
 check(not demo.is_empty() and FileAccess.file_exists(demo),"External galaxy review demo is available")
 if demo.is_empty():quit(1);return
 await activate(scene.save_panel.find_child("ImportSave",true,false));await choose(demo)
 check(scene.save_import_confirmation.visible and not scene.pending_import.is_empty(),"Real galaxy demo selection reaches explicit replacement confirmation")
 check(g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original and scene.get_instance_id()==scene_id,"Import preview leaves current runtime and original file untouched")
 await capture("confirmation")
 await activate(scene.save_import_confirmation.get_cancel_button())
 check(scene.pending_import.is_empty() and g.profile==before and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Confirmation cancellation is side-effect free")
 var old_backups:=DirAccess.get_directories_at(preload("res://scripts/save_transfer.gd").BACKUP_ROOT) if DirAccess.dir_exists_absolute(preload("res://scripts/save_transfer.gd").BACKUP_ROOT) else PackedStringArray()
 await activate(scene.save_panel.find_child("ImportSave",true,false));await choose(demo);await activate(scene.save_import_confirmation.get_ok_button())
 await process_frame;await process_frame;freeze()
 check(scene.get_instance_id()!=scene_id and scene.game.profile.cleared.has(75) and scene.game.galaxy.available(),"Confirmed UI import reloads normally with real galaxy unlock")
 check(scene.save_panel.is_visible_in_tree() and scene.save_transfer_feedback.text.contains("current-progress.json"),"Fresh scene shows import success and durable recovery location")
 var added:=Array(DirAccess.get_directories_at(preload("res://scripts/save_transfer.gd").BACKUP_ROOT)).filter(func(name):return not old_backups.has(name))
 check(added.size()==1,"One confirmation creates exactly one backup set")
 var recovery_path:=preload("res://scripts/save_transfer.gd").BACKUP_ROOT+"/"+str(added[0])+"/current-progress.json"
 check(JSON.parse_string(FileAccess.get_file_as_string(recovery_path)).resources["1"]==789,"Backup captures latest unsaved progress rather than only old on-disk file")
 check(scene.system_nav_buttons.back().visible and scene.system_nav_buttons.back().get_index()==scene.system_nav_buttons.back().get_parent().get_child_count()-1 and scene.equipment_tabs.get_tab_count()==10,"Save remains last after all imported systems unlock")
 await capture("save-page-unlocked")
 await activate(scene.system_nav_buttons[8])
 check(scene.equipment_tabs.current_tab==8 and scene.galaxy_panel.visible and scene.galaxy_panel.map.visible,"Native navigation enters the imported galaxy page")
 root.gui_release_focus()
 var play:=InputEventKey.new();play.keycode=KEY_SPACE;play.pressed=true;Input.parse_input_event(play)
 await process_frame
 play=InputEventKey.new();play.keycode=KEY_SPACE;play.pressed=false;Input.parse_input_event(play)
 scene.set_process(true)
 await process_frame;await process_frame
 check(scene.galaxy_panel.map.view.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Unpaused imported galaxy uses normal live map rendering")
 await capture("galaxy-imported")
 freeze()
 await open_settings();await activate(scene.save_panel.find_child("ExportSave",true,false))
 scene.save_file_dialog.use_native_dialog=false
 await choose("user://ui-galaxy-roundtrip.json")
 var exported: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://ui-galaxy-roundtrip.json"))
 check(exported.galaxies.has("galaxy_1") and exported.galaxies.galaxy_1.slots.size()==30,"Imported galaxy exports with all 30 real building slots")
 await activate(scene.save_panel.find_child("ImportSave",true,false));await choose("user://ui-galaxy-roundtrip.json");await activate(scene.save_import_confirmation.get_ok_button())
 await process_frame;await process_frame;freeze()
 check(scene.game.galaxy.available() and scene.game.galaxy.regions.galaxy_1.slots.size()==30,"Exported demo reimports through full UI flow")
 await activate(scene.save_panel.find_child("ImportSave",true,false));scene.save_file_dialog.use_native_dialog=false;await choose(recovery_path);await activate(scene.save_import_confirmation.get_ok_button())
 await process_frame;await process_frame;freeze()
 check(scene.game.profile.resources["1"]==789 and scene.game.profile.resources["2"]==456,"Persistent backup restores prior unsaved progress through normal import UI")
 var final_game=scene.game
 var final_bytes:=FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
 var original_interval: int=final_game.save_interval_minutes
 scene.save_interval_input.text="0"
 await activate(scene.save_panel.find_child("ApplySaveInterval",true,false))
 check(final_game.save_interval_minutes==original_interval and scene.save_interval_feedback.text==UIText.t("save.invalid_interval") and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==final_bytes,"Invalid interval displays feedback without writing")
 scene.save_interval_input.text="3"
 await activate(scene.save_panel.find_child("ApplySaveInterval",true,false))
 check(final_game.save_interval_minutes==3 and FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==final_bytes,"Apply changes interval without a save")
 scene.save_interval_input.text="unfinished"
 await activate(scene.save_panel.find_child("ManualSave",true,false))
 check(final_game.last_save_error==OK and str(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)).saveIntervalMinutes)=="3" and scene.save_interval_input.text=="unfinished","Manual button writes once with current interval and retains draft")
 DirAccess.make_dir_absolute(BattleGame.SAVE_PATH+".tmp")
 await activate(scene.save_panel.find_child("ManualSave",true,false))
 check(final_game.last_save_error!=OK and scene.save_status_label.visible and scene.save_status_label.text==scene.message,"Manual save failure appears in page and toast")
 await capture("save-page-failure")
 DirAccess.remove_absolute(BattleGame.SAVE_PATH+".tmp")
 await activate(scene.system_nav_buttons[7])
 var hidden_text: String=scene.last_save_label.text
 final_game.last_successful_save_at+=60
 scene.refresh_save_status()
 check(scene.last_save_label.text==hidden_text,"Hidden Save page receives no status writes")
 await open_settings()
 check(scene.last_save_label.text!=hidden_text and scene.save_interval_input.text=="unfinished","Reveal catches up save status without replacing draft")
 check(OS.get_user_data_dir().contains("test/work"),"All file operations stayed in isolated user directory")
 print("SAVE TRANSFER UI: %d checks, %d failures"%[checks,failures]);scene.queue_free();await process_frame;quit(1 if failures else 0)
