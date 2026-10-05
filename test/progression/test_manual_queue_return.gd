extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
const Return=preload("res://scripts/hyperspace_main_return.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
const CC=preload("res://scripts/combat_context.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func click(control:Control)->void:
 await process_frame;await process_frame
 var point=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
 var motion=InputEventMouseMotion.new();motion.position=point;motion.window_id=root.get_window_id();Input.parse_input_event(motion);await process_frame
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.window_id=root.get_window_id();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func capture(name:String)->void:
 var folder=OS.get_environment("QA_MANUAL_EVIDENCE")
 if folder.is_empty() or DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+name+".png")
func frozen_health(g)->Dictionary:
 return {"armour":g.player.armour,"shield":g.player.shield,"since_hit":g.since_hit,"cooldowns":g.cooldowns.duplicate(true),"debt":g.enhancement_deferred.duplicate(true)}
func run()->void:
 var width=OS.get_environment("QA_MANUAL_WIDTH")
 if not width.is_empty():root.size=Vector2i(int(width),int(OS.get_environment("QA_MANUAL_HEIGHT")))
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);current_scene=scene;scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.profile.onboarding.completed=true;g.profile.cleared=range(1,33);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources["1"]=1e12
 check(g.load_hyperspace_routes(),"Production routes accepted")
 # Explicit lawful progress/UI fixtures; no timing or balance acceptance.
 for ship in g.db.ships.keys():
  if g.ship_unlocked(ship) and g.active_slot_count("defence",ship)>1:g.switch_ship(ship);break
 check(g.equip_slot("defence",1,"shield"),"Legal equipped shield fixture")
 check(g.start(7,false),"Actual main route starts");g.pending_unlocks.clear();g.spawn_group()
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var panel=scene.hyperspace_panel;panel.level.value=5;panel.refresh_manual_status();panel.refresh()
 var before=JSON.stringify(g.profile);var rng_before=str(g.rng.state);var enemy_ids=g.enemies.map(func(e):return e.uid)
 check(not g.start_hyperspace("alpha",5) and JSON.stringify(g.profile)==before and str(g.rng.state)==rng_before,"Direct production entry rejects live COMBAT without ticket/profile/RNG change")
 var stable=scene.equipment_tabs;var stable_cards=panel.cards.duplicate()
 await click(panel.start_button);panel.refresh_progress()
 check(not g.manual_hyperspace.queued.is_empty() and not g.manual_hyperspace.active and JSON.stringify(g.profile)==before,"Native start queues without any authoritative profile change")
 check(panel.cancel_queue_button.visible and panel.start_button.disabled and panel.status.text.contains("尚未扣票") and panel.status.text.contains("战点"),"Native UI shows safe waiting and cancel feedback")
 await capture("01-main-combat-queued")
 var draft=g.manual_hyperspace.queued.duplicate()
 check(g.request_hyperspace(str(draft.route),5) and g.manual_hyperspace.queued==draft and JSON.stringify(g.profile)==before,"Duplicate same request cannot consume or duplicate ticket")
 await click(panel.cancel_queue_button);panel.refresh_progress()
 check(g.manual_hyperspace.queued.is_empty() and JSON.stringify(g.profile)==before and str(g.rng.state)==rng_before,"Native cancellation is zero profile/RNG change")
 check(scene.equipment_tabs==stable and panel.cards==stable_cards,"Queue/cancel preserve unrelated tab and inventory control identities")
 await click(panel.start_button)
 for enemy in g.enemies.duplicate():g.hit_enemy(enemy,1e100,0,[],false,CC.root(100,"fixture","laser"))
 g.tick(0.001)
 check(g.state==g.State.TRAVEL and not g.manual_hyperspace.active,"Actual first wave completes before queued dispatch")
 # A declared in-flight sentinel exercises eligibility only; never tick fake combat objects.
 g.projectiles.append({"sentinel":true})
 check(not g.manual_hyperspace.dispatch_queued(g) and g.manual_hyperspace.boundary_reason(g)=="projectiles","Residual shots delay dispatch without clearing them")
 g.projectiles.clear();g.missile_queue.clear();g.jewel_repeats.clear();g.drone_combat.delayed.clear()
 g.profile.enhancementLevel=100;g.invalidate_stat_cache()
 check(g.set_enhancement_branch("weapons","critical",1,"B") and g.set_enhancement_branch("weapons","critical",2,"B"),"Eligible critical branches fixture uses real selectors")
 check(g.set_enhancement_branch("defence","adaptation",2,"B"),"Eligible cover branch fixture uses real selector")
 var weapon_state=g.enhancement_branches.weapon(g,0);weapon_state.next=2;weapon_state.stacks=3;weapon_state.stack_time=5.0
 var defense_state=g.enhancement_branches.defense(g,0);defense_state.cover=g.N.minimum(4.0,g.stat("armour"));defense_state.cover_time=3.0;defense_state.cover_elapsed=0.2
 var buffer=g.N.divide(g.enhancement_module_protection_capacity(0),3.0)
 g.enhancement_buffers[0]=buffer;g.enhancement_buffer_owners[0]={"entry":g.slot_entry("defence",0),"key":"armour"}
 g.player.armour=g.N.multiply(g.stat("armour"),0.37);g.player.shield=g.N.multiply(g.max_shield(),0.23);g.since_hit=0.25
 g.queue_enhancement_deferred("armour",1.25)
 var expected=frozen_health(g);var original_point=Return.journey(g);var energy=float(g.profile.hyperspace.energy);var base=g.db
 g.tick(0.001)
 check(g.manual_hyperspace.active and is_equal_approx(float(g.profile.hyperspace.energy),minf(float(g.hyperspace.config.energy_cap),energy-float(g.hyperspace.config.ticket)+float(g.hyperspace.config.energy_rate)*0.001)),"Production tick revalidates then dispatches exactly one ticket")
 check(g.manual_hyperspace.return_state.armour==expected.armour and g.manual_hyperspace.return_state.shield==expected.shield,"Return receipt freezes already damaged main health")
 panel.refresh_progress();await capture("02-dispatched-manual")
 # Real paid growth while away must survive; no historical economy/RNG snapshot is restored.
 var old_level=int(g.profile.loadout.defence[0].level)
 check(g.upgrade("armour",1),"Real paid armour upgrade while in manual route")
 var balances=g.profile.resources.duplicate(true);g.rng.randi();var after_rng=str(g.rng.state)
 var refunded_energy=float(g.profile.hyperspace.energy)+float(g.profile.hyperspace.active.ticket)
 await click(panel.exit_button);panel.refresh_progress()
 check(not g.manual_hyperspace.active and is_same(g.db,base) and g.stage==int(original_point.stage) and g.group_index==int(original_point.groupIndex) and g.state==int(original_point.state),"Native exit returns exact completed main point without start/spawn")
 check(g.enemies.is_empty() and not g.enemies.any(func(e):return enemy_ids.has(e.uid)),"Killed main ships remain dead")
 check(frozen_health(g)==expected,"Native exit restores absolute armour/shield, shield delay, cooldowns and existing debt without heal or zero-CD")
 check(g.enhancement_branches.weapon(g,0).next==2 and g.enhancement_branches.weapon(g,0).stacks==3 and g.enhancement_branches.weapon(g,0).stack_time==5.0 and g.enhancement_branches.defense(g,0).cover_time==3.0 and g.N.compare(g.memory_buffer(0),buffer)==0,"Critical charges/stacks, owned cover and Memory buffer are frozen and restored without free regeneration")
 check(g.profile.resources==balances and str(g.rng.state)==after_rng and int(g.profile.loadout.defence[0].level)==old_level+1,"Paid growth, resource balances and advanced global RNG survive return")
 check(g.profile.hyperspace.energy==refunded_energy and not g.manual_hyperspace.finish(g,false),"Voluntary failure refunds one ticket; duplicate finish cannot refund again")
 await capture("03-restored-main")
 # Interrupted current-version save/read restores the same damage and debt exception.
 check(g.start_hyperspace("alpha",5),"Safe direct entry still available for domain/controller")
 var saved=g.portable_save_data();var json_saved=JSON.parse_string(JSON.stringify(saved))
 check(Transfer.new().prepare_data(json_saved,base).error=="","Portable save schema preserves validated main-return receipt")
 var reloaded=BattleGame.new(base,false);check(reloaded.load_hyperspace_routes(),"Reload production routes accepted")
 reloaded.load_progress_data(json_saved);reloaded.resume_progress()
 check(reloaded.profile.hyperspace.active.is_empty() and float(reloaded.profile.hyperspace.energy)==refunded_energy,"Interrupted save/read refunds exactly once without offline work")
 check(frozen_health(reloaded)==expected and reloaded.enemies.is_empty() and reloaded.group_index==int(original_point.groupIndex),"Interrupted load preserves frozen health/debt/cooldown and completed battle point")
 var once=float(reloaded.profile.hyperspace.energy);reloaded.load_progress_data(json_saved);reloaded.resume_progress()
 check(float(reloaded.profile.hyperspace.energy)==once,"Reading the same started receipt twice cannot compound refunded energy")
 var corrupt=json_saved.duplicate(true);corrupt.hyperspace.active.return_state.since_hit=-1
 var reload_before=JSON.stringify(reloaded.profile)
 check(reloaded.request_hyperspace("alpha",5),"Runtime queue fixture before corrupt import")
 reloaded.load_progress_data(corrupt)
 check(reloaded.hyperspace.last_error=="invalid_hyperspace_save" and JSON.stringify(reloaded.profile)==reload_before and not reloaded.manual_hyperspace.queued.is_empty(),"Corrupt return state rejects before profile change or queue cancellation")
 var empty_return=json_saved.duplicate(true);empty_return.hyperspace.active.return_state={}
 reloaded.load_progress_data(empty_return)
 check(reloaded.hyperspace.last_error=="invalid_hyperspace_save" and JSON.stringify(reloaded.profile)==reload_before,"Removing current receipt's return snapshot is rejected")
 var bad_point=json_saved.duplicate(true);bad_point.hyperspace.active.return_journey.groupIndex=99999
 reloaded.load_progress_data(bad_point)
 check(reloaded.hyperspace.last_error=="invalid_hyperspace_save" and JSON.stringify(reloaded.profile)==reload_before and not reloaded.manual_hyperspace.queued.is_empty(),"Out-of-bounds main point rejects before state/profile mutation")
 reloaded.cancel_hyperspace_request();g.manual_hyperspace.finish(g,false)
 # Dispatch observes current resources and ownership, not the queued preview.
 check(g.request_hyperspace("alpha",5),"Request for energy revalidation")
 g.profile.hyperspace.energy=0;var depleted=JSON.stringify(g.profile)
 check(not g.manual_hyperspace.dispatch_queued(g) and g.manual_hyperspace.queued.is_empty() and g.manual_hyperspace.queue_error=="energy" and JSON.stringify(g.profile)==depleted,"Dispatch shortage cancels without any ticket or profile mutation")
 panel.refresh_progress();await capture("04-revalidation-rejected")
 g.profile.hyperspace.energy=energy;check(g.request_hyperspace("alpha",5),"Request for current-version queue save")
 var queue_save=g.portable_save_data();var clean=BattleGame.new(base,false);clean.load_progress_data(queue_save);clean.resume_progress()
 check(clean.manual_hyperspace.queued.is_empty() and clean.profile.hyperspace.energy==g.profile.hyperspace.energy,"Unpaid queue never persists or charges on reload")
 g.cancel_hyperspace_request()
 # Big growth-number payload survives official portable cleaning.
 check(g.start_hyperspace("alpha",5),"Safe entry for large-number schema validation")
 var large=g.portable_save_data();large.hyperspace.active.return_state.enhancement_deferred={"1":{"armour":{"m":1.25,"e":350},"shield":0.0}}
 var prepared=Transfer.new().prepare_data(JSON.parse_string(JSON.stringify(large)),base)
 if not prepared.error.is_empty():print("LARGE_SAVE_REJECT ",prepared.error)
 check(prepared.error=="" and g.N.compare(prepared.data.hyperspace.active.return_state.enhancement_deferred["1"].armour,{"m":1.25,"e":350})==0,"Declared growth schema preserves huge debt without dropping or overflowing it")
 g.manual_hyperspace.finish(g,false)
 # Actual ten-wave success returns before reward settlement, retaining the earned result.
 var cleared_before=g.profile.cleared.duplicate();var front_before=int(g.profile.highestLevel);var uid_before=g.uid
 var success_health=frozen_health(g)
 check(g.start_hyperspace("alpha",5),"Safe entry for actual ten-wave success fixture")
 for layer in 10:
  g.spawn_group()
  for enemy in g.enemies.duplicate():g.hit_enemy(enemy,1e100,0,[],false,CC.root(1000+layer,"fixture","laser"))
  g.tick(0.001)
 check(not g.manual_hyperspace.active and g.profile.hyperspace.active.get("status","")=="completed_pending" and g.hyperspace.best_x1(g,"alpha",5)>0,"Actual ten-wave victory returns and keeps earned pending reward/history")
 check(g.enemies.is_empty() and g.uid>uid_before and g.profile.cleared==cleared_before and int(g.profile.highestLevel)==front_before and frozen_health(g)==success_health,"Success restores main health/debt, keeps monotonic UID and cannot clear mainline")
 var receipt=g.profile.hyperspace.active.duplicate(true)
 check(g.hyperspace.claim(g,int(receipt.round_id),int(receipt.run_id)),"Actual returned victory reward can be claimed")
 var claimed=JSON.stringify(g.profile.hyperspace)
 check(not g.hyperspace.claim(g,int(receipt.round_id),int(receipt.run_id)) and JSON.stringify(g.profile.hyperspace)==claimed,"Duplicate returned reward cannot mutate balances")
 # A legal refit while away clamps surviving amounts and cannot transfer old weapon charges.
 check(g.start_hyperspace("alpha",5),"Safe entry for refit return")
 var old_armour=g.manual_hyperspace.return_state.armour
 check(g.unequip_slot("defence",1) and g.equip_slot("weapons",0,"missile"),"Real shield removal and weapon replacement while away")
 check(g.manual_hyperspace.finish(g,false) and g.player.shield==0 and g.N.compare(g.player.armour,g.N.minimum(old_armour,g.stat("armour")))==0,"Return clamps frozen shield to current zero capacity without filling armour")
 check(g.enhancement_branches.weapon(g,0).next==0 and g.cooldowns[g.slot_id("weapons",0)]==float(g.player_weapon_row(g.combat_entry(0)).cd),"Changed weapon gets normal full CD and no old module's charged attacks")
 # Auto ownership may change while a request waits. Revalidation preserves that new owner.
 g.profile.hyperspace.energy=g.hyperspace.config.energy_cap
 check(g.request_hyperspace("alpha",5),"Request before a recorded auto run takes ownership")
 var crew_id=""
 for member in g.profile.crew:
  if g.crew.unlocked(g,str(member.crewId)) and g.crew.assign(g,str(member.crewId),"","") and g.hyperspace.Permission.crew_available(g,str(member.crewId)):crew_id=str(member.crewId);break
 check(not crew_id.is_empty() and g.hyperspace.set_auto(g,true,"alpha",5,crew_id) and g.hyperspace.start_auto(g),"Actual earned history starts genuine recorded auto operation")
 var auto_before=JSON.stringify(g.profile)
 check(not g.manual_hyperspace.dispatch_queued(g) and g.manual_hyperspace.queue_error=="busy" and g.manual_hyperspace.queued.is_empty() and JSON.stringify(g.profile)==auto_before,"Dispatch cancels stale request without pausing or refunding current auto owner")
 panel.refresh_progress();check(panel.status.text.contains("排队已取消"),"Visible auto progress also reports cancelled manual request")
 await capture("05-auto-owner-revalidation")
 print("MANUAL_QUEUE_RETURN ",checks," checks ",failures," failures");quit(1 if failures else 0)
