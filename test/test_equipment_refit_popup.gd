extends SceneTree
## Native popup input and appearance, using synthetic state and no player save.
const Chrome := preload("res://scripts/dialog_presentation.gd")
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func show_qa_tools() -> void:pass
var checks := 0
var failures := 0
var scene
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
 var point := root.get_final_transform()*control.get_global_transform_with_canvas()*Vector2(control.size.x-4,17)
 for down in [true,false]:
  var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point
  Input.parse_input_event(event);await process_frame
 await process_frame
func enter(menu: PopupMenu,index: int) -> void:
 menu.set_focused_item(index)
 for down in [true,false]:
  var event := InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down
  Input.parse_input_event(event);await process_frame
func click_option(menu: PopupMenu,index: int) -> void:
 var style:=menu.get_theme_stylebox("panel")
 var row_height: float=(menu.get_contents_minimum_size().y-style.get_minimum_size().y)/menu.item_count
 var point:=Vector2(menu.size.x*.5,style.get_content_margin(SIDE_TOP)+row_height*(index+.5))
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point
  menu.push_input(event,true);await process_frame
func inspect(card) -> void:
 var menu: PopupMenu=card.name_button.get_popup()
 check(menu.visible,"Title mouse click opens its menu")
 check(menu.get_theme_stylebox("panel").bg_color==Chrome.PAPER,"Menu uses card paper background")
 check(menu.get_theme_stylebox("hover").bg_color==Chrome.TEAL,"Menu uses teal highlight")
 check(menu.get_theme_color("font_color")==Chrome.NAVY and menu.get_theme_color("font_disabled_color")==card.MUTED,"Enabled and disabled ink remain readable")
 check(menu.get_theme_font_size("font_size")==23 and menu.get_theme_constant("v_separation")==12,"Menu uses readable type and row spacing")
 var checked := 0
 for i in menu.item_count:
  check(not menu.get_item_text(i).begins_with("W") and not menu.get_item_text(i).begins_with("D"),"Menu option omits slot prefix")
  if menu.is_item_checked(i):checked+=1
 check(checked==1 and menu.is_item_checked(card.name_button.selected),"Exactly the current item has its native radio mark")
 var transform: Transform2D=card.name_button.get_screen_transform()
 var viewport_transform: Transform2D=transform*card.name_button.get_global_transform_with_canvas().affine_inverse()
 var bounds: Rect2=(viewport_transform*card.name_button.get_viewport_rect()).grow(-8)
 check(bounds.grow(1).encloses(Rect2(Vector2(menu.position),Vector2(menu.size))),"Menu stays inside playable viewport")
 check(menu.size.x>=ceili(menu.get_contents_minimum_size().x),"Menu fits complete option names")
func capture(name: String,menu: PopupMenu) -> void:
 var folder := OS.get_environment("REFIT_POPUP_EVIDENCE")
 if folder.is_empty():return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+name+"-root.png")
 if menu.visible:menu.get_texture().get_image().save_png(folder+"/"+name+"-menu.png")
 FileAccess.open(folder+"/"+name+"-geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"popup":menu.position,"popup_size":menu.size,"window":root.position,"frame":root.get_texture().get_size(),"embedded":menu.is_embedded()}))
func run() -> void:
 root.size=Vector2i(1373,883);root.position=Vector2i.ZERO
 scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"]
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,90);g.profile.highestLevel=90;g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.unlocked.erase("longLaser");g.profile.resources={"1":1e28,"2":1e28};g.profile.onboarding.completed=true
 g.switch_ship("Heavy_Battleship");g.equip_slot("weapons",2,"missile")
 scene.refresh_tab_visibility();scene.equipment_tabs.current_tab=0
 await process_frame;await process_frame
 var panel=scene.equipment_panel;var card=panel.cards.weapons_2;var menu: PopupMenu=card.name_button.get_popup()
 await click(card.name_button);inspect(card)
 check(card.name_button.text.begins_with("W03 "),"Card title retains its weapon slot")
 var blocked: int=card.equipment_options.find("longLaser")
 check(menu.is_item_disabled(blocked),"Locked equipment remains disabled")
 await click_option(menu,blocked)
 check(g.module_entry("weapons",2).key=="missile" and menu.visible,"Actual disabled-row click cannot refit or dismiss the menu")
 g.crew.auto_upgrade(g,{"upgradeMode":"1"});panel.refresh();await process_frame
 check(menu.visible and is_same(menu,card.name_button.get_popup()) and card.name_button.text.begins_with("W03 "),"Auto-upgrade keeps the popup instance and slot title")
 menu.set_focused_item(card.name_button.selected);await process_frame;await capture("weapon",menu)
 await enter(menu,card.equipment_options.find("cannon"))
 check(g.module_entry("weapons",2).key=="cannon" and not menu.visible and not panel.detail_frame.visible,"Enabled native selection refits in place without inspector")
 check(card.name_button.text.begins_with("W03 ") and menu.is_item_checked(card.name_button.selected),"Refitted title and radio mark catch up")
 var edge=panel.cards.weapons_3
 await click(edge.name_button);inspect(edge)
 await capture("right-edge",edge.name_button.get_popup())
 edge.name_button.get_popup().hide()
 var defence=panel.cards.defence_0;panel.grid_scroll.ensure_control_visible(defence)
 await process_frame;await process_frame
 await click(defence.name_button);inspect(defence)
 check(defence.name_button.text.begins_with("D01 "),"Defence card retains slot title with the same popup style")
 await capture("defence",defence.name_button.get_popup())
 defence.name_button.get_popup().hide()
 check(not g.save_enabled,"Fixture writes no player save")
 print("REFIT POPUP: %d checks, %d failures" % [checks,failures])
 scene.queue_free();await process_frame;quit(1 if failures else 0)
