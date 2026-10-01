extends Panel
## Persistent page-owned inspector. Reads authoritative research; never owns it.
const PRESENTATION := preload("res://scripts/hightech_presentation.gd")
var host
var overview: Control
var details: Dictionary = {}

func setup(owner) -> void:
	host=owner
	position=Vector2(12,1026)
	size=Vector2(1320,124)
	add_theme_stylebox_override("panel",preload("res://scripts/hightech_presentation.gd").surface("detail-surface"))
	mouse_filter=Control.MOUSE_FILTER_STOP
	overview=Control.new()
	overview.size=size
	overview.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(overview)
	var hint: Label=host.equipment_card_label(overview,UIText.t("research.overview_hint"),Rect2(24,38,1272,40),23,PRESENTATION.MUTED)
	PRESENTATION.label_skin(hint)

func action(parent: Control, text_key: String, rect: Rect2, callback: Callable) -> Button:
	var result: Button=host.button(UIText.t(text_key),rect,callback)
	result.reparent(parent,false)
	preload("res://scripts/hightech_presentation.gd").button_skin(result)
	return result

func add_project(key: String) -> Control:
	var panel := Control.new()
	panel.size=size
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.visible=false
	add_child(panel)
	var title: Label=host.equipment_card_label(panel,"",Rect2(24,12,530,34),24,PRESENTATION.NAVY)
	# Keep the entire translated effect accessible, without stealing bay scroll input.
	var effect_scroll := ScrollContainer.new()
	effect_scroll.position=Vector2(24,50)
	effect_scroll.size=Vector2(530,62)
	effect_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	effect_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	effect_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.add_child(effect_scroll)
	PRESENTATION.scroll_skin(effect_scroll)
	var effect := PRESENTATION.PARAMETERS.create_label(effect_scroll,Rect2(0,0,506,62),21,PRESENTATION.CHROME.SHELL.face(500),PRESENTATION.NAVY)
	effect.custom_minimum_size=Vector2(506,0)
	effect.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	effect.fit_content=true
	effect.mouse_filter=Control.MOUSE_FILTER_PASS
	var progress: Label=host.equipment_card_label(panel,"",Rect2(576,16,352,32),22,PRESENTATION.NAVY)
	var time: Label=host.equipment_card_label(panel,"",Rect2(576,58,352,32),22,PRESENTATION.MUTED)
	var workers: Label=host.equipment_card_label(panel,"",Rect2(958,12,296,42),21,PRESENTATION.NAVY)
	workers.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	workers.max_lines_visible=2
	for label in [title,progress,time,workers]:
		PRESENTATION.label_skin(label,label in [title,progress,workers])
	action(panel,"research.detail_close",Rect2(1270,12,34,38),func():host.select_hightech_bay(""))
	details[key]={"panel":panel,"title":title,"effect":effect,"effect_scroll":effect_scroll,"progress":progress,"time":time,"workers":workers}
	return panel

func remove_project(key: String) -> void:
	if not details.has(key):return
	details[key].panel.queue_free()
	details.erase(key)

func _notification(what: int) -> void:
	# Tab change clears selection while hidden; catch up on reveal even if AI is unchanged.
	if what==NOTIFICATION_VISIBILITY_CHANGED and host!=null and is_visible_in_tree():refresh()

func refresh() -> void:
	if not is_visible_in_tree():return
	var selected: String=host.hightech_selected
	host.set_ui_value(overview,"visible",selected.is_empty())
	for key in details:host.set_ui_value(details[key].panel,"visible",key==selected)
	if not details.has(selected):return
	var controls: Dictionary=details[selected]
	if not host.game.hightech_unlocked(selected):
		host.set_ui_value(controls.title,"text",UIText.t("research.unrevealed"))
		host.set_ui_value(controls.title,"tooltip_text",UIText.t("research.unrevealed"))
		for field in ["effect","progress","time","workers"]:
			host.set_ui_value(controls[field],"text","")
			host.set_ui_value(controls[field],"tooltip_text","")
		# Invalidate the title snapshot so reveal restores data even after relocking.
		host.ui_state_changed(controls.title,["unrevealed"])
		return
	var level: int=host.game.hightech_level(selected)
	var points: float=host.game.profile.techPoints.get(selected,0)
	var required: float=host.game.hightech_required(selected)
	var workers: int=host.game.assigned_scientists(selected)
	var dedicated: int=host.game.dedicated_scientists(selected)
	var rate: float=host.game.research_rate(selected)
	var effect: String=preload("res://scripts/hightech_presentation.gd").effect_text(host.game,selected)
	if not host.ui_state_changed(controls.title,[level,host.game.hightech_level_bonus(),points,required,workers,dedicated,rate,effect,host.game.paused,host.game.crew.levels_unlocked(host.game)]):return
	var fraction := clampf(points/required,0,1)
	host.set_ui_value(controls.title,"text",UIText.t("gem.name_level",{"item_name":UIText.data_text("hightech",selected),"level":host.game.permanent_level_text(level,"hightech")}))
	host.set_ui_value(controls.title,"tooltip_text",controls.title.text+"\n"+host.game.permanent_level_tooltip(level,"hightech"))
	host.set_ui_value(controls.effect,"text",PRESENTATION.effect_markup(host.game,selected))
	host.set_ui_value(controls.effect,"tooltip_text",effect)
	host.set_ui_value(controls.progress,"text",UIText.t("research.detail_progress",{"percent":"%.0f" % floorf(fraction*100),"points":host.number(points),"required":host.number(required)}))
	host.set_ui_value(controls.progress,"tooltip_text",controls.progress.text)
	var seconds := ceili(maxf(0,required-points)/rate) if rate>0 else 0
	host.set_ui_value(controls.time,"text",UIText.t("research.dock_remaining",{"time":"%02d:%02d:%02d" % [seconds/3600,(seconds%3600)/60,seconds%60]}) if rate>0 else UIText.t("research.no_ai"))
	host.set_ui_value(controls.time,"tooltip_text",controls.time.text)
	var worker_text := UIText.t("research.detail_assigned",{"count":host.number(workers)})
	if host.game.crew.levels_unlocked(host.game):worker_text += "  " + host.game.crew.format_text(host.game,"dedicated_ai",{"ai":dedicated})
	host.set_ui_value(controls.workers,"text",worker_text)
	host.set_ui_value(controls.workers,"tooltip_text",worker_text)
