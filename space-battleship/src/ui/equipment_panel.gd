extends Control
## Slot operations consume owner comparisons/receipts; this view owns no price formula.
signal command_finished(result: Dictionary)
signal exclusive_ui_changed
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const BridgeTheme = preload("res://src/ui/bridge_theme.gd")
const PlayerText = preload("res://src/ui/player_text.gd")
const NAMES = {"laser":"脉冲炮","missile":"导弹","cannon":"舰炮","longLaser":"长激光","armour":"装甲","shield":"护盾","":"空槽"}
const RESOURCE_NAMES = {"1":"铁","2":"铀","chrono":"时空微粒","jewel":"强化碎片","degenerate_matter":"简并物质"}
const INK = Color("193847")
const CREAM = Color("f0f2e9")
const LIGHT = Color("c9ded9")
const CONTROL_FOCUS = Color("e5c784")
const CONTROL_DISABLED_INK = Color("9cb4b4")
const CONTROL_CUT = 5.0
const CARD_WIDTH = 420.0
const EQUIPPED_HEIGHT = 106.0
const EMPTY_HEIGHT = 52.0
const CARD_GAP = 12.0
const CONTENT_PAD = 4.0
var _session
var _font_regular: FontVariation
var _font_medium: FontVariation
var _font_strong: FontVariation
var _catalog: Dictionary
var _weapon_meta: Dictionary
var _textures: Dictionary = {}
var _hulls: Dictionary = {}
var _icons: Dictionary = {}
var _short: Texture2D
var _tall: Texture2D
var _cards: Dictionary = {}
var _facts: Array = []
var _active: Array = []
var _selected: String = ""
var _ship: String = ""
var _ship_origin = Vector2.ZERO
var _ship_factor: float = 1.0
var _ship_zoom: float = 1.0
var _structure_dirty: bool = true
var _values_dirty: bool = true
var _pending_ids: Dictionary = {}
var _budget: Dictionary = {}
var _scene_signature: Array = []
var _scroll: ScrollContainer
var _content: Control
var _body_top: float = 294.0
var _view_height: float = 510.0
var _content_height: float = 0.0
var _scroll_stops: Array[int] = [0]
var _scroll_anchor: int = 0
var _aligning_scroll: bool = false
var _identity: Panel
var _identity_title: Label
var _identity_counts: Label
var _global_quantity: Button
var _batch_open: Button
var _fallback_header: Label
var _popup: Control
var _popup_slot: String = ""
var _batch_mode: int = 0
var _toast: PanelContainer
var _toast_text: Label
var _toast_time: float = 0.0
var _tooltip: PanelContainer
var _tooltip_ticket: int = 0
var _context_caption: Label
var _shared: bool = false
var last_result: Dictionary = {}
var last_comparison: Dictionary = {}
var presentation_counts = {"refreshes":0,"numeric_refreshes":0,"comparison_reads":0,"slots_updated":0,"scene_draws":0,"scene_redraw_requests":0,"economy_signals":0,"economy_same_budget":0,"balance_dependency_changes":0,"comparison_dependency_changes":0,"maximum_reads":0}

func _init(session) -> void:
    _session = session
    custom_minimum_size = Vector2(808,900)
    size = custom_minimum_size
    mouse_filter = Control.MOUSE_FILTER_PASS
    var font = load("res://assets/fonts/NotoSansSC.ttf")
    _font_regular = FontVariation.new(); _font_regular.base_font=font; _font_regular.variation_opentype={2003265652:400.0}
    _font_medium = FontVariation.new(); _font_medium.base_font=font; _font_medium.variation_opentype={2003265652:500.0}
    _font_strong = FontVariation.new(); _font_strong.base_font=font; _font_strong.variation_opentype={2003265652:600.0}
    theme=Theme.new();theme.default_font=_font_regular;theme.default_font_size=15
    _catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/ships/manifest.json")).hulls
    _weapon_meta=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/fleet_20261019/manifest.json")).weapons
    for key in _catalog: _hulls[key]=load(str(_catalog[key].texture))
    for key in _weapon_meta: _textures[key]=load(str(_weapon_meta[key].texture))
    _textures.armour=load("res://assets/ui/equipment/cartoon_armour.svg")
    _textures.shield=load("res://assets/ui/equipment/cartoon_shield.svg")
    for key in _textures:
        var atlas=AtlasTexture.new();atlas.atlas=_textures[key];atlas.region=_textures[key].get_image().get_used_rect();_icons[key]=atlas
    _short=load("res://assets/ui/equipment/hangar/inline-short.png")
    _tall=load("res://assets/ui/equipment/hangar/inline-tall.png")
    _build()
    _budget=_session.economy.budget()
    _session.equipment.slots_changed.connect(func(ids):
        for id in ids:_pending_ids[str(id)]=true)
    _session.equipment.loadout_changed.connect(func():_structure_dirty=true)
    _session.equipment.options_changed.connect(func():_structure_dirty=true)
    _session.equipment.comparison_changed.connect(func():presentation_counts.comparison_dependency_changes+=1;_values_dirty=true)
    _session.campaign_system.ship_changed.connect(func():_structure_dirty=true)
    _session.economy.display_changed.connect(_economy_changed)

func _operation_button(button: Button, role: String="button", compact_card: bool=false, selected: bool=false) -> void:
    BridgeTheme.apply_operation_button(button,"commit" if role=="primary" else "secondary",8,selected)
    # Card controls keep the common material; local content padding supports the new28px controls.
    button.add_theme_font_override("font",_font_strong)
    if compact_card:
        for state in BridgeTheme.PUBLIC_STATES:
            var surface: StyleBox=button.get_theme_stylebox(state)
            surface.content_margin_top=2;surface.content_margin_bottom=2
            button.add_theme_stylebox_override(state,surface)

func _style(fill: Color, edge: Color, thickness: int=1) -> StyleBoxFlat:
    var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge
    style.set_border_width_all(thickness);style.content_margin_left=8;style.content_margin_right=8
    style.content_margin_top=4;style.content_margin_bottom=4
    return style

func _label(parent: Control, value: String, rect: Rect2, font_size: int=15, color: Color=INK, weight: int=500) -> Label:
    var label=Label.new();label.text=value;label.position=rect.position;label.size=rect.size
    label.add_theme_font_override("font",_font_strong if weight==600 else _font_medium if weight==500 else _font_regular)
    label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label

func _button(parent: Control, value: String, rect: Rect2, action: Callable, role: String="button", compact_card: bool=false) -> Button:
    var button=Button.new();button.text=value;button.position=rect.position;button.size=rect.size
    button.add_theme_font_override("font",_font_strong);button.add_theme_font_size_override("font_size",14)
    _operation_button(button,role,compact_card)
    button.size=rect.size
    parent.add_child(button)
    if compact_card:button.set_deferred("size",rect.size)
    button.pressed.connect(action);return button

func _panel(parent: Control, rect: Rect2) -> Panel:
    var panel=Panel.new();panel.position=rect.position;panel.size=rect.size
    panel.add_theme_stylebox_override("panel",_style(Color("173b49"),Color("72969a")))
    parent.add_child(panel);return panel

func _icon(parent: Control, key: String, rect: Rect2) -> TextureRect:
    var icon=TextureRect.new()
    # Set expansion before the texture, so its imported size never queues a
    # minimum-size resize that can outgrow the local choice after it is added.
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture=_icons.get(key);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(icon);icon.position=rect.position;icon.size=rect.size
    return icon

func _build() -> void:
    _fallback_header=_label(self,"装备",Rect2(25,10,220,45),22,CREAM,600)
    _identity=_panel(self,Rect2(16,297,276,72));_identity.mouse_filter=Control.MOUSE_FILTER_PASS
    _identity.add_theme_stylebox_override("panel",BridgeTheme.operation_plate(14))
    _identity_title=_label(_identity,"",Rect2(18,10,240,30),21,INK,600)
    _identity_counts=_label(_identity,"",Rect2(18,40,240,23),14,Color("49636c"),400)
    _global_quantity=_button(self,"×1",Rect2(552,254,64,30),_cycle_global,"button",true)
    _global_quantity.add_theme_font_size_override("font_size",16);_global_quantity.tooltip_text="全部槽位数量"
    _batch_open=_button(self,"全部升级",Rect2(628,254,134,30),_open_batch,"primary",true)
    _scroll=ScrollContainer.new();_scroll.position=Vector2(340,294);_scroll.size=Vector2(434,484)
    _scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    _scroll.focus_mode=Control.FOCUS_ALL;add_child(_scroll)
    _content=Control.new();_content.custom_minimum_size=Vector2(424,484);_scroll.add_child(_content)
    _scroll.get_v_scroll_bar().value_changed.connect(_align_scroll_rows)
    _toast=PanelContainer.new();_toast.position=Vector2(430,207);_toast.size=Vector2(348,44)
    _toast.add_theme_stylebox_override("panel",_style(Color("173b49"),Color("bda56d")))
    _toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;_toast.z_index=90;add_child(_toast)
    _toast_text=_label(_toast,"",Rect2(0,0,348,44),18,Color("f2e5c8"),600)
    _toast_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_toast_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    _toast.hide()
    _tooltip=PanelContainer.new();_tooltip.z_index=80
    _tooltip.add_theme_stylebox_override("panel",_style(Color("173b49"),Color("72969a")))
    _tooltip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_tooltip);_tooltip.hide()

func _ready() -> void:
    process_priority=1;_refresh_structure()

func _economy_changed() -> void:
    presentation_counts.economy_signals+=1
    var next: Dictionary=_session.economy.budget()
    if is_same(next,_budget) or next==_budget:
        presentation_counts.economy_same_budget+=1;return
    _budget=next;presentation_counts.balance_dependency_changes+=1;_values_dirty=true

func _fact(id: String) -> Dictionary:
    for fact in _facts:
        if str(fact.id)==id:return fact
    return {}

func _slot_name(id: String) -> String:
    var parts=id.split(":")
    return ("武器" if parts[0]=="weapon" else "防御")+str(int(parts[1])+1)

func _refresh_structure() -> void:
    _structure_dirty=false;_values_dirty=false;_pending_ids.clear();presentation_counts.refreshes+=1
    _facts=_session.equipment_slot_facts();_active=_facts.filter(func(f):return not f.dormant)
    _ship=str(_session.campaign_system.selected_ship())
    if _selected.is_empty() or _fact(_selected).get("dormant",true):_selected=str(_active[0].id) if not _active.is_empty() else ""
    var early: bool=_active.size()<=2
    _body_top=432 if early else 294
    _content_height=CONTENT_PAD*2+CARD_GAP*maxi(0,_active.size()-1)
    for fact in _active:_content_height+=EMPTY_HEIGHT if str(fact.equipment_id).is_empty() else EQUIPPED_HEIGHT
    _view_height=minf(484,_content_height)
    _scroll.position=Vector2(340,_body_top);_scroll.size=Vector2(434,_view_height)
    _global_quantity.position.y=403 if early else 260;_batch_open.position.y=_global_quantity.position.y
    _global_quantity.disabled=not _session.run_state.is_running();_batch_open.disabled=_global_quantity.disabled
    var display_height: float={"Frigate":260.0,"Destroyer":272.0,"Cruiser":286.0,"Battleship":310.0,"Heavy_Battleship":336.0}.get(_ship,286.0)
    var bottom: float=640.0 if early else 680.0
    _identity.position.y=bottom-display_height-83.0
    var ship_title: String=_ship
    for option in _session.campaign_system.ship_options():
        if option.selected:ship_title=str(option.name)
    _identity_title.text=ship_title
    _identity_counts.text="武器 %s  ·  防御 %s" % [_active.filter(func(f):return f.category=="weapon").size(),_active.filter(func(f):return f.category=="defence").size()]
    for id in _cards:_cards[id].panel.hide()
    var y: float=CONTENT_PAD
    for category in ["weapon","defence"]:
        for fact in _active.filter(func(f):return f.category==category):
            var id: String=str(fact.id)
            if not _cards.has(id):_create_card(id)
            var height: float=EMPTY_HEIGHT if str(fact.equipment_id).is_empty() else EQUIPPED_HEIGHT
            _cards[id].row_y=y;_cards[id].panel.position=Vector2(2,y);_cards[id].panel.size=Vector2(CARD_WIDTH,height)
            _refresh_card(id);y+=height+CARD_GAP
    _configure_scroll_rows()
    _update_visible_cards();_refresh_scene_picture()

func _configure_scroll_rows() -> void:
    var starts: Array[int] = []
    for fact in _active:starts.append(int(_cards[str(fact.id)].row_y-CONTENT_PAD))
    starts.sort()
    var last_start: int=0
    for start in starts:
        # Keep the final complete row group aligned with the same top inset.
        # Spare viewport height belongs below that group, never above it.
        if _content_height-CONTENT_PAD*2-start<=_view_height-CONTENT_PAD*2:
            last_start=start;break
    _scroll_stops.assign(starts.filter(func(start):return start<=last_start))
    if _scroll_stops.is_empty():_scroll_stops.append(0)
    _content_height=maxf(_content_height,last_start+_view_height)
    _content.custom_minimum_size=Vector2(424,_content_height);_content.size=_content.custom_minimum_size
    var retained: int=0
    for start in _scroll_stops:
        if start<=_scroll_anchor:retained=start
    _scroll_anchor=retained
    _aligning_scroll=true;_scroll.scroll_vertical=retained;_aligning_scroll=false
    # ScrollContainer updates its bounds in the following layout pass.
    _scroll.set_deferred("scroll_vertical",retained)

func _align_scroll_rows(value: float) -> void:
    if _aligning_scroll:return
    var requested: int=int(value)
    var target: int=_scroll_anchor
    if requested>_scroll_anchor:
        target=_scroll_stops.back()
        for stop in _scroll_stops:
            if stop>=requested:target=stop;break
    elif requested<_scroll_anchor:
        target=0
        for stop in _scroll_stops:
            if stop>requested:break
            target=stop
    _scroll_anchor=target
    _aligning_scroll=true;_scroll.scroll_vertical=target;_aligning_scroll=false
    _update_visible_cards()

func _create_card(id: String) -> void:
    var panel=Panel.new();panel.name="Card_"+id.replace(":","_");panel.size=Vector2(CARD_WIDTH,EQUIPPED_HEIGHT)
    _content.add_child(panel)
    var icon=_icon(panel,"",Rect2(12,26,44,54))
    var select=_button(panel,"",Rect2(64,10,198,28),_open_choices.bind(id),"button",true)
    select.alignment=HORIZONTAL_ALIGNMENT_LEFT;select.clip_text=true
    _operation_button(select,"button",true,true)
    # This picker is a Button opening the existing Owner-backed choice popup,
    # so consume the shared selected face and the same arrow without changing it
    # into an unrelated OptionButton selection/confirmation flow.
    var arrow=TextureRect.new();arrow.texture=preload("res://assets/ui/public_shell/stepper-down.svg")
    arrow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;arrow.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE;select.add_child(arrow);arrow.position=Vector2(176,8);arrow.size=Vector2(14,12)
    select.add_theme_font_size_override("font_size",16)
    select.size=Vector2(198,28)
    var level=_label(panel,"",Rect2(272,10,68,28),16,INK,600)
    var compare=_button(panel,"比较",Rect2(350,10,58,28),_show_comparison.bind(id,""),"button",true)
    var attribute=RichTextLabel.new();attribute.position=Vector2(72,42);attribute.size=Vector2(336,24)
    attribute.bbcode_enabled=true;attribute.scroll_active=false;attribute.mouse_filter=Control.MOUSE_FILTER_IGNORE
    attribute.add_theme_font_override("normal_font",_font_medium);attribute.add_theme_font_override("bold_font",_font_strong)
    attribute.add_theme_font_size_override("normal_font_size",16);attribute.add_theme_font_size_override("bold_font_size",16)
    panel.add_child(attribute)
    var cost_title=_label(panel,"费用",Rect2(72,70,34,24),16,Color("284650"))
    var fee_area=Control.new();fee_area.position=Vector2(108,70);fee_area.size=Vector2(144,24);panel.add_child(fee_area)
    var quantity=_button(panel,"×1",Rect2(262,68,48,28),_cycle_slot.bind(id),"button",true)
    var purchase=_button(panel,"购买1级",Rect2(322,68,86,28),_buy_slot.bind(id),"primary",true)
    _cards[id]={"panel":panel,"icon":icon,"select":select,"level":level,"compare":compare,"attribute":attribute,"cost_title":cost_title,"fees":fee_area,"fee_cells":[],"fee_cache":{},"fee_empty":null,"fee_reason":null,"border_selected":null,"quantity":quantity,"purchase":purchase,"row_y":0.0,"mode":_batch_mode,"signature":[],"comparison":{}}
    purchase.focus_entered.connect(_select_visual.bind(id));quantity.focus_entered.connect(_select_visual.bind(id))

func _comparison(id: String, candidate: String="") -> Dictionary:
    var row: Dictionary=_cards[id]
    presentation_counts.comparison_reads+=1
    if int(row.mode)==2:presentation_counts.maximum_reads+=1
    return _session.equipment_comparison(id,candidate,10 if int(row.mode)==1 else 1,int(row.mode)==2)

func _value(value) -> String:
    if value==null:return "—"
    return PlayerText.number(str(value.primary)) if value.get("status")=="known" and value.get("primary")!=null else "—" if value.get("status")=="empty" else "未知"

func _refresh_card(id: String) -> void:
    var fact: Dictionary=_fact(id)
    if fact.is_empty():return
    var row: Dictionary=_cards[id]
    var empty: bool=str(fact.equipment_id).is_empty()
    for control in [row.level,row.compare,row.attribute,row.cost_title,row.fees,row.quantity,row.purchase]:
        control.visible=not empty
    row.select.text=str(NAMES.get(str(fact.equipment_id),"装备"))
    row.select.tooltip_text=row.select.text
    row.icon.texture=_icons.get(str(fact.equipment_id))
    if empty:
        row.comparison={};row.signature=[];row.fee_cells=[]
        row.select.disabled=not _session.run_state.is_running()
        row.purchase.disabled=true;row.quantity.disabled=true
        if id==_selected:last_comparison={}
        _card_border(id)
        return
    var comparison: Dictionary=_comparison(id,str(fact.equipment_id))
    if id==_selected:last_comparison=comparison
    if not comparison.get("ok",false):
        row.purchase.disabled=true;row.quantity.disabled=true;row.select.disabled=true;row.compare.disabled=true
        return
    row.comparison=comparison;row.compare.disabled=false
    var quote: Dictionary=comparison.get("quote",{})
    var reason: String=str(comparison.get("payment_reason",comparison.get("reason","Unknown")))
    if int(row.mode)==2 and reason=="NoChange":
        var next_quote: Dictionary=_session.equipment.quote_slot(id,1)
        if not next_quote.get("ok",false):reason=str(next_quote.get("reason",reason))
    var individual: Dictionary={}
    for resource in quote.get("costs",{}):
        individual[resource]=_session.economy.can_pay({resource:quote.costs[resource]},_budget).get("ok",false)
    var signature: Array=[fact.equipment_id,fact.paid_level,row.mode,comparison,individual,_session.run_state.is_running()]
    if row.signature==signature:return
    row.signature=signature;presentation_counts.slots_updated+=1
    row.icon.texture=_icons.get(str(fact.equipment_id))
    row.select.text=str(NAMES.get(str(fact.equipment_id),"装备"))
    row.select.tooltip_text=row.select.text
    row.level.text="Lv."+str(fact.paid_level)
    var primary: String="攻击力" if fact.category=="weapon" else "容量"
    var current_ink: String=BridgeTheme.number_role_color("current","light").to_html(false)
    var gain_ink: String=BridgeTheme.number_role_color("gain","light").to_html(false)
    row.attribute.text="[color=#284650]"+primary+"  [/color][color=#"+current_ink+"]"+_value(comparison.get("current"))+"[/color][color=#49636c] → [/color][b][color=#"+gain_ink+"]"+_value(comparison.get("upgrade"))+"[/color][/b]"
    row.attribute.tooltip_text=row.attribute.get_parsed_text()
    row.quantity.text=["×1","×10","MAX"][int(row.mode)]
    row.purchase.text="购买%s级" % str(quote.count) if quote.get("ok",false) else "可购0级" if reason=="NoChange" and int(row.mode)==2 else "购买"
    var budget_rejection: bool=reason=="InsufficientResources" or (reason=="NoChange" and int(row.mode)==2)
    row.purchase.disabled=not _session.run_state.is_running() or not comparison.get("ok",false) or (not quote.get("ok",false) and not budget_rejection)
    row.quantity.disabled=not _session.run_state.is_running();row.select.disabled=not _session.run_state.is_running()
    _render_fees(id,quote,reason,budget_rejection)
    _card_border(id)

func _render_fees(id: String, quote: Dictionary, reason: String, budget_rejection: bool) -> void:
    var row: Dictionary=_cards[id]
    var values: Array=[];var total: float=0.0
    var costs: Dictionary=quote.get("costs",{}) if quote.get("ok",false) else {}
    for resource in costs:
        var name: String=str(RESOURCE_NAMES.get(str(resource),str(resource)))
        var displayed: Dictionary=_session.amount_api.apply("to_display",[costs[resource]])
        var raw: String=str(displayed.text) if displayed.get("ok",false) else "未知"
        var number: String=PlayerText.resource_number(raw) if displayed.get("ok",false) else "未知"
        var can_pay: Dictionary=_session.economy.can_pay({resource:costs[resource]},_budget)
        values.append({"id":str(resource),"name":name,"number":number,"raw":raw,"poor":not can_pay.ok})
        total+=24+_font_medium.get_string_size(name+number,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+4+12
    var omit_names: bool=total-12>row.fees.size.x
    for cached in row.fee_cache.values():cached.control.hide()
    if is_instance_valid(row.fee_empty):row.fee_empty.hide()
    if is_instance_valid(row.fee_reason):row.fee_reason.hide()
    row.fee_cells=[]
    var x: float=0.0
    for value in values:
        var name_caption: String="" if omit_names else value.name
        var name_width: float=_font_medium.get_string_size(name_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
        var number_width: float=_font_medium.get_string_size(value.number,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
        var name_gap: float=4.0 if not name_caption.is_empty() else 0.0
        var width: float=24+name_width+name_gap+number_width
        if not row.fee_cache.has(value.id):
            var created=Control.new();created.mouse_filter=Control.MOUSE_FILTER_PASS;row.fees.add_child(created)
            var icon=TextureRect.new();icon.texture=ResourceVisuals.icon(value.id);icon.modulate=ResourceVisuals.icon_modulate(value.id)
            icon.position=Vector2(0,2);icon.size=Vector2(20,20);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.size=Vector2(20,20);created.add_child(icon)
            var name_label=_label(created,"",Rect2(24,0,100,24),16,Color("1e3e4c"))
            var label=_label(created,"",Rect2(24,0,190,24),16)
            created.mouse_entered.connect(_schedule_tooltip.bind(id,created));created.mouse_exited.connect(_hide_tooltip)
            row.fee_cache[value.id]={"control":created,"name_label":name_label,"label":label}
        var cached: Dictionary=row.fee_cache[value.id]
        var cell: Control=cached.control
        cell.position=Vector2(x,0);cell.size=Vector2(width,24);cell.show()
        cached.name_label.text=name_caption;cached.name_label.size.x=name_width
        cached.label.text=value.number;cached.label.position.x=24+name_width+name_gap;cached.label.size.x=number_width
        BridgeTheme.apply_number_role(cached.label,"insufficient" if value.poor else "cost","light")
        var full: String=value.name+" · "+value.raw
        cell.set_meta("resource_tooltip",full)
        row.fee_cells.append({"control":cell,"resource":value.id,"poor":value.poor,"name_omitted":omit_names,"full_text":full})
        x+=width+12
    if values.is_empty():
        if not is_instance_valid(row.fee_empty):row.fee_empty=_label(row.fees,"—",Rect2(0,0,20,24),16)
        row.fee_empty.show()
        if not reason.is_empty() and not budget_rejection:
            row.fee_empty.hide()
            if not is_instance_valid(row.fee_reason):
                row.fee_reason=_label(row.fees,"",Rect2(0,0,144,24),16,Color("903d23"))
                row.fee_reason.clip_text=true
                row.fee_reason.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
            row.fee_reason.text="进化材料尚未开放" if reason=="EvolutionMaterialLocked" else _failure_text(reason)
            row.fee_reason.tooltip_text=row.fee_reason.text;row.fee_reason.show()

func _card_border(id: String) -> void:
    var chosen: bool=id==_selected
    if _cards[id].border_selected==chosen:return
    _cards[id].border_selected=chosen
    var face: StyleBox=BridgeTheme.operation_plate(8)
    face.state="selected" if chosen else "normal"
    _cards[id].panel.add_theme_stylebox_override("panel",face)

func _select_visual(id: String) -> void:
    if _selected==id:return
    var old: String=_selected;_selected=id
    if _cards.has(old):_card_border(old)
    _card_border(id);last_comparison=_cards[id].comparison;_refresh_scene_picture()

func select_slot(id: String) -> void:
    if _cards.has(id):_select_visual(id)

func _cycle_slot(id: String) -> void:
    _select_visual(id);_cards[id].mode=(int(_cards[id].mode)+1)%3;_refresh_card(id)

func _cycle_global() -> void:
    _apply_global_quantity((_batch_mode+1)%3)

func _apply_global_quantity(mode: int) -> void:
    if not _session.run_state.is_running():return
    _batch_mode=mode;_global_quantity.text=["×1","×10","MAX"][mode]
    for row in _cards.values():row.mode=mode
    # Only quantity-dependent quotes change; no Owner command or scene rebuild.
    for fact in _active:_refresh_card(str(fact.id))

func _update_visible_cards() -> void:
    var top: float=_scroll.scroll_vertical
    for fact in _active:
        var id: String=str(fact.id);var row: Dictionary=_cards[id]
        var y: float=float(row.row_y)
        var full: bool=y>=top and y+row.panel.size.y<=top+_view_height
        row.panel.visible=full
        if not full:
            var focus: Control=get_viewport().gui_get_focus_owner() if is_inside_tree() else null
            if focus!=null and row.panel.is_ancestor_of(focus):focus.release_focus();_scroll.grab_focus()
            if _popup_slot==id:_close_popup()
    _hide_tooltip()

func _schedule_tooltip(_id: String, cell: Control) -> void:
    _tooltip_ticket+=1;var ticket: int=_tooltip_ticket
    get_tree().create_timer(.5,false).timeout.connect(func():
        if ticket!=_tooltip_ticket or not is_instance_valid(cell) or not cell.is_visible_in_tree() or not is_visible_in_tree():return
        for child in _tooltip.get_children():child.queue_free()
        var text: String=str(cell.get_meta("resource_tooltip",""))
        var label=_label(_tooltip,text,Rect2(0,0,280,28),15,CREAM)
        label.custom_minimum_size=Vector2(_font_medium.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+20,32)
        var point: Vector2=cell.global_position-global_position
        _tooltip.position=Vector2(clampf(point.x,345,778-label.custom_minimum_size.x),clampf(point.y-43,90,842))
        _tooltip.show())

func _hide_tooltip() -> void:
    _tooltip_ticket+=1
    if is_instance_valid(_tooltip):_tooltip.hide()

func _show_toast(text: String, persistent: bool=false) -> void:
    _toast_text.text=text;_toast_time=-1.0 if persistent else 1.8;_toast.show()

func _new_popup(slot: String, height: float) -> Panel:
    _close_popup();_popup_slot=slot
    _popup=Control.new();_popup.size=Vector2(808,900);_popup.z_index=50;add_child(_popup)
    var blocker=ColorRect.new();blocker.color=Color(0,0,0,.08);blocker.size=Vector2(808,900);blocker.mouse_filter=Control.MOUSE_FILTER_STOP
    _popup.add_child(blocker);blocker.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:_close_popup())
    var y: float=(900-height)*.5
    if _cards.has(slot):
        var anchor: float=_body_top+float(_cards[slot].row_y)-_scroll.scroll_vertical
        y=anchor+46 if anchor+46+height<=minf(880,_body_top+_view_height) else maxf(100,anchor-height-4)
    var panel=_panel(_popup,Rect2(392,y,386,height));panel.mouse_filter=Control.MOUSE_FILTER_STOP
    _button(panel,"×",Rect2(344,6,32,28),_close_popup)
    exclusive_ui_changed.emit();return panel

func _close_popup() -> void:
    if is_instance_valid(_popup):
        _popup.hide();_popup.queue_free();_popup=null;_popup_slot="";exclusive_ui_changed.emit()
    _hide_tooltip()

func _open_choices(id: String) -> void:
    _select_visual(id)
    var options: Array=_session.equipment.panel_equipment(id).filter(func(option):return option.enabled and not str(option.id).is_empty())
    var panel=_new_popup(id,42+options.size()*94)
    _label(panel,"选择装备" if str(_fact(id).equipment_id).is_empty() else str(NAMES.get(str(_fact(id).equipment_id),"装备"))+"  Lv."+str(_fact(id).paid_level),Rect2(14,8,320,24),16,CREAM,600)
    for i in options.size():
        var option: Dictionary=options[i];var y: float=42+i*94
        var key: String=str(option.id)
        var current: bool=key==str(_fact(id).equipment_id)
        var choice=_button(panel,"",Rect2(8,y,268,84),_equip_choice.bind(id,key))
        choice.set_meta("equipment_id",key)
        for state in ["normal","hover","pressed","disabled"]:
            var face: StyleBox=BridgeTheme.operation_plate(8)
            face.state="selected" if current else state
            choice.add_theme_stylebox_override(state,face)
        _icon(choice,key,Rect2(10,15,42,54))
        _label(choice,str(NAMES.get(key,option.name)),Rect2(64,6,194,27),18,INK,600)
        if current:_label(choice,"现装",Rect2(194,8,62,24),14,Color("326272"))
        var owner_value: Dictionary=_session.equipment_comparison(id,key,1,false).get("candidate",{})
        _label(choice,("攻击力 " if id.begins_with("weapon:") else "容量 ")+_value(owner_value),Rect2(64,33,194,25),15,INK)
        if owner_value.get("properties",{}).has("interval_seconds"):
            _label(choice,"周期 "+str(owner_value.properties.interval_seconds)+"秒",Rect2(64,57,194,23),15,INK)
        _button(panel,"比较",Rect2(286,y,90,84),_show_comparison.bind(id,str(option.id)))
    var first: Control=panel.get_child(2) if panel.get_child_count()>2 else null
    if first!=null and first is Button:first.grab_focus()

func _show_comparison(id: String, candidate: String) -> void:
    if not _session.run_state.is_running():return
    _select_visual(id)
    var fact: Dictionary=_fact(id)
    var choice: String=str(fact.equipment_id) if candidate.is_empty() else candidate
    var compared: Dictionary=_comparison(id,choice)
    var panel=_new_popup(id,238)
    _label(panel,str(NAMES.get(str(fact.equipment_id),"空槽"))+" 属性比较",Rect2(14,8,320,26),16,CREAM,600)
    var values: Array=[compared.get("current"),compared.get("upgrade") if candidate.is_empty() else compared.get("candidate")]
    for i in 2:
        var value=values[i]
        var background=_panel(panel,Rect2(10,46+i*90,366,82));background.add_theme_stylebox_override("panel",BridgeTheme.operation_plate(8))
        var key: String=str(value.get("equipment_id",choice)) if value is Dictionary else choice
        _icon(background,key,Rect2(12,13,44,54))
        _label(background,("当前" if i==0 else "升级后" if candidate.is_empty() else "候选")+" · "+str(NAMES.get(key,"空槽")),Rect2(72,8,285,24),16,INK,600)
        _label(background,_value(value),Rect2(72,36,285,25),18,INK,600)
        if fact.category=="weapon" and value is Dictionary and value.get("properties",{}).has("interval_seconds"):
            _label(background,"周期 "+str(value.properties.interval_seconds)+"秒",Rect2(228,54,130,22),14,INK)

func _equip_choice(id: String, candidate: String) -> void:
    _select_visual(id);_close_popup()
    if candidate==str(_fact(id).get("equipment_id","")):return
    var result: Dictionary=_session.equipment.equip_slot(id,candidate,_session.equipment_inputs(),_session.publish_equipment_refit)
    _accept_result(result,false)

func _buy_slot(id: String) -> void:
    _select_visual(id)
    var mode: int=int(_cards[id].mode);var inputs: Dictionary=_session.equipment_inputs()
    var result: Dictionary=_session.equipment.buy_max_levels(id,inputs,_session.economy.affordable,_session.economy.payment,_session.publish_equipment_levels) if mode==2 else _session.equipment.buy_levels(id,10 if mode==1 else 1,inputs,_session.economy.payment,_session.publish_equipment_levels)
    if not result.get("ok",false) and str(result.get("reason",""))=="InsufficientResources":_show_toast("资源不足")
    elif not result.get("ok",false) and mode==2 and str(result.get("reason",""))=="NoChange":
        var next_quote: Dictionary=_session.equipment.quote_slot(id,1)
        _show_toast("资源不足" if next_quote.get("ok",false) else _failure_text(str(next_quote.get("reason","NoChange"))))
    _accept_result(result,true)

func _accept_result(result: Dictionary, levels: bool) -> void:
    last_result=result.duplicate(true)
    if result.get("ok",false):
        _toast.hide();_toast_time=0.0
    var receipt: Dictionary=result.get("purchase_receipt",{})
    var unknown: bool=str(receipt.get("commit_status",""))=="fault_unknown" or (result.get("fault",false) and str(receipt.get("commit_status",""))!="accepted")
    if not result.get("ok",false) and str(result.get("reason","")) not in ["InsufficientResources","NoChange","EquipmentLocked","EvolutionMaterialLocked","FirstDefenceRequired"]:
        _log_failure(result)
    if unknown:
        _close_popup();_show_toast("操作失败，当前游戏已停止。",true);_values_dirty=true
        _global_quantity.disabled=true;_batch_open.disabled=true
    elif not result.get("ok",false):
        if not _session.run_state.is_running():
            _close_popup();_show_toast("操作失败，当前游戏已停止。",true)
            _global_quantity.disabled=true;_batch_open.disabled=true
        elif str(result.get("reason","")) not in ["InsufficientResources","NoChange"]:_show_toast(_failure_text(str(result.get("reason",""))))
        _values_dirty=true
    elif levels:
        for purchase in receipt.get("purchases",[]):_pending_ids[str(purchase.slot_id)]=true
    else:_structure_dirty=true
    command_finished.emit(last_result)

func _failure_text(reason: String) -> String:
    return str({"EquipmentLocked":"装备尚未开放。","EvolutionMaterialLocked":"进化材料尚未开放。",
        "FirstDefenceRequired":"首个防御槽需要保留装备。","InsufficientResources":"资源不足。",
        "NoChange":"没有可升级的装备。"}.get(reason,"操作失败。"))

func _diagnostic_code(value: Variant) -> String:
    # Log symbolic cause codes only: never dump payloads, balances, paths or secrets.
    var code: String=str(value)
    return "none" if code.is_empty() else code if code.length()<=96 and code.is_valid_identifier() else "redacted"

func _log_failure(result: Dictionary) -> void:
    var receipt: Dictionary=result.get("purchase_receipt",{})
    print("EQUIPMENT_COMMAND_FAILURE ",JSON.stringify({"reason":_diagnostic_code(result.get("reason","none")),
        "error":_diagnostic_code(result.get("error","none")),"fault":bool(result.get("fault",false)),
        "commit_status":_diagnostic_code(receipt.get("commit_status","none")),
        "running":_session.run_state.is_running(),"stop_reason":_diagnostic_code(_session.run_state.reason())}))

func _open_batch() -> void:
    var panel=_new_popup("",minf(700,130+_active.size()*48))
    _label(panel,"全部槽位升级",Rect2(14,8,320,26),18,CREAM,600)
    for i in _active.size():
        var fact: Dictionary=_active[i]
        _label(panel,str(NAMES.get(str(fact.equipment_id),"空槽"))+"  槽位Lv."+str(fact.paid_level),Rect2(16,45+i*48,350,30),15,CREAM)
    _button(panel,["每槽 ×1","每槽 ×10","逐槽 MAX"][_batch_mode],Rect2(16,panel.size.y-48,145,36),_cycle_batch)
    var submit=_button(panel,"执行升级",Rect2(174,panel.size.y-48,196,36),_buy_all,"primary")
    submit.disabled=not _session.run_state.is_running()

func _cycle_batch() -> void:
    _apply_global_quantity((_batch_mode+1)%3);_open_batch()

func _buy_all() -> void:
    var result: Dictionary=_session.equipment.buy_all_levels(10 if _batch_mode==1 else 1,_batch_mode==2,_session.equipment_inputs(),_session.economy.affordable,_session.economy.payment,_session.publish_equipment_levels)
    _accept_result(result,true)
    if not _session.run_state.is_running():return
    if result.get("ok",false):_close_popup()
    elif str(result.get("reason",""))=="NoChange":
        # The batch owner reports no accepted slot, rather than a per-slot error.
        # Read existing admission/payment facts only after that actual response.
        var rejection: String="NoChange"
        var budget: Dictionary=_session.economy.budget()
        for fact in _active:
            var quote: Dictionary=_session.equipment.quote_slot(str(fact.id),1)
            if quote.get("ok",false):
                if not _session.economy.can_pay(quote.costs,budget).get("ok",false):
                    rejection="InsufficientResources";break
            elif rejection=="NoChange":rejection=str(quote.get("reason","NoChange"))
        _show_toast("资源不足" if rejection=="InsufficientResources" else "进化材料尚未开放" if rejection=="EvolutionMaterialLocked" else _failure_text(rejection))

func _refresh_scene_picture() -> void:
    var signature: Array=[_ship,_selected,_active.map(func(f):return [f.id,f.equipment_id])]
    if signature==_scene_signature:return
    _scene_signature=signature;presentation_counts.scene_redraw_requests+=1;queue_redraw()

func _process(dt: float) -> void:
    if not is_visible_in_tree():return
    if _toast_time>0:
        _toast_time-=dt
        if _toast_time<=0:_toast.hide()
    if _structure_dirty:_refresh_structure()
    elif _values_dirty:
        _values_dirty=false;_budget=_session.economy.budget();presentation_counts.numeric_refreshes+=1
        if not _pending_ids.is_empty():
            _facts=_session.equipment_slot_facts();_active=_facts.filter(func(f):return not f.dormant);_pending_ids.clear()
        for fact in _active:_refresh_card(str(fact.id))
    elif not _pending_ids.is_empty():
        _facts=_session.equipment_slot_facts();presentation_counts.numeric_refreshes+=1
        for id in _pending_ids:
            if _cards.has(id):_refresh_card(id)
        _pending_ids.clear()

func _draw() -> void:
    presentation_counts.scene_draws+=1
    if not _shared:draw_rect(Rect2(0,0,808,85),Color("173b49"))
    var early: bool=_active.size()<=2
    draw_texture_rect(_short if early else _tall,Rect2(-27,85,843.2,815),false)
    _draw_console_detail(early)
    if not _hulls.has(_ship):return
    var texture: Texture2D=_hulls[_ship];var bounds: Rect2=texture.get_image().get_used_rect()
    var height: float={"Frigate":260.0,"Destroyer":272.0,"Cruiser":286.0,"Battleship":310.0,"Heavy_Battleship":336.0}.get(_ship,286.0)
    _ship_factor=minf(314.0/bounds.size.x,height/bounds.size.y)
    var allocation: Rect2=Rect2(16,(640 if early else 680)-height,314,height)
    _ship_origin=allocation.position+(allocation.size-bounds.size*_ship_factor)*.5-bounds.position*_ship_factor
    _ship_zoom=_ship_factor/(350.0/float(_catalog[_ship].height))
    draw_texture_rect(texture,Rect2(_ship_origin,texture.get_size()*_ship_factor),false)
    for fact in _active:
        var key: String=str(fact.equipment_id)
        if fact.category!="weapon" or key.is_empty() or not _weapon_meta.has(key):continue
        var meta: Dictionary=_weapon_meta[key]
        var factor: float=(.16 if key in ["longLaser","cannon"] else .13)*_ship_zoom
        var mount: Vector2=_ship_origin+Vector2(_catalog[_ship].mounts[int(fact.index)][0],_catalog[_ship].mounts[int(fact.index)][1])*_ship_factor
        var origin: Vector2=mount-Vector2(meta.anchor[0],meta.anchor[1])*factor
        var weapon: Texture2D=_textures[key]
        draw_texture_rect(weapon,Rect2(origin,weapon.get_size()*factor),false)
        if str(fact.id)==_selected:
            var used: Rect2=weapon.get_image().get_used_rect()
            var target: Rect2=Rect2(origin+used.position*factor,used.size*factor).grow(4)
            for corner in [target.position,Vector2(target.end.x,target.position.y),target.end,Vector2(target.position.x,target.end.y)]:
                var direction=Vector2(1 if corner.x==target.position.x else -1,1 if corner.y==target.position.y else -1)
                var points=PackedVector2Array([corner+Vector2(0,direction.y*8),corner,corner+Vector2(direction.x*8,0)])
                draw_polyline(points,Color("153341"),3.5,true);draw_polyline(points,Color("91e2d4"),1.5,true)

func _draw_console_detail(early: bool) -> void:
    # Recessed machining marks, fully inside the console face; no status meaning.
    var y: float=418.0 if early else 275.0
    var shadow: Color=Color("728b89")
    var highlight: Color=Color("c4cebd")
    for i in 5:
        var x: float=359.0+i*9.0
        draw_line(Vector2(x,y-5),Vector2(x+5,y+5),shadow,1.0,true)
        draw_line(Vector2(x+1,y-5),Vector2(x+6,y+5),highlight,1.0,true)
    draw_polyline(PackedVector2Array([Vector2(418,y+4),Vector2(470,y+4),Vector2(478,y-4),Vector2(524,y-4)]),shadow,1.0,true)
    draw_circle(Vector2(418,y+4),2.0,shadow,false,1.0,true)
    draw_circle(Vector2(524,y-4),2.0,shadow,false,1.0,true)
    var bottom: float=670.0 if early else 792.0
    draw_line(Vector2(380,bottom),Vector2(514,bottom),shadow,1.0,true)
    draw_line(Vector2(590,bottom),Vector2(724,bottom),shadow,1.0,true)
    for i in 3:
        var center: Vector2=Vector2(540+i*12,bottom)
        draw_polyline(PackedVector2Array([center+Vector2(-3,0),center+Vector2(0,-2),center+Vector2(3,0),center+Vector2(0,2),center+Vector2(-3,0)]),shadow,1.0,true)

func set_shared_host(enabled: bool, context_slot: Control, _backdrop: Texture2D=null) -> void:
    _shared=enabled;_fallback_header.visible=not enabled
    _release_host_context()
    if enabled and is_instance_valid(context_slot):
        _context_caption=Label.new();_context_caption.text="装备";_context_caption.size=Vector2(96,26)
        _context_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;context_slot.add_child(_context_caption)
    queue_redraw()

func has_exclusive_ui() -> bool:
    return is_instance_valid(_popup) and _popup.visible

func prepare_host_hide(force: bool=false) -> bool:
    if has_exclusive_ui() and not force:return false
    if force:_close_popup()
    _hide_tooltip()
    var focus: Control=get_viewport().gui_get_focus_owner()
    if focus!=null and is_ancestor_of(focus):focus.release_focus()
    return true

func _release_host_context() -> void:
    if is_instance_valid(_context_caption):_context_caption.queue_free()
    _context_caption=null

func _exit_tree() -> void:
    _release_host_context()
