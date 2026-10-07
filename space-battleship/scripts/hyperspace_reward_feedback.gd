extends RefCounted
## UI receipt only. Never generates, settles, equips, or changes a reward.
var panel
var pending: Dictionary={}
var latest: Dictionary={}
var first_drone=false
var notice: AcceptDialog
var card: VBoxContainer
var summary: Label
var view_button: Button
var queued_notice=false
func setup(owner) -> void:
 panel=owner
 var s:Dictionary=panel.host.game.profile.hyperspace
 first_drone=not bool(s.unlocked_drones)
 if s.active.get("status","")=="completed_pending":pending=s.active.reward.duplicate(true)
 elif not s.inventory.warehouse.is_empty():
  var id=str(s.inventory.warehouse.back())
  if s.inventory.drones.has(id):latest={"drone":s.inventory.drones[id].duplicate(true),"materials":{},"ultimate_cores":0}
 panel.tree_exiting.connect(func():
  if is_instance_valid(notice):notice.queue_free())
func build(parent:Node) -> void:
 card=panel.box(parent,4);summary=panel.label(card,"",22)
 view_button=panel.button(card,"reward_view_drone",view_drone)
 card.visible=false
 if not latest.is_empty():show_receipt()
func on_event(kind:String,payload:Dictionary) -> void:
 if kind!="hyperspace_changed":return
 var reason=str(payload.get("reason",""))
 var s:Dictionary=panel.host.game.profile.hyperspace
 if reason=="completed_pending":pending=s.active.get("reward",{}).duplicate(true)
 elif reason=="claimed" and not pending.is_empty():
  latest=pending;pending={}
  var has_drone=show_receipt()
  if has_drone and first_drone:
   first_drone=false;queued_notice=true;show_first_drone.call_deferred()
 elif reason=="reforge" or reason=="inventory_reset":
  pending={};latest={};panel.put(card,"visible",false)
func show_receipt() -> bool:
 var drone:Dictionary=latest.get("drone",{})
 var has_drone=not drone.is_empty() and panel.host.game.profile.hyperspace.inventory.drones.has(str(drone.id))
 summary.text=panel.t("reward_drone_received",{"weapon":panel.t(str(drone.weapon)),"level":str(int(drone.level)),"quality":panel.quality_caption(drone)}) if has_drone else panel.t("reward_materials_received")
 var gains:Array[String]=[]
 for key in latest.get("materials",{}):
  if int(latest.materials[key])>0:gains.append(panel.t("reward_material_item",{"material":panel.t(str(key)),"count":str(int(latest.materials[key]))}))
 if int(latest.get("ultimate_cores",0))>0:gains.append(panel.t("reward_material_item",{"material":panel.t("ultimate_cores"),"count":str(int(latest.ultimate_cores))}))
 if not gains.is_empty():summary.text+="\n"+" · ".join(gains)
 panel.put(card,"visible",true);panel.put(view_button,"visible",has_drone)
 return has_drone
func show_first_drone() -> void:
 if not queued_notice or not is_instance_valid(panel.host):return
 queued_notice=false
 if notice==null:
  notice=AcceptDialog.new();notice.title=panel.t("reward_first_drone")
  notice.ok_button_text=panel.t("reward_view_drone");notice.dialog_autowrap=true
  panel.host.add_child(notice);preload("res://scripts/dialog_presentation.gd").dialog(notice)
  notice.confirmed.connect(view_drone)
 notice.dialog_text=summary.text+"\n\n"+panel.t("reward_equip_next")
 notice.popup_centered(Vector2i(560,280))
func view_drone() -> void:
 var id=str(latest.get("drone",{}).get("id",""))
 var s:Dictionary=panel.host.game.profile.hyperspace
 if id.is_empty() or not s.inventory.drones.has(id):return
 panel.host.select_system(9)
 panel.selected_id=id
 # Use the actual warehouse page rather than selecting an invisible last-page item.
 var position=s.inventory.warehouse.find(id)
 panel.page=maxi(0,int(position/panel.PAGE_SIZE))
 panel.dirty=true;panel.select_section(1)
 panel.commands.configure_operation()
