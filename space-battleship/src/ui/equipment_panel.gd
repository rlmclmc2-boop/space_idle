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
var _weapon_visible_bounds: Dictionary = {}
var _hull_textures: Dictionary = {}
var _background: Texture2D
var _upgrade_surface: Texture2D
var _locator_badge_style: StyleBoxFlat
var _title: Label
var _wallet: Label
var _current_title: Label
var _current_caption: Label
var _current_value: Label
var _next_value: Label
var _upgrade_caption: Label
var _upgrade_arrow: Label
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
var _font_regular: FontVariation
var _font_strong: FontVariation
var _terminal_texture: Texture2D
var _arm_parts: Array = []
var _cost_cells: Dictionary = {}
var _payment_state: Label
var _level_label: Label
var _compare_headers: Array = []
var _compare_values: Array = []
var _compare_periods: Array = []
var _compare_row_label: Label
var _batch_total: Label
var _batch_secondary: Label
var _batch_frame: Panel
var _batch_close: Button
var _selection_open: bool = true
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
    for key in _weapon_meta:
        _textures[key] = load(str(_weapon_meta[key].texture))
        _weapon_visible_bounds[key]=_textures[key].get_image().get_used_rect()
    _textures.shield = load("res://assets/ui/equipment/cartoon_shield.svg")
    _textures.armour = load("res://assets/ui/equipment/cartoon_armour.svg")
    _background = load("res://assets/ui/equipment/hangar/hangar-console.png")
    _upgrade_surface=load("res://assets/ui/equipment/hangar/upgrade-console.svg")
    _setup_materials()
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

func _setup_materials() -> void:
    _font_regular = FontVariation.new()
    _font_regular.base_font = load("res://assets/fonts/NotoSansSC.ttf")
    _font_regular.variation_opentype = {2003265652:400.0}
    _font_strong = FontVariation.new()
    _font_strong.base_font = _font_regular.base_font
    _font_strong.variation_opentype = {2003265652:600.0}
    theme = Theme.new()
    theme.default_font = _font_regular
    theme.default_font_size = 15
    theme.set_font("font", "Button", _font_strong)
    theme.set_color("font_color", "PopupMenu", CREAM)
    theme.set_stylebox("panel", "PopupMenu", _style(Color("173c4b"),Color("7faaa7")))
    _locator_badge_style=_style(Color("214452"),Color("e9c98b"),1)
    _terminal_texture = load("res://assets/ui/equipment/hangar/terminal-clean.svg")
    var arm: Texture2D = load("res://assets/ui/equipment/hangar/support-arm.png")
    for region in [Rect2(0,160,450,400),Rect2(450,160,1272,400),Rect2(1722,160,450,400)]:
        var part := AtlasTexture.new()
        part.atlas=arm;part.region=region
        _arm_parts.append(part)

func _frame(parent: Control, rect: Rect2) -> Panel:
    var frame := Panel.new()
    frame.position=rect.position;frame.size=rect.size
    var material := _style(Color("234d5c"),Color("dcdcc8"),3)
    material.set_corner_radius_all(10)
    material.shadow_color=Color("102c3a",0.6);material.shadow_size=3;material.shadow_offset=Vector2(0,3)
    frame.add_theme_stylebox_override("panel",material)
    frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    frame.show_behind_parent=true
    parent.add_child(frame)
    return frame

func _prepare_button_material(button: Button, form: String) -> void:
    # Each native interaction state is built once. Selection only swaps cached styles.
    var variants: Array=[]
    for selected in [false,true]:
        var states: Dictionary={}
        for state in ["normal","hover","pressed","disabled","focus"]:
            var fill:=Color("234b5b") if form!="candidate" else Color("214959")
            var edge:=Color("9baea9") if form!="candidate" else Color("dedfce")
            if selected:fill=Color("306958");edge=Color("9bd9be")
            if state=="hover":fill=Color("3c6e76");edge=Color("d4f3e4")
            elif state=="pressed":fill=Color("122f3d");edge=Color("7bb6b1")
            elif state=="disabled":fill=Color("31434a");edge=Color("62747a")
            var material:=_style(fill,edge,2 if form=="candidate" else 1)
            material.set_corner_radius_all(5 if form=="candidate" else 6)
            material.border_width_top=2
            material.border_width_bottom=3 if state!="pressed" else 1
            material.shadow_color=Color("102b38",0.45);material.shadow_size=1;material.shadow_offset=Vector2(0,2 if state!="pressed" else 0)
            if form=="slot":
                material.bg_color=Color(0,0,0,0) if state=="normal" else Color(0.65,0.95,0.86,0.16) if state=="hover" else Color(0.02,0.09,0.13,0.35) if state=="pressed" else Color(0.15,0.20,0.22,0.5)
                material.set_border_width_all(0);material.shadow_size=0
                material.expand_margin_left=-15;material.expand_margin_right=-15;material.expand_margin_top=-12;material.expand_margin_bottom=-26
            if state=="focus":
                material.bg_color=Color(0,0,0,0);material.border_color=Color("b3ead8");material.set_border_width_all(2);material.shadow_size=0
            states[state]=material
        variants.append(states)
    button.set_meta("material_variants",variants)
    _button_tint(button,false)

func _button_tint(button: Button, chosen: bool) -> void:
    if button.has_meta("material_chosen") and button.get_meta("material_chosen")==chosen:return
    button.set_meta("material_chosen",chosen)
    var states: Dictionary=button.get_meta("material_variants")[1 if chosen else 0]
    for state in states:button.add_theme_stylebox_override(state,states[state])
    button.add_theme_color_override("font_color",Color("c0f4df") if chosen else CREAM)

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
    label.text=text;label.position=rect.position;label.size=rect.size
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_font_override("font",_font_strong if font_size>=18 else _font_regular)
    label.add_theme_color_override("font_color",color)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
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

func _button(text: String, rect: Rect2, action: Callable, dark: bool = false, form: String = "button") -> Button:
    var button := Button.new()
    button.text=text;button.position=rect.position;button.size=rect.size
    button.add_theme_font_size_override("font_size",16)
    button.add_theme_font_override("font",_font_strong)
    for key in ["font_color","font_pressed_color"]:button.add_theme_color_override(key,CREAM)
    button.add_theme_color_override("font_hover_color",Color("c4fff0"))
    button.add_theme_color_override("font_disabled_color",Color("8da5ac"))
    _prepare_button_material(button,form)
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
    _label("远航舰桥",Rect2(24,10,160,34),23)
    _wallet=_label("",Rect2(204,16,590,30),15)
    _label("战力维护  /  装配",Rect2(24,52,380,28),14,Color("57777a"))
    _title=_label("装配",Rect2(35,104,236,30),18,CREAM)
    _title.add_theme_color_override("font_shadow_color",Color("173542"))
    _title.add_theme_constant_override("shadow_offset_x",1)
    _title.add_theme_constant_override("shadow_offset_y",2)
    _button("全部装备升级",Rect2(614,96,174,49),_open_batch,true).name="BatchOpen"
    _current_title=_label("现装升级",Rect2(42,610,330,29),18,CREAM)
    _level_label=_label("",Rect2(383,615,70,22),13,Color("aec5be"))
    _large_icon=_icon("laser",Rect2(42,656,64,64))
    _current_caption=_label("当前攻击力",Rect2(130,648,140,22),12,Color("6b7d79"))
    _upgrade_caption=_label("升级后",Rect2(306,648,146,22),12,Color("557a78"))
    _current_value=_label("—",Rect2(130,671,140,38),27)
    _upgrade_arrow=_label("→",Rect2(273,675,32,32),23,Color("72938d"))
    _next_value=_label("—",Rect2(306,671,148,38),27,TEAL)
    for value in [_current_value,_next_value]:
        value.mouse_filter=Control.MOUSE_FILTER_PASS
        value.clip_text=true
    _cost=_label("本次费用",Rect2(38,737,104,24),13,Color("647b75"))
    _payment_state=_label("",Rect2(38,766,414,31),13,Color("a75a3d"))
    _payment_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for index in 3:
        var captions := ["+1","+10","MAX"]
        var button := _button(captions[index],Rect2(34+index*65,810,59,37),func():_maximum=index==2;_quantity=10 if index==1 else 1;_dirty=true)
        button.name="Quantity"+str(index)
        _quantity_buttons.append(button)
    _purchase=_button("购买1级",Rect2(242,806,218,40),_buy,true)
    _purchase.name="Purchase"
    _comparison_title=_label("装备选择",Rect2(508,608,260,27),18,CREAM)
    _compare=_label("",Rect2(508,735,268,62),13,CREAM)
    _compare.hide()
    for column in 2:
        var header:=_label("",Rect2(565+column*105,730,100,19),12,Color("cbdad5") if column==0 else Color("91e4cf"))
        header.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        header.add_theme_font_override("font",_font_strong)
        header.size=Vector2(100,19)
        _compare_headers.append(header)
        var value:=_label("—",Rect2(565+column*105,749,100,25),17,CREAM if column==0 else Color("a2f0d6"))
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        value.add_theme_font_override("font",_font_strong)
        value.size=Vector2(100,25)
        _compare_values.append(value)
        var period:=_label("—",Rect2(565+column*105,774,100,19),12,Color("b6c9c6") if column==0 else Color("91caba"))
        period.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        period.size=Vector2(100,19)
        _compare_periods.append(period)
    _compare_row_label=_label("攻击力",Rect2(508,749,57,25),12,Color("a8bfbc"))
    _label("周期",Rect2(508,774,57,19),12,Color("8faeab")).name="PeriodCaption"
    _switch_state=_label("",Rect2(508,794,260,17),11,Color("f2cb83"))
    _switch_state.size=Vector2(260,17)
    _install=_button("安装",Rect2(524,812,244,36),_equip,true)
    _install.name="Install"
    _feedback=_label("",Rect2(25,875,757,24),12,Color("e5e7da"))
    _feedback.clip_text=true
    _build_batch()

func _render_costs(quote: Dictionary, affordable: bool, reason: String) -> void:
    var keys: Array = quote.get("costs",{}).keys() if quote.get("ok",false) else []
    for id in _cost_cells:_cost_cells[id].name.visible=false;_cost_cells[id].amount.visible=false
    _payment_state.text=""
    _purchase.tooltip_text=""
    _cost.text="本次费用"
    _payment_state.position=Vector2(38,766);_payment_state.size=Vector2(104,31)
    _payment_state.text="" if affordable else _reason(reason)
    for index in keys.size():
        var id: String=str(keys[index])
        if not _cost_cells.has(id):
            var name:=_label("",Rect2(143,737,102,23),13,Color("5f7876"))
            var amount:=_label("",Rect2(246,733,208,25),17,INK)
            amount.add_theme_font_override("font",_font_strong)
            amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
            _cost_cells[id]={"name":name,"amount":amount}
        var cell: Dictionary=_cost_cells[id]
        cell.name.position.y=737+index*24
        cell.amount.position.y=733+index*24
        cell.name.text={"1":"铁","2":"铀","degenerate_matter":"简并物质","jewel":"碎片"}.get(id,id)
        var formatted: Dictionary=_session.amount_api.apply("to_display",[quote.costs[id]])
        cell.amount.text=PlayerText.number(str(formatted.text)) if formatted.ok else "未知"
        cell.amount.add_theme_color_override("font_color",INK if affordable else Color("a1593b"))
        cell.name.show();cell.amount.show()
    if not quote.get("ok",false):
        _payment_state.size=Vector2(414,31)
        _payment_state.text=_reason(str(quote.get("reason",quote.get("error","Unknown"))))
    elif not affordable:
        _purchase.tooltip_text=_reason(reason)+"\n"+_cost_text(quote.costs)

func _open_batch() -> void:
    # Godot GUI picking uses scene order as well as the visual canvas order.
    move_child(_batch_blocker, get_child_count() - 1)
    move_child(_batch_frame,get_child_count()-1)
    move_child(_batch, get_child_count() - 1)
    _batch_blocker.show()
    _batch_frame.show()
    _batch.show()
    _refresh_batch()

func _close_batch() -> void:
    _batch.hide()
    _batch_frame.hide()
    _batch_blocker.hide()

func _build_batch() -> void:
    _batch_blocker=ColorRect.new();_batch_blocker.size=Vector2(808,900)
    _batch_blocker.color=Color(0.03,0.08,0.11,0.30);_batch_blocker.z_index=19
    add_child(_batch_blocker);_batch_blocker.hide()
    _batch_frame=_frame(self,Rect2(90,180,628,590))
    _batch_frame.show_behind_parent=false;_batch_frame.z_index=20;_batch_frame.hide()
    _batch=PanelContainer.new();_batch.position=Vector2(90,180);_batch.size=Vector2(628,590);_batch.z_index=21
    _batch.add_theme_stylebox_override("panel",StyleBoxEmpty.new());add_child(_batch)
    var margin:=MarginContainer.new()
    for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,30)
    _batch.add_child(margin)
    var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",14);margin.add_child(stack)
    var heading:=Label.new();heading.text="全部装备升级"
    heading.add_theme_font_override("font",_font_strong);heading.add_theme_font_size_override("font_size",24);heading.add_theme_color_override("font_color",CREAM)
    stack.add_child(heading)
    _batch_quantity=OptionButton.new()
    for caption in ["每槽 +1","每槽 +10","逐槽 MAX"]:_batch_quantity.add_item(caption)
    _batch_quantity.custom_minimum_size.y=40
    _batch_quantity.add_theme_font_override("font",_font_strong);_batch_quantity.add_theme_font_size_override("font_size",17)
    _batch_quantity.add_theme_color_override("font_color",CREAM)
    _prepare_button_material(_batch_quantity,"button")
    stack.add_child(_batch_quantity)
    _batch_total=Label.new();_batch_total.add_theme_font_override("font",_font_strong)
    _batch_total.add_theme_font_size_override("font_size",20);_batch_total.add_theme_color_override("font_color",Color("a8f0d6"))
    _batch_total.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;stack.add_child(_batch_total)
    _batch_scroll=ScrollContainer.new();_batch_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    stack.add_child(_batch_scroll)
    var results:=VBoxContainer.new();results.custom_minimum_size.x=554;results.add_theme_constant_override("separation",15);_batch_scroll.add_child(results)
    _batch_results=Label.new();_batch_results.add_theme_font_size_override("font_size",16);_batch_results.add_theme_color_override("font_color",CREAM)
    _batch_results.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_batch_results.custom_minimum_size.x=548;results.add_child(_batch_results)
    _batch_secondary=Label.new();_batch_secondary.add_theme_font_size_override("font_size",13);_batch_secondary.add_theme_color_override("font_color",Color("a3bcb9"))
    _batch_secondary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;results.add_child(_batch_secondary)
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);stack.add_child(row)
    _batch_submit=_button("执行升级",Rect2(0,0,270,44),_buy_all,true)
    remove_child(_batch_submit);_batch_submit.custom_minimum_size=Vector2(270,44);row.add_child(_batch_submit)
    _batch_close=_button("关闭",Rect2(0,0,270,44),_close_batch)
    remove_child(_batch_close);_batch_close.custom_minimum_size=Vector2(270,44);row.add_child(_batch_close)
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
    _refresh_slots(active)
    _refresh_choices(fact)
    _refresh_comparison()
    var scene_picture: Array = [_ship, _selected, active.map(func(row): return [row.id,row.category,row.index,row.equipment_id])]
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
    _current_title.text = "%s · %s" % [_slot_name(_selected),NAMES.get(str(fact.equipment_id),"装备")]
    _level_label.text = "Lv."+str(fact.paid_level)
    _current_value.text = _value(comparison.current)
    _next_value.text = _value(comparison.upgrade)
    _current_value.tooltip_text=str(comparison.current.primary) if comparison.current is Dictionary and comparison.current.get("primary")!=null else _value(comparison.current)
    _next_value.tooltip_text=str(comparison.upgrade.primary) if comparison.upgrade is Dictionary and comparison.upgrade.get("primary")!=null else _value(comparison.upgrade)
    var long_values: bool = _font_strong.get_string_size(_next_value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x>148 or _font_strong.get_string_size(_current_value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x>140
    _upgrade_arrow.visible=not long_values
    _current_caption.position=Vector2(130,656 if long_values else 652)
    _upgrade_caption.position=Vector2(130,687) if long_values else Vector2(306,652)
    _current_value.position=Vector2(232,647) if long_values else Vector2(130,674)
    _next_value.position=Vector2(232,678) if long_values else Vector2(306,674)
    _current_value.size=Vector2(222 if long_values else 140,38)
    _next_value.size=Vector2(222 if long_values else 148,38)
    var quote: Dictionary = comparison.quote
    _render_costs(quote,comparison.affordable,str(comparison.payment_reason))
    _cost.tooltip_text = _cost_text(quote.costs) if quote.get("ok",false) else _payment_state.text
    _purchase.text = "购买%s级" % str(quote.count) if quote.get("ok", false) else "购买"
    _purchase.disabled = not comparison.affordable
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining)>0 else ""

    var primary: String = "容量" if fact.category == "defence" else "攻击力"
    _current_caption.text = "当前" + primary
    _compare.text = "当前%s     所选%s\n%s  %s  /  %s" % [NAMES.get(str(fact.equipment_id), "空槽"), NAMES.get(_candidate, "空槽"), primary, _value(comparison.current), _value(comparison.candidate)]
    if fact.category == "weapon":
        _compare.text += "\n攻击周期  %s  /  %s" % [_interval(comparison.current), _interval(comparison.candidate)]
    _install.text = "安装" + str(NAMES.get(_candidate, "装备")) if not _candidate.is_empty() else "选择装备"
    _install.disabled = _candidate.is_empty() or not comparison.switch_admission.ok
    _install.tooltip_text = "" if comparison.switch_admission.ok else _reason(str(comparison.switch_admission.reason))
    _compare.visible = false
    _install.visible = _selection_open
    _comparison_title.text = "装备选择"
    _compare_row_label.text=primary
    for column in 2:
        var row = comparison.current if column==0 else comparison.candidate
        _compare_headers[column].text=("现装 · " if column==0 else "所选 · ")+str(NAMES.get(str(row.equipment_id),"空槽"))
        _compare_values[column].text=_value(row)
        _compare_periods[column].text=_interval(row) if fact.category=="weapon" else ""
    get_node("PeriodCaption").visible=fact.category=="weapon"
    if _candidate.is_empty():
        _install.text="选择装备"
        _install.tooltip_text=""
    elif str(comparison.switch_admission.get("reason",""))=="NoChange":_install.text="已装备"
    elif str(comparison.switch_admission.get("reason",""))=="EquipmentSwitchLocked":_install.text="换装冷却中"
    elif str(comparison.switch_admission.get("reason",""))=="EquipmentLocked":_install.text="尚未解锁"
    for index in 3:
        var selected: bool = (index == 2 and _maximum) or (not _maximum and index == (1 if _quantity == 10 else 0))
        if _quantity_presentations.get(index) != selected:
            _quantity_presentations[index] = selected
            presentation_counts.quantity_styles_updated += 1
            _button_tint(_quantity_buttons[index],selected)

func _refresh_slots(active: Array) -> void:
    var live: Array=[]
    for row in active:
        var id: String=str(row.id)
        live.append(id)
        var signature: Array=[row.category,row.index,row.equipment_id,row.paid_level,id==_selected]
        if _slot_presentations.get(id)==signature:continue
        _slot_presentations[id]=signature
        presentation_counts.slots_updated+=1
        if not _slot_buttons.has(id):
            var button:=_button("",Rect2(0,0,220,82),select_slot.bind(id),false,"slot")
            button.name="Slot_"+id.replace(":","_")
            var housing:=TextureRect.new()
            housing.texture=_terminal_texture;housing.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
            housing.stretch_mode=TextureRect.STRETCH_SCALE;housing.size=Vector2(220,82)
            housing.mouse_filter=Control.MOUSE_FILTER_IGNORE;housing.show_behind_parent=true
            button.add_child(housing)
            var icon:=_icon(str(row.equipment_id),Rect2(23,12,42,43),button)
            var title:=_label("",Rect2(72,12,127,23),15,CREAM)
            remove_child(title);button.add_child(title);title.add_theme_font_override("font",_font_strong)
            var meta:=_label("",Rect2(72,37,127,21),12,Color("a6c6c3"))
            remove_child(meta);button.add_child(meta)
            var led:=ColorRect.new();led.position=Vector2(18,17);led.size=Vector2(3,32);led.mouse_filter=Control.MOUSE_FILTER_IGNORE
            button.add_child(led)
            _slot_buttons[id]={"button":button,"icon":icon,"caption":title,"meta":meta,"led":led,"housing":housing}
        var item: Dictionary=_slot_buttons[id]
        item.button.position=_slot_label_position(row)
        item.caption.text=str(NAMES.get(str(row.equipment_id),"装备"))
        item.meta.text="%s · Lv.%s" % [_slot_name(id).replace("武器","武器槽").replace("防御","防御槽"),str(row.paid_level)]
        item.icon.texture=_textures.get(str(row.equipment_id))
        item.led.color=Color("f5cc84") if id==_selected else Color("3f777c")
        item.housing.modulate=Color("fff1d0") if id==_selected else Color.WHITE
        if _slot_selections.get(id)!=(id==_selected):presentation_counts.slot_styles_updated+=1;_slot_selections[id]=id==_selected
    for id in _slot_buttons.keys():
        if id not in live:
            _slot_buttons[id].button.queue_free();_slot_buttons.erase(id);_slot_presentations.erase(id);_slot_selections.erase(id)

func _refresh_choices(fact: Dictionary) -> void:
    presentation_counts.equipment_option_reads+=1
    var options: Array=_session.equipment.panel_equipment(_selected)
    var live: Array=[]
    var column: int=0
    for option in options:
        var id: String=str(option.id)
        if id.is_empty():continue
        live.append(id)
        if not _choices.has(id):
            var button:=_button("",Rect2(0,0,65,89),_select_candidate.bind(id),false,"candidate")
            button.name="Candidate_"+id
            var icon:=_icon(id,Rect2(12,7,41,40),button)
            var caption:=_label("",Rect2(3,48,59,20),13,CREAM)
            remove_child(caption);button.add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            caption.add_theme_font_override("font",_font_strong)
            caption.size=Vector2(59,20)
            var status:=_label("",Rect2(3,68,59,17),11,Color("c6dfd5"))
            remove_child(status);button.add_child(status);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            status.add_theme_font_override("font",_font_strong)
            # Initial Label sizing used the default font before its override.
            # Reapply the actual slot after the 11px font's minimum is known.
            status.size=Vector2(59,17)
            _choices[id]={"button":button,"icon":icon,"caption":caption,"status":status}
        var signature: Array=[option.enabled,str(fact.equipment_id)==id,_candidate==id,_selection_open,column]
        if _choice_presentations.get(id)==signature:column+=1;continue
        _choice_presentations[id]=signature;presentation_counts.candidates_updated+=1
        var item: Dictionary=_choices[id]
        item.button.position=Vector2(505+column*70,638)
        item.button.visible=_selection_open;item.button.disabled=not option.enabled
        item.caption.text=str(NAMES.get(id,option.name))
        item.status.text="已装备" if str(fact.equipment_id)==id else "未解锁" if not option.enabled else "待安装" if _candidate==id else ""
        item.caption.modulate=Color.WHITE if option.enabled else Color("b1beb9")
        item.icon.modulate=Color.WHITE if option.enabled else Color("718a8b")
        item.status.add_theme_color_override("font_color",Color("c6dfd5") if option.enabled else Color("d6bb8a"))
        _button_tint(item.button,_candidate==id)
        column+=1
    for id in _choices.keys():
        if id not in live:_choices[id].button.queue_free();_choices.erase(id);_choice_presentations.erase(id)

func _value(row) -> String:
    if row == null: return "—"
    return PlayerText.number(str(row.primary)) if row.get("status") == "known" and row.primary != null else "空槽" if row.get("status") == "empty" else "未知"

func _interval(row) -> String:
    return "—" if row == null or not row.get("properties", {}).has("interval_seconds") else "%s秒" % str(row.properties.interval_seconds)

func _reason(reason: String) -> String:
    return str({"EquipmentSwitchLocked": "换装冷却尚未结束", "NoChange": "没有可购买等级", "EquipmentLocked": "装备尚未解锁", "EvolutionMaterialLocked": "进化材料尚未开放", "FirstDefenceRequired": "首防御槽不可卸空", "InsufficientResources": "资源不足"}.get(reason, PlayerText.error(reason)))

func _cost_text(costs: Dictionary) -> String:
    var parts := PackedStringArray()
    for id in costs:
        var result: Dictionary = _session.amount_api.apply("to_display", [costs[id]])
        var label: String = {"1":"铁", "2":"铀", "degenerate_matter":"简并物质", "jewel":"碎片", "chrono":"时空微粒"}.get(str(id), str(id))
        parts.append((PlayerText.number(str(result.text)) if result.ok else "未知") + " " + label)
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
    _batch_total.text=""
    _batch_secondary.text=""
    if after or not result.is_empty():
        if unknown:
            _batch_results.text = "最近一次升级\n提交结果未知，会话已停止。\n本次等级变化与扣款未确认。"
        elif status == "accepted" and not receipt.get("purchases", []).is_empty():
            var purchased: Array = []
            for item in receipt.purchases: purchased.append(str(item.slot_id))
            var detail_lines:=PackedStringArray()
            for purchase in receipt.purchases:detail_lines.append("%s  +%d级    %s" % [_slot_name(str(purchase.slot_id)),int(purchase.count),_cost_text(purchase.spent)])
            var details: String="\n".join(detail_lines)
            _batch_total.text="实际总花费  "+_cost_text(receipt.spent) if receipt.get("spent") is Dictionary else "实际总花费未确认"
            if result.get("fault", false):
                _batch_results.text = details + "\n其余槽位与后续扣款状态未知。"
            else:
                var secondary:=PackedStringArray()
                for row in _facts:
                    if not row.dormant and str(row.id) not in purchased:secondary.append(_slot_name(str(row.id))+" · 未成交，等级保持")
                _batch_results.text=details
                _batch_secondary.text="\n".join(secondary)+"\n\n成交后余额  "+_batch_balance
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
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining)>0 else ""


func _ship_rect() -> Rect2:
    var side: float = 768.0 * 350.0 / float(_catalog[_ship].height)
    return Rect2(Vector2(404, 387) - Vector2.ONE * side * 0.5, Vector2.ONE * side)

func _mount_position(row: Dictionary) -> Vector2:
    var rect := _ship_rect()
    if row.category == "weapon":
        var mounts: Array = _catalog[_ship].mounts
        return rect.position + Vector2(float(mounts[int(row.index)][0]), float(mounts[int(row.index)][1])) / 768.0 * rect.size
    # Defence has no weapon-manifest geometry. These are distinct UI attachment markers.
    return [Vector2(353,453),Vector2(453,453),Vector2(495,243)][mini(int(row.index),2)]

func _slot_label_position(row: Dictionary) -> Vector2:
    if row.category=="defence":return [Vector2(66,440),Vector2(522,440),Vector2(536,164)][mini(int(row.index),2)]
    var count: int=_catalog[_ship].mounts.size()
    if count==2 or count==4:
        # Even mount layouts have a left/right pair rather than a centre bow mount.
        return Vector2(52 if int(row.index)%2==0 else 536,(260 if count==2 else 215)+floori(float(row.index)/2.0)*135)
    var positions: Array=[Vector2(294,129),Vector2(52,260),Vector2(536,260),Vector2(52,350),Vector2(536,350)]
    return positions[mini(int(row.index),positions.size()-1)]

func _draw() -> void:
    presentation_counts.scene_draws+=1
    draw_rect(Rect2(0,0,808,900),CREAM)
    draw_texture_rect_region(_background,Rect2(0,85,808,485),Rect2(0,0,1188,845))
    draw_texture_rect_region(_background,Rect2(0,570,808,330),Rect2(0,845,1188,479))
    # The ship name is lettered directly on the hangar beam, without a floating plaque.
    draw_texture_rect(_upgrade_surface,Rect2(24,606,452,252),false)
    if _ship.is_empty() or not _catalog.has(_ship):return
    for row in _facts:
        if row.dormant:continue
        var port: Vector2=_slot_label_position(row)+Vector2(110,73)
        var mount: Vector2=_mount_position(row)
        if _ship=="Frigate" and row.category=="weapon":
            # The service arm bypasses the bow, reaching the actual midship turret.
            _draw_support(port,Vector2(555,port.y))
            _draw_support(Vector2(555,port.y),Vector2(555,mount.y))
            _draw_support(Vector2(555,mount.y),mount)
        else:_draw_support(port,mount)
    draw_texture_rect(_hull_textures[_ship],_ship_rect(),false)
    for row in _facts:
        if row.dormant:continue
        var mount: Vector2=_mount_position(row)
        var key: String=str(row.equipment_id)
        if not _textures.has(key):continue
        var tex: Texture2D=_textures[key]
        if row.category=="weapon":
            var meta: Dictionary=_weapon_meta[key]
            var factor: float=0.16 if key=="longLaser" or key=="cannon" else 0.13
            var anchor:=Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor
            draw_texture_rect(tex,Rect2(mount-anchor,Vector2(tex.get_size())*factor),false)
        else:draw_texture_rect(tex,Rect2(mount-Vector2(21,21),Vector2(42,42)),false)

    _draw_selected_locator()

func _draw_support(port: Vector2, mount: Vector2) -> void:
    var length:float=port.distance_to(mount)
    draw_set_transform(port,(mount-port).angle())
    draw_texture_rect(_arm_parts[1],Rect2(10,-16,maxf(1,length-20),32),false)
    draw_texture_rect(_arm_parts[0],Rect2(-16,-16,36,32),false)
    draw_texture_rect(_arm_parts[2],Rect2(length-17,-16,36,32),false)
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _component_rect(row: Dictionary) -> Rect2:
    var point:Vector2=_mount_position(row)
    var key:String=str(row.equipment_id)
    if row.category=="weapon" and _weapon_visible_bounds.has(key):
        var factor:float=0.16 if key in ["longLaser","cannon"] else 0.13
        var meta:Dictionary=_weapon_meta[key]
        var bound:Rect2=Rect2(_weapon_visible_bounds[key])
        return Rect2(point-Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor+bound.position*factor,bound.size*factor)
    return Rect2(point-Vector2(21,21),Vector2(42,42))

func _draw_selected_locator() -> void:
    var row:Dictionary=_selected_fact()
    if row.is_empty() or row.dormant:return
    var card:Rect2=Rect2(_slot_label_position(row),Vector2(220,82))
    var target:Rect2=_component_rect(row).grow(5)
    var centre:Vector2=target.get_center()
    var direction:Vector2=centre-card.get_center()
    var start:Vector2=card.get_center()
    if absf(direction.x)>absf(direction.y):start.x=card.end.x if direction.x>0 else card.position.x
    else:start.y=card.end.y if direction.y>0 else card.position.y
    var ends:Array=[Vector2(target.position.x,centre.y),Vector2(target.end.x,centre.y),Vector2(centre.x,target.position.y),Vector2(centre.x,target.end.y)]
    var end:Vector2=ends[0];var best:float=INF
    for candidate in ends:
        var hidden:bool=false
        for id in _slot_buttons:
            if _slot_buttons[id].button.get_rect().grow(2).has_point(candidate):hidden=true;break
        if not hidden and start.distance_squared_to(candidate)<best:end=candidate;best=start.distance_squared_to(candidate)
    var points:PackedVector2Array=PackedVector2Array([start,end])
    if _ship=="Frigate" and row.category=="weapon":
        start=card.get_center()+Vector2(0,41)
        end=Vector2(target.end.x,centre.y)
        points=PackedVector2Array([start,Vector2(555,start.y),Vector2(555,end.y),end])
    var accent:Color=Color("ffdb91")
    draw_polyline(points,Color("153341"),5,true)
    if row.category=="defence":
        for i in points.size()-1:draw_dashed_line(points[i],points[i+1],accent,2,5,true)
        for edge in [PackedVector2Array([target.position,Vector2(target.end.x,target.position.y)]),PackedVector2Array([Vector2(target.end.x,target.position.y),target.end]),PackedVector2Array([target.end,Vector2(target.position.x,target.end.y)]),PackedVector2Array([Vector2(target.position.x,target.end.y),target.position])]:draw_dashed_line(edge[0],edge[1],accent,2,4,true)
    else:
        draw_polyline(points,accent,2,true)
        for corner in [target.position,Vector2(target.end.x,target.position.y),target.end,Vector2(target.position.x,target.end.y)]:
            var sign:Vector2=Vector2(1 if corner.x==target.position.x else -1,1 if corner.y==target.position.y else -1)
            draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),Color("173542"),5,true)
            draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),accent,2,true)
    var badge:Rect2=Rect2(Vector2(target.end.x-29,target.end.y+3),Vector2(32,22))
    if row.category=="defence" and int(row.index)==2:badge.position=target.position+Vector2(-30,14)
    draw_style_box(_locator_badge_style,badge)
    draw_string(_font_strong,badge.position+Vector2(3,16),("武" if row.category=="weapon" else "防")+str(int(row.index)+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,CREAM)
