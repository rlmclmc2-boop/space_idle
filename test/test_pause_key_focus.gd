extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func key(code:int,down:bool,echo:=false)->void:
 var event:=InputEventKey.new();event.keycode=code;event.pressed=down;event.echo=echo
 Input.parse_input_event(event)
 await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 var headless=DisplayServer.get_name()=="headless"
 root.size=Vector2i(1180,812)
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 await process_frame;await process_frame
 var g=scene.game;g.save_enabled=false;g.profile.onboarding.completed=true;g.pending_unlocks.clear();g.profile.resources["1"]=1000000.;g.paused=false
 scene.equipment_panel.refresh();await process_frame
 var button:Button=scene.equipment_panel.cards.weapons_0.upgrade_button
 var initial:int=g.module_entry("weapons",0).level
 var point:Vector2=root.get_final_transform()*button.get_global_transform_with_canvas()*(button.size/2)
 if headless:
  button.pressed.emit();button.grab_focus()
 else:
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;Input.parse_input_event(event);await process_frame
 check(g.module_entry("weapons",0).level==initial+1,"Initial purchase succeeds (signal fixture when headless, actual mouse otherwise)")
 check(root.gui_get_focus_owner()==button,"Upgrade retains keyboard focus")
 var level:int=g.module_entry("weapons",0).level
 var cash:float=g.profile.resources["1"]
 await key(KEY_SPACE,true);await key(KEY_SPACE,false)
 print("SPACE level_before=",level," level_after=",g.module_entry("weapons",0).level," cash_before=",cash," cash_after=",g.profile.resources["1"]," paused=",g.paused)
 check(g.paused,"Space pauses once")
 check(g.module_entry("weapons",0).level==level and g.profile.resources["1"]==cash,"Space does not purchase focused upgrade")
 await key(KEY_SPACE,true)
 check(not g.paused,"Second Space resumes")
 await key(KEY_SPACE,true,true)
 check(not g.paused,"Held Space echo does not toggle again")
 await key(KEY_SPACE,false)
 check(g.module_entry("weapons",0).level==level and g.profile.resources["1"]==cash,"Resume and echo do not purchase")
 await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
 check(g.paused,"Escape pause rule remains")
 await key(KEY_ENTER,true);await key(KEY_ENTER,false)
 check(g.module_entry("weapons",0).level==level+1,"Enter deliberately activates focused purchase")
 level=g.module_entry("weapons",0).level;cash=g.profile.resources["1"]
 scene.help_open=true
 await key(KEY_SPACE,true);await key(KEY_SPACE,false)
 check(not scene.help_open and g.paused,"Space closes help without changing pause")
 check(g.module_entry("weapons",0).level==level and g.profile.resources["1"]==cash,"Help dismissal does not purchase")
 g.pending_unlocks.append("equipment")
 await key(KEY_SPACE,true);await key(KEY_SPACE,false)
 check(g.pending_unlocks.is_empty() and g.paused,"Space acknowledges unlock without changing pause")
 check(g.module_entry("weapons",0).level==level and g.profile.resources["1"]==cash,"Unlock dismissal does not purchase")
 var edit:=LineEdit.new();edit.position=Vector2(800,700);scene.add_child(edit);edit.grab_focus();await process_frame
 # OS text key events include Unicode, unlike shortcut-only synthetic keys.
 var text_event:=InputEventKey.new();text_event.keycode=KEY_SPACE;text_event.unicode=32;text_event.pressed=true;Input.parse_input_event(text_event);await process_frame
 await key(KEY_SPACE,false)
 check(g.paused,"Text input does not toggle pause")
 check(edit.text==" ","Space remains available to text input")
 edit.queue_free()
 g.profile.highestLevel=3;g.profile.cleared=[1,2];g.rebuild_unlocks();g.pending_unlocks.clear()
 scene.equipment_panel.refresh();await process_frame
 var card=scene.equipment_panel.cards.weapons_0
 var picker:OptionButton=card.name_button
 var missile_index:int=card.equipment_options.find("missile")
 check(missile_index>=0,"Stage-three quick weapon picker offers missile")
 if missile_index>=0:
  picker.select(missile_index);picker.item_selected.emit(missile_index)
  picker.grab_focus();await process_frame
  check(g.module_entry("weapons",0).key=="missile" and root.gui_get_focus_owner()==picker,"Quick missile selection leaves native dropdown focused")
  var selected_state=JSON.stringify(g.profile)
  await key(KEY_SPACE,true)
  check(not g.paused and not picker.get_popup().visible,"Space resumes without reopening the focused dropdown")
  await key(KEY_SPACE,true,true);await key(KEY_SPACE,false)
  check(not g.paused and not picker.get_popup().visible and JSON.stringify(g.profile)==selected_state,"Space echo and release neither reopen nor reselect equipment")
  await key(KEY_SPACE,true);await key(KEY_SPACE,false)
  check(g.paused and not picker.get_popup().visible,"Next Space pauses without opening the dropdown")
  await key(KEY_ENTER,true);await key(KEY_ENTER,false)
  check(g.paused and picker.get_popup().visible,"Enter still deliberately opens the focused dropdown")
  picker.get_popup().hide()
 button.grab_focus();await process_frame
 await key(KEY_SPACE,true)
 check(not g.paused,"Space resumes before focus interruption")
 scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
 # Releasing while another window owns focus cannot reach this viewport.
 await key(KEY_SPACE,true);await key(KEY_SPACE,false)
 check(g.paused,"Focus interruption cannot leave Space latched")
 check(g.module_entry("weapons",0).level==level and g.profile.resources["1"]==cash,"Focus interruption does not purchase")
 if not headless:
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../pause-key-focus.png")
 print("RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
