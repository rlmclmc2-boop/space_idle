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
var _slot_groups: Dictionary = {}
var _slot_backdrops: Dictionary = {}
var _icon_textures: Dictionary = {}
var _icon_centres: Dictionary = {}
var _locked_icon_material: ShaderMaterial
var _current_icon_geometry: Dictionary = {}
var _workbench_outline: StyleBoxFlat
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
        _preview_rects[key]=Rect2(Vector2(404,387)-visible.get_center()*factor,Vector2(768,768)*factor)
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
    # Locked candidates retain only their alpha shape; RGB detail never reaches the canvas.
    var silhouette:=Shader.new()
    silhouette.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(0.047058824,0.145098039,0.188235294,texture(TEXTURE,UV).a); }"
    _locked_icon_material=ShaderMaterial.new()
    _locked_icon_material.shader=silhouette
    _workbench_outline=_style(Color(0,0,0,0),Color("839d98"),1)
    _workbench_outline.set_corner_radius_all(6)
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
    _label("远航舰桥",Rect2(24,10,160,34),23)
    _wallet=_label("",Rect2(204,16,590,30),15)
    _label("战力维护  /  装配",Rect2(24,52,380,28),14,Color("57777a"))
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
    _current_title=_label("现装升级",Rect2(42,654,330,29),18,CREAM)
    _level_label=_label("",Rect2(383,658,70,24),13,Color("aec5be"))
    _large_icon=_icon("laser",Rect2(42,700,64,64))
    _current_caption=_label("当前攻击力",Rect2(130,692,140,22),12,Color("6b7d79"))
    _upgrade_caption=_label("升级后",Rect2(306,692,146,22),12,Color("557a78"))
    _current_value=_label("—",Rect2(130,715,140,38),27)
    _upgrade_arrow=_label("→",Rect2(273,719,32,32),23,Color("72938d"))
    _next_value=_label("—",Rect2(306,715,148,38),27,TEAL)
    for value in [_current_value,_next_value]:
        value.mouse_filter=Control.MOUSE_FILTER_PASS
        value.clip_text=true
    _cost=_label("本次费用",Rect2(38,737,104,24),13,Color("647b75"))
    _payment_state=_label("",Rect2(38,766,414,31),13,Color("a75a3d"))
    _payment_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for index in 3:
        var captions := ["+1","+10","MAX"]
        var button := _button(captions[index],Rect2(34+index*65,840,59,36),func():_maximum=index==2;_quantity=10 if index==1 else 1;_dirty=true)
        button.name="Quantity"+str(index)
        _quantity_buttons.append(button)
    _purchase=_button("购买1级",Rect2(242,840,218,36),_buy,true)
    _purchase.name="Purchase"
    _comparison_title=_label("装备选择",Rect2(508,654,260,29),18,CREAM)
    _compare=_label("",Rect2(508,760,268,62),13,CREAM)
    _compare.hide()
    for column in 2:
        var header:=_label("",Rect2(565+column*105,760,100,18),12,INK if column==0 else TEAL)
        header.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        header.add_theme_font_override("font",_font_strong)
        header.size=Vector2(100,18)
        _compare_headers.append(header)
        var value:=_label("—",Rect2(565+column*105,778,100,25),17,INK if column==0 else TEAL)
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        value.add_theme_font_override("font",_font_strong)
        value.size=Vector2(100,25)
        _compare_values.append(value)
        var period:=_label("—",Rect2(565+column*105,803,100,18),12,Color("617c78") if column==0 else TEAL)
        period.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        period.size=Vector2(100,18)
        _compare_periods.append(period)
    _compare_row_label=_label("攻击力",Rect2(508,778,57,25),12,Color("617c78"))
    _label("周期",Rect2(508,803,57,18),12,Color("617c78")).name="PeriodCaption"
    _switch_state=_label("",Rect2(508,821,260,17),11,Color("946338"))
    _switch_state.size=Vector2(260,17)
    _install=_button("安装",Rect2(524,840,244,36),_equip,true)
    _install.name="Install"
    _feedback=_label("",Rect2(25,879,757,20),12,Color("e5e7da"))
    _feedback.clip_text=true
    _build_batch()

func _place_current_icon(key: String) -> void:
    _large_icon.texture=_icon_textures.get(key)
    if _large_icon.texture==null:
        _current_icon_geometry={}
        return
    # The accepted icon bezel/optical inset translates with the whole shared workbench; no icon fit is changed.
    var safe:=Rect2(43,709,52,47)
    var centre:=Vector2(69,734)
    var mass:Vector2=_icon_centres[key]
    var source:Vector2=_large_icon.texture.get_size()
    var before:Vector2=source*mass
    var after:Vector2=source-before
    var factor:float=minf(minf((centre.x-safe.position.x)/before.x,(safe.end.x-centre.x)/after.x),minf((centre.y-safe.position.y)/before.y,(safe.end.y-centre.y)/after.y))
    _large_icon.size=source*factor
    _large_icon.position=centre-before*factor
    _current_icon_geometry={"key":key,"frame_inner":Rect2(37,703,64,59),"safe":safe,"visible_rect":_large_icon.get_rect(),"alpha_centre_normalized":mass,"displayed_alpha_centre":_large_icon.position+_large_icon.size*mass,"primary_surface_centre_y":731,"optical_mass_offset_y":3}

func _render_costs(quote: Dictionary, affordable: bool, reason: String) -> void:
    var keys: Array = quote.get("costs",{}).keys() if quote.get("ok",false) else []
    for id in _cost_cells:_cost_cells[id].name.visible=false;_cost_cells[id].amount.visible=false
    _purchase.tooltip_text=""
    _cost.text="本次费用"
    var first_row_y:float=804-maxi(0,keys.size()-1)*26
    _cost.position=Vector2(38,first_row_y);_cost.size=Vector2(90,25)
    var single:bool=keys.size()<=1
    # Payment feedback shares the single resource line; more resources grow only their actual rows.
    _payment_state.position=Vector2(294,804) if single else Vector2(38,804)
    _payment_state.size=Vector2(160,25) if single else Vector2(100,31)
    _payment_state.text="" if affordable else _reason(reason)
    # Both operation surfaces share this fixed baseline; only actual fee rows grow upward.
    for button in _quantity_buttons:button.position.y=840
    _purchase.position.y=840
    for index in keys.size():
        var id: String=str(keys[index])
        if not _cost_cells.has(id):
            var name:=_label("",Rect2(143,734,102,25),13,Color("5f7876"))
            var amount:=_label("",Rect2(246,731,208,27),17,INK)
            amount.add_theme_font_override("font",_font_strong)
            amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
            _cost_cells[id]={"name":name,"amount":amount}
        var cell: Dictionary=_cost_cells[id]
        cell.name.position=Vector2(130,804) if single else Vector2(143,first_row_y+index*26)
        cell.name.size=Vector2(36,25) if single else Vector2(102,25)
        cell.amount.position=Vector2(166,801) if single else Vector2(246,first_row_y-3+index*26)
        cell.amount.size=Vector2(112,27) if single else Vector2(208,27)
        cell.name.text={"1":"铁","2":"铀","degenerate_matter":"简并物质","jewel":"碎片"}.get(id,id)
        var formatted: Dictionary=_session.amount_api.apply("to_display",[quote.costs[id]])
        cell.amount.text=PlayerText.number(str(formatted.text)) if formatted.ok else "未知"
        cell.amount.add_theme_color_override("font_color",INK if affordable else Color("a1593b"))
        cell.name.show();cell.amount.show()
    if not quote.get("ok",false):
        _payment_state.position=Vector2(143,804);_payment_state.size=Vector2(311,31)
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
    _place_current_icon(str(fact.equipment_id))
    _current_title.text = "%s · %s" % [_slot_name(_selected),NAMES.get(str(fact.equipment_id),"装备")]
    _level_label.text = "Lv."+str(fact.paid_level)
    _current_value.text = _value(comparison.current)
    _next_value.text = _value(comparison.upgrade)
    _current_value.tooltip_text=str(comparison.current.primary) if comparison.current is Dictionary and comparison.current.get("primary")!=null else _value(comparison.current)
    _next_value.tooltip_text=str(comparison.upgrade.primary) if comparison.upgrade is Dictionary and comparison.upgrade.get("primary")!=null else _value(comparison.upgrade)
    var long_values: bool = _font_strong.get_string_size(_next_value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x>148 or _font_strong.get_string_size(_current_value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x>140
    _upgrade_arrow.visible=not long_values
    # Shared-workbench primary surface is y699..763. Captions have inner padding; numeric widths/font stay intact.
    _current_caption.position=Vector2(130,708 if long_values else 705)
    _upgrade_caption.position=Vector2(130,738) if long_values else Vector2(306,705)
    _current_caption.size=Vector2(102 if long_values else 140,18)
    _upgrade_caption.size=Vector2(102 if long_values else 146,18)
    _current_value.position=Vector2(232,695) if long_values else Vector2(130,723)
    _next_value.position=Vector2(232,725) if long_values else Vector2(306,723)
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
            var button:=_button("",Rect2(0,0,65,70),_select_candidate.bind(id),false,"candidate")
            button.name="Candidate_"+id
            var icon:=_icon(id,Rect2(18,2,29,28),button)
            var caption:=_label("",Rect2(3,30,59,20),13,CREAM)
            remove_child(caption);button.add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            caption.add_theme_font_override("font",_font_strong)
            caption.size=Vector2(59,20)
            var status:=_label("",Rect2(3,50,59,18),12,Color("c6dfd5"))
            remove_child(status);button.add_child(status);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            status.add_theme_font_override("font",_font_strong)
            # Initial Label sizing used the default font before its override.
            # Reapply the actual slot after the status font's minimum is known.
            status.size=Vector2(59,18)
            _choices[id]={"button":button,"icon":icon,"caption":caption,"status":status}
        var signature: Array=[option.enabled,str(fact.equipment_id)==id,_candidate==id,_selection_open,column]
        if _choice_presentations.get(id)==signature:column+=1;continue
        _choice_presentations[id]=signature;presentation_counts.candidates_updated+=1
        var item: Dictionary=_choices[id]
        item.button.position=Vector2(505+column*70,690)
        item.button.visible=_selection_open;item.button.disabled=not option.enabled
        item.caption.text=str(NAMES.get(id,option.name))
        item.status.text="已装备" if str(fact.equipment_id)==id else "未解锁" if not option.enabled else "待安装" if _candidate==id else ""
        item.caption.modulate=Color.WHITE if option.enabled else Color("b1beb9")
        item.icon.modulate=Color.WHITE
        item.icon.material=null if option.enabled else _locked_icon_material
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
    return _preview_rects[_ship]

func _weapon_factor(key: String) -> float:
    return (0.16 if key in ["longLaser","cannon"] else 0.13)*float(_preview_zooms[_ship])

func _mount_position(row: Dictionary) -> Vector2:
    var rect := _ship_rect()
    if row.category == "weapon":
        var mounts: Array = _catalog[_ship].mounts
        return rect.position + Vector2(float(mounts[int(row.index)][0]), float(mounts[int(row.index)][1])) / 768.0 * rect.size
    # Defence has no weapon-manifest geometry. These are distinct UI attachment markers.
    var legacy:Vector2=[Vector2(353,453),Vector2(453,453),Vector2(495,243)][mini(int(row.index),2)]
    return Vector2(404,387)+(legacy-Vector2(404,387))*float(_preview_zooms[_ship])

func _slot_label_position(row: Dictionary) -> Vector2:
    var weapons: int=_catalog[_ship].mounts.size()
    return Vector2(26,202+int(row.index)*31 if row.category=="weapon" else 249+weapons*31+int(row.index)*31)

func _draw() -> void:
    presentation_counts.scene_draws+=1
    draw_rect(Rect2(0,0,808,900),CREAM)
    draw_texture_rect_region(_background,Rect2(0,85,808,535),Rect2(0,0,1188,845))
    # Shared lower frame: thinner top/bottom structure, both columns use the same exterior height.
    var sy:float=479.0/330.0
    draw_texture_rect_region(_background,Rect2(0,620,808,20),Rect2(0,845,1188,36*sy))
    draw_texture_rect_region(_background,Rect2(0,640,808,244),Rect2(0,845+36*sy,1188,262*sy))
    draw_texture_rect_region(_background,Rect2(0,884,808,16),Rect2(0,845+298*sy,1188,32*sy))
    # A clean source strip supplies identical ivory/navy material to both surfaces, without duplicate artwork.
    for surface in [Rect2(24,650,452,232),Rect2(496,650,288,232)]:
        draw_texture_rect_region(_upgrade_surface,Rect2(surface.position,Vector2(surface.size.x,42)),Rect2(84,0,4,42))
        draw_texture_rect_region(_upgrade_surface,Rect2(surface.position+Vector2(0,42),Vector2(surface.size.x,190)),Rect2(84,42,4,210))
        draw_style_box(_workbench_outline,surface)
    # Preserve the accepted visible icon inset and primary-data surface at their new common-workbench origin.
    draw_texture_rect_region(_upgrade_surface,Rect2(116,699,343,64),Rect2(92,49,343,64))
    draw_texture_rect_region(_upgrade_surface,Rect2(34,702,70,64),Rect2(10,52,70,64))
    draw_texture_rect_region(_upgrade_surface,Rect2(505,758,270,80),Rect2(92,49,343,64))
    if _ship.is_empty() or not _catalog.has(_ship):return
    draw_texture_rect(_hull_textures[_ship],_ship_rect(),false)
    for row in _facts:
        if row.dormant:continue
        var mount: Vector2=_mount_position(row)
        var key: String=str(row.equipment_id)
        if not _textures.has(key):continue
        var tex: Texture2D=_textures[key]
        if row.category=="weapon":
            var meta: Dictionary=_weapon_meta[key]
            var factor:float=_weapon_factor(key)
            var anchor:=Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor
            draw_texture_rect(tex,Rect2(mount-anchor,Vector2(tex.get_size())*factor),false)
        else:
            var extent:=Vector2(42,42)*float(_preview_zooms[_ship])
            draw_texture_rect(tex,Rect2(mount-extent*0.5,extent),false)

    _draw_selected_locator()

func _component_rect(row: Dictionary) -> Rect2:
    var point:Vector2=_mount_position(row)
    var key:String=str(row.equipment_id)
    if row.category=="weapon" and _weapon_visible_bounds.has(key):
        var factor:float=_weapon_factor(key)
        var meta:Dictionary=_weapon_meta[key]
        var bound:Rect2=Rect2(_weapon_visible_bounds[key])
        return Rect2(point-Vector2(float(meta.anchor[0]),float(meta.anchor[1]))*factor+bound.position*factor,bound.size*factor)
    var extent:=Vector2(42,42)*float(_preview_zooms[_ship])
    return Rect2(point-extent*0.5,extent)

func _draw_selected_locator() -> void:
    var row:Dictionary=_selected_fact()
    if row.is_empty() or row.dormant:return
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
    var accent:Color=Color("ffdb91") if row.category=="defence" else Color("91e2d4")
    draw_polyline(points,Color("153341"),3.5,true)
    if row.category=="defence":
        for i in points.size()-1:draw_dashed_line(points[i],points[i+1],accent,2,5,true)
        for edge in [PackedVector2Array([target.position,Vector2(target.end.x,target.position.y)]),PackedVector2Array([Vector2(target.end.x,target.position.y),target.end]),PackedVector2Array([target.end,Vector2(target.position.x,target.end.y)]),PackedVector2Array([Vector2(target.position.x,target.end.y),target.position])]:draw_dashed_line(edge[0],edge[1],accent,2,4,true)
    else:
        draw_polyline(points,accent,1.5,true)
        for corner in [target.position,Vector2(target.end.x,target.position.y),target.end,Vector2(target.position.x,target.end.y)]:
            var sign:Vector2=Vector2(1 if corner.x==target.position.x else -1,1 if corner.y==target.position.y else -1)
            draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),Color("173542"),3.5,true)
            draw_polyline(PackedVector2Array([corner+Vector2(0,sign.y*10),corner,corner+Vector2(sign.x*10,0)]),accent,1.5,true)
    var badge:Rect2=_locator_badge_rect(row,target)
    if not badge.has_area():return
    draw_style_box(_locator_badge_style,badge)
    draw_string(_font_strong,badge.position+Vector2(3,16),("武" if row.category=="weapon" else "防")+str(int(row.index)+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,CREAM)

func _locator_badge_rect(row: Dictionary, target: Rect2) -> Rect2:
    var centre:Vector2=target.get_center()
    var positions:Array=[Vector2(target.end.x-29,target.end.y+3),Vector2(target.end.x+5,centre.y-11),Vector2(target.position.x-37,centre.y-11),Vector2(centre.x-16,target.position.y-25),Vector2(target.position.x,target.end.y+3),Vector2(centre.x-16,target.end.y+3),Vector2(target.end.x+5,target.position.y),Vector2(target.position.x-37,target.end.y-22)]
    if row.category=="defence" and int(row.index)==2:positions.push_front(target.position+Vector2(-30,14))
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
