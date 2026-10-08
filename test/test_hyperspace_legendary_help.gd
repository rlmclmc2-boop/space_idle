extends SceneTree
## Owned-effect help and transient disabled UI; never exercises gameplay reset rules.
var checks=0
var failures=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(9)
 await process_frame
 var p=scene.hyperspace_panel;var bag:Dictionary=g.profile.hyperspace.inventory
 var rng=RandomNumberGenerator.new();rng.seed=391
 var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"legend-help","legendary","laser",5,"1")
 bag.drones[d.id]=d;bag.warehouse.append(d.id);bag.generation+=1
 p.refresh_manual_status();p.selected_id=d.id;p.select_section(1)
 var profile_before=JSON.stringify(g.profile);var rng_before=g.rng.state
 for id in g.hyperspace.config.legendary_effects:
  var params:Dictionary={}
  for key in g.hyperspace.config.legendary_effects[id].parameters:params[key]=g.hyperspace.config.legendary_effects[id].parameters[key][0]
  p.bag.drones[d.id].legendary_effect={"effect_id":id,"parameters":params}
  p.refresh_details()
  check(p.legendary_group.visible and p.legendary_summary.text==p.legendary_help.summary(id) and not p.legendary_summary.text.is_empty(),str(id)+" has a separate visible core effect")
  check(not p.details.text.contains(p.effect_name(id)),str(id)+" full effect is absent from ordinary affix text")
  p.legendary_button.pressed.emit()
  check(p.legendary_help.dialog.visible and p.legendary_help.body.text.contains(p.effect_name(id)) and not p.legendary_help.body.text.contains("{"),str(id)+" click opens resolved explanation")
  for key in params:check(p.legendary_help.body.text.contains(p.t("effect_parameter_"+str(key))),str(id)+" exact rolled parameter is explained")
  p.legendary_help.dialog.hide()
 check(JSON.stringify(g.profile)==profile_before and g.rng.state==rng_before,"Reading every effect leaves gameplay and RNG unchanged")
 var cfg:Dictionary=g.hyperspace.config.legendary_effects.drone_rebuild.constants
 var saved_limit=cfg.maximum_stacks;cfg.maximum_stacks=7
 check(p.legendary_help.explanation({"effect_id":"drone_rebuild","parameters":{}}).contains("最多 7 次"),"Rebuild limit comes from live config")
 cfg.maximum_stacks=saved_limit
 bag.equipped=[d.id];g.drone_combat.disabled=[d.id];bag.generation+=1;p.refresh_manual_status();p.refresh()
 check(p.protection_flags(d.id).contains(p.t("equipped")) and p.protection_flags(d.id).contains(p.t("rebuild_disabled_short")),"Disabled drone retains equipped status and adds temporary status")
 check(p.details.text.contains("本战点暂时停用") and bag.equipped.has(d.id),"Current detail explains temporary state without unequipping")
 g.drone_combat.disabled.clear();p.refresh()
 check(not p.details.text.contains("本战点暂时停用") and bag.equipped.has(d.id),"UI clears disabled status when actual state clears")
 p.select_section(2);p.forge_legendary_button.pressed.emit()
 check(p.forge_legendary_button.visible and p.legendary_help.dialog.visible,"Refit selection also opens the owned effect")
 print("Legendary help: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
