extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
var failures=0
var checks=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func click(control: Control) -> void:
 if DisplayServer.get_name()=="headless":control.pressed.emit();await process_frame;return
 await process_frame;await process_frame
 var ancestor=control.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:
   ancestor.ensure_control_visible(control);await process_frame;await process_frame
   ancestor.ensure_control_visible(control);await process_frame;await process_frame
   break
  ancestor=ancestor.get_parent()
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.position=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2);e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e);await process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("HYPERSPACE_UI_EVIDENCE").is_empty():return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("HYPERSPACE_UI_EVIDENCE")+"/"+name+".png")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);root.add_child(scene);current_scene=scene;scene.set_process(false)
 scene.music.stop();scene.music.stream=null
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.highestLevel=6;scene.refresh_tab_visibility();check(scene.equipment_tabs.is_tab_hidden(9),"Exploration locked before seven")
 g.profile.highestLevel=80;g.profile.cleared=range(1,80);scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh();check(not scene.equipment_tabs.is_tab_hidden(9),"Exploration unlocks at seven")
 check(scene.equipment_tabs.get_tab_idx_from_control(scene.save_panel)==10,"Save remains last")
 check(p.level.min_value==5 and p.level.max_value==80,"Level uses this round highest")
 check(p.start_button.disabled and p.crew_button.disabled,"Unavailable adapters disabled")
 check(p.cards.size()==8 and p.find_children("*","SubViewport",true,false).is_empty(),"Eight reusable cards, no card viewports")
 await capture("exploration")
 var Bag=preload("res://scripts/drone_inventory.gd")
 var s=g.hyperspace.fresh();s.unlocked_drones=true
 for i in 200:
  var d={"id":"ui:%d"%i,"origin_quality":"gold","weapon":["laser","missile","cannon","longLaser"][i%4],"level":20,"legendary":false,"ultimate":false,"blue_source_bonus":false,"legendary_effect":{},"ultimate_affix":{},"affixes":[{"key":"global_damage","tier":2,"value":65.5,"locked":false}],"hangings":[]}
  check(Bag.insert(s.inventory,d,g.hyperspace.config),"Fixture insert")
 g.hyperspace.publish(g,s,"fixture");p.refresh();var refreshes=p.list_refreshes
 for i in 120:p.refresh_progress()
 check(p.list_refreshes==refreshes,"Progress never refreshes warehouse")
 var cards=p.cards.duplicate();var profile=JSON.stringify(g.profile)
 p.scroll.ensure_control_visible(p.next);await process_frame;await process_frame
 await click(p.next);check(p.page==1 and p.cards[0].get_meta("drone_id")=="ui:8","Native pagination follows stable IDs")
 check(JSON.stringify(g.profile)==profile,"Pagination is read-only")
 p.scroll.ensure_control_visible(p.cards[0]);await process_frame;await process_frame
 await click(p.cards[0]);p.scroll.ensure_control_visible(p.favorite);await process_frame;await process_frame;await click(p.favorite);p.refresh();check(g.profile.hyperspace.inventory.favorites.has("ui:8"),"Favorite uses domain command")
 check(p.cards[0]==cards[0],"Favorite reuses card instance")
 await capture("warehouse-page2")
 p.page=24;p.refresh_list();check(p.next.disabled and p.cards[7].get_meta("drone_id")=="ui:199","Last page bounded")
 await capture("warehouse-last-page")
 p.scroll.ensure_control_visible(p.filter_text);await process_frame;await process_frame;await capture("filter-and-forge")
 var filter_profile=JSON.stringify(g.profile)
 p.weapon_filter.select(3);p.weapon_filter.item_selected.emit(3);check(p.page==0 and p.cards[0].get_meta("drone_id")=="ui:2","Local weapon filter projects inventory")
 check(JSON.stringify(g.profile)==filter_profile,"Local filters never execute auto-destroy")
 p.weapon_filter.select(0);p.weapon_filter.item_selected.emit(0)
 var focus=p.preset_names[0];focus.text="草稿";focus.grab_focus();var list_count=p.list_refreshes
 p.refresh();check(p.preset_names[0].text=="草稿" and root.gui_get_focus_owner()==focus,"Refresh preserves draft and focus")
 check(p.list_refreshes==list_count,"Unchanged refresh does not rebuild list")
 scene.select_system(0);await process_frame;p.dirty=true;p.refresh();check(p.list_refreshes==list_count,"Hidden page has no list writes")
 scene.select_system(9);await process_frame
 var Codec=preload("res://scripts/drone_filter_preview.gd")
 check(Codec.parse('{"version":1,"mode":"or","conditions":[{"kind":"weapon","value":"cannon"}]}').ok,"Versioned rule preview")
 for invalid in ['{"version":2,"mode":"and","conditions":[]}','{"version":1,"mode":"and","conditions":[{"kind":"weapon","value":"bad"}]}','x'.repeat(4097),'{"version":1,"mode":"and","conditions":[{"kind":"min_level","value":5.5}]}']:
  check(not Codec.parse(invalid).ok,"Invalid schema, enum, length, fraction rejected")
 check(Codec.parse('{"version":1,"mode":"and","conditions":[{"kind":"affix","value":{"key":"global_damage","max_tier":2}}]}',["global_damage"]).ok,"Affix preview validates catalog and tier")
 check(not Codec.parse('{"version":1,"mode":"and","conditions":[{"kind":"affix","value":{"key":"bad","max_tier":2}}]}',["global_damage"]).ok,"Unknown affix rejected")
 # Read-only visual integration: max hull + five drones + existing ordinary turrets.
 g.switch_ship("Heavy_Battleship")
 for entry in g.weapon_entries():entry.key="laser"
 var next_state=g.hyperspace.snapshot(g);next_state.inventory.equipped=["ui:0","ui:1","ui:2","ui:3","ui:4"];next_state.inventory.generation+=1;g.hyperspace.publish(g,next_state,"fixture")
 scene._process(0);var visual=scene.hyperspace_visual
 check(visual.nodes.size()==5 and scene.ship_view.carriers.size()==3 and scene.ship_view.viewport.get_parent()==scene.ship_view,"Five models share existing fleet viewport")
 var rebuilds=visual.rebuilds
 g.profile.hyperspace.inventory.drones["ui:0"].level=21;visual.sync(g.profile.hyperspace.inventory)
 check(visual.rebuilds==rebuilds,"Numeric changes excluded from model signature")
 await capture("max-hull-five-models")
 var active=g.hyperspace.start(g,"alpha",5,"manual");var reward_drone=g.profile.hyperspace.inventory.drones["ui:0"].duplicate(true);reward_drone.level=5
 check(g.hyperspace.complete(g,int(active.round_id),int(active.run_id),true,{"drone":reward_drone,"materials":{"degenerate_matter":1}}),"Pending reward from formal completion")
 p.refresh();check(scene.system_nav_buttons[9].get_node("ActivationBadge").visible,"Pending reward lights navigation badge")
 await click(p.claim_button);p.refresh();check(g.profile.hyperspace.inventory.overflow.size()==1 and g.profile.hyperspace.active.is_empty(),"Formal claim enters fixed overflow cache")
 g.profile.hyperspace.inventory.equipped=[];visual.sync(g.profile.hyperspace.inventory);check(visual.nodes.is_empty(),"Unequipped source removes visuals")
 scene.music.stop();scene.music.stream=null;scene.queue_free();await process_frame;await process_frame
 print("HYPERSPACE UI ",checks-failures,"/",checks," display=",DisplayServer.get_name());quit(1 if failures else 0)
