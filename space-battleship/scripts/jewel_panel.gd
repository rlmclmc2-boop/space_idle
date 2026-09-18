extends Panel

# Owns only presentation selection and its controls; inventory is always game.profile.
var host: Node
var game: BattleGame
var selected: Array = []
var category := ""
var equipment_index := -1
var equipment_identity: Dictionary = {}
var cells: Array[Button] = []
var socket_buttons: Array[Button] = []
var inventory_list: GridContainer
var empty_cells: Array[Button] = []
var gem_buttons: Dictionary = {}
var textures: Dictionary = {}
var socket_row: HBoxContainer
var summary: Label
var detail: Label
var fragments: Label
var equipment_title: Label
var combine: Button
var combine_all: Button
var bulk_summary := ""
var bulk_rewards := ""
var compose: Button
var socket_action: Button
var detail_icon: TextureRect
var detail_heading: Label
var preview: Label
var feedback: Label
var empty_hint: Label
var detail_scroll: ScrollContainer
var metrics_timer: Timer
var compose_dialog: ConfirmationDialog
var pending_compose := -1
var inspected_socket := -1
var target_socket := -1
var result_token := -1
# Presentation-only acknowledgement and animation state, never saved or used as inventory.
var new_tokens: Dictionary = {}
var observed_serial := 0
var generated_count := 0
var acting := false
var palettes: Dictionary = {}
var effect_layer: Control
var flights: Array[TextureRect] = []
var flight_cursor := 0
var animations: Dictionary = {}
var metric_state: Array = []

func _init() -> void:
	hide()
	set_process(false)

func setup(owner_node: Node) -> void:
	host = owner_node
	game = host.game
	observed_serial = game.jewel_serial
	create_palettes()
	position = Vector2(50, 65)
	size = Vector2(1340, 535)
	add_theme_stylebox_override("panel", host.style(host.PANEL, host.CYAN))
	add_theme_font_override("font", host.font)
	label("宝石工坊", Rect2(22,12,240,32), 23)
	var legend := label("青色 选中   绿色 可合成   金色 MAX", Rect2(280,17,600,26), 13)
	legend.add_theme_color_override("font_color",host.MUTED)
	add_button("关闭", Rect2(1220,12,94,34), func():hide())
	add_button("按ID排序", Rect2(22,54,138,32), func():game.sort_jewels(false))
	add_button("等级从高到低", Rect2(168,54,150,32), func():game.sort_jewels(true))
	add_button("清空选择", Rect2(326,54,120,32), func():selected.clear();inspected_socket=-1;result_token=-1;bulk_summary="";refresh())
	summary = label("", Rect2(460,54,232,32), 14)
	combine_all=add_button("一键合成",Rect2(708,54,158,32),combine_all_selected)
	combine_all.tooltip_text="自动连续合成背包宝石；跳过已镶嵌、锁定、禁用及满级宝石"
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22,98)
	scroll.size = Vector2(844,258)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	inventory_list = GridContainer.new()
	inventory_list.columns = 6
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("h_separation",6)
	inventory_list.add_theme_constant_override("v_separation",6)
	scroll.add_child(inventory_list)
	empty_hint = label("击败敌人获得碎片\n收集足够碎片，将自动生成宝石",Rect2(100,174,640,65),19)
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var divider := ColorRect.new()
	divider.position=Vector2(879,54)
	divider.size=Vector2(1,452)
	divider.color=host.LINE
	divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(divider)
	detail_icon=TextureRect.new()
	detail_icon.position=Vector2(894,57)
	detail_icon.size=Vector2(48,48)
	detail_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(detail_icon)
	detail_heading=label("宝石详情",Rect2(956,60,350,42),21)
	detail_scroll=ScrollContainer.new()
	detail_scroll.position=Vector2(894,118)
	detail_scroll.size=Vector2(414,275)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	detail_scroll.add_child(content)
	detail=label("",Rect2(0,0,394,0),15)
	detail.reparent(content,false)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.clip_text=false
	detail.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	detail.custom_minimum_size.x=390
	preview=label("",Rect2(0,0,394,0),15)
	preview.reparent(content,false)
	preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview.clip_text=false
	preview.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	preview.custom_minimum_size.x=390
	preview.add_theme_color_override("font_color",Color("95ddc7"))
	combine = add_button("合成", Rect2(894,408,198,40), combine_selected)
	compose = add_button("分解宝石", Rect2(894,408,198,40), request_compose)
	socket_action=add_button("镶嵌",Rect2(1104,408,202,40),func():operate_socket(target_socket if not selected.is_empty() else inspected_socket))
	apply_palette(compose,"danger")
	feedback=label("选择宝石开始强化",Rect2(894,460,412,54),14)
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_color_override("font_color",host.CYAN)
	fragments = label("", Rect2(22,364,844,40), 13)
	fragments.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_title = label("", Rect2(22,408,844,30), 15)
	socket_row = HBoxContainer.new()
	socket_row.position = Vector2(22,445)
	socket_row.size = Vector2(844,62)
	socket_row.add_theme_constant_override("separation",8)
	add_child(socket_row)
	metrics_timer=Timer.new()
	metrics_timer.wait_time=1.0
	metrics_timer.timeout.connect(refresh_metrics)
	add_child(metrics_timer)
	compose_dialog=ConfirmationDialog.new()
	compose_dialog.title="分解满级宝石"
	compose_dialog.ok_button_text="确认分解"
	compose_dialog.cancel_button_text="保留宝石"
	# Let the dialog finish restoring focus before the consumed gem/action disappears.
	compose_dialog.confirmed.connect(compose_selected,CONNECT_DEFERRED)
	compose_dialog.canceled.connect(func():pending_compose=-1)
	host.add_child(compose_dialog)
	create_effect_pool()
	visibility_changed.connect(on_visibility_changed)
	hide()
	set_process(false)

func label(value: String, rect: Rect2, font_size: int) -> Label:
	return host.equipment_card_label(self, value, rect, font_size, host.INK)

func add_button(value: String, rect: Rect2, action: Callable) -> Button:
	var control: Button = host.button(value, rect, action)
	control.reparent(self, false)
	return control

func open(for_category := "", index := -1) -> void:
	if not game.jewels_unlocked():
		return
	category = for_category
	equipment_index = index
	equipment_identity = game.slot_entry(category, index) if index >= 0 else {}
	selected.clear()
	bulk_summary=""
	inspected_socket=-1
	target_socket=-1
	result_token=-1
	show()
	host.set_ui_value(feedback,"text","选满同级宝石合成，或选择插槽查看镶嵌效果")
	refresh()
	animate(self,"modulate",Color(1,1,1,0.35),Color.WHITE,0.16)

func select_cell(index: int) -> void:
	if index >= game.profile.jewels.size():
		return
	var token := int(game.profile.jewels[index].token)
	bulk_summary=""
	new_tokens.erase(token)
	inspected_socket=-1
	target_socket=-1
	result_token=-1
	if selected.has(token):
		selected.erase(token)
	elif equipment_index >= 0:
		selected = [token]
	else:
		var gem := game.jewel_inventory(token)
		var first := game.jewel_inventory(int(selected[0])) if not selected.is_empty() else {}
		if not first.is_empty() and (gem.id != first.id or gem.level != first.level):
			selected.clear()
		if selected.size() < maxi(1, int(game.db.config.get("jewelCombine", 0))):
			selected.append(token)
	refresh()
	pulse(gem_buttons.get(token),host.CYAN)

func gem_name(gem: Dictionary) -> String:
	return "%s Lv.%d" % [str(game.db.jewel(str(gem.id)).get("name", gem.id)), int(gem.level)]

func gem_description(gem: Dictionary) -> String:
	var id := str(gem.id)
	var description := str(game.db.jewel(id).get("des", ""))
	var regex := RegEx.new()
	regex.compile("\\{([^{}]+)\\}")
	for match_value in regex.search_all(description):
		var block := match_value.get_string(1).split(",")
		var expression := block[0].replace("等级", str(int(gem.level)))
		for n in [2,4,5,6]:
			expression = expression.replace("para%d" % n, str(game.db.jewel_parameter(id,n)))
		var counter := "武器攻击次数" if expression.contains("武器攻击次数") else "承受攻击次数"
		if expression.contains(counter):
			var entry := game.slot_entry(category,equipment_index) if equipment_index >= 0 else {}
			var count := maxi(1,int(entry.get("attacks" if counter == "武器攻击次数" else "hits",0)))
			expression = expression.replace("log10(%s)" % counter, str(log(float(count))/log(10.0)))
		var arithmetic := Expression.new()
		var allowed := RegEx.new()
		allowed.compile("^[0-9.eE+*/() -]+$")
		var value := "？"
		if allowed.search(expression) != null and arithmetic.parse(expression) == OK:
			var result = arithmetic.execute([],null,false)
			if not arithmetic.has_execute_failed() and (result is int or result is float):
				value = ("%s%%" % host.number(roundf(float(result)*100))) if block.size()>1 else host.number(float(result))
		description = description.replace(match_value.get_string(),value)
	return description

func refresh() -> void:
	if not visible:
		return
	if not game.jewels_unlocked():
		hide()
		return
	selected = selected.filter(func(token):return not game.jewel_inventory(int(token)).is_empty())
	var counts := inventory_counts()
	var eligible_counts := inventory_counts(true)
	apply_palette(combine_all,"ready" if eligible_counts.values().any(func(count):return game.jewel_combine_count()>=2 and count>=game.jewel_combine_count()) else "normal")
	var live_tokens := {}
	cells.clear()
	for gem in game.profile.jewels:
		var token := int(gem.token)
		live_tokens[token] = true
		if not gem_buttons.has(token):
			var control := add_button("",Rect2(0,0,132,64),func():
				var current := game.jewel_inventory(token)
				if not current.is_empty():select_cell(game.profile.jewels.find(current)))
			control.custom_minimum_size = Vector2(132,64)
			control.clip_text = true
			control.add_theme_font_size_override("font_size",12)
			control.alignment = HORIZONTAL_ALIGNMENT_LEFT
			control.add_theme_constant_override("icon_max_width",32)
			control.expand_icon = true
			control.reparent(inventory_list,false)
			gem_buttons[token] = control
		var cell: Button = gem_buttons[token]
		if cell.get_index() != cells.size():
			inventory_list.move_child(cell,cells.size())
		cells.append(cell)
		var maxed := int(gem.level) >= game.db.jewel_max_level(str(gem.id))
		var ready := game.jewel_combine_eligible(gem) and game.jewel_combine_count()>=2 and int(eligible_counts.get(gem_key(gem),0)) >= game.jewel_combine_count()
		var compatible := equipment_index < 0 or game.jewel_allowed(str(gem.id),category)
		var protected: bool=gem.get("locked",false) or gem.get("disabled",false)
		var visual := "selected" if selected.has(token) else "blocked" if protected or not compatible else "max" if maxed else "ready" if ready else "new" if new_tokens.has(token) else "normal"
		apply_palette(cell,visual)
		var badge := "  MAX" if maxed else "  ↑" if ready else ""
		if new_tokens.has(token):badge+=" 新"
		host.set_ui_value(cell,"text",gem_name(gem).replace(" Lv.","\nLv.")+badge)
		host.set_ui_value(cell,"icon",gem_texture(str(gem.id)))
		host.set_ui_value(cell,"tooltip_text",gem_name(gem)+"\n"+gem_description(gem)+"\n未镶嵌 · "+("已锁定或禁用，不参与合成" if protected else "槽位不兼容" if not compatible else "已达到最高等级" if maxed else "可合成 ↑" if ready else "同级数量不足"))
	for token in gem_buttons.keys():
		if not live_tokens.has(token):
			var removed: Button = gem_buttons[token]
			inventory_list.remove_child(removed)
			removed.queue_free()
			gem_buttons.erase(token)
	# Keep empty visual slots without a capacity counter; only changed slots mutate.
	var empty_count := maxi(0,mini(BattleGame.JEWEL_CAPACITY,maxi(30,int(ceilf(cells.size()/6.0))*6))-cells.size())
	while empty_cells.size() > empty_count:
		var removed: Button = empty_cells.pop_back()
		inventory_list.remove_child(removed)
		removed.queue_free()
	while empty_cells.size() < empty_count:
		var empty := add_button("",Rect2(0,0,132,54),func():pass)
		empty.custom_minimum_size = Vector2(132,64)
		empty.disabled = true
		empty.text="◇"
		empty.tooltip_text="空格 · 收集碎片自动生成宝石"
		apply_palette(empty,"empty")
		empty.reparent(inventory_list,false)
		empty_cells.append(empty)
	host.set_ui_value(empty_hint,"visible",cells.is_empty())
	refresh_sockets()
	refresh_detail(counts)
	refresh_metrics()

func refresh_sockets() -> void:
	var entry := game.slot_entry(category,equipment_index) if equipment_index >= 0 else {}
	if not is_same(entry,equipment_identity) and equipment_index >= 0:
		category = ""
		equipment_index = -1
		entry = {}
	var title := "装备镶嵌：请从装备卡的「镶嵌」按钮进入"
	if not entry.is_empty():
		title = "%s · Lv.%d · %d插槽  /  选宝石镶嵌，选槽位查看" % [host.NAMES.get(str(entry.key),entry.key),int(entry.level),game.equipment_socket_count(entry)]
	host.set_ui_value(equipment_title,"text",title)
	var sockets: Array = entry.get("sockets",[])
	var count := maxi(game.equipment_socket_count(entry),sockets.size())
	while socket_buttons.size() > count:
		var removed: Button = socket_buttons.pop_back()
		socket_row.remove_child(removed)
		removed.queue_free()
	while socket_buttons.size() < count:
		var index := socket_buttons.size()
		var control := add_button("", Rect2(0,0,180,55),func():
			if not selected.is_empty():operate_socket(index)
			else:
				bulk_summary=""
				inspected_socket=index
				result_token=-1
				refresh_sockets()
				refresh_detail())
		control.mouse_entered.connect(func():
			if not selected.is_empty():
				target_socket=index
				refresh_detail())
		control.custom_minimum_size = Vector2(180,55)
		control.expand_icon = true
		control.add_theme_constant_override("icon_max_width",28)
		control.add_theme_font_size_override("font_size",14)
		control.reparent(socket_row,false)
		socket_buttons.append(control)
	for i in count:
		var gem: Dictionary = sockets[i] if i < sockets.size() else {}
		var error := socket_error(i)
		apply_palette(socket_buttons[i],"selected" if inspected_socket==i and selected.is_empty() else "ready" if not selected.is_empty() and error.is_empty() else "blocked" if not error.is_empty() else "installed" if not gem.is_empty() else "empty")
		host.set_ui_value(socket_buttons[i],"text","插槽 %d · 镶嵌" % (i+1) if gem.is_empty() else gem_name(gem)+("\n已镶嵌 · 替换" if not selected.is_empty() else "\n已镶嵌 · 查看"))
		host.set_ui_value(socket_buttons[i],"icon",null if gem.is_empty() else gem_texture(str(gem.id)))
		host.set_ui_value(socket_buttons[i],"tooltip_text",(gem_name(gem)+"\n"+gem_description(gem)+"\n已镶嵌\n" if not gem.is_empty() else "")+(error if not error.is_empty() else "点击替换" if not selected.is_empty() and not gem.is_empty() else "点击镶嵌" if not selected.is_empty() else "查看详情 / 卸下"))
		host.set_ui_value(socket_buttons[i],"disabled",not error.is_empty() if not selected.is_empty() else gem.is_empty())

func operate_socket(index: int) -> void:
	var entry := game.slot_entry(category,equipment_index)
	if index < 0 or not is_same(entry,equipment_identity):
		refresh()
		return
	var sockets: Array = entry.get("sockets",[])
	var gem: Dictionary = sockets[index] if index < sockets.size() else {}
	var error := socket_error(index)
	if not error.is_empty():
		show_feedback(error,false)
		return
	var destination := control_center(socket_buttons[index])
	var old_texture: Texture2D = null if gem.is_empty() else gem_texture(str(gem.id))
	var old_token := int(gem.get("token",-1))
	var before := entry.duplicate(true)
	acting=true
	if not selected.is_empty():
		var token := int(selected[0])
		var incoming := game.jewel_inventory(token)
		var origin := bag_center(token)
		var texture := gem_texture(str(incoming.id))
		if game.socket_jewel(category,equipment_index,index,token):
			inspected_socket=index
			fly(texture,origin,destination)
			if old_token >= 0:fly(old_texture,destination,bag_center(old_token))
			show_feedback(("镶嵌成功" if gem.is_empty() else "替换成功 · 旧宝石已返回背包")+"\n"+stat_comparison(before,entry))
		else:
			show_feedback("背包已满或槽位不可用",false)
	elif not gem.is_empty():
		if not game.unsocket_jewel(category,equipment_index,index,int(gem.token)):
			show_feedback("宝石背包已满或插槽已变化",false)
		else:
			inspected_socket=-1
			result_token=old_token
			fly(old_texture,destination,bag_center(old_token))
			show_feedback("卸下成功 · 宝石已返回背包\n"+stat_comparison(before,entry))
	acting=false
	refresh()
	pulse(socket_buttons[index],host.CYAN)
	if old_token >= 0:pulse(gem_buttons.get(old_token),host.CYAN)

func gem_key(gem: Dictionary) -> String:
	return "%s:%d" % [gem.id,int(gem.level)]

func inventory_counts(eligible_only := false) -> Dictionary:
	var counts := {}
	for gem in game.profile.jewels:
		if eligible_only and not game.jewel_combine_eligible(gem):continue
		var key := gem_key(gem)
		counts[key]=int(counts.get(key,0))+1
	return counts

func socket_gem(index: int) -> Dictionary:
	var sockets: Array=game.slot_entry(category,equipment_index).get("sockets",[])
	return sockets[index] if index >= 0 and index < sockets.size() else {}

func socket_error(index: int) -> String:
	var entry := game.slot_entry(category,equipment_index)
	if entry.is_empty() or index < 0:return "请先选择装备插槽"
	var installed := socket_gem(index)
	if not selected.is_empty():
		if index >= game.equipment_socket_count(entry):return "插槽尚未解锁"
		var error := game.jewel_socket_error(category,equipment_index,int(selected[0]),index)
		if not error.is_empty():return error
	elif installed.is_empty():return "请先选择背包宝石"
	if not installed.is_empty() and game.profile.jewels.size() >= BattleGame.JEWEL_CAPACITY:
		return "背包已满 · 请先腾出位置"
	return ""

func refresh_detail(counts: Dictionary = {}) -> void:
	if not visible:return
	if counts.is_empty():counts=inventory_counts()
	var first := game.jewel_inventory(int(selected[0])) if not selected.is_empty() else socket_gem(inspected_socket) if inspected_socket >= 0 else game.jewel_inventory(result_token)
	var installed := inspected_socket >= 0 and selected.is_empty() and not first.is_empty()
	var required := int(game.db.config.get("jewelCombine",0))
	var maxed := not first.is_empty() and int(first.level) >= game.db.jewel_max_level(str(first.id))
	var description := "点击宝石查看当前效果与升级预览。\n\n绿色边框 ↑ 表示同级数量足够合成。\n选满%d颗同ID同等级宝石后即可合成。\n\n从装备卡进入工坊可管理镶嵌。" % required
	var comparison := ""
	var heading := "选择一颗宝石"
	var can_combine := game.can_combine_jewels(selected)
	var combine_reason := "已达到最高等级" if maxed else "数量不足 · 请选满%d颗同ID同等级宝石（已选%d）" % [required,selected.size()]
	if not first.is_empty() and (first.get("locked",false) or first.get("disabled",false)):combine_reason="已锁定或禁用，不参与合成"
	if not first.is_empty():
		heading=gem_name(first)+(" · MAX" if maxed else "")
		description="当前效果\n"+gem_description(first)+"\n\n"+("已镶嵌 · 插槽%d" % (inspected_socket+1) if installed else "未镶嵌")+" · 背包同级持有%d颗" % int(counts.get(gem_key(first),0))
		if maxed:
			description+="\n已达到最高等级 · MAX"
			if not installed:description+="\n分解返还：宝石碎片 +%.2f" % game.jewel_fragment_amount(game.jewel_compose_reward(first))
		elif not installed:
			var next := first.duplicate()
			next.level=int(first.level)+1
			comparison="下一等级 · Lv.%d\n%s\n\n合成需求 %d颗 · 已选 %d颗" % [int(next.level),gem_description(next),required,selected.size()]
			if not can_combine:comparison+="\n"+combine_reason
	if not selected.is_empty() and equipment_index >= 0:
		var entry := game.slot_entry(category,equipment_index)
		if target_socket < 0 or target_socket >= game.equipment_socket_count(entry):
			target_socket=-1
			# Prefer a compatible empty socket, then a compatible replacement.
			for empty_only in [true,false]:
				for i in game.equipment_socket_count(entry):
					if socket_error(i).is_empty() and (not empty_only or socket_gem(i).is_empty()):
						target_socket=i
						break
				if target_socket >= 0:break
			if target_socket < 0 and game.equipment_socket_count(entry)>0:target_socket=0
		var old := socket_gem(target_socket)
		var error := socket_error(target_socket)
		comparison="插槽 %d · %s\n" % [target_socket+1,"镶嵌预览" if old.is_empty() else "替换预览"]
		comparison+=(preview_socket(first,target_socket) if error.is_empty() else error)+"\n\n"
		if not old.is_empty():comparison+="当前："+gem_name(old)+"\n"+gem_description(old)+"\n\n"
		comparison+="放入："+gem_name(first)+"（效果见上方）"
	if installed:
		comparison="卸下预览\n"+preview_socket({},inspected_socket)+"\n\n卸下后完整返回背包。"
	if not bulk_summary.is_empty():
		heading="一键合成完成"
		description=bulk_summary
		comparison=bulk_rewards
	host.set_ui_value(summary,"text","合成台 %d / %d%s" % [selected.size(),required," · 可以合成 ↑" if can_combine else " · 选择同级宝石"])
	host.set_ui_value(detail_heading,"text",heading)
	host.set_ui_value(detail_icon,"texture",null if first.is_empty() else gem_texture(str(first.id)))
	host.set_ui_value(detail,"text",description)
	host.set_ui_value(preview,"text",comparison)
	var preview_color: Color=host.ORANGE if comparison.contains("(-") else Color("95ddc7")
	if preview.get_theme_color("font_color")!=preview_color:preview.add_theme_color_override("font_color",preview_color)
	host.set_ui_value(combine,"visible",bulk_summary.is_empty() and not first.is_empty() and not maxed and not installed)
	host.set_ui_value(combine,"disabled",not can_combine)
	host.set_ui_value(combine,"tooltip_text","合成后获得下一等级宝石" if can_combine else combine_reason)
	apply_palette(combine,"ready" if can_combine else "normal")
	host.set_ui_value(compose,"visible",bulk_summary.is_empty() and not first.is_empty() and maxed and not installed)
	host.set_ui_value(compose,"disabled",selected.size()!=1 or game.jewel_compose_reward(first)<=0)
	host.set_ui_value(compose,"tooltip_text","永久消耗此宝石，返还详情中所示碎片；需要确认" if not compose.disabled else "请选择一颗可分解的满级宝石")
	var show_socket := bulk_summary.is_empty() and equipment_index >= 0 and (not selected.is_empty() or installed)
	var reason := socket_error(target_socket if not selected.is_empty() else inspected_socket)
	host.set_ui_value(socket_action,"visible",show_socket)
	host.set_ui_value(socket_action,"disabled",not show_socket or not reason.is_empty())
	host.set_ui_value(socket_action,"text","卸下" if installed else "镶嵌" if socket_gem(target_socket).is_empty() else "替换")
	host.set_ui_value(socket_action,"tooltip_text",reason if not reason.is_empty() else "将宝石返回背包" if installed else "应用上方预览到目标插槽")
	apply_palette(socket_action,"ready" if not socket_action.disabled else "normal")

func preview_socket(gem: Dictionary, index: int) -> String:
	var entry := game.slot_entry(category,equipment_index)
	if entry.is_empty() or index < 0:return ""
	var copy := entry.duplicate(true)
	var sockets: Array=copy.get("sockets",[])
	while sockets.size()<=index:sockets.append({})
	sockets[index]=gem.duplicate()
	copy.sockets=sockets
	return stat_comparison(entry,copy)

func stat_comparison(before: Dictionary, after: Dictionary) -> String:
	var old := game.jewel_equipment_stat(before)
	var value := game.jewel_equipment_stat(after)
	var lines: PackedStringArray=[]
	if not is_equal_approx(old,value):
		lines.append("%s  %s → %s  (%+.0f)" % ["容量" if category=="defence" else "单次伤害",host.number(old),host.number(value),value-old])
	if category=="weapons":
		var old_crit := game.jewel_critical(before)
		var new_crit := game.jewel_critical(after)
		if not is_equal_approx(old_crit.x,new_crit.x):
			lines.append("暴击率  %.2f%% → %.2f%%  (%+.2f%%)" % [old_crit.x*100,new_crit.x*100,(new_crit.x-old_crit.x)*100])
	return "\n".join(lines) if not lines.is_empty() else "基础数值不变 · 特殊效果见宝石说明"

func refresh_metrics() -> void:
	if not visible:return
	var entry := game.slot_entry(category,equipment_index)
	if equipment_index >= 0 and not is_same(entry,equipment_identity):
		refresh()
		return
	var state: Array=[game.profile.jewelFragments,game.resource_minute_total("jewel"),game.jewel_create_cost(),game.jewel_ratio(),game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY,entry.get("attacks",0),entry.get("hits",0),entry.get("level",0)]
	if metric_state==state:return
	var changed: bool = not metric_state.is_empty() and metric_state[0]!=state[0]
	metric_state=state
	var text := "%s宝石碎片：%.2f   /   每分钟宝石碎片获取量：%.2f\n" % ["背包已满 · " if state[4] else "",state[0],state[1]]
	text+="每%.0f碎片生成随机宝石 · 当前倍率 %.2f%s" % [state[2],state[3]," · 暂停生成，碎片已保留" if state[4] else " · 最近60秒实际收入"]
	host.set_ui_value(fragments,"text",text)
	if changed:pulse(fragments,host.ORANGE if state[4] else host.CYAN)
	refresh_detail()

func gem_texture(id: String) -> Texture2D:
	if not textures.has(id):
		var path := str(game.db.jewel(id).get("image","res://assets/jewels/%s.svg" % id))
		textures[id] = load(path) if ResourceLoader.exists(path) else null
	return textures[id]

func create_palettes() -> void:
	var colors := {"normal":host.LINE,"selected":host.CYAN,"ready":Color("77d6ad"),"installed":Color("7ca9ea"),"max":host.ORANGE,"new":host.PURPLE,"blocked":Color("445265"),"empty":Color("263447"),"danger":Color("ec9c85")}
	for key in colors:
		var accent: Color=colors[key]
		var fill: Color=host.PANEL.lerp(accent,0.17 if key in ["selected","ready","new","danger"] else 0.04)
		var normal: StyleBoxFlat=host.style(fill,accent)
		normal.set_border_width_all(2 if key=="selected" else 1)
		if key in ["selected","ready","new"]:
			normal.shadow_color=Color(accent,0.18)
			normal.shadow_size=3
		palettes[key]={"normal":normal,"hover":host.style(fill.lightened(0.13),accent.lightened(0.3)),"pressed":host.style(fill.lightened(0.25),Color.WHITE),"disabled":host.style(Color("101722"),Color("33404f")),"focus":host.style(Color(0,0,0,0),accent)}

func apply_palette(control: Button, key: String) -> void:
	if control.get_meta("jewel_palette","")==key:return
	control.set_meta("jewel_palette",key)
	for state in palettes[key]:control.add_theme_stylebox_override(state,palettes[key][state])
	control.add_theme_color_override("font_color",host.MUTED if key in ["blocked","empty"] else host.INK)
	control.add_theme_color_override("font_disabled_color",Color("748396"))

func create_effect_pool() -> void:
	effect_layer=Control.new()
	effect_layer.name="JewelFeedback"
	effect_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	effect_layer.z_index=100
	host.ui.add_child(effect_layer)
	for i in 8:
		var icon:=TextureRect.new()
		icon.size=Vector2(32,32)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.hide()
		effect_layer.add_child(icon)
		flights.append(icon)

func control_center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func bag_center(token: int) -> Vector2:
	var control: Control=gem_buttons.get(token)
	var scroll: Control=inventory_list.get_parent()
	if is_instance_valid(control) and scroll.get_global_rect().encloses(control.get_global_rect()):return control_center(control)
	return control_center(summary)

func fly(texture: Texture2D, origin: Vector2, destination: Vector2) -> void:
	var icon := flights[flight_cursor%flights.size()]
	flight_cursor+=1
	var old: Tween=icon.get_meta("flight") if icon.has_meta("flight") else null
	if old!=null:old.kill()
	icon.texture=texture
	icon.position=origin-Vector2(16,16)
	icon.modulate=Color.WHITE
	icon.show()
	var tween:=icon.create_tween()
	icon.set_meta("flight",tween)
	tween.tween_property(icon,"position",destination-Vector2(16,16),0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon,"modulate:a",0.0,0.1).set_delay(0.18)
	tween.tween_callback(icon.hide)

func animate(control: Control, property: String, from: Variant, to: Variant, duration: float) -> void:
	if not is_instance_valid(control):return
	var key := "%s:%s" % [control.get_instance_id(),property]
	if animations.has(key):animations[key].tween.kill()
	control.set(property,from)
	var tween := control.create_tween()
	animations[key]={"control":control,"property":property,"rest":to,"tween":tween}
	tween.tween_property(control,property,to,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():animations.erase(key))

func pulse(control: Control, color: Color) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():return
	animate(control,"self_modulate",Color(1+color.r*0.4,1+color.g*0.4,1+color.b*0.4),Color.WHITE,0.3)

func on_visibility_changed() -> void:
	if not is_instance_valid(metrics_timer):return
	if visible:
		metrics_timer.start()
		return
	metrics_timer.stop()
	if compose_dialog.visible:compose_dialog.hide()
	pending_compose=-1
	for item in animations.values():
		item.tween.kill()
		if is_instance_valid(item.control):item.control.set(item.property,item.rest)
	animations.clear()
	for icon in flights:
		var tween: Tween=icon.get_meta("flight") if icon.has_meta("flight") else null
		if tween!=null:tween.kill()
		icon.hide()

func _exit_tree() -> void:
	if is_instance_valid(effect_layer):effect_layer.queue_free()
	if is_instance_valid(compose_dialog):compose_dialog.queue_free()

func inventory_changed() -> void:
	bulk_summary=""
	for key in animations.keys():
		if not is_instance_valid(animations[key].control):
			animations[key].tween.kill()
			animations.erase(key)
	generated_count=0
	var live := {}
	for gem in game.profile.jewels:
		live[int(gem.token)]=true
		if int(gem.token)>observed_serial:
			new_tokens[int(gem.token)]=true
			generated_count+=1
	for token in new_tokens.keys():
		if not live.has(token):new_tokens.erase(token)
	observed_serial=game.jewel_serial
	refresh()
	if generated_count>0 and not acting:
		var text := "获得宝石 ×%d · 已放入背包" % generated_count
		if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY:text+=" · 背包已满，余下碎片保留"
		show_feedback(text)
		var shown:=0
		for token in new_tokens:
			var control: Control=gem_buttons.get(token)
			if visible and is_instance_valid(control) and inventory_list.get_parent().get_global_rect().intersects(control.get_global_rect()):
				pulse(control,host.PURPLE)
				shown+=1
				if shown>=6:break

func pickup_feedback(info: Dictionary) -> void:
	var tab_bar: TabBar=host.equipment_tabs.get_tab_bar()
	var target: Vector2 = control_center(fragments) if visible else tab_bar.global_position+tab_bar.get_tab_rect(5).get_center()
	fly(gem_texture("1"),Vector2(info.x,info.y),target)
	var text := "宝石碎片 +%.2f" % float(info.amount)
	if generated_count>0:text+=" · 生成宝石 ×%d" % generated_count
	if game.profile.jewels.size()>=BattleGame.JEWEL_CAPACITY:text+=" · 背包已满，碎片已保留"
	show_feedback(text)
	if visible:pulse(fragments,host.CYAN)

func show_feedback(text: String, success := true) -> void:
	host.toast(text)
	host.beep(880 if success else 180)
	if visible:
		host.set_ui_value(feedback,"text",text)
		host.set_ui_value(feedback,"tooltip_text",text)
		pulse(feedback,host.CYAN if success else host.ORANGE)

func combine_selected() -> void:
	if not game.can_combine_jewels(selected):
		show_feedback(combine.tooltip_text,false)
		return
	var gem := game.jewel_inventory(int(selected[0])).duplicate()
	var origins: Array[Vector2]=[]
	for token in selected:
		if origins.size()<8:origins.append(bag_center(int(token)))
	var serial := game.jewel_serial
	acting=true
	var ok := game.combine_jewels(selected.duplicate())
	acting=false
	if not ok:return
	for created in game.profile.jewels:
		if int(created.token)>serial and created.id==gem.id and int(created.level)==int(gem.level)+1:
			result_token=int(created.token)
			break
	refresh_detail()
	for origin in origins:fly(gem_texture(str(gem.id)),origin,control_center(detail_icon))
	pulse(detail_icon,host.ORANGE)
	pulse(gem_buttons.get(result_token),host.ORANGE)
	pulse(detail_heading,host.ORANGE)
	show_feedback("合成成功 · Lv.%d → Lv.%d\n新宝石已入背包，提升效果见上方" % [int(gem.level),int(gem.level)+1])

func combine_all_selected() -> void:
	if acting:return
	acting=true
	var result := game.combine_all_jewels()
	acting=false
	if not result.ok:
		show_feedback(str(result.message),false)
		return
	if int(result.count)==0:
		show_feedback("当前没有可合成宝石",false)
		return
	bulk_summary="合成 %d 次 · 累计消耗 %d 颗\n（消耗包含继续参与合成的中间产物）" % [int(result.count),int(result.consumed)]
	var lines: PackedStringArray=["最终获得"]
	for reward in result.results:
		lines.append("%s ×%d" % [gem_name(reward),int(reward.count)])
	bulk_rewards="\n".join(lines)
	result_token=-1
	for token in result.tokens:
		var gem := game.jewel_inventory(int(token))
		if result_token<0 or int(gem.level)>int(game.jewel_inventory(result_token).level):result_token=int(token)
		pulse(gem_buttons.get(token),host.ORANGE)
	refresh_detail()
	detail_scroll.scroll_vertical=0
	show_feedback("合成 %d 次 · 累计消耗 %d 颗\n%s" % [int(result.count),int(result.consumed),"、".join(lines.slice(1))])
	pulse(detail_icon,host.ORANGE)

func request_compose() -> void:
	if selected.size()!=1:return
	var gem := game.jewel_inventory(int(selected[0]))
	if gem.is_empty():return
	pending_compose=int(gem.token)
	compose_dialog.dialog_text="永久分解 %s？\n返还宝石碎片 +%.2f\n满足数量的碎片会自动生成新宝石。" % [gem_name(gem),game.jewel_fragment_amount(game.jewel_compose_reward(gem))]
	compose_dialog.popup_centered(Vector2i(480,180))

func compose_selected() -> void:
	var token := pending_compose
	pending_compose=-1
	var gem := game.jewel_inventory(token)
	if gem.is_empty():return
	var reward := game.jewel_fragment_amount(game.jewel_compose_reward(gem))
	var origin := bag_center(token)
	acting=true
	var ok := game.decompose_jewel(token)
	acting=false
	if not ok:
		show_feedback("分解条件已变化，宝石保留",false)
		return
	fly(gem_texture(str(gem.id)),origin,control_center(fragments))
	show_feedback("分解成功 · 碎片 +%.2f%s" % [reward," · 生成%d颗宝石" % generated_count if generated_count>0 else ""])
	pulse(fragments,host.ORANGE)
