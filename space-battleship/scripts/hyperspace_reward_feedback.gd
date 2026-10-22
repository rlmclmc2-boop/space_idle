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
var unread=false
var receipt_marker:Dictionary={}
func setup(owner) -> void:
 panel=owner
 var s:Dictionary=panel.host.game.hyperspace.state
 first_drone=not bool(s.unlocked_drones)
 if s.active.get("status","")=="completed_pending":pending=s.active.reward.duplicate(true)
 elif not s.inventory.warehouse.is_empty():
  var id=str(s.inventory.warehouse.back())
  if s.inventory.drones.has(id):latest={"drone":s.inventory.drones[id].duplicate(true),"materials":{},"ultimate_cores":0}
 restore_read_state()
 panel.tree_exiting.connect(func():
  if is_instance_valid(notice):notice.queue_free())
func build(parent:Node) -> void:
 card=panel.box(parent,4);summary=panel.label(card,"",22)
 view_button=panel.button(card,"reward_view_drone",view_drone)
 card.visible=false
 if not latest.is_empty():show_receipt()
func on_event(kind:String,payload:Dictionary) -> void:
 if kind in ["state","hyperspace_rebuild"]:
  if receipt_marker!=panel.host.game.hyperspace.receipt_marker():
   restore_read_state();show_receipt()
  else:remember_pending(true)
  return
 if kind!="hyperspace_changed":return
 var reason=str(payload.get("reason",""))
 var s:Dictionary=panel.host.game.hyperspace.state
 if reason=="completed_pending":remember_pending()
 elif reason=="claimed":
  var received:Dictionary=payload.get("reward",{}).duplicate(true)
  if received.is_empty():return
  latest=received;pending={}
  var has_drone=show_receipt()
  receipt_marker=payload.receipt.duplicate()
  unread=bool(receipt_marker.unread)
  if has_drone and first_drone:
   first_drone=false;queued_notice=true;show_first_drone.call_deferred()
 elif reason=="reforge" or reason=="inventory_reset":
  pending={};latest={};unread=false;receipt_marker=panel.host.game.hyperspace.receipt_marker().duplicate();panel.put(card,"visible",false);sync_receipt_area()
func restore_read_state() -> void:
 var g=panel.host.game;var s:Dictionary=g.hyperspace.state
 first_drone=not bool(s.unlocked_drones)
 receipt_marker=g.hyperspace.receipt_marker().duplicate(true)
 unread=bool(receipt_marker.get("unread",false)) and int(receipt_marker.get("round",0))==int(s.round_id)
 latest={};pending={}
 if unread:
  var id=str(receipt_marker.get("drone_id",""))
  latest={"drone":s.inventory.drones.get(id,{}).duplicate(true),"materials":{},"ultimate_cores":0}
 elif not s.inventory.warehouse.is_empty():
  var id=str(s.inventory.warehouse.back())
  if s.inventory.drones.has(id):latest={"drone":s.inventory.drones[id].duplicate(true),"materials":{},"ultimate_cores":0}
 remember_pending(true)
func receipt_key(receipt:Dictionary) -> String:
 return str(receipt.get("round_id",-1))+":"+str(receipt.get("run_id",-1))
func remember_pending(reset=false) -> void:
 if reset:pending={}
 var s:Dictionary=panel.host.game.hyperspace.state
 for slot in ["active","idle"]:
  var receipt:Dictionary=s.get(slot,{})
  if receipt.get("status","")=="completed_pending":
   pending=receipt.get("reward",{}).duplicate(true)
func save_read_state() -> void:
 var g=panel.host.game
 if not unread and g.hyperspace.acknowledge_receipt(int(receipt_marker.get("round",0)),int(receipt_marker.get("run",0))):g.save_progress()
 receipt_marker=g.hyperspace.receipt_marker().duplicate()
func nav_key() -> String:
 return "reward_nav_drone" if not latest.get("drone",{}).is_empty() else "reward_nav_received"
func sync_receipt_area() -> void:
 panel.put(panel.exploration_receipt_area,"visible",panel.section_index==0 and card.visible)
func mark_viewed() -> void:
 if not unread or queued_notice or not panel.is_visible_in_tree():return
 if is_instance_valid(notice) and notice.visible:return
 var id=str(latest.get("drone",{}).get("id",""))
 var receipt_visible=panel.section_index==0 and card.is_visible_in_tree() and panel.get_global_rect().encloses(summary.get_global_rect()) and (not view_button.visible or panel.get_global_rect().encloses(view_button.get_global_rect()))
 var drone_visible=panel.section_index==1 and panel.selected_id==id and not id.is_empty() and panel.details.is_visible_in_tree()
 if receipt_visible or drone_visible:
  unread=false;save_read_state();panel.host.refresh_hyperspace_badge()
func show_receipt() -> bool:
 if latest.is_empty():
  panel.put(card,"visible",false);sync_receipt_area();return false
 var drone:Dictionary=latest.get("drone",{})
 var has_drone=not drone.is_empty() and panel.host.game.hyperspace.state.inventory.drones.has(str(drone.id))
 summary.text=panel.t("reward_drone_received",{"weapon":panel.t(str(drone.weapon)),"level":str(int(drone.level)),"quality":panel.quality_caption(drone)}) if has_drone else panel.t("reward_materials_received")
 var gains:Array[String]=[]
 for key in latest.get("materials",{}):
  if int(latest.materials[key])>0:gains.append(panel.t("reward_material_item",{"material":panel.t(str(key)),"count":str(int(latest.materials[key]))}))
 if int(latest.get("ultimate_cores",0))>0:gains.append(panel.t("reward_material_item",{"material":panel.t("ultimate_cores"),"count":str(int(latest.ultimate_cores))}))
 if not gains.is_empty():summary.text+="\n"+" · ".join(gains)
 panel.put(card,"visible",true);panel.put(view_button,"visible",has_drone);sync_receipt_area()
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
 var s:Dictionary=panel.host.game.hyperspace.state
 if id.is_empty() or not s.inventory.drones.has(id):return
 panel.host.select_system(9)
 panel.selected_id=id
 # An explicit reward action must reveal its card even under an old filter.
 panel.weapon_filter.select(0);panel.quality_filter.select(0);panel.sort_order.select(0)
 panel.inventory_dirty=true
 # Use the actual warehouse page rather than selecting an invisible last-page item.
 var position=s.inventory.warehouse.find(id)
 panel.page=maxi(0,int(position/panel.PAGE_SIZE))
 panel.dirty=true;panel.select_section(1)
 panel.commands.configure_operation()
