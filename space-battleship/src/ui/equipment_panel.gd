extends Control
## Equipment owns all prices, admission and receipts; this scene owns only presentation.
signal command_finished(result: Dictionary)
signal exclusive_ui_changed
var _shared_chrome: Array = []
var _context_slot: Control
var _context_caption: Label
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
var _slot_groups: Dictionary = {}
var _slot_backdrops: Dictionary = {}
var _icon_textures: Dictionary = {}
var _icon_centres: Dictionary = {}
var _current_icon_geometry: Dictionary = {}
var _workbench: Panel
var _workbench_divider: ColorRect
var _upgrade_data: Panel
var _icon_bezel: Panel
var _transaction_rail: Panel
var _workbench_layout: Dictionary = {}
var _receipt_toast: Panel
var _receipt_toast_remaining: float = 0.0
var _receipt_history_button: Button
var _receipt_history_popup: PopupPanel
var _receipt_history_label: Label
var _receipt_history: Array[String] = []
var _candidate_row: Control
var _comparison_group: Control
var _period_caption: Label
var _upgrade_section_title: Label
var _defence_scope: bool = false
var _hull_visible_bounds: Dictionary = {}
var _preview_rects: Dictionary = {}
var _preview_zooms: Dictionary = {}
var _preview_reference: Dictionary = {}
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
var _cost_cells: Dictionary = {}
var _payment_state: Label
var _level_label: Label
var _compare_headers: Array = []
var _compare_values: Array = []
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
    var largest_reference:float=0.0
    for key in _catalog:
        _hull_textures[key]=load(str(_catalog[key].texture))
        _hull_visible_bounds[key]=_hull_textures[key].get_image().get_used_rect()
        # Read the existing public visual-geometry output once; do not duplicate or change battle parameters.
        var inputs:Dictionary=_session.battle.mount_inputs(key)
        var image:Image=load(str(inputs.art.texture)).get_image()
        var reference_height:float=inputs.dimensions.y*image.get_used_rect().size.y/image.get_height()
        _preview_reference[key]={"height":reference_height,"source":str(inputs.art.texture)}
        largest_reference=maxf(largest_reference,reference_height)
    for key in _catalog:
        var visible:Rect2=Rect2(_hull_visible_bounds[key])
        var height:float=320.0*_preview_reference[key].height/largest_reference
        var factor:float=height/visible.size.y
        # The pad's front docking line is authored in the hangar source; each hull uses its visible aft anchor.
        var dock_source:=Vector2(594,730)
        var dock_target:=Vector2(dock_source.x*808.0/1188.0,85.0+dock_source.y*600.0/845.0)
        var aft:=Vector2(visible.get_center().x,visible.end.y)
        _preview_rects[key]=Rect2(dock_target-aft*factor,Vector2(768,768)*factor)
        _preview_reference[key].dock_source=dock_source
        _preview_reference[key].dock_target=dock_target
        _preview_reference[key].aft_source=aft
        # 350 only converts the existing authored weapon calibration; it is no longer a per-ship target fit.
        _preview_zooms[key]=factor/(350.0/float(_catalog[key].height))
        _preview_reference[key].preview_height=height
        _preview_reference[key].canvas_scale=factor
    for key in _weapon_meta:
        _textures[key] = load(str(_weapon_meta[key].texture))
        _weapon_visible_bounds[key]=_textures[key].get_image().get_used_rect()
    _textures.shield = load("res://assets/ui/equipment/cartoon_shield.svg")
    _textures.armour = load("res://assets/ui/equipment/cartoon_armour.svg")
    # Cache visible-only thumbnail regions once; formal scene textures and mount anchors stay intact.
    for key in _textures:
        var texture: Texture2D = _textures[key]
        var thumbnail := AtlasTexture.new()
        thumbnail.atlas = texture
        var pixels: Image = texture.get_image()
        thumbnail.region = pixels.get_used_rect()
        _icon_textures[key] = thumbnail
        # A small initialization-only alpha sample records optical mass, not the PNG canvas centre.
        var sample: Image = pixels.get_region(Rect2i(thumbnail.region))
        sample.resize(32,32,Image.INTERPOLATE_BILINEAR)
        var weighted:=Vector2.ZERO
        var mass:float=0.0
        for y in 32:
            for x in 32:
                var alpha:float=sample.get_pixel(x,y).a
                weighted+=Vector2(x+0.5,y+0.5)*alpha
                mass+=alpha
        _icon_centres[key]=weighted/(mass*32.0) if mass>0.0 else Vector2(0.5,0.5)
    _background = load("res://assets/ui/equipment/hangar/hangar-console.png")
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
            var material:=_style(fill,edge,1)
            material.set_corner_radius_all(5 if form=="candidate" else 6)
            material.border_width_top=2
            material.border_width_bottom=2 if state!="pressed" else 1
            material.shadow_color=Color("102b38",0.45);material.shadow_size=1;material.shadow_offset=Vector2(0,2 if state!="pressed" else 0)
            if form=="slot":
                material.bg_color=Color(0,0,0,0) if state=="normal" else Color(0.65,0.95,0.86,0.16) if state=="hover" else Color(0.02,0.09,0.13,0.35) if state=="pressed" else Color(0.15,0.20,0.22,0.5)
                material.set_border_width_all(0);material.shadow_size=0
                material.expand_margin_left=-15;material.expand_margin_right=-15;material.expand_margin_top=-12;material.expand_margin_bottom=-26
            if form=="index":
                material.bg_color=Color(0,0,0,0) if not selected else Color(0.12,0.39,0.41,0.88)
                material.border_color=Color(0.47,0.77,0.75,0.18) if not selected else Color("97e2d4")
                material.set_border_width_all(1 if selected else 0)
                material.set_corner_radius_all(4)
                material.shadow_size=0
                if state=="hover":material.bg_color=Color(0.15,0.38,0.41,0.8)
                elif state=="pressed":material.bg_color=Color("153c49")
            if form=="candidate":
                material.shadow_size=0
                material.set_border_width_all(1)
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
    image.texture = _icon_textures.get(key)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.position = rect.position
    image.size = rect.size
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(image)
    return image

func _build() -> void:
    _shared_chrome.append(_label("远航舰桥",Rect2(24,10,160,34),23))
    _wallet=_label("",Rect2(204,16,590,30),15)
    _shared_chrome.append(_label("战力维护  /  装配",Rect2(24,52,380,28),14,Color("57777a")))
    _title=_label("装配",Rect2(35,104,236,30),18,CREAM)
    _title.add_theme_color_override("font_shadow_color",Color("173542"))
    _title.add_theme_constant_override("shadow_offset_x",1)
    _title.add_theme_constant_override("shadow_offset_y",2)
    _button("全部装备升级",Rect2(614,96,174,49),_open_batch,true).name="BatchOpen"
    for category in ["weapon","defence"]:
        var backing:=Panel.new()
        backing.position=Vector2(24,164);backing.size=Vector2(184,71)
        backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
        var material:=_style(Color(0.06,0.16,0.21,0.78),Color(0,0,0,0),0)
        material.set_corner_radius_all(4)
        backing.add_theme_stylebox_override("panel",material)
        add_child(backing);_slot_backdrops[category]=backing
        _slot_groups[category]=_label("",Rect2(30,170,178,25),15,CREAM)
        _slot_groups[category].add_theme_color_override("font_shadow_color",Color("173542"))
        _slot_groups[category].add_theme_constant_override("shadow_offset_y",1)
    _build_workbench()
    _build_batch()

func _workbench_label(text:String,rect:Rect2,font_size:int=16,color:Color=INK,parent:Control=null) -> Label:
    var label:=_label(text,rect,font_size,color)
    remove_child(label)
    (parent if parent!=null else _workbench).add_child(label)
    return label

func _workbench_button(text:String,rect:Rect2,action:Callable) -> Button:
    var button:=_button(text,rect,action,true)
    remove_child(button);_workbench.add_child(button)
    return button

func _build_workbench() -> void:
    _workbench=Panel.new();_workbench.name="EquipmentWorkbench"
    _workbench.position=Vector2(16,610);_workbench.size=Vector2(776,286)
    _workbench.clip_contents=true;_workbench.mouse_filter=Control.MOUSE_FILTER_PASS
    var body:=_style(Color("e9e7d6"),Color("849a93"),1)
    body.set_corner_radius_all(9);body.shadow_color=Color("102b36",0.35);body.shadow_size=3;body.shadow_offset=Vector2(0,2)
    _workbench.add_theme_stylebox_override("panel",body);add_child(_workbench)
    var header:=Panel.new();header.name="ObjectHeader";header.size=Vector2(776,36);header.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var beam:=_style(Color("244b5b"),Color("244b5b"),0)
    beam.corner_radius_top_left=8;beam.corner_radius_top_right=8;beam.corner_radius_bottom_left=0;beam.corner_radius_bottom_right=0
    header.add_theme_stylebox_override("panel",beam);_workbench.add_child(header)
    _current_title=_workbench_label("现装",Rect2(20,4,250,28),18,CREAM)
    _level_label=_workbench_label("",Rect2(190,7,150,22),13,Color("b8d3ca"))
    _receipt_toast=Panel.new();_receipt_toast.name="ReceiptToast";_receipt_toast.position=Vector2(238,150);_receipt_toast.size=Vector2(340,32)
    _receipt_toast.add_theme_stylebox_override("panel",_style(Color("244b5b"),Color("9bd9be"),1));_receipt_toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_receipt_toast)
    _feedback=_workbench_label("",Rect2(10,4,320,24),13,Color("d9eee2"),_receipt_toast)
    _feedback.clip_text=true;_feedback.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_feedback.mouse_filter=Control.MOUSE_FILTER_PASS
    _receipt_toast.hide()
    _upgrade_section_title=_workbench_label("装备升级",Rect2(20,42,400,24),16)
    _comparison_title=_workbench_label("装备选择",Rect2(460,42,174,24),16)
    _switch_state=_workbench_label("",Rect2(638,46,122,18),12,Color("946338"));_switch_state.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    _workbench_divider=ColorRect.new();_workbench_divider.position=Vector2(440,48);_workbench_divider.size=Vector2(1,110);_workbench_divider.color=Color("b5c3b8");_workbench_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;_workbench.add_child(_workbench_divider)
    _transaction_rail=Panel.new();_transaction_rail.name="PurchaseRail";_transaction_rail.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _transaction_rail.add_theme_stylebox_override("panel",_style(Color("dde3d5"),Color("b5c3b8"),1));_workbench.add_child(_transaction_rail)
    _upgrade_data=Panel.new();var data:Panel=_upgrade_data;data.name="UpgradeValues";data.position=Vector2(100,85);data.size=Vector2(320,80);data.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var glass:=_style(Color("e1e9dc"),Color("b0c0b4"),1);glass.set_corner_radius_all(4);data.add_theme_stylebox_override("panel",glass);_workbench.add_child(data)
    _icon_bezel=Panel.new();var icon_frame:Panel=_icon_bezel;icon_frame.name="CurrentIconBezel";icon_frame.position=Vector2(20,88);icon_frame.size=Vector2(66,61);icon_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var bezel:=_style(Color("eeecda"),Color("a6b9aa"),1);bezel.set_corner_radius_all(4);icon_frame.add_theme_stylebox_override("panel",bezel);_workbench.add_child(icon_frame)
    _large_icon=_icon("laser",Rect2(27,95,52,47),_workbench)
    _current_caption=_workbench_label("当前攻击力",Rect2(114,91,140,18),12,Color("617c78"))
    _upgrade_caption=_workbench_label("升级后",Rect2(290,91,146,18),12,Color("617c78"))
    _current_value=_workbench_label("—",Rect2(114,109,140,38),27)
    _upgrade_arrow=_workbench_label("→",Rect2(257,105,32,32),23,Color("72938d"))
    _next_value=_workbench_label("—",Rect2(290,109,148,38),27,TEAL)
    for value in [_current_value,_next_value]:value.mouse_filter=Control.MOUSE_FILTER_PASS;value.clip_text=true
    _cost=_workbench_label("本次费用",Rect2(22,204,90,25),13,Color("647b75"))
    _payment_state=_workbench_label("",Rect2(278,204,160,25),13,Color("a75a3d"));_payment_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for index in 3:
        var captions: Array=["+1","+10","MAX"]
        var button:=_workbench_button(captions[index],Rect2(18+index*65,240,59,36),func():_maximum=index==2;_quantity=10 if index==1 else 1;_dirty=true)
        button.name="Quantity"+str(index);_quantity_buttons.append(button)
    _purchase=_workbench_button("购买1级",Rect2(226,240,218,36),_buy);_purchase.name="Purchase"
    _purchase.clip_text=true;_purchase.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _candidate_row=Control.new();_candidate_row.name="CandidateChoices";_candidate_row.position=Vector2(464,74);_candidate_row.size=Vector2(296,88);_candidate_row.clip_contents=true;_candidate_row.mouse_filter=Control.MOUSE_FILTER_PASS;_workbench.add_child(_candidate_row)
    _comparison_group=Control.new();_comparison_group.name="DifferentCandidateComparison";_comparison_group.position=Vector2(464,170);_comparison_group.size=Vector2(296,64);_comparison_group.clip_contents=true;_comparison_group.mouse_filter=Control.MOUSE_FILTER_PASS;_workbench.add_child(_comparison_group)
    for column in 2:
        var header_label:=_workbench_label("",Rect2(52+column*124,0,118,18),12,INK if column==0 else TEAL,_comparison_group)
        header_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;header_label.add_theme_font_override("font",_font_strong);_compare_headers.append(header_label)
        var value:=_workbench_label("—",Rect2(52+column*124,18,118,25),17,INK if column==0 else TEAL,_comparison_group)
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.add_theme_font_override("font",_font_strong);_compare_values.append(value)
    _compare_row_label=_workbench_label("攻击力",Rect2(0,18,48,25),12,Color("617c78"),_comparison_group)
    _period_caption=_workbench_label("周期",Rect2(0,43,48,18),12,Color("617c78"),_comparison_group)
    _install=_workbench_button("安装",Rect2(484,220,266,36),_equip);_install.name="Install"
    _receipt_history_button=_workbench_button("最近结果",Rect2(232,208,92,36),_show_receipt_history);_receipt_history_button.name="ReceiptHistory";_receipt_history_button.disabled=true
    _build_receipt_history()

func _text_ink_bounds(text:String, font:Font, font_size:int) -> Rect2:
    var line:=TextLine.new();line.add_string(text,font,font_size)
    var server:=TextServerManager.get_primary_interface()
    var pen:float=0.0
    var bounds:=Rect2()
    for glyph in server.shaped_text_get_glyphs(line.get_rid()):
        for repeat in int(glyph.repeat):
            var rect:=Rect2(Vector2(pen,0)+Vector2(glyph.offset)+server.font_get_glyph_offset(glyph.font_rid,Vector2i(glyph.font_size,0),glyph.index),server.font_get_glyph_size(glyph.font_rid,Vector2i(glyph.font_size,0),glyph.index))
            if rect.has_area():bounds=bounds.merge(rect) if bounds.has_area() else rect
            pen+=float(glyph.advance)
    return bounds

func _place_ink_label(label:Label, centre:Vector2) -> void:
    var font:Font=label.get_theme_font("font");var font_size:int=label.get_theme_font_size("font_size")
    var ink:Rect2=_text_ink_bounds(label.text,font,font_size)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.vertical_alignment=VERTICAL_ALIGNMENT_TOP;label.clip_text=false
    label.size=Vector2(ceilf(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+8,font.get_height(font_size))
    label.position=(centre-ink.get_center()-Vector2(0,font.get_ascent(font_size))).round()

func _layout_workbench(different: bool, defence: bool, resource_count: int) -> void:
    var rows:int=maxi(1,resource_count)
    var signature:Array=[different,defence,rows]
    if _workbench_layout.get("signature",[])==signature:return
    var extra:float=maxi(0,rows-2)*22.0 if different else 0.0
    var height:float=272.0+extra if different else 260.0
    var action_y:float=220.0+extra if different else 208.0
    _workbench.position.y=896.0-height;_workbench.size.y=height
    _workbench_divider.size.y=162.0+extra if different else 110.0
    _upgrade_data.position=Vector2(100,70)
    _icon_bezel.position=Vector2(20,70);_icon_bezel.size=Vector2(66,80)
    _candidate_row.position=Vector2(460,70)
    _comparison_group.position=Vector2(460,166);_comparison_group.size.y=43
    _install.position=Vector2(492,action_y);_install.size=Vector2(258,36)
    for index in _quantity_buttons.size():
        _quantity_buttons[index].position=Vector2(26+index*63,action_y);_quantity_buttons[index].size=Vector2(55,36)
    _purchase.position=Vector2(220 if different else 528,action_y);_purchase.size=Vector2(204 if different else 222,36)
    _receipt_history_button.text="记录" if different else "最近结果"
    _receipt_history_button.position=Vector2(432 if different else 326,action_y);_receipt_history_button.size=Vector2(48 if different else 92,36)
    _transaction_rail.position=Vector2(16,action_y-8);_transaction_rail.size=Vector2(744,52)
    _workbench_layout={"signature":signature,"different":different,"rows":rows,"data_y":70.0,"action_y":action_y,"height":height,"fee_y":166.0}

func _layout_primary_values() -> void:
    var long_values:bool=_text_ink_bounds(_current_value.text,_font_strong,27).size.x>124 or _text_ink_bounds(_next_value.text,_font_strong,27).size.x>124
    var y:float=_workbench_layout.data_y
    _upgrade_arrow.show()
    _upgrade_arrow.text="↓" if long_values else "→";_upgrade_arrow.add_theme_font_size_override("font_size",16 if long_values else 23)
    if long_values:
        _place_ink_label(_current_caption,Vector2(151,y+17));_place_ink_label(_upgrade_caption,Vector2(151,y+63))
        _place_ink_label(_current_value,Vector2(304,y+17));_place_ink_label(_next_value,Vector2(304,y+63))
        var gap_centre_y:float=y+40+(_text_ink_bounds(_current_value.text,_font_strong,27).size.y-_text_ink_bounds(_next_value.text,_font_strong,27).size.y)*0.25
        _place_ink_label(_upgrade_arrow,Vector2(304,gap_centre_y))
    else:
        _place_ink_label(_current_caption,Vector2(174,y+15));_place_ink_label(_upgrade_caption,Vector2(346,y+15))
        _place_ink_label(_current_value,Vector2(174,y+55));_place_ink_label(_next_value,Vector2(346,y+55))
        var gap_centre_x:float=260+(_text_ink_bounds(_current_value.text,_font_strong,27).size.x-_text_ink_bounds(_next_value.text,_font_strong,27).size.x)*0.25
        _place_ink_label(_upgrade_arrow,Vector2(gap_centre_x,y+55))
    _workbench_layout.long_values=long_values

func _place_current_icon(key: String) -> void:
    _large_icon.texture=_icon_textures.get(key)
    if _large_icon.texture==null:
        _current_icon_geometry={}
        return
    var shift:float=float(_workbench_layout.get("data_y",70.0))-77.0
    var safe:=Rect2(27,95+shift,52,47)
    var centre:=Vector2(53,120+shift)
    var mass:Vector2=_icon_centres[key]
    var source:Vector2=_large_icon.texture.get_size()
    var before:Vector2=source*mass
    var after:Vector2=source-before
    var factor:float=minf(minf((centre.x-safe.position.x)/before.x,(safe.end.x-centre.x)/after.x),minf((centre.y-safe.position.y)/before.y,(safe.end.y-centre.y)/after.y))
    _large_icon.size=source*factor
    _large_icon.position=centre-before*factor
    _current_icon_geometry={"key":key,"frame_inner":Rect2(_workbench.global_position+Vector2(21,_workbench_layout.data_y+1),Vector2(64,78)),"safe":Rect2(_workbench.global_position+safe.position,safe.size),"visible_rect":_large_icon.get_global_rect(),"alpha_centre_normalized":mass,"displayed_alpha_centre":_large_icon.global_position+_large_icon.size*mass,"primary_surface_centre_y":_workbench.global_position.y+_workbench_layout.data_y+40,"optical_mass_offset_y":3}

func _render_costs(quote: Dictionary, affordable: bool, reason: String) -> void:
    var keys: Array = quote.get("costs",{}).keys() if quote.get("ok",false) else []
    for id in _cost_cells:_cost_cells[id].name.visible=false;_cost_cells[id].amount.visible=false
    _purchase.tooltip_text=""
    var different:bool=_workbench_layout.different
    var first_row_y:float=_workbench_layout.fee_y
    _cost.text="本次费用";_cost.position=Vector2(20,first_row_y);_cost.size=Vector2(84,22)
    _cost.visible=affordable;_payment_state.visible=not affordable
    _payment_state.position=Vector2(20,first_row_y);_payment_state.size=Vector2(84,22)
    _payment_state.text="" if affordable else _reason(reason);_payment_state.tooltip_text=_payment_state.text
    _payment_state.autowrap_mode=TextServer.AUTOWRAP_OFF;_payment_state.clip_text=true;_payment_state.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_payment_state.mouse_filter=Control.MOUSE_FILTER_PASS
    for index in keys.size():
        var id:String=str(keys[index])
        if not _cost_cells.has(id):
            var name:=_workbench_label("",Rect2(0,0,90,22),13,Color("5f7876"))
            var amount:=_workbench_label("",Rect2(0,0,220,26),17,INK)
            amount.add_theme_font_override("font",_font_strong);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
            _cost_cells[id]={"name":name,"amount":amount}
        var cell:Dictionary=_cost_cells[id]
        var width:float=308.0 if different or keys.size()==1 else (644.0-24.0*(keys.size()-1))/keys.size()
        var x:float=112.0 if different else 112.0+index*(width+24.0)
        var row_y:float=first_row_y+index*22 if different else first_row_y
        cell.name.position=Vector2(x,row_y);cell.name.size=Vector2(78,22)
        cell.amount.position=Vector2(x+82,row_y-3);cell.amount.size=Vector2(width-86,26)
        cell.name.text={"1":"铁","2":"铀","degenerate_matter":"简并物质","jewel":"碎片"}.get(id,id)
        var formatted:Dictionary=_session.amount_api.apply("to_display",[quote.costs[id]])
        cell.amount.text=PlayerText.number(str(formatted.text)) if formatted.ok else "未知"
        cell.amount.add_theme_color_override("font_color",INK if affordable else Color("a1593b"));cell.name.show();cell.amount.show()
    if not quote.get("ok",false):
        _payment_state.position=Vector2(112,first_row_y);_payment_state.size=Vector2(308,22)
        _payment_state.text=_reason(str(quote.get("reason",quote.get("error","Unknown"))))
    elif not affordable:_purchase.tooltip_text=_reason(reason)+"\n"+_cost_text(quote.costs)

func _build_receipt_history() -> void:
    _receipt_history_popup=PopupPanel.new();_receipt_history_popup.title="最近结果";add_child(_receipt_history_popup)
    _receipt_history_popup.add_theme_stylebox_override("panel",_style(Color("173c4b"),Color("91b7aa"),1))
    _receipt_history_popup.visibility_changed.connect(func():exclusive_ui_changed.emit())
    var margin:=MarginContainer.new()
    for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
    _receipt_history_popup.add_child(margin)
    var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);margin.add_child(box)
    var heading:=Label.new();heading.text="最近结果";heading.add_theme_font_override("font",_font_strong);heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",CREAM);box.add_child(heading)
    var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(540,280);box.add_child(scroll)
    _receipt_history_label=Label.new();_receipt_history_label.custom_minimum_size.x=520;_receipt_history_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_receipt_history_label.add_theme_color_override("font_color",CREAM);scroll.add_child(_receipt_history_label)
    var close:=_button("关闭",Rect2(0,0,540,36),_receipt_history_popup.hide);remove_child(close);box.add_child(close)

func _show_receipt_history() -> void:
    _receipt_history_label.text="\n\n".join(_receipt_history)
    _receipt_history_popup.popup(Rect2i(104,230,600,420))

func _hide_receipt_toast() -> void:
    _receipt_toast_remaining=0.0;_receipt_toast.hide()


func _open_batch() -> void:
    # Godot GUI picking uses scene order as well as the visual canvas order.
    move_child(_batch_blocker, get_child_count() - 1)
    move_child(_batch_frame,get_child_count()-1)
    move_child(_batch, get_child_count() - 1)
    _batch_blocker.show()
    _batch_frame.show()
    _batch.show()
    _refresh_batch()
    exclusive_ui_changed.emit()

func _close_batch() -> void:
    _batch_quantity.get_popup().hide()
    _batch.hide()
    _batch_frame.hide()
    _batch_blocker.hide()
    exclusive_ui_changed.emit()

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
    _batch_quantity.get_popup().visibility_changed.connect(func():exclusive_ui_changed.emit())
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
    if id!=_selected:
        _feedback.text="";_feedback.tooltip_text="";_hide_receipt_toast()
    _selected = id
    _selection_open = true
    var fact: Dictionary = _selected_fact()
    _candidate = str(fact.get("equipment_id", ""))
    _dirty = true

func _select_candidate(id: String) -> void:
    if id!=_candidate:
        _feedback.text="";_feedback.tooltip_text="";_hide_receipt_toast()
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
    var scope:bool=fact.category=="defence"
    if scope!=_defence_scope:
        _defence_scope=scope
        _title.add_theme_color_override("font_color",Color("b9e6d7") if scope else CREAM)
    var quote: Dictionary = comparison.quote
    var different:bool=not _candidate.is_empty() and _candidate!=str(fact.equipment_id)
    _layout_workbench(different,scope,quote.get("costs",{}).size() if quote.get("ok",false) else 0)
    _place_current_icon(str(fact.equipment_id))
    _current_title.text = "%s · %s" % [_slot_name(_selected),NAMES.get(str(fact.equipment_id),"装备")]
    _level_label.text = "Lv."+str(fact.paid_level)
    var title_ink:Rect2=_text_ink_bounds(_current_title.text,_current_title.get_theme_font("font"),18)
    var level_ink:Rect2=_text_ink_bounds(_level_label.text,_level_label.get_theme_font("font"),13)
    _place_ink_label(_current_title,Vector2(20+title_ink.size.x*0.5,18))
    _place_ink_label(_level_label,Vector2(32+title_ink.size.x+level_ink.size.x*0.5,18))
    _current_value.text = _value(comparison.current)
    _next_value.text = _value(comparison.upgrade)
    _current_value.tooltip_text=str(comparison.current.primary) if comparison.current is Dictionary and comparison.current.get("primary")!=null else _value(comparison.current)
    _next_value.tooltip_text=str(comparison.upgrade.primary) if comparison.upgrade is Dictionary and comparison.upgrade.get("primary")!=null else _value(comparison.upgrade)
    _render_costs(quote,comparison.affordable,str(comparison.payment_reason))
    _cost.tooltip_text = _cost_text(quote.costs) if quote.get("ok",false) else _payment_state.text
    _purchase.text = "购买%s级" % str(quote.count) if quote.get("ok", false) else "购买"
    if quote.get("ok",false):_purchase.tooltip_text=("" if comparison.affordable else _purchase.tooltip_text+"\n")+_purchase.text
    _purchase.disabled = not comparison.affordable
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining)>0 else ""
    _switch_state.visible=not _switch_state.text.is_empty()

    var primary: String = "容量" if fact.category == "defence" else "攻击力"
    _current_caption.text = "当前" + primary
    _layout_primary_values()
    _install.text = "安装" + str(NAMES.get(_candidate, "装备")) if not _candidate.is_empty() else "选择装备"
    _install.disabled = _candidate.is_empty() or not comparison.switch_admission.ok
    _install.tooltip_text = "" if comparison.switch_admission.ok else _reason(str(comparison.switch_admission.reason))
    _comparison_group.visible=_selection_open and different
    _install.visible=_selection_open and different
    _comparison_title.text = "装备选择"
    _compare_row_label.text=primary
    for column in 2:
        var row = comparison.current if column==0 else comparison.candidate
        _compare_headers[column].text=("现装 · " if column==0 else "所选 · ")+(_interval(row) if fact.category=="weapon" else str(NAMES.get(str(row.equipment_id),"空槽")))
        _compare_values[column].text=_value(row)
    _period_caption.position=Vector2(0,0)
    _period_caption.visible=fact.category=="weapon"
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
    var weapons: int=active.filter(func(row): return row.category=="weapon").size()
    var defences: int=active.size()-weapons
    for category in _slot_groups:
        var count: int=weapons if category=="weapon" else defences
        _slot_groups[category].text=("武器" if category=="weapon" else "防御")+" · 启用 "+str(count)
        _slot_groups[category].position.y=170 if category=="weapon" else 217+weapons*31
        _slot_groups[category].visible=count>0
        _slot_backdrops[category].position.y=_slot_groups[category].position.y-6
        _slot_backdrops[category].size.y=40+count*31
        _slot_backdrops[category].visible=count>0
    for row in active:
        var id: String=str(row.id)
        live.append(id)
        if not _slot_buttons.has(id):
            var button:=_button("",Rect2(0,0,180,30),select_slot.bind(id),false,"index")
            button.name="Slot_"+id.replace(":","_")
            var number:=_label(str(int(row.index)+1),Rect2(10,0,24,30),14,Color("b4d7d1"))
            remove_child(number);button.add_child(number)
            var title:=_label("",Rect2(38,0,77,30),14,CREAM)
            remove_child(title);button.add_child(title)
            var meta:=_label("",Rect2(115,0,57,30),12,Color("b2cac5"))
            meta.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
            remove_child(meta);button.add_child(meta)
            _slot_buttons[id]={"button":button,"caption":title,"meta":meta,"number":number}
        var item: Dictionary=_slot_buttons[id]
        # Ship changes can move the defence group even when this slot's own facts are stable.
        item.button.position=_slot_label_position(row)
        var signature: Array=[row.category,row.index,row.equipment_id,row.paid_level,id==_selected]
        if _slot_presentations.get(id)!=signature:
            _slot_presentations[id]=signature
            presentation_counts.slots_updated+=1
            item.caption.text=str(NAMES.get(str(row.equipment_id),"装备"))
            item.meta.text="Lv."+str(row.paid_level) if not str(row.equipment_id).is_empty() else ""
        if _slot_selections.get(id)!=(id==_selected):
            presentation_counts.slot_styles_updated+=1
            _slot_selections[id]=id==_selected
            _button_tint(item.button,id==_selected)
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
            var button:=_button("",Rect2(0,0,68,88),_select_candidate.bind(id),false,"candidate")
            remove_child(button);_candidate_row.add_child(button)
            button.name="Candidate_"+id
            var icon:=_icon(id,Rect2(16,8,36,32),button)
            var caption:=_label("",Rect2(3,42,62,20),13,CREAM)
            remove_child(caption);button.add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            caption.add_theme_font_override("font",_font_strong)
            caption.size=Vector2(62,20)
            var status:=_label("",Rect2(3,62,62,18),12,Color("c6dfd5"))
            remove_child(status);button.add_child(status);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            status.add_theme_font_override("font",_font_strong)
            # Initial Label sizing used the default font before its override.
            # Reapply the actual slot after the status font's minimum is known.
            status.size=Vector2(62,18)
            _choices[id]={"button":button,"icon":icon,"caption":caption,"status":status}
        var signature: Array=[option.enabled,str(fact.equipment_id)==id,_candidate==id,_selection_open,column]
        if _choice_presentations.get(id)==signature:column+=1;continue
        _choice_presentations[id]=signature;presentation_counts.candidates_updated+=1
        var item: Dictionary=_choices[id]
        item.button.position=Vector2(column*76,0)
        # Keep the catalog column even while its whole control is hidden. Unlocking never compacts the row.
        item.button.visible=_selection_open and option.enabled;item.button.disabled=not option.enabled
        item.button.mouse_filter=Control.MOUSE_FILTER_STOP if option.enabled else Control.MOUSE_FILTER_IGNORE
        item.button.focus_mode=Control.FOCUS_ALL if option.enabled else Control.FOCUS_NONE
        item.button.tooltip_text=""
        item.caption.text=str(NAMES.get(id,option.name))
        item.status.text="已装备" if str(fact.equipment_id)==id else "待安装" if _candidate==id else ""
        item.caption.modulate=Color.WHITE if option.enabled else Color("b1beb9")
        item.icon.modulate=Color.WHITE
        item.icon.material=null
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

func _receipt_summary(result: Dictionary) -> String:
    var receipt:Dictionary=result.get("purchase_receipt",{})
    if receipt.get("commit_status")=="fault_unknown":return "提交结果未知，会话已停止。"
    var purchases:Array=receipt.get("purchases",[])
    if receipt.get("commit_status")=="accepted" and not purchases.is_empty():
        if purchases.size()==1:return "%s · 购级完成 +%d级" % [_slot_name(str(purchases[0].slot_id)),int(purchases[0].count)]
        return "已完成%d个槽位购级" % purchases.size()
    if not result.get("ok",false):return _reason(str(result.get("reason",result.get("error","Unknown"))))
    return "没有变更" if receipt.has("purchases") else "换装完成"

func _accept_result(result: Dictionary) -> void:
    last_result = result.duplicate(true)
    _feedback.text = _receipt_summary(result)
    _feedback.tooltip_text = _receipt_text(result)
    _receipt_history.push_front(_feedback.tooltip_text)
    if _receipt_history.size()>8:_receipt_history.pop_back()
    _receipt_history_button.disabled=false;_receipt_history_button.tooltip_text=_feedback.tooltip_text
    if _receipt_history_popup.visible:_receipt_history_label.text="\n\n".join(_receipt_history)
    _receipt_toast_remaining=3.0;_receipt_toast.show()
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
    if _receipt_toast_remaining>0:
        _receipt_toast_remaining=maxf(0.0,_receipt_toast_remaining-dt)
        if _receipt_toast_remaining==0:_receipt_toast.hide()
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
    _switch_state.visible=not _switch_state.text.is_empty()


func _ship_rect() -> Rect2:
    return _preview_rects[_ship]

func _weapon_factor(key: String) -> float:
    return (0.16 if key in ["longLaser","cannon"] else 0.13)*float(_preview_zooms[_ship])

func _mount_position(row: Dictionary) -> Vector2:
    var rect := _ship_rect()
    if row.category == "weapon":
        var mounts: Array = _catalog[_ship].mounts
        return rect.position + Vector2(float(mounts[int(row.index)][0]), float(mounts[int(row.index)][1])) / 768.0 * rect.size
    # Logical defence has no scene component or physical target point.
    return Vector2.ZERO

func _slot_label_position(row: Dictionary) -> Vector2:
    var weapons: int=_catalog[_ship].mounts.size()
    return Vector2(26,202+int(row.index)*31 if row.category=="weapon" else 249+weapons*31+int(row.index)*31)

func _draw() -> void:
    presentation_counts.scene_draws+=1
    draw_rect(Rect2(0,0,808,900),CREAM)
    draw_texture_rect_region(_background,Rect2(0,85,808,600),Rect2(0,0,1188,845))
    draw_rect(Rect2(0,685,808,215),Color("203b49"))
    if _ship.is_empty() or not _catalog.has(_ship):return
    draw_texture_rect(_hull_textures[_ship],_ship_rect(),false)
    for row in _facts:
        if row.dormant or row.category!="weapon":continue
        var mount: Vector2=_mount_position(row)
        var key: String=str(row.equipment_id)
        if not _textures.has(key):continue
        var tex: Texture2D=_textures[key]
        var meta: Dictionary=_weapon_meta[key]
        var factor:float=_weapon_factor(key)
        var anchor:=Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor
        draw_texture_rect(tex,Rect2(mount-anchor,Vector2(tex.get_size())*factor),false)

    _draw_selected_locator()

func _component_rect(row: Dictionary) -> Rect2:
    var point:Vector2=_mount_position(row)
    var key:String=str(row.equipment_id)
    if row.category=="weapon" and _weapon_visible_bounds.has(key):
        var factor:float=_weapon_factor(key)
        var meta:Dictionary=_weapon_meta[key]
        var bound:Rect2=Rect2(_weapon_visible_bounds[key])
        return Rect2(point-Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor+bound.position*factor,bound.size*factor)
    return Rect2()

func _draw_selected_locator() -> void:
    var row:Dictionary=_selected_fact()
    if row.is_empty() or row.dormant or row.category!="weapon":return
    # An open empty slot has no visible weapon PNG to locate. Its index and workbench remain selectable.
    if row.category=="weapon" and not _weapon_visible_bounds.has(str(row.equipment_id)):return
    var card:Rect2=Rect2(_slot_label_position(row),Vector2(180,30))
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
    var accent:Color=Color("91e2d4")
    draw_polyline(points,Color("153341"),3.5,true)
    draw_polyline(points,accent,1.5,true)
    for corner in [target.position,Vector2(target.end.x,target.position.y),target.end,Vector2(target.position.x,target.end.y)]:
        var sign:Vector2=Vector2(1 if corner.x==target.position.x else -1,1 if corner.y==target.position.y else -1)
        draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),Color("173542"),3.5,true)
        draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),accent,1.5,true)
    var badge:Rect2=_locator_badge_rect(row,target)
    if not badge.has_area():return
    draw_style_box(_locator_badge_style,badge)
    draw_string(_font_strong,badge.position+Vector2(3,16),"武"+str(int(row.index)+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,CREAM)

func _locator_badge_rect(row: Dictionary, target: Rect2) -> Rect2:
    if row.category!="weapon":return Rect2()
    var centre:Vector2=target.get_center()
    var positions:Array=[Vector2(target.end.x-29,target.end.y+3),Vector2(target.end.x+5,centre.y-11),Vector2(target.position.x-37,centre.y-11),Vector2(centre.x-16,target.position.y-25),Vector2(target.position.x,target.end.y+3),Vector2(centre.x-16,target.end.y+3),Vector2(target.end.x+5,target.position.y),Vector2(target.position.x-37,target.end.y-22)]
    for position in positions:
        var badge:Rect2=Rect2(position,Vector2(32,22))
        if not Rect2(16,90,776,470).encloses(badge):continue
        var blocked:bool=false
        for id in _slot_buttons:
            if badge.intersects(_slot_buttons[id].button.get_rect().grow(4)):blocked=true;break
        if blocked:continue
        for other in _facts:
            if other.dormant or other.id==row.id:continue
            if badge.intersects(_component_rect(other).grow(2)):blocked=true;break
        if not blocked:return badge
    # Never paint a clipped fragment if a future unverified layout has no free candidate.
    return Rect2()


## H1 chrome/exclusive ports: the host owns routing, shared input gates and the context slot.
func set_shared_host(enabled: bool, context_slot: Control, _backdrop: Texture2D = null) -> void:
    for item in _shared_chrome:item.visible=not enabled
    _wallet.visible=not enabled
    _release_host_context()
    _context_slot=context_slot
    if enabled and is_instance_valid(context_slot):
        _context_caption=Label.new()
        _context_caption.text="装备"
        _context_caption.size=Vector2(96,26)
        _context_caption.clip_text=true
        _context_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
        context_slot.add_child(_context_caption)

func has_exclusive_ui() -> bool:
    return _batch.visible or _batch_quantity.get_popup().visible or _receipt_history_popup.visible

func prepare_host_hide(force: bool = false) -> bool:
    if has_exclusive_ui() and not force:return false
    if force:
        _receipt_history_popup.hide();_close_batch()
    _hide_receipt_toast()
    var focus:Control=get_viewport().gui_get_focus_owner()
    if focus!=null and (focus==self or is_ancestor_of(focus)):focus.release_focus()
    return true

func _release_host_context() -> void:
    if is_instance_valid(_context_caption):
        _context_caption.hide()
        _context_caption.queue_free()
    _context_caption=null
    _context_slot=null

func _exit_tree() -> void:
    _release_host_context()
