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
var socket_row: HBoxContainer
var summary: Label
var detail: Label
var fragments: Label
var equipment_title: Label
var combine: Button
var compose: Button

func setup(owner_node: Node) -> void:
	host = owner_node
	game = host.game
	position = Vector2(50, 65)
	size = Vector2(1340, 535)
	add_theme_stylebox_override("panel", host.style(host.PANEL, host.CYAN))
	add_theme_font_override("font", host.font)
	label("宝石工坊 · 30格背包", Rect2(22,12,600,32), 23)
	add_button("关闭", Rect2(1220,12,94,34), func():hide())
	add_button("按ID排序", Rect2(22,54,138,32), func():game.sort_jewels(false))
	add_button("等级从高到低", Rect2(168,54,150,32), func():game.sort_jewels(true))
	add_button("清空合成台", Rect2(326,54,140,32), func():selected.clear();refresh())
	summary = label("", Rect2(480,54,820,32), 15)
	for i in 30:
		var cell := add_button("", Rect2(22+(i%6)*142,98+(i/6)*61,134,54), func():select_cell(i))
		cell.add_theme_font_size_override("font_size", 14)
		cells.append(cell)
	detail = label("", Rect2(890,96,420,165), 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combine = add_button("合成", Rect2(890,268,202,36), func():
		if not game.combine_jewels(selected.duplicate()):
			host.toast("合成条件不足或宝石已被移动")
		refresh())
	compose = add_button("满级分解", Rect2(1104,268,202,36), func():
		if selected.size() == 1:
			game.decompose_jewel(int(selected[0]))
		refresh())
	fragments = label("", Rect2(890,316,420,202), 13)
	fragments.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_title = label("", Rect2(22,408,844,30), 15)
	socket_row = HBoxContainer.new()
	socket_row.position = Vector2(22,445)
	socket_row.size = Vector2(844,62)
	socket_row.add_theme_constant_override("separation",8)
	add_child(socket_row)
	visibility_changed.connect(func():set_process(visible))
	hide()
	set_process(false)

func label(value: String, rect: Rect2, font_size: int) -> Label:
	return host.equipment_card_label(self, value, rect, font_size, host.INK)

func add_button(value: String, rect: Rect2, action: Callable) -> Button:
	var control: Button = host.button(value, rect, action)
	control.reparent(self, false)
	return control

func open(for_category := "", index := -1) -> void:
	category = for_category
	equipment_index = index
	equipment_identity = game.slot_entry(category, index) if index >= 0 else {}
	selected.clear()
	show()
	refresh()

func _process(_dt: float) -> void:
	refresh()

func select_cell(index: int) -> void:
	if index >= game.profile.jewels.size():
		return
	var token := int(game.profile.jewels[index].token)
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
	for i in cells.size():
		var gem: Dictionary = game.profile.jewels[i] if i < game.profile.jewels.size() else {}
		var text := "空格 %d" % (i+1) if gem.is_empty() else gem_name(gem)
		if not gem.is_empty() and selected.has(int(gem.token)):
			text = "✓ " + text
		host.set_ui_value(cells[i],"text",text)
		host.set_ui_value(cells[i],"disabled",gem.is_empty())
		host.set_ui_value(cells[i],"tooltip_text","" if gem.is_empty() else gem_description(gem))
	var required := int(game.db.config.get("jewelCombine",0))
	host.set_ui_value(summary,"text","背包 %d/30 · 合成台 %d/%d · 点击同ID同等级宝石放入" % [game.profile.jewels.size(),selected.size(),required])
	var first := game.jewel_inventory(int(selected[0])) if not selected.is_empty() else {}
	var description := "选择宝石查看效果。\n打开装备卡上的「镶嵌」可管理插槽。"
	if not first.is_empty():
		var maxed := int(first.level) == game.db.jewel_max_level(str(first.id))
		description = gem_name(first)+"\n"+gem_description(first)+("\n已满级 · 可分解" if maxed else "\n合成结果：Lv.%d（需%d颗）" % [int(first.level)+1,required])
		if maxed and game.jewel_compose_reward().is_empty():
			description += "\n分解未配置：缺少有效 jewelCompose"
		elif maxed:
			description += "\n分解获得：" + host.cost_text(game.jewel_compose_reward())
		if equipment_index >= 0:
			var error := game.jewel_socket_error(category,equipment_index,int(first.token))
			description += "\n"+(error if not error.is_empty() else "点击空插槽镶嵌；点击已镶嵌宝石卸下")
	host.set_ui_value(detail,"text",description)
	host.set_ui_value(detail,"tooltip_text",description)
	host.set_ui_value(combine,"disabled",not game.can_combine_jewels(selected))
	host.set_ui_value(compose,"disabled",selected.size()!=1 or first.is_empty() or int(first.get("level",0)) != game.db.jewel_max_level(str(first.get("id",""))) or game.jewel_compose_reward().is_empty())
	var lines: PackedStringArray = ["碎片（不占格，达到需求自动生成）"]
	var fragments_line := ""
	for id in game.db.data.get("jewel",{}):
		var value := "%s  %d / %d" % [game.db.jewel(str(id)).get("name",id),int(game.profile.jewelFragments.get(id,0)),int(game.db.jewel_parameter(str(id),3))]
		if fragments_line.is_empty():
			fragments_line = value
		else:
			lines.append(fragments_line + "    " + value)
			fragments_line = ""
	if not fragments_line.is_empty():
		lines.append(fragments_line)
	host.set_ui_value(fragments,"text","\n".join(lines))
	refresh_sockets()

func refresh_sockets() -> void:
	var entry := game.slot_entry(category,equipment_index) if equipment_index >= 0 else {}
	if not is_same(entry,equipment_identity) and equipment_index >= 0:
		category = ""
		equipment_index = -1
		entry = {}
	var title := "装备镶嵌：请从装备卡的「镶嵌」按钮进入"
	if not entry.is_empty():
		title = "%s · Lv.%d · %d插槽（点击已镶嵌宝石卸下）" % [host.NAMES.get(str(entry.key),entry.key),int(entry.level),game.equipment_socket_count(entry)]
	host.set_ui_value(equipment_title,"text",title)
	var sockets: Array = entry.get("sockets",[])
	var count := maxi(game.equipment_socket_count(entry),sockets.size())
	while socket_buttons.size() > count:
		var removed: Button = socket_buttons.pop_back()
		socket_row.remove_child(removed)
		removed.queue_free()
	while socket_buttons.size() < count:
		var index := socket_buttons.size()
		var control := add_button("", Rect2(0,0,180,55),func():operate_socket(index))
		control.custom_minimum_size = Vector2(180,55)
		control.add_theme_font_size_override("font_size",14)
		control.reparent(socket_row,false)
		socket_buttons.append(control)
	for i in count:
		var gem: Dictionary = sockets[i] if i < sockets.size() else {}
		host.set_ui_value(socket_buttons[i],"text","插槽 %d · 空" % (i+1) if gem.is_empty() else gem_name(gem)+"\n点击卸下")
		host.set_ui_value(socket_buttons[i],"tooltip_text","" if gem.is_empty() else gem_description(gem))
		host.set_ui_value(socket_buttons[i],"disabled",(selected.is_empty() or i >= game.equipment_socket_count(entry)) if gem.is_empty() else game.profile.jewels.size()>=30)

func operate_socket(index: int) -> void:
	var entry := game.slot_entry(category,equipment_index)
	if not is_same(entry,equipment_identity):
		refresh()
		return
	var sockets: Array = entry.get("sockets",[])
	var gem: Dictionary = sockets[index] if index < sockets.size() else {}
	if not gem.is_empty():
		if not game.unsocket_jewel(category,equipment_index,index,int(gem.token)):
			host.toast("宝石背包已满或插槽已变化")
	elif not selected.is_empty():
		var error := game.jewel_socket_error(category,equipment_index,int(selected[0]))
		if not error.is_empty():
			host.toast(error)
		else:
			game.socket_jewel(category,equipment_index,index,int(selected[0]))
	refresh()
