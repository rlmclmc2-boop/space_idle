extends RefCounted
## Display domain quotes and submit their immutable request; never convert balances in UI.
const MATERIALS=["degenerate_matter","glueball","antiproton","zero_point_energy"]
var panel
var dialog:AcceptDialog
var confirmation:ConfirmationDialog
var source:OptionButton
var target:OptionButton
var source_owned:Label
var target_owned:Label
var amount:SpinBox
var maximum:Button
var preview:Label
var reason:Label
var feedback:Label
var exchange:Button
var quote:Dictionary={}
var pending_request:Dictionary={}
func setup(owner) -> void:panel=owner
func game():return panel.host.game
func t(key:String,params:Dictionary={}) -> String:return panel.t(key,params)
func material(choice:OptionButton) -> String:
 return str(choice.get_item_metadata(choice.selected)) if choice.selected>=0 else ""
func show() -> void:
 if dialog==null:build()
 refresh_quote(true);dialog.popup_centered(Vector2i(760,540))
func show_prefilled(from:String,to:String,count:int) -> void:
 if dialog==null:build()
 for i in source.item_count:
  if str(source.get_item_metadata(i))==from:source.select(i)
 for i in target.item_count:
  if str(target.get_item_metadata(i))==to:target.select(i)
 amount.set_value_no_signal(maxi(1,count))
 refresh_quote(true);dialog.popup_centered(Vector2i(760,540))
func build() -> void:
 dialog=panel.commands.build_dialog("exchange_title");dialog.ok_button_text=t("exchange_close")
 # Native dialog labels must not wrap while the newly attached content still has zero width.
 var body=panel.commands.content(dialog)
 var selections=panel.row(body)
 var from=panel.box(selections);panel.commands.dialog_label(from,t("exchange_source"),21)
 source=panel.option(from);source_owned=panel.commands.dialog_label(from,"",20)
 var to=panel.box(selections);panel.commands.dialog_label(to,t("exchange_target"),21)
 target=panel.option(to);target_owned=panel.commands.dialog_label(to,"",20)
 for key in MATERIALS:
  source.add_item(t(key));source.set_item_metadata(source.item_count-1,key)
  target.add_item(t(key));target.set_item_metadata(target.item_count-1,key)
 target.select(1)
 panel.commands.dialog_label(body,t("exchange_amount"),21)
 var quantity=panel.row(body)
 amount=SpinBox.new();amount.min_value=1;amount.max_value=4500000000000000;amount.step=1;amount.value=1
 amount.size_flags_horizontal=Control.SIZE_EXPAND_FILL;quantity.add_child(amount);panel.input_skin(amount.get_line_edit())
 maximum=panel.button(quantity,"exchange_maximum",fill_maximum)
 preview=panel.commands.dialog_label(body,"",22);reason=panel.commands.dialog_label(body,"",20)
 exchange=panel.button(body,"exchange_review",review)
 feedback=panel.commands.dialog_label(body,"",20)
 source.item_selected.connect(func(_index):refresh_quote(true))
 target.item_selected.connect(func(_index):refresh_quote(true))
 amount.value_changed.connect(func(_value):refresh_quote(true))
 confirmation=ConfirmationDialog.new();confirmation.title=t("exchange_confirm_title")
 confirmation.ok_button_text=t("exchange_confirm");confirmation.cancel_button_text=t("exchange_cancel")
 # Fixed two-line numeric quote fits this width; avoid zero-width autowrap minimum inflation.
 confirmation.dialog_autowrap=false;confirmation.min_size=Vector2i(620,260);confirmation.size=Vector2i(620,260);dialog.add_child(confirmation)
 preload("res://scripts/dialog_presentation.gd").dialog(confirmation)
 confirmation.confirmed.connect(commit)
 confirmation.canceled.connect(func():pending_request={})
 panel.tree_exiting.connect(func():
  if is_instance_valid(dialog):dialog.queue_free())
func summary(result:Dictionary) -> String:
 var from=str(result.get("source",""));var to=str(result.get("target",""))
 return t("exchange_summary",{"source":t(from),"target":t(to),"cost":str(int(result.get("cost",{}).get(from,0))),"received":str(int(result.get("received",{}).get(to,0)))})
func error_text(code:String) -> String:
 match code:
  "same_material":return t("exchange_same")
  "insufficient_materials":return t("exchange_insufficient")
  "invalid_amount":return t("exchange_invalid_amount")
  "material_limit":return t("exchange_material_limit")
  "stale_round","stale_command","command_conflict":return t("exchange_stale")
  _:return t("exchange_unavailable")
func refresh_quote(clear_feedback=false) -> void:
 if dialog==null:return
 var from=material(source);var to=material(target)
 quote={"error":"unavailable"}
 if game().has_method("hyperspace_material_exchange_quote"):
  quote=game().hyperspace_material_exchange_quote(from,to,int(amount.value))
 var balances:Dictionary=game().profile.hyperspace.materials
 panel.put(source_owned,"text",t("exchange_owned",{"amount":str(int(quote.get("source_owned",balances.get(from,0))))}))
 panel.put(target_owned,"text",t("exchange_owned",{"amount":str(int(quote.get("target_owned",balances.get(to,0))))}))
 var has_amount=not quote.get("cost",{}).is_empty() and not quote.get("received",{}).is_empty()
 panel.put(preview,"visible",has_amount)
 if has_amount:panel.put(preview,"text",summary(quote))
 var code=str(quote.get("error","unavailable"))
 var valid=code.is_empty() and not quote.get("request",{}).is_empty() and from!=to and game().has_method("exchange_hyperspace_materials")
 panel.put(reason,"visible",not code.is_empty());panel.put(reason,"text",error_text(code) if not code.is_empty() else "")
 panel.put(exchange,"disabled",not valid)
 panel.put(maximum,"disabled",int(quote.get("max_receive",0))<1)
 if clear_feedback:panel.put(feedback,"text","")
func fill_maximum() -> void:
 refresh_quote()
 var count=int(quote.get("max_receive",0))
 if count>0:amount.value=count
func review() -> void:
 # Refresh may reject a changed balance; preserve the exact quote the confirmation describes.
 refresh_quote()
 if exchange.disabled:return
 pending_request=quote.request.duplicate(true)
 confirmation.dialog_text=summary(quote)
 confirmation.popup_centered(Vector2i(620,260))
func commit() -> void:
 if pending_request.is_empty():return
 var request=pending_request;pending_request={}
 if not game().has_method("exchange_hyperspace_materials"):return
 var result:Dictionary=game().exchange_hyperspace_materials(request)
 if str(result.get("error","unavailable")).is_empty() and bool(result.get("applied",false)):
  panel.put(feedback,"text",t("exchange_success",{"summary":summary(result)}))
  # Exchanging balances invalidates the open forge quote, not the selected operation or drone.
  panel.commands.invalidate();panel.commands.refresh_materials();panel.dirty=true
 else:panel.put(feedback,"text",error_text(str(result.get("error","unavailable"))))
 refresh_quote()
func on_event(kind:String,payload:Dictionary) -> void:
 if dialog==null or not dialog.visible:return
 if kind not in ["hyperspace_changed","state","hyperspace_rebuild"]:return
 if not bool(game().profile.hyperspace.unlocked_drones) or str(payload.get("reason","")) in ["reforge","inventory_reset"]:
  pending_request={};confirmation.hide();dialog.hide();return
 refresh_quote()
