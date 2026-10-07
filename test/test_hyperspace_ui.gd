extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
const ENERGY_ABSOLUTE_ERROR := 0.00000001
var failures=0
var checks=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func expected_manual_energy_after_tick(g,queued_energy: float,dt: float) -> float:
 # Dispatch pays first. Derive online gain independently from the table values;
 # do not call the production charge, ramp_gain or online_config helpers.
 var c: Dictionary=g.hyperspace.config
 var multiplier=1.0+float(g.hyperspace_totals().hangings.get("hyperspace_charge",0.0))
 var cap=float(c.energy_cap)*multiplier
 var base_rate=float(c.energy_rate)*multiplier
 var gain=base_rate*dt
 if g.profile.cleared.has(int(c.late_supply_unlock_stage)):
  var maximum=float(c.late_energy_rate_multiplier)
  if c.has("late_supply_ramp_seconds"):
   var duration=float(c.late_supply_ramp_seconds)
   var start=clampf(float(g.profile.hyperspace.get("late_supply_work",0.0)),0.0,duration)
   var ramp_seconds=minf(dt,duration-start)
   var first_rate=base_rate*(1.0+(maximum-1.0)*start/duration)
   var last_rate=base_rate*(1.0+(maximum-1.0)*(start+ramp_seconds)/duration)
   # Trapezoid integral for the linear segment, then the constant terminal rate.
   gain=(first_rate+last_rate)*0.5*ramp_seconds+base_rate*maximum*(dt-ramp_seconds)
  else:gain=base_rate*maximum*dt
 var paid_energy=queued_energy-float(c.ticket)
 # Refunded energy may already exceed the cap; charging never discards it.
 return paid_energy if paid_energy>=cap else minf(cap,paid_energy+gain)
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
 var p=scene.hyperspace_panel
 check(not g.load_hyperspace_routes(null,{}),"Explicit isolated missing-file projection rejected")
 p.refresh_manual_status();p.refresh()
 check(p.start_button.disabled and not p.manual_projection.manual_ready and p.manual_projection.manual_error=="space_data_missing" and not p.manual_reason.text.contains("space_data"),"Missing-data negative fixture retains friendly disabled UI")
 var negative_energy=float(g.profile.hyperspace.energy);p.start_manual()
 check(g.profile.hyperspace.active.is_empty() and g.profile.hyperspace.energy==negative_energy,"Missing-data button cannot charge")
 check(g.load_hyperspace_routes(),"Final accepted forty routes load")
 p.refresh_manual_status();p.refresh();check(not scene.equipment_tabs.is_tab_hidden(9),"Exploration unlocks at seven")
 check(scene.equipment_tabs.get_tab_idx_from_control(scene.save_panel)==10,"Save remains last")
 check(p.level.min_value==5 and p.level.max_value==80,"Level uses this round highest")
 check(not p.start_button.disabled and not p.crew_button.disabled,"Final routes enable manual; crew manager available")
 check(p.manual_projection.manual_ready and not p.manual_reason.visible,"Final production projection ready")
 var base_db=g.db
 for i in p.routes.size():
  await click(p.routes[i]);p.level.value=5
  var ticket_energy=float(g.profile.hyperspace.energy)
  await click(p.start_button)
  check(not g.manual_hyperspace.queued.is_empty() and not g.manual_hyperspace.active and g.profile.hyperspace.energy==ticket_energy,"Actual selected route queues without ticket")
  var tick_seconds=0.001;var ticket=float(g.hyperspace.config.ticket)
  var charged_energy=expected_manual_energy_after_tick(g,ticket_energy,tick_seconds)
  var refunded_energy=charged_energy+ticket
  g.paused=false;g.tick(tick_seconds)
  check(g.manual_hyperspace.active and g.profile.hyperspace.active.route==g.hyperspace.config.routes.keys()[i],"Actual selected route dispatches at safe standby")
  check(absf(float(g.profile.hyperspace.energy)-charged_energy)<=ENERGY_ABSOLUTE_ERROR and float(g.profile.hyperspace.active.ticket)==ticket,"One actual manual ticket charged")
  print("MANUAL_TICKET_ENERGY route=",i," queued=","%.12f"%ticket_energy," charged=","%.12f"%float(g.profile.hyperspace.energy)," expected=","%.12f"%charged_energy," earned=","%.12f"%(charged_energy-(ticket_energy-ticket))," expected_refund=","%.12f"%refunded_energy)
  g.spawn_group();g.paused=true;scene._process(0)
  check(not g.enemies.is_empty() and g.db.levels[4].groups.size()==10,"Formal first group spawns in isolated ten-wave view")
  p.refresh_progress();await capture("formal-route%d"%i)
  g.save_enabled=true;g.save_progress();g.save_enabled=false
  check(g.last_save_error==OK and FileAccess.file_exists(g.SAVE_PATH),"Actual isolated manual save writes successfully")
  var saved=g.progress_writer.read_progress(g.SAVE_PATH);var restored=BattleGame.new(base_db,false);restored.load_progress_data(saved)
  check(restored.profile.hyperspace.active.is_empty() and absf(float(restored.profile.hyperspace.energy)-refunded_energy)<=ENERGY_ABSOLUTE_ERROR,"Short save/read refunds interrupted run exactly once")
  await click(p.exit_button);p.refresh()
  check(not g.manual_hyperspace.active and is_same(g.db,base_db) and absf(float(g.profile.hyperspace.energy)-refunded_energy)<=ENERGY_ABSOLUTE_ERROR and not p.exit_button.visible,"Native exit restores original context and exploration page")
  check(not p.start_button.disabled,"Next route available after exit")
 g.paused=true
 check(p.cards.size()==8 and p.find_children("*","SubViewport",true,false).is_empty(),"Eight reusable cards, no card viewports")
 await capture("exploration")
 var Bag=preload("res://scripts/drone_inventory.gd")
 var s=g.hyperspace.fresh();s.unlocked_drones=true
 for i in 200:
  var rng=RandomNumberGenerator.new();rng.seed=12345+i
  var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"ui:%d"%i,"gold",["laser","missile","cannon","longLaser"][i%4],20,"1")
  d.affixes=[{"key":"global_damage","tier":2,"value":0.655,"locked":false}]
  check(Bag.insert(s.inventory,d,g.hyperspace.config),"Fixture insert")
 g.hyperspace.publish(g,s,"fixture");p.refresh();p.select_section(1);await process_frame;var refreshes=p.list_refreshes;var snapshots=p.manual_snapshot_reads
 for i in 120:p.refresh_progress()
 check(p.list_refreshes==refreshes and p.manual_snapshot_reads==snapshots,"Progress refresh never clones namespace or warehouse")
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
 p.filter_text.text=preload("res://scripts/hyperspace_filter.gd").export_string({"version":2,"enabled":false,"action":"clear_matches","mode":"all","conditions":[{"field":"quality","value":"blue"},{"field":"minimum_level","value":40}]},g.hyperspace.config)
 p.import_filter_draft();check(not p.string_dialog.visible and p.filter_kinds[0].get_item_metadata(p.filter_kinds[0].selected)=="quality" and p.condition_levels[1].value==40,"Validated import populates localized controls")
 check(JSON.stringify(g.profile)==string_profile,"String import never mutates profile")
 var focus=p.preset_names[0];focus.text="草稿";focus.grab_focus();var list_count=p.list_refreshes
 p.refresh();check(p.preset_names[0].text=="草稿" and root.gui_get_focus_owner()==focus,"Refresh preserves draft and focus")
 check(p.list_refreshes==list_count,"Unchanged refresh does not rebuild list")
 scene.select_system(0);await process_frame;p.dirty=true;p.refresh();check(p.list_refreshes==list_count,"Hidden page has no list writes")
 scene.select_system(9);await process_frame
 var Codec=preload("res://scripts/hyperspace_filter.gd")
 var rule={"version":2,"enabled":false,"action":"keep_matches","mode":"any","conditions":[{"field":"weapon","value":"cannon"}]}
 check(p.valid_draft(Codec.import_string(Codec.export_string(rule,g.hyperspace.config),g.hyperspace.config)),"Domain versioned rule preview")
 for invalid in ['SPACE-FILTER-v1:AAAA','SPACE-FILTER-v1:????','x'.repeat(4097),'{"version":2}']:
  check(Codec.import_string(invalid,g.hyperspace.config).is_empty(),"Invalid version, encoding, length rejected")
 check(not p.filter_enabled.button_pressed,"Auto processing defaults off")
 p.filter_enabled.button_pressed=true;p.filter_action.select(1);p.save_filter()
 check(g.profile.hyperspace.filter.enabled and g.profile.hyperspace.filter.action=="clear_matches" and p.filter_result.text==p.t("filter_saved"),"Explicit action saved through real domain")
 check(g.hyperspace.export_filter(g).begins_with("SPACE-FILTER-v2:") and Codec.import_string(g.hyperspace.export_filter(g),g.hyperspace.config).action=="clear_matches","Action survives formal export and preview")
 # Real preset application and capacity use the domain, without injected adapters.
 g.switch_ship("Heavy_Battleship")
 check(g.hyperspace.set_equipped(g,["ui:8"]),"Equip through actual hull capacity")
 check(g.hyperspace.set_preset(g,0,"旗舰",["ui:8"]),"Save named preset")
 check(g.hyperspace.set_equipped(g,[]),"Clear equipped")
 p.preset_adapter.call(0);check(g.profile.hyperspace.inventory.equipped==["ui:8"],"Preset applies actual domain")
 # Quoting is read-only; commit uses the frozen command and localizes failures.
 p.selected_id="ui:8";p.select_section(2);p.commands.select_operation("reroll_values")
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
 g.profile.hyperspace.hanging_modules.resource_collector.level=3;g.invalidate_stat_cache()
 p.commands.show_totals();await capture_window(p.commands.totals_dialog,"equipped-totals")
 check(p.commands.totals_label.text.contains(p.t("percent",{"value":"%.1f"%(float(g.hyperspace_totals().hangings.resource_collector)*100.0)})),"Installed module total comes from domain projection")
 var totals_scroll=p.commands.totals_label.get_parent();totals_scroll.scroll_vertical=9999
 await capture_window(p.commands.totals_dialog,"equipped-totals-modules")
 check(p.commands.totals_label.text.contains("全局伤害") and not p.commands.totals_label.text.contains("chrono"),"Authoritative totals displayed without old storage target")
 p.commands.totals_dialog.hide()
 g.profile.hyperspace.legendary_seen=["scatter_pulse"];p.commands.show_collection();await capture_window(p.commands.collection_dialog,"legendary-collection")
 check(p.commands.collection_choices.size()==1,"Collection only offers seen effects");p.commands.collection_dialog.hide()
 # Read-only visual integration: max hull + five drones + existing ordinary turrets.
 g.switch_ship("Heavy_Battleship")
 for entry in g.weapon_entries():entry.key="laser"
 var next_state=g.hyperspace.snapshot(g);next_state.inventory.equipped=["ui:0","ui:1","ui:2","ui:3","ui:4"];next_state.inventory.generation+=1;g.hyperspace.publish(g,next_state,"fixture")
 p.select_section(1);scene._process(0);var visual=scene.hyperspace_visual
 check(visual.nodes.size()==5 and scene.ship_view.carriers.size()==3 and scene.ship_view.viewport.get_parent()==scene.ship_view,"Five models share existing fleet viewport")
 for id in visual.identities:
  check(visual.muzzles.has(id) and not visual.muzzles[id].is_empty(),"Each model owns an authored muzzle")
 check(visual.muzzles["ui:1"].size()==2,"Twin missile bays are distinct authored muzzles")
 var aim=Vector2(250,100);var sample=scene._prototype_drone_launch_pose("ui:1",aim,0)
 var actual=scene.battle_logical_point(visual.screen_muzzle_for_drone("ui:1",0,scene.ship_view))
 check(sample.position.distance_to(actual)<0.001,"Provider uses actual camera-projected mesh front")
 scene.close_up=true;scene._process(0)
 check(scene._prototype_drone_launch_pose("ui:1",aim,0).position.distance_to(sample.position)<0.001,"Inspection magnification preserves canonical launch point")
 scene.close_up=false;scene._process(0)
 check(scene._prototype_drone_launch_pose("ui:1",aim,1).position.distance_to(sample.position)>1.0,"Salvo alternates actual bay fronts")
 var projectile_index=g.weapon_entries().size()+1
 check(g.start(7,false),"Ordinary encounter fixture starts without hyperspace route injection");g.spawn_group()
 var enemy=g.enemies[0];enemy.hp=1000000000.0;enemy.max_hp=1000000000.0
 scene._process(0);sample=scene._prototype_drone_launch_pose("ui:1",aim,0)
 g.refresh_missile_target_registry();g.begin_enhancement_attack(projectile_index,enemy)
 var attack=g.jewel_attack(projectile_index);var weapon=g.player_weapon_row(g.combat_entry(projectile_index))
 g.launch_player_attack(projectile_index,enemy,weapon,attack,g.player_weapon_offset(projectile_index),0.0,0,1);g.finish_enhancement_attack(projectile_index);g.tick_projectiles(0.0)
 check(not g.projectiles.is_empty() and g.projectiles.back().get("prototype_missile",false) and g.projectiles.back().launch_point.distance_to(sample.position)<0.001,"Real queued missile launches from its visible drone bay")
 scene.pulse_layer.queue_redraw();scene.battle_layer.queue_redraw()
 await capture("actual-drone-missile-launch")
 var source_events: Array[Dictionary]=[];g.event.connect(func(kind,data):
  if kind=="fire" or kind=="beam_started":source_events.append(data.shot))
 var pulse_index=g.weapon_entries().size();g.begin_enhancement_attack(pulse_index,enemy)
 g.launch_player_attack(pulse_index,enemy,g.player_weapon_row(g.combat_entry(pulse_index)),g.jewel_attack(pulse_index),g.player_weapon_offset(pulse_index),0.0);g.finish_enhancement_attack(pulse_index)
 var pulse=source_events.back()
 check(pulse.entry.drone_id=="ui:0" and scene.shot_mount(pulse)==-1 and scene.visual_muzzle(pulse).distance_to(scene._prototype_drone_launch_pose("ui:0",aim,0).position)<0.001,"Real pulse fire event owns correct lens and excludes ordinary turrets")
 scene.pulse_layer.queue_redraw();scene.battle_layer.queue_redraw();await capture("actual-drone-pulse-launch")
 var plain_rail_index=g.weapon_entries().size()+2;g.begin_enhancement_attack(plain_rail_index,enemy)
 g.launch_player_attack(plain_rail_index,enemy,g.player_weapon_row(g.combat_entry(plain_rail_index)),g.jewel_attack(plain_rail_index),g.player_weapon_offset(plain_rail_index),0.0);g.finish_enhancement_attack(plain_rail_index)
 var plain_rail=source_events.back()
 check(plain_rail.entry.drone_id=="ui:2" and plain_rail.dead and not g.projectiles.has(plain_rail) and scene.visual_muzzle(plain_rail).distance_to(scene._prototype_drone_launch_pose("ui:2",aim,0).position)<0.001,"Real ordinary rail event owns correct cap and retires immediately")
 scene.pulse_layer.queue_redraw();scene.battle_layer.queue_redraw();await capture("actual-drone-ordinary-rail")
 # Explicit legendary fixture exercises shared cannon geometry without editing any production table.
 var rail_drone=g.profile.hyperspace.inventory.drones["ui:2"];rail_drone.legendary=true;rail_drone.legendary_effect={"effect_id":"higgs_cannon","parameters":{"damage_bonus":2.2,"area_bonus":1.5}};g.invalidate_stat_cache()
 var rail_index=g.weapon_entries().size()+2;g.begin_enhancement_attack(rail_index,enemy)
 var fired: Array[Dictionary]=[];g.event.connect(func(kind,data):
  if kind=="fire":fired.append(data.shot))
 var rail_attack=g.jewel_attack(rail_index);g.launch_player_attack(rail_index,enemy,g.player_weapon_row(g.combat_entry(rail_index)),rail_attack,g.player_weapon_offset(rail_index),0.0);g.finish_enhancement_attack(rail_index)
 var rail_shot=fired.back();var rail_origin=scene.battle_point(scene._prototype_drone_launch_pose("ui:2",aim,0).position)
 check(not g.projectiles.has(rail_shot) and rail_shot.dead,"Instantaneous rail is retired on fire frame")
 check(g.rail_geometry_provider.is_valid() and g.drone_launch_provider.is_valid(),"Both Higgs geometry and drone launch providers survive merge")
 check(rail_shot.higgs.origin.distance_to(rail_origin)<0.001,"Higgs frozen origin uses actual drone rail cap")
 check(is_equal_approx(float(rail_shot.higgs.full_width),scene.rail_vfx.discharge_width(2.5)) and is_equal_approx(float(scene.rail_events.filter(func(e):return e.kind=="fire").back().full_width),float(rail_shot.higgs.full_width)),"Higgs display and hit strip share frozen width")
 scene.pulse_layer.queue_redraw();scene.battle_layer.queue_redraw()
 await capture("actual-drone-higgs-discharge")
 var beam_index=g.weapon_entries().size()+3;g.lock_long_laser(g.player,g.player_weapon_row(g.combat_entry(beam_index)),false,beam_index,g.combat_entry(beam_index))
 var beam=g.projectiles.back();check(beam.get("beam",false) and scene.visual_muzzle(beam).distance_to(scene._prototype_drone_launch_pose("ui:3",aim,0).position)<0.001,"Actual drone beam displays its own optical emitter")
 scene.pulse_layer.queue_redraw();scene.battle_layer.queue_redraw();await capture("actual-drone-beam-emitter")
 check(scene.shot_mount(beam)==-1 and scene.shot_mount(g.projectiles[0])==-1,"Drone shot visuals cannot index ordinary turret state")
 g.enemies.clear();g.projectiles.clear();g.state=g.State.MAIN_MENU
 var rebuilds=visual.rebuilds
 g.profile.hyperspace.inventory.drones["ui:0"].level=21;visual.sync(g.profile.hyperspace.inventory)
 check(visual.rebuilds==rebuilds,"Numeric changes excluded from model signature")
 var retained=visual.nodes.duplicate();scene.select_system(0);scene._process(0);scene.select_system(9);scene._process(0)
 check(visual.rebuilds==rebuilds and visual.nodes==retained,"Hidden/revealed workspace retains model identities")
 g.drone_combat.disabled=["ui:0"];scene._process(0)
 check(not visual.nodes[0].visible and visual.nodes[1].visible and visual.rebuilds==rebuilds,"Disabled drone hides without model rebuild")
 g.drone_combat.disabled.clear();scene._process(0)
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
