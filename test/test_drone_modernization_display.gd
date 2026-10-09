extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Agg=preload("res://scripts/drone_effect_aggregator.gd")
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
 var rng:=RandomNumberGenerator.new();rng.seed=218
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"modern-display","legendary","laser",1,"1")
 d.affixes=[{"key":"global_damage","tier":5,"value":0.099,"locked":false},{"key":"global_defence","tier":5,"value":0.098,"locked":false}]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"legal legendaryLv1 fixture")
 g.profile.hyperspace.history.alpha={"2":105.88};g.profile.hyperspace.materials.degenerate_matter=100000
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var c=p.commands;var a=c.forge_actions
 p.refresh_manual_status();p.selected_id=d.id;p.select_section(2);a.refresh()
 var before_state:=JSON.stringify(g.profile);var before_rng:int=g.rng.state
 var req:Dictionary=a.request("modernize");var preview:String=c.modernization_text(req)
 var projected:Dictionary=d.duplicate(true);projected.level=2
 for affix in d.affixes:
  var before:String=p.affix_display(affix,d).value_text;var after:String=p.affix_display(affix,projected).value_text
  check(preview.contains(before+" → "+after) or (preview.contains(before) and preview.contains(after)),"Preview uses same effective values as object panel")
  check(c.result_details.text.contains(before) and before!=p.t("percent",{"value":"%.1f"%(float(affix.value)*100)}),"Lv1 panel shows effective value, not unchanged raw affix")
 check(JSON.stringify(g.profile)==before_state and g.rng.state==before_rng,"Preview is read-only")
 a.buttons.modernize.pressed.emit()
 check(a.confirmation.visible and JSON.stringify(g.profile)==before_state,"Actual confirmation contains preview and waits")
 a.confirmation.confirmed.emit();a.confirmation.hide()
 var current:Dictionary=g.profile.hyperspace.inventory.drones[d.id]
 check(current.level==2 and current.affixes==d.affixes and p.selected_id==d.id,"Applied modernization keeps object/affix identity and changes level")
 p.select_section(1);p.refresh()
 for affix in current.affixes:
  var expected:String=p.t("percent",{"value":"%.1f"%(Agg.affix_value(affix,current,g.hyperspace.config)*100)})
  check(c.result_details.text.contains(expected) and p.details.text.contains(expected),"Result and object panels refresh to actual effectiveLv2 values")
  check(preview.contains(expected),"Applied values were previewed")
 scene.queue_free();await process_frame
 print("MODERNIZATION DISPLAY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
