extends RefCounted
## Owned legendary effects: compact summary stays visible; full rules require a click.
var panel
var dialog: AcceptDialog
var body: Label
var shown_drone_id:=""
func setup(owner) -> void:panel=owner
func summary(id:String) -> String:
 return panel.t("legendary_core."+id) if panel.host.game.hyperspace.config.legendary_effects.has(id) else ""
func master_status(drone_id:String="") -> String:
 var g=panel.host.game
 var active:Dictionary=g.drone_combat.effect(g,"drone_master")
 var lines:Array[String]=[panel.t("master_current_reduction",{"value":"%.1f"%(100.0*g.drone_combat.master_reduction(g))})]
 if active.is_empty():lines.append(panel.t("master_not_active"))
 elif not drone_id.is_empty() and str(active.drone_id)!=drone_id:lines.append(panel.t("master_other_source"))
 return "\n".join(lines)
func explanation(effect:Dictionary,drone_id:String="") -> String:
 var id=str(effect.get("effect_id",""))
 var definition:Dictionary=panel.host.game.hyperspace.config.legendary_effects.get(id,{})
 if definition.is_empty():return ""
 var constants:Dictionary=definition.get("constants",{})
 var params:Dictionary={}
 match id:
  "precise_guidance":params={"factor":str(constants.stack_multiplier)}
  "prism_tower":params={"targets":str(int(constants.nearby_targets))}
  "strange_matter":params={"chance":"%.0f"%(float(constants.spawn_probability)*100.0),"count":str(int(constants.kill_spawns)),"delay":str(constants.delay)}
  "laser_charge":params={"bonus":"%.0f"%(float(constants.bonus_per_laser)*100.0)}
  "wild_missile":params={"period":str(int(constants.attack_period)+1),"blast":"%.0f"%(float(constants.blast_fraction)*100.0)}
  "dodge_counter":params={"cooldown":str(constants.cooldown)}
  "black_hole":params={"period":str(constants.period),"duration":str(constants.absorption_duration)}
  "drone_rebuild":params={"limit":str(int(constants.maximum_stacks))}
 var lines:Array[String]=[panel.effect_name(id),"",panel.t("legendary_details."+id,params)]
 if id=="drone_master":lines.append(master_status(drone_id))
 for parameter in effect.get("parameters",{}):
  lines.append(panel.t("master_owned_cap" if id=="drone_master" and str(parameter)=="maximum_reduction" else "effect_parameter_"+str(parameter))+": "+panel.t("percent",{"value":"%.1f"%(float(effect.parameters[parameter])*100.0)}))
 if id in ["higgs_cannon","scatter_pulse","prism_tower","strange_matter","wild_missile","dodge_counter","black_hole"]:
  lines.append("\n"+panel.t("legendary_derived_rule"))
 return "\n".join(lines)
func refresh_open() -> void:
 if dialog==null or not dialog.visible or shown_drone_id.is_empty():return
 var drone:Dictionary=panel.host.game.profile.hyperspace.inventory.drones.get(shown_drone_id,{})
 if drone.is_empty() or not bool(drone.get("legendary",false)):dialog.hide();return
 panel.put(body,"text",explanation(drone.legendary_effect,shown_drone_id))
func show(effect:Dictionary,drone_id:String="") -> void:
 shown_drone_id=drone_id
 var text=explanation(effect,drone_id)
 if text.is_empty():return
 if dialog==null:
  dialog=panel.commands.build_dialog("legendary_details_title")
  var content=panel.commands.content(dialog)
  var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(680,350)
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(scroll)
  body=panel.commands.dialog_label(scroll,"",22,660)
 body.text=text
 dialog.popup_centered(Vector2i(760,480))
