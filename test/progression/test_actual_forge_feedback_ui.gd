extends "res://qa/hyperspace_longrun.gd"
var ui_results:Array=[]
var ui_checks:=0
var ui_failures:=0
func check(ok:bool,label:String):
 ui_checks+=1
 if not ok:ui_failures+=1;printerr("FAIL: ",label)

func ui_record(kind:String,values:Dictionary):
 values["kind"]=kind;values["x1_seconds"]=game.simulated_time;ui_results.append(values);print("UI_PLAY ",JSON.stringify(values))
func click_ui(control,label:String):
 var ok=await player_input.press(control);check(ok,"Actual native click "+label);ui_record("native_click",{"label":label,"ok":ok,"gate":player_input.last_gate.duplicate(true)});return ok
func save_sig():
 var s=game.portable_save_data().duplicate(true);s.erase("chronoSavedAt");s.erase("hightechSavedAt");return s
func capture(name:String):
 var before=save_sig();var rng=str(game.rng.state);driver.scene._process(0.0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png");ui_record("screenshot",{"name":name,"size":str(root.get_texture().get_size()),"model_unchanged":save_sig()==before and rng==str(game.rng.state)})
const Meter=preload("res://qa/stage_meter.gd")
func _initialize():call_deferred("review_native")
func observe_state(kind:String):
 var p=driver.scene.hyperspace_panel
 ui_record(kind,{"x1":game.simulated_time,"state":int(game.state),"stage":game.stage,"group":game.group_index,"boundary":game.manual_hyperspace.boundary_reason(game),"qa_pending_ready":not space_policy.pending_manual_action(game,game.simulated_time).is_empty(),"projectiles":game.projectiles.size(),"start_gate":player_input.gate(p.start_button),"start_text":p.start_button.text,"start_tooltip":p.start_button.tooltip_text,"reason_text":p.manual_reason.text,"status":p.status.text,"queued":game.manual_hyperspace.queued.duplicate(true),"active":game.profile.hyperspace.active.duplicate(true),"energy":game.profile.hyperspace.energy,"resources":game.profile.resources.duplicate(true),"rng":str(game.rng.state)})
func key(code:int,wid:int=-1):
 for down in [true,false]:
  var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;e.window_id=root.get_window_id() if wid<0 else wid;Input.parse_input_event(e);await process_frame
func choose_option(control,index:int,label:String):
 await click_ui(control,label);var pop=control.get_popup();var wid=root.get_window_id() if root.gui_embed_subwindows else pop.get_window_id()
 await key(KEY_HOME,wid)
 for i in 20:
  if pop.get_focused_item()==index:break
  await key(KEY_DOWN if pop.get_focused_item()<index else KEY_UP,wid)
 ui_record("native_menu_focus",{"label":label,"focus":pop.get_focused_item(),"window":wid,"embedded":root.gui_embed_subwindows})
 await key(KEY_ENTER,wid);await process_frame
 ui_record("native_option",{"label":label,"selected":control.selected,"expected":index})
 check(control.selected==index,"Native menu selected exact operation "+label)
func find_text_button(parent:Node,txt:String):
 if parent is Button and parent.text==txt:return parent
 for c in parent.get_children():
  var v=find_text_button(c,txt)
  if v!=null:return v
 return null
func forge_observe(name:String):
 var p=driver.scene.hyperspace_panel;var c=p.commands;var h=game.profile.hyperspace
 ui_record(name,{"selected":p.selected_id,"operation":c.operation.get_item_metadata(c.operation.selected),"quote":c.quote_label.text,"feedback":c.feedback.text,"quote_visible":c.quote_label.is_visible_in_tree(),"feedback_visible":c.feedback.is_visible_in_tree(),"commit_gate":player_input.gate(c.commit_button),"request":c.quoted_request.duplicate(true),"materials":h.materials.duplicate(),"cores":h.ultimate_cores,"seq":h.command_seq,"drone":h.inventory.drones.get(p.selected_id,{}).duplicate(true)})
func review_native():
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"));trace=FileAccess.open(output+"/native-actions.jsonl",FileAccess.WRITE)
 var packet=bytes_to_var(FileAccess.get_file_as_bytes(OS.get_environment("QA_UI_RETURN_VARIANT")))
 game=Game.new(ShipDatabase.new());game.stat_cache_enabled=true;game.save_enabled=false;check(game.load_hyperspace_routes(),"Actual production routes load")
 driver=Driver.new();driver.production_ui_ticks=true;driver.scene_path="res://qa/cached_battlefield.tscn";driver.drop_post_vfx=true;driver.ui_refresh_seconds=3600;driver.setup(self,game)
 player_input=PlayerInput.new();player_input.setup(driver.scene,self);root.size=Vector2i(int(OS.get_environment("QA_UI_WIDTH")) if not OS.get_environment("QA_UI_WIDTH").is_empty() else 1373,int(OS.get_environment("QA_UI_HEIGHT")) if not OS.get_environment("QA_UI_HEIGHT").is_empty() else 883);root.grab_focus();await process_frame;await process_frame
 var restored=Checkpoint.restore(self,packet.payload)
 var s:Dictionary=packet.state
 for key in s:
  if key in ["profile","rng","galaxies","branch_weapons","branch_defenses","branch_sources"]:continue
  if game.get(key) is Array:game.get(key).assign(s[key])
  else:game.set(key,s[key])
 game.profile=s.profile.duplicate(true);game.simulated_time=packet.payload.x1_seconds;game.rng.state=int(s.rng)
 game.enhancement_branches.weapons=s.branch_weapons.duplicate(true);game.enhancement_branches.defenses=s.branch_defenses.duplicate(true);game.enhancement_branches.incoming_sources=s.branch_sources.duplicate(true)
 game.invalidate_stat_cache();driver.scene.refresh_navigation();driver.scene.refresh_visible_cards();driver.before_tick(0.0)
 ui_record("captured_actual_replay_state",{"source_x1":packet.payload.x1_seconds,"source_conditions":packet.conditions,"source_uid":game.enemies.map(func(e):return e.uid),"projectile_uids":game.projectiles.map(func(e):return e.get("uid",-1)),"restored_production_load":restored,"scope":"诊断真实发生时的原生Variant运行态投影画面，无伪造尾弹，无tick"})

 await visit_page(9);observe_state("actual_clean_boundary_before_request");await capture("01-clean-boundary-before-native-queue")
 var energy=game.profile.hyperspace.energy;var bank=game.profile.resources.duplicate(true);var rng=str(game.rng.state)
 await click_ui(driver.scene.hyperspace_panel.start_button,"native_queue_at_actual_clean_boundary");await capture("02-native-queued-ready-not-charged");observe_state("after_actual_queue_draw")
 driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP);driver.scene.refresh_visible_cards();await capture("03-actual-expired-timer-paid-entry");observe_state("after_actual_production_tick_draw")
 check(game.manual_hyperspace.active and game.profile.hyperspace.active.ticket==108000.0,"Original actual expired countdown now starts one real paid receipt")
 check(game.manual_hyperspace.return_state.clear_timer==0.0,"Actual receipt contains normalized elapsed countdown")
 await click_ui(driver.scene.hyperspace_panel.exit_button,"native_exit_actual_paid_timer_receipt")
 check(not game.manual_hyperspace.active and game.stage==7,"Native exit restores real source main stage")
 # Separate explicit contract fixture, NOT natural progress: nonfinite remaining timer is still invalid.
 game.clear_timer=INF;var fixture_energy:float=game.profile.hyperspace.energy;var fixture_bank=game.profile.resources.duplicate(true);var fixture_rng=str(game.rng.state)
 ui_record("declared_nonfinite_timer_contract_fixture",{"field":"clear_timer","scope":"Isolated actual-source UI instance; explicit invalid remaining-time fixture, not a natural campaign event"})
 driver.scene.refresh_visible_cards();await click_ui(driver.scene.hyperspace_panel.start_button,"native_queue_nonfinite_contract_fixture")
 driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP);driver.scene.refresh_visible_cards()
 driver.scene._process(0.0);await process_frame
 var panel=driver.scene.hyperspace_panel
 check(game.manual_hyperspace.last_error=="invalid_main_return" and game.manual_hyperspace.queue_error=="invalid_main_return","Actual start failure retains precise domain cause")
 check(not game.manual_hyperspace.active and game.profile.hyperspace.energy>=fixture_energy-1.0 and fixture_bank==game.profile.resources and fixture_rng==str(game.rng.state),"Invalid contract fixture never pays a ticket or rolls economy/RNG")
 check(panel.status.text.contains("主线状态") and not panel.status.text.contains("路线或等级"),"Visible queue feedback describes return-state failure")
 check(panel.manual_reason.visible and panel.start_button.tooltip_text.contains("重新载入"),"Retry control keeps actionable recovery explanation")
 await capture("08-invalid-return-contract-recovery-message")

 ui_record("real_failure_semantics",{"logical_ticks":1,"manual_error":game.manual_hyperspace.last_error,"queue_error":game.manual_hyperspace.queue_error,"energy_unchanged":energy==game.profile.hyperspace.energy,"resources_unchanged":bank==game.profile.resources,"rng_unchanged":rng==str(game.rng.state),"clear_timer":game.clear_timer})
 driver.close();await process_frame
 game=Game.new(ShipDatabase.new());game.stat_cache_enabled=true;game.save_enabled=false;check(game.load_hyperspace_routes(),"Actual production routes load")
 driver=Driver.new();driver.production_ui_ticks=true;driver.scene_path="res://qa/cached_battlefield.tscn";driver.drop_post_vfx=true;driver.ui_refresh_seconds=3600;driver.setup(self,game)
 player_input=PlayerInput.new();player_input.setup(driver.scene,self);root.size=Vector2i(int(OS.get_environment("QA_UI_WIDTH")) if not OS.get_environment("QA_UI_WIDTH").is_empty() else 1373,int(OS.get_environment("QA_UI_HEIGHT")) if not OS.get_environment("QA_UI_HEIGHT").is_empty() else 883);await process_frame;await process_frame
 var src=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_UI_FORGE_SOURCE")));var payload=packet.payload.duplicate(true);payload.save=src.save.duplicate(true);payload.x1_seconds=src.x1_seconds;payload.rng_state=src.rng_state;Checkpoint.restore(self,payload);driver.scene.refresh_navigation();driver.scene.refresh_visible_cards()
 ui_record("actual_forge_source",{"x1":src.x1_seconds,"source":"libfile_ddfba8c24064819190d1170a2788bca7 v1 real57600","scope":"same real source isolated UI projection; no fabricated materials/drone"})
 await visit_page(9);var p=driver.scene.hyperspace_panel;await click_ui(p.section_buttons[1],"native_inventory_section")
 var card=null
 for b in p.cards:
  if b.get_meta("drone_id","")=="space:1:14":card=b
 await click_ui(card,"native_select_actual_blue_missile_14");await click_ui(p.section_buttons[2],"native_forge_section")
 var c=p.commands;await choose_option(c.operation,4,"native_promote_affix_operation");forge_observe("promote_before_quote")
 check(c.promotion_hint.is_visible_in_tree() and c.promotion_hint.text.contains("失败仍消耗") and c.promotion_hint.text.contains("未锁定"),"Promotion risk is visible before paying")
 var before=save_sig();var r0=str(game.rng.state);var f0=str(game.profile.hyperspace.inventory.drones[p.selected_id].forge_rng_state)
 var quote=find_text_button(p.sections[2],p.t("quote"));await click_ui(quote,"native_promote_quote");await capture("04-promote-price-and-quote-real-materials");forge_observe("promote_after_quote")
 check(before==save_sig() and r0==str(game.rng.state) and f0==str(game.profile.hyperspace.inventory.drones[p.selected_id].forge_rng_state),"Preview is readonly for business and both RNGs")
 ui_record("quote_readonly",{"business_unchanged":before==save_sig(),"global_rng_unchanged":r0==str(game.rng.state),"forge_rng_unchanged":f0==str(game.profile.hyperspace.inventory.drones[p.selected_id].forge_rng_state)})
 await click_ui(c.commit_button,"native_paid_promote_once");await capture("05-paid-promote-actual-result");forge_observe("promote_after_commit")
 check(game.profile.hyperspace.materials.antiproton==1 and c.feedback.text.contains("未成功") and game.profile.hyperspace.inventory.drones[p.selected_id].affixes.map(func(a):return int(a.tier))==[5,4],"Same-source actual paid draw fails once and debits exactly one")
 check(c.quote_label.text.replace(" ","").contains("持有1") and not c.quote_label.text.replace(" ","").contains("持有2") and c.quoted_request.is_empty() and c.commit_button.disabled,"Completed debit shows current balance and cannot reuse old quote")
 await choose_option(c.operation,8,"native_legendary_insufficient_operation");await capture("07-new-operation-clears-old-result-feedback");forge_observe("changed_operation_before_requote")
 check(c.feedback.text.is_empty() and not c.promotion_hint.visible,"Changing operation clears previous result and promotion-only hint")
 var before_insuff=save_sig();await click_ui(quote,"native_legendary_insufficient_quote");await capture("06-insufficient-materials-price-and-reason");forge_observe("legendary_after_quote");check(before_insuff==save_sig() and c.commit_button.disabled and c.quote_label.text.replace(" ","").contains("持有1"),"Real insufficient legendary quote stays readonly and disabled");ui_record("insufficient_preview_readonly",{"business_unchanged":before_insuff==save_sig()})
 FileAccess.open(output+"/native-ui-observations.json",FileAccess.WRITE).store_string(JSON.stringify(ui_results,"\t"));trace.close();driver.close();await process_frame;print("FORGE_FEEDBACK_UI ",ui_checks," checks ",ui_failures," failures");quit(2 if ui_failures else 0)
