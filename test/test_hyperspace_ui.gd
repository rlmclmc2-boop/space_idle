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
func capture_window(dialog: Window,name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("HYPERSPACE_UI_EVIDENCE").is_empty():return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 check(dialog.size.y<=550,"Command dialog fits short screen")
 dialog.get_texture().get_image().save_png(OS.get_environment("HYPERSPACE_UI_EVIDENCE")+"/"+name+".png")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true
 scene.music.stop();scene.music.stream=null
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.highestLevel=6;scene.refresh_tab_visibility();check(scene.equipment_tabs.is_tab_hidden(9),"Exploration locked before seven")
 g.profile.highestLevel=80;g.profile.cleared=range(1,80);g.rebuild_unlocks();g.pending_unlocks.clear();scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh();check(not scene.equipment_tabs.is_tab_hidden(9),"Exploration unlocks at seven")
 check(scene.equipment_tabs.get_tab_idx_from_control(scene.save_panel)==10,"Save remains last")
 check(p.level.min_value==5 and p.level.max_value==80,"Level uses this round highest")
 check(p.start_button.disabled and not p.crew_button.disabled,"Manual waits for battle; real crew manager available")
 check(p.cards.size()==8 and p.find_children("*","SubViewport",true,false).is_empty(),"Eight reusable cards, no card viewports")
 await capture("exploration")
 var Bag=preload("res://scripts/drone_inventory.gd")
 var s=g.hyperspace.fresh();s.unlocked_drones=true
 for i in 200:
  var rng=RandomNumberGenerator.new();rng.seed=12345+i
  var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"ui:%d"%i,"gold",["laser","missile","cannon","longLaser"][i%4],20,"1")
  d.affixes=[{"key":"global_damage","tier":2,"value":0.655,"locked":false}]
  check(Bag.insert(s.inventory,d,g.hyperspace.config),"Fixture insert")
 g.hyperspace.publish(g,s,"fixture");p.refresh();p.select_section(1);await process_frame;var refreshes=p.list_refreshes
 for i in 120:p.refresh_progress()
 check(p.list_refreshes==refreshes,"Progress never refreshes warehouse")
 var cards=p.cards.duplicate();var profile=JSON.stringify(g.profile)
 await click(p.next);check(p.page==1 and p.cards[0].get_meta("drone_id")=="ui:8","Native pagination follows stable IDs")
 check(JSON.stringify(g.profile)==profile,"Pagination is read-only")
 await click(p.cards[0]);await click(p.favorite);p.refresh();check(g.profile.hyperspace.inventory.favorites.has("ui:8"),"Favorite uses domain command")
 check(p.cards[0]==cards[0],"Favorite reuses card instance")
 await capture("warehouse-page2")
 p.page=24;p.refresh_list();check(p.next.disabled and p.cards[7].get_meta("drone_id")=="ui:199","Last page bounded")
 await capture("warehouse-last-page")
 await click(p.section_buttons[3]);await capture("filter-and-presets")
 check(not p.filter_text.is_visible_in_tree(),"String editor stays in hidden dialog")
 await click(p.section_buttons[1])
 var filter_profile=JSON.stringify(g.profile)
 p.weapon_filter.select(3);p.weapon_filter.item_selected.emit(3);check(p.page==0 and p.cards[0].get_meta("drone_id")=="ui:2","Local weapon filter projects inventory")
 check(JSON.stringify(g.profile)==filter_profile,"Local filters never execute auto-destroy")
 p.weapon_filter.select(0);p.weapon_filter.item_selected.emit(0)
 await click(p.section_buttons[3])
 # Dropdown rule editing stays localized; valid import is preview-only.
 p.filter_kinds[0].select(1);p.configure_condition(0);p.condition_values[0].select(2)
 p.filter_mode.select(1);p.build_filter_draft()
 check(p.filter_result.text.contains("或") and not p.filter_result.text.contains("or"),"Rule mode localized")
 var string_profile=JSON.stringify(g.profile)
 await click(p.string_button);check(p.filter_text.is_visible_in_tree(),"Strings visible only after explicit dialog open")
 await capture_window(p.string_dialog,"filter-string-window")
 p.filter_text.text=preload("res://scripts/hyperspace_filter.gd").export_string({"version":1,"enabled":false,"action":"clear_matches","mode":"all","conditions":[{"field":"quality","value":"blue"},{"field":"minimum_level","value":40}]},g.hyperspace.config)
 p.import_filter_draft();check(not p.string_dialog.visible and p.filter_kinds[0].get_item_metadata(p.filter_kinds[0].selected)=="quality" and p.condition_levels[1].value==40,"Validated import populates localized controls")
 check(JSON.stringify(g.profile)==string_profile,"String import never mutates profile")
 var focus=p.preset_names[0];focus.text="草稿";focus.grab_focus();var list_count=p.list_refreshes
 p.refresh();check(p.preset_names[0].text=="草稿" and root.gui_get_focus_owner()==focus,"Refresh preserves draft and focus")
 check(p.list_refreshes==list_count,"Unchanged refresh does not rebuild list")
 scene.select_system(0);await process_frame;p.dirty=true;p.refresh();check(p.list_refreshes==list_count,"Hidden page has no list writes")
 scene.select_system(9);await process_frame
 var Codec=preload("res://scripts/hyperspace_filter.gd")
 var rule={"version":1,"enabled":false,"action":"keep_matches","mode":"any","conditions":[{"field":"weapon","value":"cannon"}]}
 check(p.valid_draft(Codec.import_string(Codec.export_string(rule,g.hyperspace.config),g.hyperspace.config)),"Domain versioned rule preview")
 for invalid in ['SPACE-FILTER-v2:AAAA','SPACE-FILTER-v1:????','x'.repeat(4097),'{"version":1}']:
  check(Codec.import_string(invalid,g.hyperspace.config).is_empty(),"Invalid version, encoding, length rejected")
 check(not p.filter_enabled.button_pressed,"Auto processing defaults off")
 var prior=JSON.stringify(g.profile.hyperspace.filter);p.save_filter()
 check(JSON.stringify(g.profile.hyperspace.filter)==prior and p.filter_result.text==p.t("filter_action_wait"),"Missing action authority cannot mutate filter")
 # Real preset application and capacity use the domain, without injected adapters.
 g.switch_ship("Heavy_Battleship")
 check(g.hyperspace.set_equipped(g,["ui:8"]),"Equip through actual hull capacity")
 check(g.hyperspace.set_preset(g,0,"旗舰",["ui:8"]),"Save named preset")
 check(g.hyperspace.set_equipped(g,[]),"Clear equipped")
 p.preset_adapter.call(0);check(g.profile.hyperspace.inventory.equipped==["ui:8"],"Preset applies actual domain")
 # Quoting is read-only; commit uses the frozen command and localizes failures.
 p.selected_id="ui:8";p.select_section(2);p.commands.operation.select(5);p.commands.configure_operation()
 var before_quote=JSON.stringify(g.profile.hyperspace);p.commands.preview()
 check(JSON.stringify(g.profile.hyperspace)==before_quote and p.commands.commit_button.disabled,"Insufficient quote is read-only")
 check(p.commands.feedback.text.contains("材料不足") and not p.commands.quote_label.text.contains("antiproton"),"Quote costs and errors localized")
 g.profile.hyperspace.materials.antiproton=20;p.commands.preview();var receipt=p.commands.quoted_request.duplicate(true)
 check(not p.commands.commit_button.disabled and receipt.expected_revision==0,"Affordable frozen quote")
 await capture("forge-affordable-quote");await click(p.commands.commit_button);check(g.profile.hyperspace.materials.antiproton==15 and g.profile.hyperspace.inventory.drones["ui:8"].forge_revision==1,"Forge commits real debit and revision")
 p.commands.execute_quote();check(g.profile.hyperspace.materials.antiproton==15,"Double click cannot pay twice")
 p.commands.preview();var stale=p.commands.quoted_request.duplicate(true)
 g.hyperspace.forge(g,{"round_id":stale.round_id,"command_seq":stale.command_seq,"drone_id":"ui:9","operation":"reroll_values","args":{},"expected_revision":0})
 var after_external=JSON.stringify(g.profile.hyperspace);p.commands.execute_quote()
 check(JSON.stringify(g.profile.hyperspace)==after_external and p.commands.feedback.text.contains("重新预览"),"Stale quote never silently changes sequence")
 # Real crew manager projects occupied status and dispatches only an eligible ID.
 g.profile.hyperspace.history.alpha={"5":40.0};p.route="alpha";p.level.value=5;p.select_section(0);await click(p.crew_button)
 var available=-1
 for n in p.commands.crew_choice.item_count:
  if p.commands.crew_choice.get_item_metadata(n)=="navigator":available=n
 check(available>=0,"Real navigator appears in manager")
 if available>=0:
  p.commands.crew_choice.select(available);p.commands.refresh_crew();await capture_window(p.commands.crew_dialog,"crew-manager");check(not p.commands.crew_enable.disabled,"Available crew with real X1 can dispatch")
  p.commands.set_auto(true);check(g.profile.hyperspace.auto.enabled and g.profile.hyperspace.auto.crew_id=="navigator","Automatic dispatch uses real crew ID")
  check(not g.crew.can_assign(g,"navigator","weapon","laser"),"Domain reserves dispatched crew")
  p.commands.set_auto(false);check(not g.profile.hyperspace.auto.enabled,"Domain stops automatic exploration")
 p.commands.crew_dialog.hide()
 # Module settings validate slots, unlock and no-repeat through the domain.
 g.profile.hyperspace.inventory.drones["ui:8"].hanging_slots=1;g.profile.hyperspace.inventory.generation+=1;g.profile.hyperspace.hanging_modules.resource_collector.unlocked=true
 p.dirty=true;p.refresh();p.selected_id="ui:8";p.commands.show_modules();await capture_window(p.commands.module_dialog,"module-manager")
 check(p.commands.module_choices.size()==g.hyperspace.config.hanging_modules.size(),"Module manager uses config catalog")
 check(g.hyperspace.attach_hangings(g,"ui:8",["resource_collector"]),"Attach unlocked module")
 check(not g.hyperspace.attach_hangings(g,"ui:8",["resource_collector","resource_collector"]),"Domain rejects same-drone duplicate")
 p.commands.module_dialog.hide()
 g.profile.hyperspace.legendary_seen=["scatter_pulse"];p.commands.show_collection();await capture_window(p.commands.collection_dialog,"legendary-collection")
 check(p.commands.collection_choices.size()==1,"Collection only offers seen effects");p.commands.collection_dialog.hide()
 # Read-only visual integration: max hull + five drones + existing ordinary turrets.
 g.switch_ship("Heavy_Battleship")
 for entry in g.weapon_entries():entry.key="laser"
 var next_state=g.hyperspace.snapshot(g);next_state.inventory.equipped=["ui:0","ui:1","ui:2","ui:3","ui:4"];next_state.inventory.generation+=1;g.hyperspace.publish(g,next_state,"fixture")
 p.select_section(1);scene._process(0);var visual=scene.hyperspace_visual
 check(visual.nodes.size()==5 and scene.ship_view.carriers.size()==3 and scene.ship_view.viewport.get_parent()==scene.ship_view,"Five models share existing fleet viewport")
 var rebuilds=visual.rebuilds
 g.profile.hyperspace.inventory.drones["ui:0"].level=21;visual.sync(g.profile.hyperspace.inventory)
 check(visual.rebuilds==rebuilds,"Numeric changes excluded from model signature")
 await capture("max-hull-five-models")
 var active=g.hyperspace.start(g,"alpha",5,"manual");var reward_drone=g.profile.hyperspace.inventory.drones["ui:0"].duplicate(true);reward_drone.level=5
 check(g.hyperspace.complete(g,int(active.round_id),int(active.run_id),true),"Pending reward from formal completion")
 p.refresh();check(scene.system_nav_buttons[9].get_node("ActivationBadge").visible,"Pending reward lights navigation badge")
 p.select_section(0);await click(p.claim_button);p.refresh();check(g.profile.hyperspace.inventory.overflow.size()==1 and g.profile.hyperspace.active.is_empty(),"Formal claim enters fixed overflow cache")
 check(p.protection_flags("ui:8").contains(p.t("favorite")) and p.protection_flags("ui:8").contains(p.t("preset")) and not p.protection_flags("ui:8").contains(p.t("legendary")),"Protection excludes legendary and ultimate status")
 check(p.flags("ui:8",{"legendary":true,"ultimate":true}).contains(p.t("legendary")) and p.flags("ui:8",{"legendary":true,"ultimate":true}).contains(p.t("ultimate")),"Legendary and ultimate remain separate flags")
 # Common window sizes use actual framebuffer captures and bounding rectangles.
 for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.size=resolution;await process_frame;await process_frame;await process_frame
  for section in range(4):
   p.select_section(section);await process_frame;await process_frame
   await capture("section%d-%dx%d"%[section,resolution.x,resolution.y])
   var bounds:Rect2=p.sections[section].get_global_rect()
   for candidate in p.sections[section].find_children("*","Button",true,false):
    if candidate.is_visible_in_tree():
     var rect:Rect2=candidate.get_global_rect()
     check(rect.position.y>=bounds.position.y-2 and rect.end.y<=bounds.end.y+2,"Visible section button stays inside content bounds")
   if section==1:
    var viewport_rect=Rect2(Vector2.ZERO,Vector2(root.size))
    for control in [p.next,p.previous,p.favorite,p.equip]:
     var physical=root.get_final_transform()*control.get_global_rect().get_center()
     check(viewport_rect.has_point(physical),"Warehouse action stays on screen")
    check(p.favorite.get_global_rect().get_center().distance_to(p.detail_title.get_global_rect().get_center())<220,"Selection and actions remain adjacent")
  check(not p.details.text.contains("global_damage") and p.details.text.contains("全局伤害") and p.details.text.contains("%"),"Chinese affix labels and percentage units")
 g.profile.hyperspace.inventory.equipped=[];visual.sync(g.profile.hyperspace.inventory);check(visual.nodes.is_empty(),"Unequipped source removes visuals")
 scene.music.stop();scene.music.stream=null;scene.queue_free();await process_frame;await process_frame
 print("HYPERSPACE UI ",checks-failures,"/",checks," display=",DisplayServer.get_name());quit(1 if failures else 0)
