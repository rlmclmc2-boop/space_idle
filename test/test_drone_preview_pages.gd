extends SceneTree
## Actual-input static preview fixture; never reads or writes player saves.
class IsolatedUI extends "res://scripts/battlefield.gd":
 var writes:Array=[]
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
  if control.get(property)!=value:writes.append([control,property])
  super.set_ui_value(control,property,value)
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func click(control:Control)->void:
 if DisplayServer.get_name()=="headless":control.pressed.emit();await process_frame;return
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("DRONE_PREVIEW_EVIDENCE")+"/"+name+".png")
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 scene.music.stop();scene.music.stream=null
 var g:BattleGame=scene.game
 g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.cleared=range(1,90);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.resources={"1":1e28,"2":1e28};g.profile.onboarding.completed=true
 g.switch_ship("Heavy_Battleship")
 for e in g.weapon_entries():e.key="laser"
 scene.refresh_tab_visibility();scene.select_system(3);await process_frame
 var p=scene.ship_controls.page;p.candidate="Heavy_Battleship";p.refresh();await process_frame
 check(p.picture.size==Vector2(680,680),"Hull stays680 square")
 check(p.find_children("*","SubViewport",true,false).is_empty(),"Static page has no runtime viewport")
 check(p.drone_cards.size()==3,"Exactly three persistent cards")
 for i in 3:
  check(p.drone_cards[i].visible and p.drone_cards[i].get_meta("slot_id")==g.slot_id("weapons",5+i),"Default carrier exact weapon ID")
  check(p.drone_cards[i].get_child(0).texture==p.drone_texture,"Shared static texture")
  check(p.mounts[g.slot_id("weapons",5+i)].get_meta("slot_id")==p.drone_cards[i].get_meta("slot_id"),"Right row and card agree")
 check(not p.drone_next.visible and not p.drone_previous.visible,"One page needs no arrows")
 await capture("default-three-carriers")
 await click(p.mounts.weapons_5)
 check(scene.equipment_tabs.current_tab==0 and scene.equipment_panel.selected=="weapons_5","Native right row routes same W06 equipment")
 scene.equipment_tabs.current_tab=3;await process_frame
 var cards=p.drone_cards.duplicate();var hull=p.picture
 # Test many carriers without altering authoritative shipped config.
 scene.db.ships.Heavy_Battleship.weaponSlots=13;g.ensure_loadout()
 for e in g.weapon_entries():e.key="laser"
 p.refresh();await process_frame
 check(p.drone_next.visible and p.drone_previous.disabled and not p.drone_next.disabled,"Many carriers paginate")
 await click(p.drone_next)
 check(p.drone_page==1 and p.drone_cards[0].get_meta("slot_id")=="weapons_8","Native next page uses W09")
 await click(p.drone_next)
 check(p.drone_page==2 and p.drone_next.disabled and not p.drone_previous.disabled,"Final page bound")
 check(p.drone_cards[0].get_meta("slot_id")=="weapons_11" and p.drone_cards[1].get_meta("slot_id")=="weapons_12" and not p.drone_cards[2].visible,"Partial final page exact IDs")
 await capture("many-carriers-last-page")
 await click(p.drone_cards[1])
 check(scene.equipment_tabs.current_tab==0 and scene.equipment_panel.selected=="weapons_12","Native card opens exact W13 equipment: tab%s selected%s"%[scene.equipment_tabs.current_tab,scene.equipment_panel.selected])
 scene.equipment_tabs.current_tab=3;await process_frame
 check(p.drone_page==2,"Hide/reveal keeps page")
 p.mount_scroll.scroll_vertical=9999;await process_frame
 var scroll:int=p.mount_scroll.scroll_vertical
 p.drone_previous.grab_focus();var focus:Control=root.gui_get_focus_owner()
 p.refresh();scene.writes.clear();p.refresh()
 check(scene.writes.is_empty(),"Unchanged paused refresh writes no properties")
 check(p.mount_scroll.scroll_vertical==scroll and root.gui_get_focus_owner()==focus,"Preserve scroll and focus")
 for i in 3:check(is_same(cards[i],p.drone_cards[i]),"Reuse card instance")
 check(is_same(hull,p.picture),"Reuse main hull")
 await click(p.drone_previous)
 check(p.drone_page==1,"Native previous page")
 # Sparse occupied slots compact visual assignments, never logical identities.
 g.weapon_entries()[0].key="";g.weapon_entries()[6].key="";p.refresh()
 var expected:Array=[]
 var assigned=preload("res://dev/toon_ship/hybrid_layout.gd").assign(g.module_entries("weapons"),g.active_slot_count("weapons",p.candidate),5)
 for item in assigned:
  if item.carrier=="drone":expected.append(g.slot_id("weapons",int(item.slot)))
 for page in ceili(float(expected.size())/3):
  p.drone_page=page;p.refresh()
  for i in 3:
   var n:int=page*3+i
   check(p.drone_cards[i].visible==(n<expected.size()),"Sparse visibility bound")
   if n<expected.size():check(p.drone_cards[i].get_meta("slot_id")==expected[n],"Sparse identity follows actual assignment")
 check(p.mounts.weapons_0.get_parent()==p.mount_lists.weapons and p.mounts.weapons_6.get_parent()==p.mount_lists.weapons,"Empty slots stay logical empty rows")
 var profile:String=JSON.stringify(g.profile)
 await click(p.choices.Destroyer)
 check(JSON.stringify(g.profile)==profile and p.candidate=="Destroyer","Native candidate selection read-only")
 check(p.drone_page==0,"New candidate resets only UI page")
 for c in p.drone_cards:
  if c.visible:check(c.disabled,"Candidate carriers read-only")
 var cleared:Array=g.profile.cleared;g.profile.cleared=[];p.candidate="Heavy_Battleship";p.refresh()
 check(not p.drone_strip.visible and not p.mount_scroll.visible,"Locked candidate hides carrier actions")
 g.profile.cleared=cleared;p.candidate="Heavy_Battleship"
 for e in g.weapon_entries():e.key=""
 p.refresh()
 check(p.drone_empty.visible and p.drone_page==0 and not p.drone_next.visible,"No occupied carriers shows empty state")
 for c in p.drone_cards:check(not c.visible,"No invented drone for empty slot")
 await capture("empty-carrier-slots")
 scene.equipment_tabs.current_tab=0;await process_frame;scene.writes.clear();p.refresh()
 check(scene.writes.is_empty(),"Hidden preview performs no writes")
 scene.equipment_tabs.current_tab=3;await process_frame
 check(p.drone_empty.visible and not g.save_enabled,"Reveal catches up without saves")
 var manifest=preload("res://scripts/ship_panel.gd").preview_data
 check(manifest.drone.model==JSON.parse_string(FileAccess.get_file_as_string("res://dev/toon_ship/hybrid_manifest.json")).drone.path,"Snapshot uses actual live carrier GLB")
 for path in manifest.source_sha256:check(FileAccess.get_sha256(path)==manifest.source_sha256[path],"Truthful baked source fingerprint")
 scene.music.stop();scene.music.stream=null;scene.queue_free();await process_frame;await process_frame
 print("DRONE PREVIEW PAGES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
