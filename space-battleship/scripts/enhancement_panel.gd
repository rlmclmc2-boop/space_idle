extends Panel
## Shared enhancement presentation. All levels, prices and effects remain game-owned.
const SKIN := preload("res://scripts/dialog_presentation.gd")
const SHELL := preload("res://scripts/shell_presentation.gd")
const FORMAT := preload("res://scripts/number_format.gd")
const PARAMETER_TEXT := preload("res://scripts/parameter_text.gd")
const N := preload("res://scripts/growth_number.gd")
const RESOURCE_ART := preload("res://scripts/resource_art.gd")
const NAVY := SHELL.NAVY
const PAPER := SHELL.PAPER
const TEAL := SHELL.TEAL
const MUTED := Color("637782")
var host: Node
var game: BattleGame
var level_label: Label
var bonus_label: Label
var balance_label: Label
var cost_label: Label
var progress: ProgressBar
var upgrade_button: Button
var max_button: Button
var preview_button: Button
var preview_dialog: AcceptDialog
var preview_body: RichTextLabel
var history_label: Label
var feedback: Label
var rule_label: Label
var scroll: ScrollContainer
var content: Control
var effect_cards: Dictionary = {}
var metrics_timer: Timer
var dirty := true
var branch_overlay: Control
var branch_close_button: Button
var branch_title: Label
var branch_subtitle: Label
var branch_rows: Array = []
var branch_category := ""
var branch_effect := ""
var branch_scroll: ScrollContainer
var effect_detail_dialog: AcceptDialog
var effect_detail_body: RichTextLabel
var detail_effect := ""
var detail_category := ""

func _init() -> void:
	hide()
	set_process(false)

func setup(owner_node: Node) -> void:
	host = owner_node
	game = host.game
	size = Vector2(1340,1180)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var header := frame(self,Rect2(10,4,1310,168),PAPER)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/shell/enhancement.svg")
	icon.position = Vector2(26,34)
	icon.size = Vector2(96,96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)

	level_label = text_label(header,"",Rect2(148,24,500,44),34)
	level_label.set_script(preload("res://scripts/enhancement_tooltip.gd").HoverLabel)
	level_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bonus_label = text_label(header,"",Rect2(148,83,500,28),21,MUTED)
	var fragment_icon := TextureRect.new()
	fragment_icon.name = "FragmentBalanceIcon"
	fragment_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fragment_icon.texture = RESOURCE_ART.FRAGMENT
	fragment_icon.position = Vector2(674,18)
	fragment_icon.size = Vector2(32,32)
	fragment_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fragment_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(fragment_icon)
	balance_label = text_label(header,"",Rect2(714,18,560,34),23)
	cost_label = text_label(header,"",Rect2(674,57,600,32),21)
	progress = ProgressBar.new()
	progress.position = Vector2(674,101)
	progress.size = Vector2(296,22)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",SKIN.surface(Color("ccd8d2"),NAVY,0))
	progress.add_theme_stylebox_override("fill",SKIN.surface(TEAL,NAVY,0))
	header.add_child(progress)
	upgrade_button = button(header,"enhance.upgrade",Rect2(985,98,144,48),func():purchase(1),true)
	preview_button = button(header,"enhance.preview_button",Rect2(148,120,210,38),show_upgrade_preview)
	max_button = button(header,"enhance.upgrade_max",Rect2(1140,98,145,48),func():purchase(-1))

	scroll = ScrollContainer.new()
	scroll.position = Vector2(10,188)
	scroll.size = Vector2(1310,634)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = Control.new()
	content.custom_minimum_size = Vector2(1290,620)
	scroll.add_child(content)
	for category in ["weapons","defence"]:
		var left := 0.0 if category=="weapons" else 658.0
		var section := frame(content,Rect2(left,0,636,620),Color("304c60"))
		text_label(section,UIText.t("weapon.tab" if category=="weapons" else "defense.tab"),Rect2(22,14,590,38),26,PAPER)
		effect_cards[category] = []
		for index in 3:
			var card := create_effect_card(section,Rect2(14,62+index*184,608,180),category,index)
			effect_cards[category].append(card)
	rule_label = text_label(self,"",Rect2(24,840,1280,32),21,PAPER)
	rule_label.mouse_filter = Control.MOUSE_FILTER_PASS
	history_label = text_label(self,"",Rect2(24,1128,880,32),20,TEAL)
	feedback = text_label(self,"",Rect2(905,887,395,32),20,TEAL)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	history_label.hide()
	build_branch_drawer()
	metrics_timer = Timer.new()
	metrics_timer.wait_time = 1.0
	metrics_timer.timeout.connect(refresh)
	add_child(metrics_timer)
	visibility_changed.connect(on_visibility_changed)
	hide()

func frame(parent: Node, rect: Rect2, fill: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",SKIN.surface(fill,NAVY,0))
	parent.add_child(panel)
	return panel

func text_label(parent: Node, value: String, rect: Rect2, font_size: int, color := NAVY) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.add_theme_font_override("font",SHELL.face(500))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button(parent: Node, key: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var control := Button.new()
	control.position = rect.position
	control.size = rect.size
	control.text = UIText.t(key)
	control.add_theme_font_size_override("font_size",21)
	SKIN.button_skin(control,primary)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func create_effect_card(parent: Node, rect: Rect2, category: String, index: int) -> Dictionary:
	var card := frame(parent,rect,PAPER)
	var rank := text_label(card,str(index+1).pad_zeros(2),Rect2(18,14,44,32),24,MUTED)
	var title := text_label(card,"",Rect2(78,14,380,34),25)
	var threshold := text_label(card,"",Rect2(78,55,374,28),20,MUTED)
	threshold.hide()
	var description := PARAMETER_TEXT.create_label(card,Rect2(20,65,568,48),20,SHELL.face(500),NAVY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.set_script(preload("res://scripts/enhancement_tooltip.gd").HoverRichText)
	description.preview_text=func():return effect_hover_text(category,index)
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	var state := text_label(card,"",Rect2(20,132,314,32),21,MUTED)
	var up := button(card,"enhance.move_up",Rect2(484,12,50,38),func():move_effect(category,index,-1))
	var down := button(card,"enhance.move_down",Rect2(544,12,50,38),func():move_effect(category,index,1))
	var details := button(card,"equipment.inspect",Rect2(350,128,106,36),func():open_effect_details(category,str(game.enhancement_order(category)[index])))
	var branches := button(card,"enhance.branches.open",Rect2(466,128,128,36),func():open_branches(category,str(game.enhancement_order(category)[index])))
	up.tooltip_text = UIText.t("enhance.move_up_hint")
	down.tooltip_text = UIText.t("enhance.move_down_hint")
	return {"panel":card,"rank":rank,"title":title,"threshold":threshold,"description":description,"state":state,"up":up,"down":down,"branches":branches,"details":details}

func open(_category := "", _index := -1) -> void:
	if not game.enhancement_unlocked():return
	show()
	host.ui.move_child(self,-1)
	refresh()

func close() -> void:
	if host.equipment_tabs.current_tab==4:host.return_to_first_system()
	else:hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(branch_overlay) and branch_overlay.visible:branch_overlay.hide()
		else:close()
		get_viewport().set_input_as_handled()

func on_visibility_changed() -> void:
	if not is_instance_valid(metrics_timer):return
	if visible:
		metrics_timer.start()
		refresh()
	else:
		metrics_timer.stop()
		if is_instance_valid(effect_detail_dialog):effect_detail_dialog.hide()

func invalidate() -> void:
	dirty = true
	if visible:refresh()

func inventory_changed() -> void:
	invalidate()

func pickup_feedback(_info: Dictionary) -> void:
	invalidate()

func purchase(count: int) -> void:
	var purchased := game.upgrade_enhancement(count)
	if purchased>0:
		host.set_ui_value(feedback,"text",UIText.t("enhance.upgraded",{"count":purchased}))
	else:
		host.set_ui_value(feedback,"text",UIText.t("enhance.limit_reached" if game.enhancement_at_limit() else "enhance.insufficient"))
	refresh()

func move_effect(category: String, index: int, direction: int) -> void:
	var order: Array = game.enhancement_order(category).duplicate()
	var destination := index+direction
	if index<0 or destination<0 or index>=order.size() or destination>=order.size():return
	var previous = order[index]
	order[index] = order[destination]
	order[destination] = previous
	if game.set_enhancement_order(category,order):
		host.set_ui_value(feedback,"text",UIText.t("enhance.reordered"))
		refresh()
		var focused: Button = effect_cards[category][destination]["up" if direction<0 else "down"]
		focused.grab_focus()

func parameter(key: String) -> float:
	return game.enhancement_parameter(key)

func display(value: Variant) -> String:
	return FORMAT.precise(value)

func threshold_level(index: int) -> int:
	return game.enhancement_effect_threshold(index)

func effect_name(kind: String) -> String:
	return UIText.t("enhance.effect."+kind) if not kind.is_empty() else UIText.t("enhance.effect.pending")

func effect_description(kind: String) -> String:
	if game.has_method("enhancement_effect_runtime"):
		return runtime_effect_description(kind)
	var level := game.enhancement_effective_level()
	match kind:
		"proficiency","adaptation":
			var count := int(game.profile.get("enhancementAttacks" if kind=="proficiency" else "enhancementHits",0))
			var coefficient := parameter("proficiency_growth" if kind=="proficiency" else "adaptation_growth")
			var round_scale := parameter("bonus_round_scale")
			var bonus := roundf(coefficient*level*log(float(maxi(1,count)))/log(parameter("counter_log_base"))*round_scale)/round_scale
			return UIText.t("enhance.description."+kind,{"bonus":FORMAT.percentage(bonus*100),"count":FORMAT.compact(count)})
		"repeat":
			return UIText.t("enhance.description.repeat",{"chance":FORMAT.percentage(parameter("repeat_probability")*100),"delay":display(parameter("repeat_delay")),"bonus":FORMAT.percentage(100.0+parameter("repeat_growth")*level*100)})
		"critical":
			return UIText.t("enhance.description.critical",{"chance":FORMAT.percentage(parameter("base_critical_rate")*100),"multiplier":FORMAT.percentage(N.multiply(parameter("base_critical_multiplier")+parameter("critical_growth")*level,100.0))})
		"delayed_damage":
			var duration := parameter("deferred_duration")
			var interval := parameter("deferred_interval")
			var ticks := ceili(duration/interval-0.000000001)
			return UIText.t("enhance.description.delayed_damage",{"fraction":FORMAT.percentage(game.enhancement_deferred_fraction()*100),"duration":display(duration),"interval":display(interval),"ticks":ticks,"chance":FORMAT.percentage(parameter("deferred_clear_probability")*100)})
		"memory_material":
			return UIText.t("enhance.description.memory_material",{"interval":display(parameter("memory_interval")),"recovery":FORMAT.percentage(parameter("memory_heal_fraction")*level*100),"cap":FORMAT.percentage(parameter("memory_buffer_fraction")*level*100)})
	return UIText.t("enhance.description.pending")

func runtime_effect_description(kind: String) -> String:
	var values: Dictionary = game.call("enhancement_effect_runtime",kind)
	match kind:
		"proficiency","adaptation":
			var count := int(values.get("history",0))
			var bonus := roundf(float(values.growth)*game.enhancement_effective_level()*log(float(maxi(1,count)))/log(parameter("counter_log_base"))*parameter("bonus_round_scale"))/parameter("bonus_round_scale")
			return UIText.t("enhance.description."+kind+".runtime",{"count":FORMAT.compact(count),"bonus":FORMAT.percentage(bonus*100),"branch":FORMAT.percentage(values.branch_bonus_percent)})
		"repeat":
			return UIText.t("enhance.description.repeat.runtime",{"chance":FORMAT.percentage(values.probability_percent),"delay":display(values.delay),"bonus":FORMAT.percentage(100.0+float(values.damage_percent))})
		"critical":
			var guaranteed := game.enhancement_branch_choice("weapons",kind,3)=="B" and game.enhancement_branch_unlocked("weapons",kind,3) and int(values.eligible_modules)>0
			var key := "enhance.description.critical.runtime" if guaranteed else "enhance.description.critical.runtime_regular"
			var arguments := {"chance":FORMAT.percentage(values.probability_percent),"multiplier":FORMAT.percentage(N.multiply(values.damage_multiplier,100.0))}
			if guaranteed:arguments.underlying=FORMAT.percentage(values.underlying_probability_percent)
			return UIText.t(key,arguments)
		"memory_material":
			return UIText.t("enhance.description.memory_material.runtime",{"interval":display(values.interval),"recovery":FORMAT.percentage(values.heal_percent),"charge":FORMAT.percentage(values.charge_percent),"cap":FORMAT.percentage(values.capacity_percent)})
		"delayed_damage":
			var ticks := ceili(float(values.duration)/float(values.interval)-0.000000001)
			return UIText.t("enhance.description.delayed_damage",{"fraction":FORMAT.percentage(values.fraction_percent),"duration":display(values.duration),"interval":display(values.interval),"ticks":ticks,"chance":FORMAT.percentage(values.probability_percent)})
	return UIText.t("enhance.description.pending")

func compact_branch_path(category: String, kind: String) -> String:
	var choices: Array[String] = []
	for node in range(1,4):
		var choice := game.enhancement_branch_choice(category,kind,node)
		choices.append(choice if not choice.is_empty() else UIText.t("enhance.overview.branch_empty"))
	return " · ".join(choices)

func effect_overview_text(key: String, value: Variant, unit := "%") -> String:
	return PARAMETER_TEXT.render(key,{"value":FORMAT.percentage(value)},{"value":{"role":"effect","unit":unit}})

func effect_overview(kind: String, context: BattleGame = null) -> String:
	if context==null:context=game
	var runtime: Dictionary = context.enhancement_effect_runtime(kind)
	var level := int(runtime.effective_level)
	match kind:
		"proficiency","adaptation":
			var count := int(runtime.history)
			var bonus := roundf(float(runtime.growth)*level*log(float(maxi(1,count)))/log(parameter("counter_log_base"))*parameter("bonus_round_scale"))/parameter("bonus_round_scale")
			return effect_overview_text("enhance.overview."+kind,bonus*100)
		"repeat":
			return PARAMETER_TEXT.render("enhance.overview.repeat",{"chance":FORMAT.percentage(runtime.probability_percent),"multiplier":FORMAT.percentage(100.0+float(runtime.damage_percent))},{"chance":{"role":"effect","unit":"%"},"multiplier":{"role":"effect","unit":"%"}})
		"critical":
			var guaranteed := context.enhancement_branch_choice("weapons",kind,3)=="B" and context.enhancement_branch_unlocked("weapons",kind,3) and int(runtime.eligible_modules)>0
			var values := {"chance":FORMAT.percentage(runtime.probability_percent),"multiplier":FORMAT.percentage(N.multiply(runtime.damage_multiplier,100.0))}
			if guaranteed:values.underlying=FORMAT.percentage(runtime.underlying_probability_percent)
			return PARAMETER_TEXT.render("enhance.overview.critical_guaranteed" if guaranteed else "enhance.overview.critical",values,{"chance":{"role":"effect","unit":"%"},"underlying":{"role":"effect","unit":"%"},"multiplier":{"role":"effect","unit":"%"}})
		"memory_material":return effect_overview_text("enhance.overview.memory_material",float(runtime.heal_percent)/float(runtime.interval),"%/秒")
		"delayed_damage":return PARAMETER_TEXT.render("enhance.overview.delayed_damage",{"value":FORMAT.percentage(runtime.fraction_percent),"chance":FORMAT.percentage(runtime.probability_percent)},{"value":{"role":"effect","unit":"%"},"chance":{"role":"effect","unit":"%"}})
	return UIText.t("enhance.description.pending")

func upgrade_preview_text() -> String:
	if game.enhancement_at_limit():return UIText.t("enhance.limit_reached")
	# Project through the existing game queries on an isolated copy, only on request.
	var projected := BattleGame.new(game.db,false)
	projected.profile=game.profile.duplicate(true)
	var current:Array[String]=[]
	var kinds:Array[String]=[]
	for category in ["weapons","defence"]:
		var order:Array=game.enhancement_order(category)
		for index in order.size():
			if game.enhancement_effective_level()+1<threshold_level(index):continue
			var kind=str(order[index])
			kinds.append(kind)
			current.append(effect_overview(kind,projected) if game.enhancement_effective_level()>=threshold_level(index) else UIText.t("enhance.preview_not_active"))
	projected.profile.enhancementLevel=int(projected.profile.enhancementLevel)+1
	var lines:Array[String]=[UIText.t("enhance.preview_heading",{"level":str(game.enhancement_level()+1),"cost":FORMAT.compact(game.enhancement_cost())}),UIText.t("enhance.preview_scope")]
	for index in kinds.size():
		var after=effect_overview(kinds[index],projected)
		if current[index]==after:continue
		var parts=changed_preview_parts(current[index],after)
		lines.append(UIText.t("enhance.preview_effect",{"name":effect_name(kinds[index]),"before":parts[0],"after":parts[1]}))
	return "\n\n".join(lines)

func changed_preview_parts(before:String,after:String) -> Array[String]:
	var old=before.split(" · ");var next=after.split(" · ")
	if old.size()!=next.size():return [before,after]
	var old_changed:Array[String]=[];var new_changed:Array[String]=[]
	for index in old.size():
		if old[index]!=next[index]:old_changed.append(old[index]);new_changed.append(next[index])
	return [" · ".join(old_changed)," · ".join(new_changed)]

func show_upgrade_preview() -> void:
	if not is_instance_valid(preview_dialog):
		preview_dialog=AcceptDialog.new();SKIN.dialog(preview_dialog);add_child(preview_dialog)
		preview_body=RichTextLabel.new();preview_body.add_theme_font_size_override("normal_font_size",20);preview_body.bbcode_enabled=true;preview_body.selection_enabled=true;preview_body.scroll_active=true;preview_body.custom_minimum_size=Vector2(600,360);preview_dialog.add_child(preview_body)
	preview_dialog.title=UIText.t("enhance.preview_button")
	preview_body.text=upgrade_preview_text()
	preview_dialog.popup_centered(Vector2i(740,500))

func eligible_count(category: String, index: int) -> int:
	var count := 0
	for entry in game.loadout_entries(category):
		if not str(entry.get("key","")).is_empty() and game.active_enhancement_effect_count(entry)>index:count+=1
	return count

func refresh() -> void:
	if not visible:
		dirty = true
		return
	dirty = false
	var level := game.enhancement_level()
	var bonus := game.enhancement_level_bonus()
	var at_limit := game.enhancement_at_limit()
	var cost = game.enhancement_cost()
	var balance = game.profile.get("jewelFragments",0)
	host.set_ui_value(level_label,"text",UIText.t("enhance.level",{"level":level}))
	host.set_ui_value(bonus_label,"visible",bonus!=0)
	if bonus!=0:
		host.set_ui_value(bonus_label,"text",UIText.t("enhance.bonus",{"bonus":bonus,"effective":game.enhancement_effective_level()}))
	host.set_ui_value(balance_label,"text",UIText.t("enhance.balance",{"amount":FORMAT.compact(balance)}))
	host.set_ui_value(balance_label,"tooltip_text",UIText.t("enhance.balance",{"amount":display(balance)}))
	host.set_ui_value(cost_label,"text",UIText.t("enhance.limit_reached") if at_limit else UIText.t("enhance.cost",{"level":level+1,"cost":FORMAT.compact(cost)}))
	host.set_ui_value(cost_label,"tooltip_text",UIText.t("enhance.limit_reached") if at_limit else UIText.t("enhance.cost",{"level":level+1,"cost":display(cost)}))
	host.set_ui_value(upgrade_button,"disabled",not game.can_upgrade_enhancement())
	host.set_ui_value(max_button,"disabled",not game.can_upgrade_enhancement())
	host.set_ui_value(progress,"value",clampf(floorf(N.ratio(balance,cost)*100),0,100) if N.compare(cost,0)>0 else 0.0)
	for category in effect_cards:
		var order: Array = game.enhancement_order(category)
		for index in 3:
			var card: Dictionary = effect_cards[category][index]
			var kind := str(order[index]) if index<order.size() else ""
			host.set_ui_value(card.title,"text",effect_name(kind))
			var active := game.enhancement_effective_level()>=threshold_level(index)
			host.set_ui_value(card.description,"text",effect_overview(kind) if active or kind.is_empty() else UIText.t("enhance.candidate."+kind))
			host.set_ui_value(card.description,"tooltip_text",effect_details_text(kind))
			var state_key := "enhance.effect.active" if active else "enhance.effect.reorder" if game.enhancement_effective_level()>=threshold_level(0) else "enhance.effect.first_upgrade"
			var state_values := {"count":eligible_count(category,index)} if active else {}
			host.set_ui_value(card.state,"text",UIText.t("enhance.pending_state") if kind.is_empty() else UIText.t(state_key,state_values))
			host.set_ui_value(card.up,"disabled",index==0)
			host.set_ui_value(card.down,"disabled",index==2)
			host.set_ui_value(card.details,"disabled",kind.is_empty())
			host.set_ui_value(card.branches,"disabled",kind.is_empty())
			host.set_ui_value(card.branches,"tooltip_text",branch_summary(category,kind))
	var active_count := 0
	for index in 3:
		if game.enhancement_effective_level()>=threshold_level(index):active_count+=1
	host.set_ui_value(rule_label,"text",UIText.t("enhance.overview.current",{"count":active_count}) if active_count>0 else UIText.t("enhance.effect.first_upgrade"))
	host.set_ui_value(rule_label,"tooltip_text",UIText.t("enhance.overview.thresholds",{"first":threshold_level(0),"second":threshold_level(1),"third":threshold_level(2)}))
	refresh_branches()
	refresh_effect_details()
	host.set_ui_value(level_label,"tooltip_text",UIText.t("enhance.history",{"attacks":FORMAT.compact(game.profile.get("enhancementAttacks",0)),"hits":FORMAT.compact(game.profile.get("enhancementHits",0))}))

func candidate_effect_preview(category:String,kind:String) -> String:
	if game.enhancement_effective_level()<threshold_level(0):return UIText.t("enhance.preview_not_active")
	# Only a requested hover/detail builds this isolated, permanent-state view.
	# Fresh combat state excludes temporary stacks and pending attack bonuses.
	var projected:=BattleGame.new(game.db,false)
	projected.profile=game.profile.duplicate(true)
	var order:Array=game.enhancement_order(category).duplicate()
	order.erase(kind);order.push_front(kind)
	projected.profile.enhancementOrder[category]=order
	projected.invalidate_stat_cache()
	var plain:=RichTextLabel.new();plain.bbcode_enabled=true
	plain.text=effect_overview(kind,projected)
	var summary:=plain.get_parsed_text();plain.free()
	return UIText.t("enhance.candidate_current",{"level":str(game.enhancement_effective_level()),"summary":summary})

func effect_hover_text(category:String,index:int) -> String:
	var kind:=str(game.enhancement_order(category)[index])
	return candidate_effect_preview(category,kind) if game.enhancement_effective_level()<threshold_level(index) else effect_details_text(kind)

func effect_details_text(kind: String) -> String:
	var text := effect_description(kind)
	if kind in ["proficiency","adaptation"]:
		text+="\n\n"+UIText.t("enhance.history."+kind)
	if kind=="memory_material":text+="\n\n"+host.enhancement_protection_details()
	return text

func open_effect_details(category: String, kind: String) -> void:
	if kind.is_empty():return
	detail_category=category
	detail_effect=kind
	if not is_instance_valid(effect_detail_dialog):
		effect_detail_dialog=AcceptDialog.new()
		SKIN.dialog(effect_detail_dialog)
		effect_detail_body=RichTextLabel.new()
		effect_detail_body.custom_minimum_size=Vector2(600,360)
		effect_detail_body.selection_enabled=true
		effect_detail_body.scroll_active=true
		effect_detail_dialog.add_child(effect_detail_body)
		add_child(effect_detail_dialog)
	refresh_effect_details(true)
	effect_detail_dialog.popup_centered(Vector2i(640,460))

func refresh_effect_details(force := false) -> void:
	if not is_instance_valid(effect_detail_dialog) or (not force and not effect_detail_dialog.visible):return
	var index := game.enhancement_order(detail_category).find(detail_effect)
	host.set_ui_value(effect_detail_dialog,"title",effect_name(detail_effect))
	var text := UIText.t("enhance.effect.state",{"level":threshold_level(index),"count":eligible_count(detail_category,index)})+"\n\n"+(candidate_effect_preview(detail_category,detail_effect) if game.enhancement_effective_level()<threshold_level(index) else effect_details_text(detail_effect))
	host.set_ui_value(effect_detail_body,"text",text)

func build_branch_drawer() -> void:
	branch_overlay = Control.new()
	branch_overlay.size = size
	branch_overlay.z_index = 20
	add_child(branch_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.05,0.10,0.14,0.76)
	shade.size = size
	branch_overlay.add_child(shade)
	var body := frame(branch_overlay,Rect2(130,48,1080,1080),PAPER)
	branch_title = text_label(body,"",Rect2(26,20,830,44),30)
	branch_subtitle = text_label(body,"",Rect2(26,72,1028,32),21,MUTED)
	branch_close_button = button(body,"enhance.branches.close",Rect2(906,20,148,46),func():branch_overlay.hide())
	branch_scroll = ScrollContainer.new()
	branch_scroll.position = Vector2(20,120)
	branch_scroll.size = Vector2(1040,874)
	branch_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(branch_scroll)
	var rows := Control.new()
	rows.custom_minimum_size = Vector2(1018,988)
	branch_scroll.add_child(rows)
	for node in range(1,4):
		var row := frame(rows,Rect2(0,(node-1)*332,1018,316),Color("dae4df"))
		var title := text_label(row,"",Rect2(22,12,974,32),24)
		var status := text_label(row,"",Rect2(22,49,974,28),20,MUTED)
		var options := {"title":title,"status":status}
		for option in ["A","B"]:
			var left := 18.0 if option=="A" else 518.0
			var control := button(row,"enhance.branches."+option.to_lower(),Rect2(left,88,482,224),func():choose_branch(node,option))
			control.text = ""
			var name_label := text_label(control,"",Rect2(18,12,446,34),24)
			var description := PARAMETER_TEXT.create_label(control,Rect2(18,53,446,136),20,SHELL.face(500),NAVY)
			var implementation := text_label(control,"",Rect2(18,194,446,25),18,MUTED)
			options[option] = control
			options[option+"_title"] = name_label
			options[option+"_description"] = description
			options[option+"_implementation"] = implementation
		branch_rows.append(options)
	var note := text_label(body,UIText.t("enhance.branches.note"),Rect2(28,1014,1024,44),21,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branch_overlay.hide()

func branch_metadata(category: String, kind: String, node: int, option: String) -> Dictionary:
	if game.has_method("enhancement_branch_metadata"):
		var metadata: Dictionary = game.call("enhancement_branch_metadata",category,kind,node,option)
		var parameters: Dictionary = metadata.get("parameters",{})
		if kind=="memory_material" and node==2 and option=="B" and float(parameters.get("resistance_min_percent",0))!=float(parameters.get("resistance_max_percent",0)):
			metadata.description_text_id="enhance.branch.memory_material.2.B.description_mixed"
		return metadata
	return {"implemented":false,"title_text_id":"enhance.branches."+option.to_lower(),"description_text_id":"enhance.branches.placeholder","parameters":{}}

func branch_option_text(metadata: Dictionary, field: String) -> String:
	var text_id := str(metadata.get(field,""))
	var values: Dictionary = metadata.get("parameters",{})
	var parameters := {}
	for key in UIText.contracts.get(text_id,{}).get("params",[]):
		if not values.has(key):continue
		parameters[key] = FORMAT.percentage(values[key]) if str(key).ends_with("_percent") else FORMAT.compact(values[key]) if values[key] is float else values[key]
	return UIText.t(text_id,parameters)

func branch_option_markup(metadata: Dictionary) -> String:
	var text_id := str(metadata.get("description_text_id",""))
	var values: Dictionary = metadata.get("parameters",{})
	var parameters := {}
	var spans := {}
	for key in UIText.contracts.get(text_id,{}).get("params",[]):
		if not values.has(key):continue
		parameters[key] = FORMAT.percentage(values[key]) if str(key).ends_with("_percent") else FORMAT.compact(values[key]) if values[key] is float else values[key]
		var unit := "%"
		var role := "effect"
		if key in ["interval","duration","lockout"]:unit=" 秒";role="time"
		elif key=="extra_targets":unit=" 个"
		elif key in ["extra_repeats","attacks"]:unit=" 次"
		elif key=="stacks":unit=" 层" if str(metadata.effect)=="critical" else " 次"
		elif key=="probability_percent" and (str(metadata.choice)=="A" or (str(metadata.effect)=="critical" and int(metadata.node)==2)):unit=" 个百分点"
		spans[key]={"role":role,"unit":unit}
	return PARAMETER_TEXT.render(text_id,parameters,spans)

func branch_path(category: String, kind: String) -> String:
	if kind.is_empty():return ""
	var choices: Array[String] = []
	for node in range(1,4):
		var choice := game.enhancement_branch_choice(category,kind,node)
		choices.append(choice if not choice.is_empty() else UIText.t("enhance.branches.unselected"))
	return " / ".join(choices)

func branch_summary(category: String, kind: String) -> String:
	var summary := UIText.t("enhance.branches.summary",{"path":branch_path(category,kind)})
	for node in range(1,4):
		var choice := game.enhancement_branch_choice(category,kind,node)
		if choice.is_empty():continue
		var metadata := branch_metadata(category,kind,node,choice)
		summary += "\n"+branch_option_text(metadata,"title_text_id")+"："+branch_option_text(metadata,"description_text_id")
	return summary

func open_branches(category: String, kind: String) -> void:
	if kind.is_empty() or not game.enhancement_order(category).has(kind):return
	if branch_category!=category or branch_effect!=kind:branch_scroll.scroll_vertical=0
	branch_category = category
	branch_effect = kind
	branch_overlay.show()
	refresh_branches()

func choose_branch(node: int, choice: String) -> void:
	if game.set_enhancement_branch(branch_category,branch_effect,node,choice):
		host.set_ui_value(feedback,"text",UIText.t("enhance.branches.changed"))
		refresh()

func refresh_branches() -> void:
	if not is_instance_valid(branch_overlay) or not branch_overlay.visible:return
	host.set_ui_value(branch_title,"text",UIText.t("enhance.branches.title",{"effect":effect_name(branch_effect)}))
	host.set_ui_value(branch_subtitle,"text",UIText.t("enhance.branches.level",{"level":game.enhancement_effective_level(),"purchased":game.enhancement_level(),"bonus":game.enhancement_level_bonus()}))
	for node in range(1,4):
		var row: Dictionary = branch_rows[node-1]
		var unlocked := game.enhancement_branch_unlocked(branch_category,branch_effect,node)
		var choice := game.enhancement_branch_choice(branch_category,branch_effect,node)
		host.set_ui_value(row.title,"text",UIText.t("enhance.branches.milestone",{"node":node,"level":game.enhancement_branch_threshold(node,branch_category,branch_effect)}))
		host.set_ui_value(row.status,"text",UIText.t("enhance.branches.locked") if not unlocked else UIText.t("enhance.branches.awaiting") if choice.is_empty() else UIText.t("enhance.branches.selected",{"choice":choice}))
		for option in ["A","B"]:
			var control: Button = row[option]
			host.set_ui_value(control,"disabled",not unlocked)
			var metadata := branch_metadata(branch_category,branch_effect,node,option)
			var option_name := branch_option_text(metadata,"title_text_id")
			var description := branch_option_text(metadata,"description_text_id")
			host.set_ui_value(row[option+"_title"],"text",UIText.t("enhance.branches.option_title",{"option":option,"title":option_name}))
			host.set_ui_value(row[option+"_description"],"text",branch_option_markup(metadata))
			host.set_ui_value(control,"tooltip_text",option_name+"\n"+description)
			var implemented := bool(metadata.get("implemented",false))
			host.set_ui_value(row[option+"_implementation"],"visible",not implemented)
			host.set_ui_value(row[option+"_implementation"],"text",UIText.t("enhance.branches.placeholder") if not implemented else "")
			var selected: bool = option==choice
			if not control.has_meta("branch_selected") or bool(control.get_meta("branch_selected"))!=selected:
				control.set_meta("branch_selected",selected)
				SKIN.button_skin(control,selected)
