extends RefCounted
const SKIN=preload("res://scripts/dialog_presentation.gd")
var host_ref:WeakRef
var host:
 get:return host_ref.get_ref()
var dialog:AcceptDialog
var enabled:CheckBox
var summary:Label
var details:RichTextLabel
var timer:Timer
func t(key:String,values:Dictionary={}) -> String:return UIText.t("battle.damage_stats."+key,values)
func setup(owner) -> void:host_ref=weakref(owner)
func show() -> void:
 if dialog==null:build()
 enabled.set_pressed_no_signal(false);summary.text=t("stopped");details.text=""
 dialog.popup_centered(Vector2i(650,540))
func build() -> void:
 dialog=AcceptDialog.new();dialog.title=t("title");dialog.ok_button_text=UIText.t("system.confirm");host.ui.add_child(dialog);SKIN.dialog(dialog)
 var body=VBoxContainer.new();body.custom_minimum_size=Vector2(600,440);dialog.add_child(body)
 enabled=CheckBox.new();enabled.text=t("enable");body.add_child(enabled)
 var hint=Label.new();hint.text=t("scope");hint.add_theme_font_size_override("font_size",18);body.add_child(hint)
 summary=Label.new();body.add_child(summary)
 details=RichTextLabel.new();details.custom_minimum_size=Vector2(600,320);details.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(details)
 timer=Timer.new();timer.wait_time=0.5;timer.timeout.connect(refresh);dialog.add_child(timer)
 enabled.toggled.connect(func(value):
  host.game.damage_stats.set_enabled(value)
  if value:timer.start();refresh()
  else:timer.stop();summary.text=t("stopped");details.text="")
 dialog.confirmed.connect(stop);dialog.canceled.connect(stop)
 dialog.visibility_changed.connect(func():
  if not dialog.visible:stop())
func stop() -> void:
 timer.stop();host.game.damage_stats.set_enabled(false);enabled.set_pressed_no_signal(false)
func refresh() -> void:
 if not dialog.visible or not host.game.damage_stats.enabled:return
 var values=host.game.damage_stats.snapshot()
 summary.text=t("total",{"dps":NumberFormat.damage(values.dps),"damage":NumberFormat.damage(values.damage),"seconds":NumberFormat.scalar(values.seconds)})
 var lines:Array[String]=[]
 for row in values.rows:
  var source:String=row.source;var name=t("other")
  if source.begins_with("module:"):name=t("module",{"slot":str(int(source.trim_prefix("module:"))+1)})
  elif source.begins_with("drone:"):
   var id=source.trim_prefix("drone:");var drone:Dictionary=host.game.profile.hyperspace.inventory.drones.get(id,{})
   name=t("drone",{"id":id,"weapon":UIText.t("hyperspace."+str(drone.get("weapon","unknown_affix")))})
  elif source=="legendary:black_hole":name=t("black_hole")
  lines.append(t("row",{"source":name,"dps":NumberFormat.damage(row.dps),"damage":NumberFormat.damage(row.damage)}))
 details.text="\n".join(lines)
