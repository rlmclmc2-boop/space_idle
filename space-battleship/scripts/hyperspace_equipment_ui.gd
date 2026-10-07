extends RefCounted
var panel
var heading: Label
var slots: Array[Button]=[]
var capacity_hint: Label
var feedback: Label
var replacement_dialog: AcceptDialog
var replacement_choice: OptionButton
var incoming=""
func setup(owner) -> void:panel=owner
func build(parent:Node) -> void:
 heading=panel.label(parent,"",23)
 var row=panel.row(parent)
 var maximum=0
 for value in panel.host.game.hyperspace.config.hull_capacities.values():maximum=maxi(maximum,int(value))
 for index in maximum:
  var slot=panel.button(row,"slot_empty",func():select_slot(index))
  slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slots.append(slot)
 capacity_hint=panel.label(parent,"",18)
 feedback=panel.label(parent,"",21)
func refresh() -> void:
 var g=panel.host.game;var bag:Dictionary=g.profile.hyperspace.inventory
 var cap=mini(int(panel.hull_capacity_provider.call()),int(g.hyperspace.config.maximum_equipped))
 panel.put(heading,"text",panel.t("slots_heading",{"used":str(bag.equipped.size()),"capacity":str(cap)}))
 for i in slots.size():
  var id=str(bag.equipped[i]) if i<bag.equipped.size() else ""
  var name=panel.t("slot_locked") if i>=cap else panel.t("slot_empty") if id.is_empty() else panel.t("slot_drone",{"weapon":panel.t(str(bag.drones[id].weapon)),"level":str(int(bag.drones[id].level))})
  panel.put(slots[i],"text",str(i+1)+" · "+name);panel.put(slots[i],"disabled",id.is_empty())
  panel.skin_selection(slots[i],not id.is_empty() and id==panel.selected_id)
 var next_ship="";var next_gate=""
 for key in g.hyperspace.config.hull_capacities:
  if mini(int(g.hyperspace.config.hull_capacities[key]),int(g.hyperspace.config.maximum_equipped))<=cap:continue
  var ship:Dictionary=g.db.data.ship.get(key,{})
  var gate:Dictionary=g.db.data.unlock.get(g.db.unlock_id("ship",str(key)),{})
  if gate.is_empty():continue
  if next_ship.is_empty() or int(gate.level)<int(next_gate):next_ship=UIText.data_text("ship",str(key),"des");next_gate=str(int(gate.level))
 var ship:Dictionary=g.db.data.ship.get(str(g.profile.selectedShip),{})
 var text=panel.t("slot_capacity_source",{"ship":UIText.data_text("ship",str(g.profile.selectedShip),"des"),"capacity":str(cap)})
 if not next_ship.is_empty():text+="\n"+panel.t("slot_next_hull",{"ship":next_ship,"level":next_gate})
 panel.put(capacity_hint,"text",text)
 var selected=panel.selected_id
 panel.put(panel.equip,"text",panel.t("slot_unequip") if bag.equipped.has(selected) else panel.t("slot_replace") if bag.equipped.size()>=cap else panel.t("slot_equip"))
func select_slot(index:int) -> void:
 var ids:Array=panel.host.game.profile.hyperspace.inventory.equipped
 if index>=ids.size():return
 panel.selected_id=str(ids[index]);panel.refresh_details()
func activate() -> void:
 var g=panel.host.game;var bag:Dictionary=g.profile.hyperspace.inventory
 var id=panel.selected_id
 if not bag.drones.has(id):return
 if bag.equipped.has(id):
  var result:Dictionary=g.hyperspace.unequip_drone(g,id)
  show_result(bool(result.ok),str(result.reason));return
 var cap=mini(int(panel.hull_capacity_provider.call()),int(g.hyperspace.config.maximum_equipped))
 if bag.equipped.size()<cap:
  var result:Dictionary=g.hyperspace.equip_drone(g,id)
  show_result(bool(result.ok),str(result.reason));return
 if bag.equipped.size()==1:replace(id,str(bag.equipped[0]));return
 if bag.equipped.is_empty():show_result(false);return
 incoming=id
 if replacement_dialog==null:
  replacement_dialog=panel.commands.build_dialog("slot_choose_replacement")
  var box=panel.commands.content(replacement_dialog);replacement_choice=panel.option(box)
  replacement_dialog.confirmed.connect(func():replace(incoming,str(replacement_choice.get_item_metadata(replacement_choice.selected))))
 replacement_choice.clear()
 for old in bag.equipped:
  var d:Dictionary=bag.drones[old]
  replacement_choice.add_item(panel.t("slot_drone",{"weapon":panel.t(str(d.weapon)),"level":str(int(d.level))}));replacement_choice.set_item_metadata(replacement_choice.item_count-1,old)
 replacement_dialog.popup_centered(Vector2i(660,370))
func replace(new_id:String,old_id:String) -> void:
 var h=panel.host.game.hyperspace
 var result:Dictionary=h.equip_drone(panel.host.game,new_id,old_id)
 show_result(bool(result.get("ok",false)),str(result.get("reason","")))
func show_result(applied:bool,error:String="") -> void:
 var key="hyperspace.equipment_error_"+error
 var message=panel.t("slot_changed") if applied else UIText.t(key) if not error.is_empty() and UIText.entries.has(key) else panel.t("slot_rejected")
 panel.put(feedback,"text",message)
 var color=Color("243d50") if applied else Color("b32929")
 if feedback.get_theme_color("font_color")!=color:feedback.add_theme_color_override("font_color",color)
 panel.dirty=true;panel.refresh()
