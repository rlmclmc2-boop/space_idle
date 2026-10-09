extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,9);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.hyperspace.unlocked_drones=true
 var rng:=RandomNumberGenerator.new();rng.seed=228
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"promotion-preview","legendary","laser",6,"1")
 d.affixes=[{"key":"global_damage","tier":5,"value":0.099,"locked":false},{"key":"global_defence","tier":5,"value":0.098,"locked":false}]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"Legal two-T5 fixture")
 g.profile.hyperspace.materials.antiproton=10000
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var c=p.commands;var a=c.forge_actions
 p.refresh_manual_status();p.selected_id=d.id;p.select_section(2);a.refresh()
 var before:=JSON.stringify(g.profile);var before_rng:int=g.rng.state
 var total:=0.0;var stronger:=0.0
 for tier in g.hyperspace.config.tier_weights:
  var weight:float=float(g.hyperspace.config.tier_weights[tier]);total+=weight
  if int(tier)<5:stronger+=weight
 var forecast:Dictionary=c.promotion_forecast(d)
 check(forecast.count==2 and is_equal_approx(forecast.chance,stronger/total),"Two T5 success chance matches configured stronger-tier mass, not doubled by two targets")
 print("CONFIGURED T5 FIRST-ATTEMPT CHANCE: %.6f%%"%(100.0*forecast.chance))
 check(a.buttons.promote_affix.text.contains(c.promotion_summary(d)),"Main action exposes current short success chance")
 for row in forecast.rows:
  var bounds:Array=g.hyperspace.config.affixes[d.affixes[row.index].key].ranges["4"]
  var minimum:Dictionary=d.affixes[row.index].duplicate(true);minimum.tier=4;minimum.value=bounds[0]
  var maximum:Dictionary=minimum.duplicate(true);maximum.value=bounds[1]
  check(row.next_tier==4 and row.minimum==p.affix_display(minimum,d).value_text and row.maximum==p.affix_display(maximum,d).value_text,"Success range is exactly the next tier's effective bounds")
 a.buttons.promote_affix.pressed.emit()
 check(a.confirmation.visible and a.confirmation.dialog_text.contains(c.promotion_summary(d)) and a.confirmation.dialog_text.contains("2条"),"Actual confirmation displays chance and affected pool before payment")
 a.confirmation.custom_action.emit("promotion_details");await process_frame
 check(not a.confirmation.visible and c.guide_dialog.visible and c.quoted_request.is_empty(),"Expanded probability action opens help and clears unconfirmed quote")
 check(c.guide_label.text.contains(forecast.rows[0].minimum+"–"+forecast.rows[0].maximum) and c.guide_label.text.contains("不是整批保证"),"Expanded help displays ranges and changing batch probability limitation")
 c.guide_dialog.hide()
 check(JSON.stringify(g.profile)==before and g.rng.state==before_rng,"All preview and help paths preserve materials, affixes and both RNG states")
 var mixed:Dictionary=d.duplicate(true)
 mixed.affixes[1].tier=2
 mixed.affixes.append({"key":"global_damage","tier":3,"value":0.12,"locked":true})
 mixed.affixes.append({"key":"global_defence","tier":1,"value":0.22,"locked":false})
 g.hyperspace.config.tier_weights={"1":1.0,"2":2.0,"3":3.0,"4":4.0,"5":5.0}
 forecast=c.promotion_forecast(mixed)
 check(forecast.count==2 and is_equal_approx(forecast.chance,(10.0/15.0+1.0/15.0)/2.0),"Distinct positive weights, mixed grades, locked and T1 exclusion use correct mean chance")
 check(forecast.rows[0].next_tier==4 and forecast.rows[1].next_tier==1,"Success always advances one grade even if draw is much stronger")
 mixed.omen=true
 check(c.promotion_forecast(mixed)==forecast,"Omen does not bias promotion target pool")
 for affix in mixed.affixes:affix.tier=1
 check(c.promotion_forecast(mixed).is_empty(),"All highest-grade pool has no fabricated chance")
 scene.queue_free();await process_frame
 print("PROMOTION FORECAST: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
