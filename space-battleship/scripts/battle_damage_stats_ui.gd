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
var source_names:Dictionary={}

func t(key:String,values:Dictionary={}) -> String:return UIText.t("battle.damage_stats."+key,values)

func setup(owner)->void:
	host_ref=weakref(owner)
	owner.tree_exiting.connect(dispose)

func show()->void:
	if dialog==null:build()
	stop()
	summary.text=t("stopped")
	details.text=""
	dialog.popup_centered(Vector2i(650,420))

func build()->void:
	dialog=AcceptDialog.new()
	dialog.title=t("title")
	dialog.ok_button_text=UIText.t("system.confirm")
	host.ui.add_child(dialog)
	SKIN.dialog(dialog)
	var body=VBoxContainer.new()
	body.custom_minimum_size=Vector2(600,320)
	dialog.add_child(body)
	enabled=CheckBox.new()
	enabled.text=t("enable")
	body.add_child(enabled)
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		enabled.add_theme_color_override(state,SKIN.NAVY)
	var hint=Label.new()
	hint.text=t("scope")
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x=600
	body.add_child(hint)
	summary=Label.new()
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(summary)
	details=RichTextLabel.new()
	details.custom_minimum_size=Vector2(600,210)
	details.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(details)
	timer=Timer.new()
	timer.wait_time=0.5
	timer.timeout.connect(refresh)
	dialog.add_child(timer)
	enabled.toggled.connect(toggle)
	dialog.confirmed.connect(stop)
	dialog.canceled.connect(stop)
	dialog.visibility_changed.connect(func():
		if is_instance_valid(dialog) and not dialog.visible:stop())

func toggle(value:bool)->void:
	if host==null:return
	if not host.game.set_damage_stats_enabled(value):
		enabled.set_pressed_no_signal(false)
		summary.text=t("unavailable")
		return
	if value:
		source_names.clear()
		var inventory:Dictionary=host.game.profile.hyperspace.inventory
		for index in inventory.equipped.size():
			var id:String=inventory.equipped[index]
			if not id.is_empty():source_names["drone:"+id]=t("drone",{"slot":str(index+1)})
		timer.start()
		refresh()
	else:
		timer.stop()
		source_names.clear()
		summary.text=t("stopped")
		details.text=""

func stop()->void:
	if is_instance_valid(timer):timer.stop()
	if host!=null:host.game.set_damage_stats_enabled(false)
	if is_instance_valid(enabled):enabled.set_pressed_no_signal(false)
	source_names.clear()

func dispose()->void:
	stop()
	if host!=null and host.tree_exiting.is_connected(dispose):host.tree_exiting.disconnect(dispose)
	if is_instance_valid(dialog):dialog.queue_free()
	dialog=null;timer=null;enabled=null

func refresh()->void:
	if not dialog.visible or host==null or not host.game.damage_stats.enabled:return
	var values:Dictionary=host.game.damage_stats.snapshot()
	host.set_ui_value(summary,"text",t("total",{"dps":NumberFormat.damage(values.dps),"damage":NumberFormat.damage(values.damage),"seconds":NumberFormat.rate(values.seconds)}))
	values.rows.sort_custom(func(a,b):return str(a.source)<str(b.source))
	var lines:Array[String]=[]
	for row in values.rows:
		var source:String=row.source
		var name=t("other")
		if source.begins_with("module:"):
			name=t("module",{"slot":str(int(source.trim_prefix("module:"))+1)})
		elif source.begins_with("drone:"):
			if not source_names.has(source):
				var slot:int=host.game.profile.hyperspace.inventory.equipped.find(source.trim_prefix("drone:"))+1
				source_names[source]=t("drone",{"slot":str(slot) if slot>0 else t("unknown_slot")})
			name=source_names[source]
		lines.append(t("row",{"source":name,"dps":NumberFormat.damage(row.dps),"damage":NumberFormat.damage(row.damage)}))
	host.set_ui_value(details,"text","\n".join(lines))
