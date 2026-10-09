extends SceneTree
var checks=0
var failures=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.enhancementLevel=15;g.profile.enhancementAttacks=2048;g.profile.enhancementHits=512;g.profile.jewelFragments=g.enhancement_cost()
 scene.refresh_tab_visibility();scene.select_system(4);await process_frame
 var p=scene.enhancement_panel
 var snapshot=JSON.stringify(g.profile);var rng_state=g.rng.state
 var original:Dictionary={}
 for kind in ["proficiency","adaptation","repeat","memory_material"]:original[kind]=p.effect_overview(kind)
 var preview=p.upgrade_preview_text()
 check(JSON.stringify(g.profile)==snapshot and g.rng.state==rng_state,"Next-level preview leaves live profile and RNG unchanged")
 check(not preview.contains(p.effect_name("critical")) and not preview.contains(p.effect_name("delayed_damage")),"Preview does not reveal effects beyond the immediately projected level")
 check(g.upgrade_enhancement(1)==1,"Original upgrade purchases exactly the projected level")
 var matched=true
 for kind in original:
  var parts=p.changed_preview_parts(original[kind],p.effect_overview(kind))
  matched=matched and preview.contains(parts[0]) and preview.contains(parts[1])
 check(matched,"Both comparison values match original game queries before and after a real isolated purchase")
 g.profile.enhancementLevel=19;g.profile.jewelFragments=g.enhancement_cost();g.invalidate_stat_cache()
 preview=p.upgrade_preview_text()
 check(preview.contains(p.effect_name("critical")) and preview.contains(UIText.t("enhance.preview_not_active")),"Immediately activating effect distinguishes inactive current state")
 g.upgrade_enhancement(1)
 check(preview.contains(p.effect_overview("critical")) and preview.contains(p.effect_overview("delayed_damage")),"Activation-level preview matches original upgrade behavior")
 scene.select_system(6);await process_frame
 var planet=scene.planet_panel;var state=g.planet_buildings.state(g,"1","shipyard")
 # A one-trip-remaining fixture follows the live construction table, not the historical QA save.
 var building_row:Dictionary=g.db.data.planet_build["shipyard"]
 var build_total=int(building_row.build_explore)
 state.status="building";state.build_progress=maxi(0,build_total-1);state.crew=[]
 g.profile.planets["1"].degree=int(building_row.unlock_explore)+build_total+1;planet.refresh()
 planet._show_facility("1","shipyard")
 check(planet.facility_status.text.contains(UIText.t("planet.facility_progress",{"progress":str(int(state.build_progress)),"total":str(build_total)})) and planet.facility_status.text.contains(UIText.t("planet.builder_choice_hint")),"Construction dialog gives progress unit and equal-builder choice basis")
 state.status="built";planet._refresh_facility_dialog()
 check(not planet.facility_status.text.contains(UIText.t("planet.builder_choice_hint")),"Completed facility omits obsolete construction instructions")
 check(planet.facility_description.text==UIText.t("planet.shipyard_built_hint"),"Built shipyard teaches the currently available action")
 var d=preload("res://scripts/drone_rewards.gd").create_drone(g.rng,g.hyperspace.config,"first-use-retain","white","laser",6,"1")
 g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.inventory.drones[d.id]=d;g.profile.hyperspace.inventory.warehouse.append(d.id)
 snapshot=JSON.stringify(g.profile);rng_state=g.rng.state
 planet.facility_dialog.hide()
 planet._confirm_reforge("1")
 var dialog=planet.get_children().filter(func(child):return child.get_script()==preload("res://scripts/hyperspace_reforge_dialog.gd")).back()
 # Build expected text directly from source rows; do not call the UI/reward method under test.
 var reward_rows:Array=g.db.data.planet_buff.values().filter(func(row):return int(row.planet_id)==1 and str(row.source)=="conquer")
 reward_rows.sort_custom(func(a,b):return float(a.order)<float(b.order) if a.order!=b.order else int(a.id)<int(b.id))
 var brief_parts:PackedStringArray=[]
 for row in reward_rows.slice(0,2):brief_parts.append(str(row.des).replace("{value}",NumberFormat.precise(float(row.value))))
 var expected_start=clampi(int(g.db.data.planet["1"].get("reforgeStartLevel",1)),1,maxi(1,g.db.levels.size()))
 check(dialog.reward_brief.text==UIText.t("planet.reforge_gain_brief",{"rewards":" · ".join(brief_parts)}) and dialog.feedback.text==UIText.t("planet.reforge_start_brief",{"level":str(expected_start)}),"Reforge draft puts authoritative permanent gains and restart point beside retention")
 check(dialog.rewards_text.contains(UIText.t("planet.reforge_next_planet")) and not dialog.rewards_text.contains(str(g.planet_row("2").name)),"Unopened next planet is described without revealing its identity")
 check(dialog.rules_text.contains(UIText.t("planet.reforge_confirm_basic",{"level":expected_start})) and dialog.rules_text.contains(UIText.t("planet.reforge_drones")),"Detailed reset and retention rules remain available for active lookup")
 dialog.choices[d.id].button_pressed=true
 check(dialog.selected==[d.id] and JSON.stringify(g.profile)==snapshot and g.rng.state==rng_state,"Draft retention selection leaves the live save and RNG unchanged")
 dialog.canceled.emit();await process_frame
 check(JSON.stringify(g.profile)==snapshot,"Canceling first-view draft applies no reforge")
 print("Later first use: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
