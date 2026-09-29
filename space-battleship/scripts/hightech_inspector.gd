extends Panel
## Persistent page-owned inspector. Reads authoritative research; never owns it.
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
	host.equipment_card_label(overview,UIText.t("research.overview_hint"),Rect2(145,37,774,40),22,host.MUTED)

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
	var title: Label=host.equipment_card_label(panel,"",Rect2(145,14,374,34),24,host.INK)
	var effect: Label=host.equipment_card_label(panel,"",Rect2(145,51,374,60),19,host.INK)
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible=2
	effect.size=Vector2(374,60)
	var progress: Label=host.equipment_card_label(panel,"",Rect2(550,16,370,30),21,host.INK)
	var time: Label=host.equipment_card_label(panel,"",Rect2(550,57,370,30),21,host.MUTED)
	var workers: Label=host.equipment_card_label(panel,"",Rect2(885,14,250,30),21,host.INK)
	action(panel,"research.detail_close",Rect2(1138,8,38,32),func():host.select_hightech_bay(""))
	details[key]={"panel":panel,"title":title,"effect":effect,"progress":progress,"time":time,"workers":workers}
	return panel

func remove_project(key: String) -> void:
	if not details.has(key):return
	details[key].panel.queue_free()
	details.erase(key)

func refresh() -> void:
	if not is_visible_in_tree():return
	var selected: String=host.hightech_selected
	host.set_ui_value(overview,"visible",selected.is_empty())
	for key in details:host.set_ui_value(details[key].panel,"visible",key==selected)
	if not details.has(selected):return
	var controls: Dictionary=details[selected]
	if not host.game.hightech_unlocked(selected):
		host.set_ui_value(controls.title,"text",UIText.t("research.unrevealed"))
		for field in ["effect","progress","time","workers"]:host.set_ui_value(controls[field],"text","")
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
	host.set_ui_value(controls.title,"tooltip_text",host.game.permanent_level_tooltip(level,"hightech"))
	host.set_ui_value(controls.effect,"text",effect)
	host.set_ui_value(controls.progress,"text",UIText.t("research.detail_progress",{"percent":"%.0f" % floorf(fraction*100),"points":host.number(points),"required":host.number(required)}))
	var seconds := ceili(maxf(0,required-points)/rate) if rate>0 else 0
	host.set_ui_value(controls.time,"text",UIText.t("research.dock_remaining",{"time":"%02d:%02d:%02d" % [seconds/3600,(seconds%3600)/60,seconds%60]}) if rate>0 else UIText.t("research.no_ai"))
	var worker_text := UIText.t("research.detail_assigned",{"count":host.number(workers)})
	if host.game.crew.levels_unlocked(host.game):worker_text += "  " + host.game.crew.format_text(host.game,"dedicated_ai",{"ai":dedicated})
	host.set_ui_value(controls.workers,"text",worker_text)
