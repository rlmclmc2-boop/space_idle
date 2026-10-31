extends Control
## Equipment owns all prices, admission and receipts; this scene owns only presentation.
signal command_finished(result: Dictionary)
const PlayerText = preload("res://src/ui/player_text.gd")
const NAMES := {"laser": "脉冲炮", "missile": "导弹", "cannon": "舰炮", "longLaser": "长激光", "shield": "护盾", "armour": "装甲", "": "空槽"}
const INK := Color("203f50")
const TEAL := Color("175466")
const CREAM := Color("f3f0df")
const LIGHT := Color("d8ece8")
var _session
var _selected: String = ""
var _candidate: String = ""
var _quantity: int = 1
var _maximum: bool = false
var _dirty: bool = true
var _comparison_dirty: bool = false
var _wallet_dependency: Dictionary = {}
var _clock: float = 0.0
var _ship: String = ""
var _facts: Array = []
var _slot_buttons: Dictionary = {}
var _slot_presentations: Dictionary = {}
var _slot_selections: Dictionary = {}
var _choice_presentations: Dictionary = {}
var _quantity_presentations: Dictionary = {}
var _scene_picture: Array = []
# Bounded presentation-only diagnostics; no state or rules come from these counts.
var presentation_counts := {"refreshes":0,"comparison_reads":0,"slot_fact_reads":0,"cooldown_fact_reads":0,"slots_updated":0,"slot_styles_updated":0,"candidates_updated":0,"quantity_styles_updated":0,"scene_redraw_requests":0,"scene_draws":0,"economy_signals":0,"economy_same_budget":0,"balance_dependency_changes":0,"comparison_dependency_changes":0,"wallet_refreshes":0,"equipment_option_reads":0,"maximum_reads":0}
var _choices: Dictionary = {}
var _quantity_buttons: Array = []
var _catalog: Dictionary
var _weapon_meta: Dictionary
var _textures: Dictionary = {}
var _hull_textures: Dictionary = {}
var _background: Texture2D
var _title: Label
var _wallet: Label
var _current_title: Label
var _current_caption: Label
var _current_value: Label
var _next_value: Label
var _cost: Label
var _purchase: Button
var _install: Button
var _compare: Label
var _comparison_title: Label
var _large_icon: TextureRect
var _feedback: Label
var _switch_state: Label
var _batch_blocker: ColorRect
var _batch: PanelContainer
var _batch_quantity: OptionButton
var _batch_results: Label
var _batch_scroll: ScrollContainer
var _batch_submit: Button
var _summary: Label
var _selection_open: bool = false
var _empty_choice: Button
var last_result: Dictionary = {}
var _last_batch_result: Dictionary = {}
var _batch_balance: String = ""
var last_comparison: Dictionary = {}

func _init(session) -> void:
    _session = session
    custom_minimum_size = Vector2(808, 900)
    size = custom_minimum_size
    mouse_filter = Control.MOUSE_FILTER_PASS
    _catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/ships/manifest.json")).hulls
    _weapon_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/fleet_20261019/manifest.json")).weapons
    for key in _catalog: _hull_textures[key] = load(str(_catalog[key].texture))
    for key in _weapon_meta: _textures[key] = load(str(_weapon_meta[key].texture))
    _textures.shield = load("res://assets/ui/equipment/cartoon_shield.svg")
    _textures.armour = load("res://assets/ui/equipment/cartoon_armour.svg")
    _background = load("res://assets/ui/equipment/hangar/hangar-console.png")
    _build()
    _session.equipment.slots_changed.connect(func(_ids): _dirty = true)
    _session.equipment.loadout_changed.connect(func(): _dirty = true)
    _session.equipment.options_changed.connect(func(): _dirty = true)
    _session.campaign_system.ship_changed.connect(func(): _dirty = true)
    _wallet_dependency = _session.economy.budget()
    _session.economy.display_changed.connect(_economy_display_changed)
    _session.equipment.comparison_changed.connect(func():
        presentation_counts.comparison_dependency_changes += 1
        _comparison_dirty = true)

func _economy_display_changed() -> void:
    presentation_counts.economy_signals += 1
    var budget: Dictionary = _session.economy.budget()
    # Economy also notifies marker motion. Its accepted budget is immutable.
    if is_same(budget, _wallet_dependency) or budget == _wallet_dependency:
        _wallet_dependency = budget
        presentation_counts.economy_same_budget += 1
        return
    _wallet_dependency = budget
    presentation_counts.balance_dependency_changes += 1
    _comparison_dirty = true

func _ready() -> void:
    process_priority = 1
    _refresh()

func _label(text: String, rect: Rect2, font_size: int = 16, color: Color = INK) -> Label:
    var label := Label.new()
    label.text = text
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label

func _style(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(width)
    style.set_corner_radius_all(6)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    return style

func _button(text: String, rect: Rect2, action: Callable, dark: bool = false) -> Button:
    var button := Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", CREAM if dark else INK)
    button.add_theme_color_override("font_hover_color", CREAM if dark else INK)
    button.add_theme_color_override("font_pressed_color", CREAM if dark else INK)
    button.add_theme_color_override("font_disabled_color", Color("859795"))
    button.add_theme_stylebox_override("normal", _style(TEAL if dark else CREAM, Color("89aaa9")))
    button.add_theme_stylebox_override("hover", _style(Color("277384") if dark else Color("e4eee5"), Color("75d4d0"), 2))
    button.add_theme_stylebox_override("pressed", _style(Color("123e4c") if dark else Color("cce5dd"), Color("6ed1ca"), 2))
    button.add_theme_stylebox_override("disabled", _style(Color("425c66") if dark else Color("e0e1d7"), Color("9ba9a2")))
    button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), Color("d9ae5d"), 2))
    add_child(button)
    button.pressed.connect(action)
    return button

func _icon(key: String, rect: Rect2, parent: Control = self) -> TextureRect:
    var image := TextureRect.new()
    image.texture = _textures.get(key)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.position = rect.position
    image.size = rect.size
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(image)
    return image

func _build() -> void:
    _label("远航舰桥", Rect2(22, 10, 160, 34), 24)
    _wallet = _label("", Rect2(204, 15, 590, 30), 16)
    _label("战力维护  /  装配", Rect2(24, 52, 380, 28), 15, TEAL)
    _title = _label("装配", Rect2(24, 96, 480, 38), 23)
    _title.add_theme_stylebox_override("normal", _style(Color("f3f0df", 0.93), Color(0,0,0,0)))
    _button("全部装备升级", Rect2(622, 101, 166, 44), _open_batch, true).name = "BatchOpen"
    _summary = _label("", Rect2(26, 559, 754, 24), 13, CREAM)
    _summary.add_theme_stylebox_override("normal", _style(Color("183a49", 0.88), Color(0,0,0,0)))
    _current_title = _label("现装升级", Rect2(32, 640, 435, 30), 19)
    _large_icon = _icon("laser", Rect2(34, 680, 104, 114))
    _current_caption = _label("当前攻击力", Rect2(155, 682, 120, 24), 14, TEAL)
    _label("本次升级后", Rect2(324, 682, 126, 24), 14, TEAL)
    _current_value = _label("—", Rect2(154, 711, 132, 42), 27)
    _label("→", Rect2(281, 713, 42, 42), 28, TEAL)
    _next_value = _label("—", Rect2(325, 711, 130, 42), 27)
    _switch_state = _label("", Rect2(155, 763, 295, 30), 13, TEAL)
    for index in 3:
        var captions := ["+1", "+10", "MAX"]
        var button := _button(captions[index], Rect2(32 + index * 56, 807, 50, 45), func(): _maximum = index == 2; _quantity = 10 if index == 1 else 1; _dirty = true)
        button.name = "Quantity" + str(index)
        _quantity_buttons.append(button)
    _cost = _label("", Rect2(206, 789, 106, 68), 14)
    _purchase = _button("购买1级", Rect2(318, 807, 133, 45), _buy, true)
    _purchase.name = "Purchase"
    _comparison_title = _label("点击槽位选择装备", Rect2(505, 639, 278, 28), 18, CREAM)
    _empty_choice = _button("卸下", Rect2(726, 638, 54, 25), _select_candidate.bind(""))
    _compare = _label("", Rect2(505, 757, 278, 66), 13, CREAM)
    _install = _button("安装", Rect2(505, 833, 274, 33), _equip, true)
    _install.name = "Install"
    _feedback = _label("", Rect2(24, 875, 760, 24), 12, CREAM)
    _feedback.clip_text = true
    _feedback.tooltip_text = ""
    _build_batch()

func _open_batch() -> void:
    # Godot GUI picking uses scene order as well as the visual canvas order.
    move_child(_batch_blocker, get_child_count() - 1)
    move_child(_batch, get_child_count() - 1)
    _batch_blocker.show()
    _batch.show()
    _refresh_batch()

func _close_batch() -> void:
    _batch.hide()
    _batch_blocker.hide()

func _build_batch() -> void:
    _batch_blocker = ColorRect.new()
    _batch_blocker.size = Vector2(808,900)
    _batch_blocker.color = Color(0.03,0.08,0.11,0.2)
    _batch_blocker.z_index = 19
    _batch_blocker.hide()
    add_child(_batch_blocker)
    _batch = PanelContainer.new()
    _batch.z_index = 20
    _batch.position = Vector2(90, 230)
    _batch.size = Vector2(628, 530)
    _batch.add_theme_stylebox_override("panel", _style(CREAM, TEAL, 2))
    add_child(_batch)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
    _batch.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 16)
    margin.add_child(stack)
    var heading := Label.new()
    heading.text = "全部装备升级"
    heading.add_theme_font_size_override("font_size", 25)
    heading.add_theme_color_override("font_color", INK)
    stack.add_child(heading)
    _batch_quantity = OptionButton.new()
    for caption in ["每槽 +1", "每槽 +10", "逐槽 MAX"]: _batch_quantity.add_item(caption)
    _batch_quantity.add_theme_color_override("font_color", INK)
    _batch_quantity.add_theme_font_size_override("font_size", 18)
    _batch_quantity.add_theme_stylebox_override("normal", _style(Color("dbe9df"), Color("8da6a2")))
    stack.add_child(_batch_quantity)
    _batch_scroll = ScrollContainer.new()
    _batch_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(_batch_scroll)
    _batch_results = Label.new()
    _batch_results.add_theme_font_size_override("font_size", 16)
    _batch_results.add_theme_color_override("font_color", INK)
    _batch_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _batch_results.custom_minimum_size.x = 565
    _batch_scroll.add_child(_batch_results)
    var row := HBoxContainer.new()
    stack.add_child(row)
    _batch_submit = _button("执行升级", Rect2(0, 0, 270, 44), _buy_all, true)
    remove_child(_batch_submit)
    _batch_submit.custom_minimum_size = Vector2(270, 44)
    row.add_child(_batch_submit)
    var close := _button("关闭", Rect2(0, 0, 270, 44), _close_batch)
    remove_child(close)
    close.custom_minimum_size = Vector2(270, 44)
    row.add_child(close)
    _batch.hide()

func _selected_fact() -> Dictionary:
    for row in _facts:
        if str(row.id) == _selected: return row
    return {}

func select_slot(id: String) -> void:
    _selected = id
    _selection_open = true
    var fact: Dictionary = _selected_fact()
    _candidate = str(fact.get("equipment_id", ""))
    _dirty = true

func _select_candidate(id: String) -> void:
    _candidate = id
    _dirty = true

func _refresh() -> void:
    _dirty = false
    presentation_counts.refreshes += 1
    presentation_counts.slot_fact_reads += 1
    _facts = _session.equipment_slot_facts()
    var active: Array = _facts.filter(func(row): return not row.dormant)
    if _selected_fact().is_empty() or _selected_fact().get("dormant", false):
        _selected = str(active[0].id) if not active.is_empty() else ""
        _candidate = str(_selected_fact().get("equipment_id", ""))
    var fact: Dictionary = _selected_fact()
    if fact.is_empty(): return
    _ship = str(_session.campaign_system.selected_ship())
    for option in _session.campaign_system.ship_options():
        if option.selected: _title.text = "装配 · " + str(option.name)
    _summary.text = "%d个武器槽 · %d个防御槽" % [int(_session.equipment_inputs().mounts.weapon), int(_session.equipment_inputs().mounts.defence)]
    var dormant_count: int = _facts.size() - active.size()
    if dormant_count > 0: _summary.text += " · %d个未启用槽位" % dormant_count
    _refresh_slots(active)
    _refresh_choices(fact)
    _refresh_comparison()
    var scene_picture: Array = [_ship, active.map(func(row): return [row.id,row.category,row.index,row.equipment_id])]
    if scene_picture != _scene_picture:
        _scene_picture = scene_picture
        presentation_counts.scene_redraw_requests += 1
        queue_redraw()

func _refresh_comparison() -> void:
    _comparison_dirty = false
    var fact: Dictionary = _selected_fact()
    if fact.is_empty():
        _dirty = true
        return
    _wallet_dependency = _session.economy.budget()
    presentation_counts.wallet_refreshes += 1
    _wallet.text = _cost_text(_wallet_dependency).replace(" / ", "   ")
    if _maximum: presentation_counts.maximum_reads += 1
    presentation_counts.comparison_reads += 1
    last_comparison = _session.equipment_comparison(_selected, _candidate, _quantity, _maximum)
    if not last_comparison.get("ok", false):
        _cost.text = PlayerText.error(str(last_comparison.get("reason", "Unknown")))
        _purchase.disabled = true
        _install.disabled = true
        return
    var comparison: Dictionary = last_comparison
    _large_icon.texture = _textures.get(str(fact.equipment_id))
    _current_title.text = "现装升级 · %s %s  Lv.%s" % [_slot_name(_selected), NAMES.get(str(fact.equipment_id), "装备"), str(fact.paid_level)]
    _current_value.text = _value(comparison.current)
    _next_value.text = _value(comparison.upgrade)
    var quote: Dictionary = comparison.quote
    _cost.text = "本次费用\n" + _cost_text(quote.costs).replace(" / ", "\n") if quote.get("ok", false) else _reason(str(quote.get("reason", quote.get("error", "Unknown"))))
    _cost.tooltip_text = _cost.text
    _purchase.text = "购买%s级" % str(quote.count) if quote.get("ok", false) else "购买"
    _purchase.disabled = not comparison.affordable
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining) > 0 else "换装就绪"
    if quote.get("ok", false) and not comparison.affordable: _switch_state.text += " · " + _reason(str(comparison.payment_reason))
    var primary: String = "容量" if fact.category == "defence" else "攻击力"
    _current_caption.text = "当前" + primary
    _compare.text = "当前%s     所选%s\n%s  %s  /  %s" % [NAMES.get(str(fact.equipment_id), "空槽"), NAMES.get(_candidate, "空槽"), primary, _value(comparison.current), _value(comparison.candidate)]
    if fact.category == "weapon":
        _compare.text += "\n攻击周期  %s  /  %s" % [_interval(comparison.current), _interval(comparison.candidate)]
    _install.text = "安装" + str(NAMES.get(_candidate, "装备")) if not _candidate.is_empty() else "卸下装备"
    _install.disabled = not comparison.switch_admission.ok
    _install.tooltip_text = "" if comparison.switch_admission.ok else _reason(str(comparison.switch_admission.reason))
    _empty_choice.visible = _selection_open and _selected != "defence:0"
    _compare.visible = _selection_open
    _install.visible = _selection_open
    _comparison_title.text = "换装比较" if _selection_open else "选择槽位查看装备"
    for index in 3:
        var selected: bool = (index == 2 and _maximum) or (not _maximum and index == (1 if _quantity == 10 else 0))
        if _quantity_presentations.get(index) != selected:
            _quantity_presentations[index] = selected
            presentation_counts.quantity_styles_updated += 1
            _quantity_buttons[index].add_theme_stylebox_override("normal", _style(Color("b8ded4") if selected else CREAM, TEAL if selected else Color("9aafac"), 2 if selected else 1))

func _refresh_slots(active: Array) -> void:
    var live: Array = []
    for row in active:
        var id: String = str(row.id)
        live.append(id)
        var signature: Array = [row.category,row.index,row.equipment_id,row.paid_level,id==_selected]
        if _slot_presentations.get(id) == signature: continue
        _slot_presentations[id] = signature
        presentation_counts.slots_updated += 1
        if not _slot_buttons.has(id):
            var button := _button("", Rect2(0,0,178,66), select_slot.bind(id))
            button.name = "Slot_" + id.replace(":", "_")
            button.alignment = HORIZONTAL_ALIGNMENT_LEFT
            var icon := _icon(str(row.equipment_id), Rect2(7,7,48,50), button)
            var caption := Label.new()
            caption.position = Vector2(59,8)
            caption.size = Vector2(115,48)
            caption.add_theme_font_size_override("font_size", 13)
            caption.add_theme_color_override("font_color", INK)
            caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
            button.add_child(caption)
            _slot_buttons[id] = {"button": button, "icon": icon, "caption": caption}
        var button: Button = _slot_buttons[id].button
        button.position = _slot_label_position(row)
        _slot_buttons[id].caption.text = "%s%d · %s\nLv.%s" % ["武器" if row.category == "weapon" else "防御", int(row.index) + 1, NAMES.get(str(row.equipment_id), "装备"), str(row.paid_level)]
        button.add_theme_font_size_override("font_size", 13)
        if _slot_selections.get(id) != (id == _selected):
            _slot_selections[id] = id == _selected
            presentation_counts.slot_styles_updated += 1
            button.add_theme_stylebox_override("normal", _style(CREAM, Color("d5a652") if id == _selected else Color("9bb3ab"), 2 if id == _selected else 1))
        _slot_buttons[id].icon.texture = _textures.get(str(row.equipment_id))
    for id in _slot_buttons.keys():
        if id not in live:
            _slot_buttons[id].button.queue_free()
            _slot_buttons.erase(id)
            _slot_presentations.erase(id)
            _slot_selections.erase(id)

func _refresh_choices(fact: Dictionary) -> void:
    presentation_counts.equipment_option_reads += 1
    var options: Array = _session.equipment.panel_equipment(_selected)
    var live: Array = []
    var column: int = 0
    for option in options:
        var id: String = str(option.id)
        if id.is_empty(): continue
        live.append(id)
        if not _choices.has(id):
            var button := _button("", Rect2(0,0,63,88), _select_candidate.bind(id))
            button.name = "Candidate_" + ("empty" if id.is_empty() else id)
            var icon := _icon(id, Rect2(8,5,47,49), button)
            var caption := Label.new()
            caption.position = Vector2(1,56)
            caption.size = Vector2(61,28)
            caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            caption.add_theme_font_size_override("font_size", 12)
            caption.add_theme_color_override("font_color", INK)
            caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
            button.add_child(caption)
            _choices[id] = {"button": button, "icon": icon, "caption": caption}
        var signature: Array = [option.enabled,str(fact.equipment_id)==id,_candidate==id,_selection_open,column]
        if _choice_presentations.get(id) == signature:
            column += 1
            continue
        _choice_presentations[id] = signature
        presentation_counts.candidates_updated += 1
        var control: Button = _choices[id].button
        control.position = Vector2(505 + column * 69, 666)
        control.visible = _selection_open
        control.disabled = not option.enabled
        control.tooltip_text = str(option.name) + (" · 已装备" if str(fact.equipment_id) == id else "" if option.enabled else " · 未解锁")
        _choices[id].caption.text = str(NAMES.get(id, option.name)) + ("\n已装备" if str(fact.equipment_id) == id else "" if option.enabled else "\n未解锁")
        _choices[id].caption.position.y = 51
        _choices[id].caption.size.y = 35
        control.add_theme_stylebox_override("normal", _style(Color("bbdfd6") if str(fact.equipment_id) == id else CREAM, Color("58c6c8") if _candidate == id else Color("90a9a5"), 3 if _candidate == id else 1))
        column += 1
    for id in _choices.keys():
        if id not in live:
            _choices[id].button.queue_free()
            _choices.erase(id)
            _choice_presentations.erase(id)

func _value(row) -> String:
    if row == null: return "—"
    return PlayerText.number(str(row.primary)) if row.get("status") == "known" and row.primary != null else "空槽" if row.get("status") == "empty" else "未知"

func _interval(row) -> String:
    return "—" if row == null or not row.get("properties", {}).has("interval_seconds") else "%s秒" % str(row.properties.interval_seconds)

func _reason(reason: String) -> String:
    return str({"EquipmentSwitchLocked": "换装冷却尚未结束", "NoChange": "没有可购买等级", "EquipmentLocked": "装备尚未解锁", "EvolutionMaterialLocked": "进化材料尚未开放", "FirstDefenceRequired": "首防御槽不可卸空", "InsufficientResources": "资源不足"}.get(reason, PlayerText.error(reason)))

func _cost_text(costs: Dictionary) -> String:
    var parts := PackedStringArray()
    var shown: Dictionary = _session.economy.cost_texts(costs)
    for id in costs:
        var label: String = {"1":"铁", "2":"铀", "degenerate_matter":"简并物质", "jewel":"碎片", "chrono":"时空微粒"}.get(str(id), str(id))
        parts.append((PlayerText.resource_number(str(shown.texts[id])) if shown.ok else "未知") + " " + label)
    return " / ".join(parts) if not parts.is_empty() else "0"

func _buy() -> void:
    var inputs: Dictionary = _session.equipment_inputs()
    var result: Dictionary = _session.equipment.buy_max_levels(_selected, inputs, _session.economy.affordable, _session.economy.payment, _session.publish_equipment_levels) if _maximum else _session.equipment.buy_levels(_selected, _quantity, inputs, _session.economy.payment, _session.publish_equipment_levels)
    _accept_result(result)

func _equip() -> void:
    _accept_result(_session.equipment.equip_slot(_selected, _candidate, _session.equipment_inputs(), _session.publish_equipment_refit))

func _buy_all() -> void:
    var mode: int = _batch_quantity.selected
    var result: Dictionary = _session.equipment.buy_all_levels(10 if mode == 1 else 1, mode == 2, _session.equipment_inputs(), _session.economy.affordable, _session.economy.payment, _session.publish_equipment_levels)
    _last_batch_result = result.duplicate(true)
    var status: String = str(result.get("purchase_receipt", {}).get("commit_status", ""))
    _batch_balance = "" if status == "fault_unknown" or result.get("fault", false) else _cost_text(_session.economy.budget()).replace(" / ", "   ")
    _accept_result(result)
    _refresh_batch(true)

func _receipt_text(result: Dictionary) -> String:
    var receipt: Dictionary = result.get("purchase_receipt", {})
    var lines := PackedStringArray()
    if receipt.get("commit_status") == "fault_unknown": return "提交结果未知，会话已停止。"
    for purchase in receipt.get("purchases", []):
        lines.append("%s  +%d级 · %s" % [_slot_name(str(purchase.slot_id)), int(purchase.count), _cost_text(purchase.spent)])
    if receipt.get("spent") is Dictionary and not receipt.spent.is_empty(): lines.append("实际花费：" + _cost_text(receipt.spent))
    if not result.get("ok", false): lines.append(_reason(str(result.get("reason", result.get("error", "Unknown")))))
    return "\n".join(lines) if not lines.is_empty() else "换装完成" if result.get("ok", false) else "没有变更"

func _slot_name(id: String) -> String:
    var pieces := id.split(":")
    return ("武器" if pieces[0] == "weapon" else "防御") + str(int(pieces[1]) + 1) if pieces.size() == 2 else id

func _accept_result(result: Dictionary) -> void:
    last_result = result.duplicate(true)
    _feedback.text = _receipt_text(result).replace("\n", " · ")
    _feedback.tooltip_text = _receipt_text(result)
    _dirty = true
    command_finished.emit(last_result)

func _refresh_batch(after: bool = false) -> void:
    var result: Dictionary = _last_batch_result
    var receipt: Dictionary = result.get("purchase_receipt", {})
    var status: String = str(receipt.get("commit_status", ""))
    var unknown: bool = status == "fault_unknown" or (result.get("fault", false) and status != "accepted")
    if after or not result.is_empty():
        if unknown:
            _batch_results.text = "最近一次升级\n提交结果未知，会话已停止。\n本次等级变化与扣款未确认。"
        elif status == "accepted" and not receipt.get("purchases", []).is_empty():
            var purchased: Array = []
            for item in receipt.purchases: purchased.append(str(item.slot_id))
            var details: String = ("最近一次成交" if result.get("ok", false) else "已确认部分成交") + "\n" + _receipt_text(result)
            if result.get("fault", false):
                _batch_results.text = details + "\n其余槽位与后续扣款状态未知。"
            else:
                for row in _facts:
                    if not row.dormant and str(row.id) not in purchased: details += "\n" + _slot_name(str(row.id)) + " · 未成交，等级保持"
                _batch_results.text = details + "\n\n成交后余额：" + _batch_balance
        elif status == "accepted":
            _batch_results.text = "已接纳，成交明细未返回。\n扣款与槽位变化待核对。"
        elif status == "rejected":
            _batch_results.text = "本次提交被拒绝\n" + _reason(str(result.get("reason", result.get("error", "Unknown")))) + "\n未确认成交。"
        elif status == "not_submitted" or (status.is_empty() and not result.get("ok", false)):
            _batch_results.text = "本次未执行升级\n" + _reason(str(result.get("reason", result.get("error", "Unknown"))))
        else:
            _batch_results.text = "成交明细未返回。\n本次扣款与槽位变化待核对。"
    else:
        _batch_results.text = "\n".join(_facts.filter(func(row): return not row.dormant).map(func(row): return "%s · %s · Lv.%s" % [_slot_name(str(row.id)), NAMES.get(str(row.equipment_id), "空槽"), str(row.paid_level)]))
    _batch_submit.disabled = unknown or (status == "accepted" and receipt.get("purchases", []).is_empty()) or not _session.run_state.is_running()

func _process(dt: float) -> void:
    if not is_visible_in_tree(): return
    _clock += dt
    var cooldown: bool = _facts.any(func(row): return float(row.cooldown_remaining) > 0)
    if _dirty:
        _clock = 0.0
        _refresh()
    elif _comparison_dirty:
        _refresh_comparison()
    elif cooldown and _clock >= 0.1:
        _clock = 0.0
        _refresh_cooldown()

func _refresh_cooldown() -> void:
    var previous: Dictionary = _selected_fact()
    presentation_counts.cooldown_fact_reads += 1
    _facts = _session.equipment_slot_facts()
    var fact: Dictionary = _selected_fact()
    if fact.is_empty() or previous.is_empty():
        _dirty = true
        return
    if float(previous.cooldown_remaining) > 0 and float(fact.cooldown_remaining) <= 0:
        # Admission is always re-read from the owner when the deadline is crossed.
        _dirty = true
        return
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining) > 0 else "换装就绪"
    if last_comparison.get("quote", {}).get("ok", false) and not last_comparison.get("affordable", false):
        _switch_state.text += " · " + _reason(str(last_comparison.payment_reason))

func _ship_rect() -> Rect2:
    var side: float = 768.0 * 350.0 / float(_catalog[_ship].height)
    return Rect2(Vector2(404, 387) - Vector2.ONE * side * 0.5, Vector2.ONE * side)

func _mount_position(row: Dictionary) -> Vector2:
    var rect := _ship_rect()
    if row.category == "weapon":
        var mounts: Array = _catalog[_ship].mounts
        return rect.position + Vector2(float(mounts[int(row.index)][0]), float(mounts[int(row.index)][1])) / 768.0 * rect.size
    return Vector2(353 if int(row.index) == 0 else 453, 453)

func _slot_label_position(row: Dictionary) -> Vector2:
    if row.category == "defence": return Vector2(95 if int(row.index) == 0 else 536, 462)
    var positions := [Vector2(310,153), Vector2(95,275), Vector2(536,275), Vector2(95,366), Vector2(536,366)]
    return positions[mini(int(row.index), positions.size()-1)]

func _draw() -> void:
    presentation_counts.scene_draws += 1
    draw_rect(Rect2(0,0,808,900), CREAM)
    draw_texture_rect(_background, Rect2(0,85,808,815), false)
    draw_line(Vector2(0,84), Vector2(808,84), Color("8aaba8"), 1)
    if _ship.is_empty() or not _catalog.has(_ship): return
    draw_texture_rect(_hull_textures[_ship], _ship_rect(), false)
    for row in _facts:
        if row.dormant: continue
        var mount: Vector2 = _mount_position(row)
        var label_rect := Rect2(_slot_label_position(row), Vector2(178,66))
        var start: Vector2 = label_rect.get_center()
        draw_line(start, mount, Color("e8f7ec", 0.95), 2, true)
        draw_circle(mount, 5, Color("eaf9ee"))
        var key: String = str(row.equipment_id)
        if not _textures.has(key): continue
        var tex: Texture2D = _textures[key]
        if row.category == "weapon":
            var meta: Dictionary = _weapon_meta[key]
            var scale_factor: float = 0.16 if key == "longLaser" or key == "cannon" else 0.13
            var anchor := Vector2(float(meta.anchor[0]), float(meta.anchor[1])) * scale_factor
            draw_texture_rect(tex, Rect2(mount - anchor, Vector2(tex.get_size()) * scale_factor), false)
        else:
            draw_texture_rect(tex, Rect2(mount - Vector2(21,21), Vector2(42,42)), false)
