extends Control
## Equipment owns all prices, admission and receipts; this scene owns only presentation.
signal command_finished(result: Dictionary)
signal exclusive_ui_changed
var _shared_chrome: Array = []
var _context_slot: Control
var _context_caption: Label
const ResourceVisuals = preload("res://src/ui/resource_visuals.gd")
const RESOURCE_NAMES := {"1":"铁", "2":"铀", "chrono":"时空微粒", "jewel":"强化碎片", "degenerate_matter":"简并物质"}
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
var _workbench_layout: Dictionary = {}
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
var _choice_options: Array = []
var _choice_option_slot: String = ""
var _face_texture: Texture2D
var _console_texture: Texture2D
var _pending_level_ids: Dictionary = {}
var _batch_state_dirty: bool = false
var _scene_picture: Array = []
# Bounded presentation-only diagnostics; no state or rules come from these counts.
var presentation_counts := {"refreshes":0,"numeric_refreshes":0,"comparison_reads":0,"slot_fact_reads":0,"cooldown_fact_reads":0,"slots_updated":0,"slot_styles_updated":0,"candidates_updated":0,"quantity_styles_updated":0,"scene_redraw_requests":0,"scene_draws":0,"economy_signals":0,"economy_same_budget":0,"balance_dependency_changes":0,"comparison_dependency_changes":0,"wallet_refreshes":0,"equipment_option_reads":0,"maximum_reads":0}
var _choices: Dictionary = {}
var _quantity_button: Button
var _catalog: Dictionary
var _weapon_meta: Dictionary
var _textures: Dictionary = {}
var _weapon_visible_bounds: Dictionary = {}
var _hull_textures: Dictionary = {}
var _background: Texture2D
var _locator_badge_style: StyleBox
var _title: Label
var _wallet: Control
var _wallet_cells: Dictionary = {}
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
var _switch_state: Label
var _batch_blocker: ColorRect
var _batch: PanelContainer
var _batch_quantity: Button
var _batch_mode: int = 0
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
var _batch_frame: Panel
var _batch_close: Button
var _selection_open: bool = true
var last_result: Dictionary = {}
var _last_batch_result: Dictionary = {}
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
    _session.equipment.slots_changed.connect(_queue_level_values)
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
    var shell:Texture2D=load("res://assets/ui/equipment/materials-20261029/painted-console-shell.png")
    var paint:Image=shell.get_image().get_region(Rect2i(8,56,2102,620))
    # One uniform scale for the painted frame at native UI pixel scale; rounded height is189px.
    paint.resize(640,189,Image.INTERPOLATE_LANCZOS)
    _console_texture=ImageTexture.create_from_image(paint)
    # All controls share one painted albedo and one edge profile. Sample only the
    # existing navy key's inner paint, never its separate metallic border.
    var source_face:Image=load("res://assets/ui/equipment/materials-20261029/control-materials.png").get_image()
    var face:Image=source_face.get_region(Rect2i(120,800,1200,130))
    face.resize(298,64,Image.INTERPOLATE_LANCZOS)
    for y in face.get_height():
        for x in face.get_width():
            var pixel:Color=face.get_pixel(x,y)
            var light:float=pixel.r*0.2126+pixel.g*0.7152+pixel.b*0.0722
            var pigment:float=clampf(0.44+1.60*light,0.71,0.94)
            face.set_pixel(x,y,Color(pigment,pigment,pigment,pixel.a))
    _face_texture=ImageTexture.create_from_image(face)
    _locator_badge_style=_surface_material("navy",Color.WHITE,"locator")

const CONTROL_FOCUS := Color("8ab9b2")
const CONTROL_DISABLED_INK := Color("ccd6d0")
const CONTROL_CUT := 5.0

class EquipmentSurface extends StyleBox:
    var texture:Texture2D
    var tone:Color=Color.WHITE
    var profile:String
    var depressed:bool=false
    var quiet:bool=false
    var disabled:bool=false
    func _draw(canvas:RID,r:Rect2)->void:
        if quiet:return
        var focus:bool=profile.begins_with("focus_")
        var form:String=profile.trim_prefix("focus_") if focus else profile
        var face:Rect2=r.grow(-3)
        if form=="tray" or form=="candidate":face=Rect2(r.position+Vector2(8,4),Vector2(r.size.x-16,52.0))
        elif form=="index":face=r.grow(-1)
        elif form in ["backing","locator"]:face=r
        if depressed:face.position.y+=1;face.size.y-=1
        var cut:float=minf(CONTROL_CUT,minf(face.size.x,face.size.y)*0.25)
        var points:=PackedVector2Array([
            face.position+Vector2(cut,0),Vector2(face.end.x-cut,face.position.y),
            Vector2(face.end.x,face.position.y+cut),face.end-Vector2(0,cut),
            face.end-Vector2(cut,0),Vector2(face.position.x+cut,face.end.y),
            Vector2(face.position.x,face.end.y-cut),face.position+Vector2(0,cut)])
        if form=="header":
            face=Rect2(r.position+Vector2(12,14),Vector2(r.size.x-24,26))
            points=PackedVector2Array([r.position+Vector2(32,14),r.position+Vector2(r.size.x-32,14),r.position+Vector2(r.size.x-12,32),r.position+Vector2(r.size.x-12,40),r.position+Vector2(12,40),r.position+Vector2(12,32)])
        var outline:=points.duplicate();outline.append(points[0])
        if focus:
            RenderingServer.canvas_item_add_polyline(canvas,outline,PackedColorArray([CONTROL_FOCUS]),1.5,true)
            return
        # One coated-metal cross section: a small light-facing shoulder, a broad
        # matte face and a down-facing return. Keys stand off the deck; readouts
        # sit in it, so the same light gives opposite contact-edge emphasis.
        var key:bool=form=="button"
        var recessed:bool=form in ["instrument","tray","candidate"]
        if form not in ["header","backing"]:
            var shadow:=points.duplicate()
            for i in shadow.size():shadow[i]+=Vector2(0,3 if key and not depressed else 1)
            RenderingServer.canvas_item_add_polygon(canvas,shadow,PackedColorArray([Color(0.045,0.085,0.095,0.36 if key else 0.22)]))
        if form=="header":
            var uv:=PackedVector2Array()
            for point in points:uv.append((point-face.position)/face.size)
            RenderingServer.canvas_item_add_polygon(canvas,points,PackedColorArray([tone]),uv,texture.get_rid())
        else:
            # The illumination is independent of texture stretch and screen height.
            # No white reflection is baked across the top of a short tray.
            var shoulder:float=minf(3.0,face.size.y*0.10)/face.size.y
            var return_edge:float=minf(3.0 if key else 1.5,face.size.y*0.10)/face.size.y
            var bands:Array=[0.0,shoulder,0.36,0.78,1.0-return_edge,1.0]
            var shades:Array=[0.90,1.10,1.02,0.97,0.91,0.66] if key else [0.78,0.97,1.0,0.97,0.94,0.84]
            if disabled:shades=[0.88,0.94,0.94,0.93,0.91,0.77]
            if depressed:shades=[0.72,0.89,0.93,0.94,0.91,0.83]
            for band in range(bands.size()-1):
                var top:float=bands[band]*face.size.y
                var bottom:float=bands[band+1]*face.size.y
                var inset_top:float=maxf(0.0,cut-minf(top,face.size.y-top))
                var inset_bottom:float=maxf(0.0,cut-minf(bottom,face.size.y-bottom))
                var section:=PackedVector2Array([face.position+Vector2(inset_top,top),face.position+Vector2(face.size.x-inset_top,top),face.position+Vector2(face.size.x-inset_bottom,bottom),face.position+Vector2(inset_bottom,bottom)])
                var uv:=PackedVector2Array()
                for point in section:uv.append((point-face.position)/face.size)
                var upper:=Color(tone.r*shades[band],tone.g*shades[band],tone.b*shades[band],tone.a)
                var lower:=Color(tone.r*shades[band+1],tone.g*shades[band+1],tone.b*shades[band+1],tone.a)
                RenderingServer.canvas_item_add_polygon(canvas,section,PackedColorArray([upper,upper,lower,lower]),uv,texture.get_rid())
        if form=="backing":return
        var edge:=Color(0.10,0.19,0.22,0.34 if disabled else 0.56)
        RenderingServer.canvas_item_add_polyline(canvas,outline,PackedColorArray([edge]),1.0,true)
        if not disabled:
            var lit_edge:=PackedVector2Array([points[3],points[4],points[5],points[6]]) if recessed else PackedVector2Array([points[-1],points[0],points[1],points[2]])
            RenderingServer.canvas_item_add_polyline(canvas,lit_edge,PackedColorArray([Color(0.86,0.88,0.77,0.28 if recessed else 0.36)]),1.0,true)

func _console_material(dark:bool)->StyleBox:
    var frame:=StyleBoxTexture.new()
    frame.texture=_console_texture;frame.draw_center=true
    for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:frame.set_texture_margin(side,32)
    frame.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
    frame.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
    var paint_tint:Color=Color(0.29,0.40,0.43) if dark else Color.WHITE
    frame.modulate_color=paint_tint
    return frame

func _surface_material(kind:String, modulation:Color=Color.WHITE, profile:String="flat", depressed:bool=false) -> StyleBox:
    if profile=="deck":return _console_material(kind=="navy_face")
    var material:=EquipmentSurface.new()
    material.texture=_face_texture;material.profile=profile;material.depressed=depressed
    var tones:Dictionary={"glass":Color(0.91,0.95,0.91),"enamel":Color(0.91,0.95,0.91),"teal":Color(0.68,0.90,0.81),"selected_dark":Color(0.29,0.53,0.54),"navy_face":Color(0.28,0.42,0.48),"navy":Color(0.31,0.46,0.53),"primary":Color(0.38,0.51,0.54),"disabled":Color(0.23,0.33,0.38),"quiet":Color(0.31,0.46,0.53)}
    material.tone=tones.get(kind,Color.WHITE)*modulation
    material.quiet=kind=="clear";material.disabled=kind=="disabled"
    material.content_margin_left=8;material.content_margin_right=8
    material.content_margin_top=(6 if depressed else 4) if profile=="button" else 5
    material.content_margin_bottom=(4 if depressed else 6) if profile=="button" else 5
    return material


func _frame(parent: Control, rect: Rect2) -> Panel:
    var frame := Panel.new()
    frame.position=rect.position;frame.size=rect.size
    var material := _surface_material("navy_face",Color.WHITE,"deck")
    frame.add_theme_stylebox_override("panel",material)
    frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    frame.show_behind_parent=true
    parent.add_child(frame)
    return frame

func _prepare_button_material(button: Button, form: String) -> void:
    # Cache only the materials this control uses; no discarded old-frame styles.
    var variants:Array=[]
    var focus_material:=_surface_material("navy",Color.WHITE,"focus_"+form)
    for selected in ([false,true] if form in ["candidate","index"] else [false]):
        var states:Dictionary={}
        for state in ["normal","hover","pressed","disabled","focus"]:
            if state=="focus":
                states[state]=focus_material
            else:
                var tint:=Color(1.06,1.07,1.06) if state=="hover" else Color(0.88,0.90,0.91) if state=="pressed" else Color.WHITE
                var kind:String="disabled" if state=="disabled" else "primary" if form=="primary" else "teal" if form=="candidate" and selected else "enamel" if form=="candidate" else "selected_dark" if form=="index" and selected else "navy"
                if form in ["quiet","index"] and not selected:
                    if state=="normal":kind="clear"
                    elif state!="disabled":tint.a=0.65
                var section:String="tray" if form=="candidate" else "index" if form=="index" else "button"
                states[state]=_surface_material(kind,tint,section,state=="pressed")
        variants.append(states)
    button.set_meta("material_variants",variants)
    button.set_meta("material_chosen",null)
    button.set_meta("material_role",form)
    _button_tint(button,false)

func _button_tint(button: Button, chosen: bool) -> void:
    if button.has_meta("material_chosen") and button.get_meta("material_chosen")==chosen:return
    button.set_meta("material_chosen",chosen)
    var states: Dictionary=button.get_meta("material_variants")[1 if chosen else 0]
    for state in states:button.add_theme_stylebox_override(state,states[state])
    var quiet:bool=button.get_meta("material_role","")=="quiet"
    var ink:Color=LIGHT if quiet else CREAM
    for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,ink)
    button.add_theme_color_override("font_disabled_color",CONTROL_DISABLED_INK)

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

func _button(text: String, rect: Rect2, action: Callable, dark: bool = false, form: String = "button") -> Button:
    var button := Button.new()
    button.text=text;button.position=rect.position;button.size=rect.size
    button.add_theme_font_size_override("font_size",16)
    button.add_theme_font_override("font",_font_strong)
    for key in ["font_color","font_pressed_color"]:button.add_theme_color_override(key,CREAM)
    button.add_theme_color_override("font_hover_color",CREAM)
    button.add_theme_color_override("font_disabled_color",CONTROL_DISABLED_INK)
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

func _resource_icon(id: String, pixels: float, parent: Control) -> TextureRect:
    var mark:=TextureRect.new()
    mark.texture=ResourceVisuals.icon(id);mark.modulate=ResourceVisuals.icon_modulate(id)
    mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mark.size=Vector2(pixels,pixels);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(mark);mark.hide()
    return mark

func _render_wallet() -> void:
    for id in _wallet_cells:_wallet_cells[id].icon.hide();_wallet_cells[id].text.hide()
    var count:int=_wallet_dependency.size()
    var x:float=0.0
    for raw_id in _wallet_dependency:
        var id:=str(raw_id)
        if not _wallet_cells.has(id):continue
        var cell:Dictionary=_wallet_cells[id]
        var formatted:Dictionary=_session.amount_api.apply("to_display",[_wallet_dependency[raw_id]])
        cell.text.text=RESOURCE_NAMES[id]+" "+(PlayerText.number(str(formatted.text)) if formatted.ok else "未知")
        cell.text.tooltip_text=cell.text.text
        var width:float=minf(590.0/maxi(1,count),cell.text.get_theme_font("font").get_string_size(cell.text.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+35.0)
        cell.icon.position=Vector2(x,6);cell.text.position=Vector2(x+23,0);cell.text.size=Vector2(width-29,30)
        cell.icon.show();cell.text.show();x+=width

func _build() -> void:
    _shared_chrome.append(_label("远航舰桥",Rect2(24,10,160,34),23))
    _wallet=Control.new();_wallet.position=Vector2(204,16);_wallet.size=Vector2(590,30)
    _wallet.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_wallet)
    # Resource identity nodes/textures are cached at construction, never per quote.
    for id in RESOURCE_NAMES:
        var mark:=_resource_icon(id,17,_wallet)
        var text:=_label("",Rect2(0,0,100,30),15)
        remove_child(text);_wallet.add_child(text)
        text.clip_text=true;text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        text.mouse_filter=Control.MOUSE_FILTER_PASS
        _wallet_cells[id]={"icon":mark,"text":text}

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
        var material:=_surface_material("navy",Color(1,1,1,0.82),"backing")
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

func _workbench_button(text:String,rect:Rect2,action:Callable,form:String="button") -> Button:
    var button:=_button(text,rect,action,true,form)
    remove_child(button);_workbench.add_child(button)
    return button

func _build_workbench() -> void:
    _workbench=Panel.new();_workbench.name="EquipmentWorkbench"
    _workbench.position=Vector2(16,610);_workbench.size=Vector2(776,286)
    _workbench.clip_contents=true;_workbench.mouse_filter=Control.MOUSE_FILTER_PASS
    var body:=_surface_material("enamel",Color.WHITE,"deck")
    _workbench.add_theme_stylebox_override("panel",body);add_child(_workbench)
    var header:=Panel.new();header.name="ObjectHeader";header.size=Vector2(776,40);header.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var beam:=_surface_material("navy_face",Color.WHITE,"header")
    header.add_theme_stylebox_override("panel",beam);_workbench.add_child(header)
    _current_title=_workbench_label("现装",Rect2(20,4,250,28),18,CREAM)
    _level_label=_workbench_label("",Rect2(190,7,150,22),13,Color("b8d3ca"))
    _upgrade_section_title=_workbench_label("装备升级",Rect2(20,42,400,24),16)
    _comparison_title=_workbench_label("装备选择",Rect2(460,42,174,24),16)
    _switch_state=_workbench_label("",Rect2(638,46,122,18),12,Color("946338"));_switch_state.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    _workbench_divider=ColorRect.new();_workbench_divider.position=Vector2(440,48);_workbench_divider.size=Vector2(1,110);_workbench_divider.color=Color("b5c3b8");_workbench_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;_workbench.add_child(_workbench_divider)
    _upgrade_data=Panel.new();var data:Panel=_upgrade_data;data.name="UpgradeValues";data.position=Vector2(100,85);data.size=Vector2(320,80);data.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var glass:=_surface_material("glass",Color.WHITE,"instrument");data.add_theme_stylebox_override("panel",glass);_workbench.add_child(data)
    _large_icon=_icon("laser",Rect2(27,95,52,47),_workbench)
    _current_caption=_workbench_label("当前攻击力",Rect2(114,91,140,18),12,Color("4a6265"))
    _upgrade_caption=_workbench_label("升级后",Rect2(290,91,146,18),12,Color("4a6265"))
    _current_value=_workbench_label("—",Rect2(114,109,140,38),27)
    _upgrade_arrow=_workbench_label("→",Rect2(257,105,32,32),23,Color("72938d"))
    _next_value=_workbench_label("—",Rect2(290,109,148,38),27,TEAL)
    for value in [_current_value,_next_value]:value.mouse_filter=Control.MOUSE_FILTER_PASS;value.clip_text=true
    _cost=_workbench_label("本次费用",Rect2(22,204,90,25),13,Color("4a6265"))
    for id in RESOURCE_NAMES:
        var mark:=_resource_icon(id,20,_workbench)
        var name:=_workbench_label(RESOURCE_NAMES[id],Rect2(0,0,90,22),13,Color("4a6265"))
        var amount:=_workbench_label("",Rect2(0,0,220,26),17,INK)
        amount.add_theme_font_override("font",_font_strong);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        _cost_cells[id]={"icon":mark,"name":name,"amount":amount}
    _payment_state=_workbench_label("",Rect2(278,204,160,25),13,Color("a75a3d"));_payment_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _quantity_button=_workbench_button("×1",Rect2(20,208,96,36),_cycle_quantity)
    _quantity_button.name="QuantityCycle"
    _purchase=_workbench_button("购买1级",Rect2(226,240,218,36),_buy,"primary");_purchase.name="Purchase"
    _purchase.clip_text=true;_purchase.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _candidate_row=Control.new();_candidate_row.name="CandidateChoices";_candidate_row.position=Vector2(464,74);_candidate_row.size=Vector2(296,88);_candidate_row.clip_contents=true;_candidate_row.mouse_filter=Control.MOUSE_FILTER_PASS;_workbench.add_child(_candidate_row)
    _comparison_group=Control.new();_comparison_group.name="DifferentCandidateComparison";_comparison_group.position=Vector2(464,170);_comparison_group.size=Vector2(296,64);_comparison_group.clip_contents=true;_comparison_group.mouse_filter=Control.MOUSE_FILTER_PASS;_workbench.add_child(_comparison_group)
    for column in 2:
        var header_label:=_workbench_label("",Rect2(52+column*124,0,118,18),12,INK if column==0 else TEAL,_comparison_group)
        header_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;header_label.add_theme_font_override("font",_font_strong);_compare_headers.append(header_label)
        var value:=_workbench_label("—",Rect2(52+column*124,18,118,25),17,INK if column==0 else TEAL,_comparison_group)
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.add_theme_font_override("font",_font_strong);_compare_values.append(value)
    _compare_row_label=_workbench_label("攻击力",Rect2(0,18,48,25),12,Color("4a6265"),_comparison_group)
    _period_caption=_workbench_label("周期",Rect2(0,43,48,18),12,Color("4a6265"),_comparison_group)
    _install=_workbench_button("安装",Rect2(484,220,266,36),_equip,"primary");_install.name="Install"

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
    var height:float=maxf(288.0 if different and not defence else 266.0,266.0+maxi(0,rows-1)*22.0)
    var action_y:float=height-68.0
    _workbench.position.y=896.0-height;_workbench.size.y=height
    _workbench_divider.size.y=action_y-48.0
    _upgrade_data.position=Vector2(100,70)
    _candidate_row.position=Vector2(460,70 if different else roundf(70.0+(action_y-70.0-100.0)*0.5));_candidate_row.size.y=100
    _comparison_group.position=Vector2(460,176);_comparison_group.size.y=43
    _install.position=Vector2(20 if defence and different else 460,action_y);_install.size=Vector2(740 if defence and different else 300,36)
    _quantity_button.position=Vector2(20,action_y);_quantity_button.size=Vector2(96,36)
    _purchase.position=Vector2(128,action_y);_purchase.size=Vector2(292 if different else 632,36)
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
    _current_icon_geometry={"key":key,"allocation_inner":Rect2(_workbench.global_position+Vector2(21,_workbench_layout.data_y+1),Vector2(64,78)),"safe":Rect2(_workbench.global_position+safe.position,safe.size),"visible_rect":_large_icon.get_global_rect(),"alpha_centre_normalized":mass,"displayed_alpha_centre":_large_icon.global_position+_large_icon.size*mass,"primary_surface_centre_y":_workbench.global_position.y+_workbench_layout.data_y+40,"optical_mass_offset_y":3}

func _render_costs(quote: Dictionary, affordable: bool, reason: String) -> void:
    var keys: Array = quote.get("costs",{}).keys() if quote.get("ok",false) else []
    for id in _cost_cells:_cost_cells[id].icon.hide();_cost_cells[id].name.hide();_cost_cells[id].amount.hide()
    _purchase.tooltip_text=""
    var first_row_y:float=_workbench_layout.fee_y
    _cost.text="升级费用";_cost.position=Vector2(20,first_row_y);_cost.size=Vector2(84,22)
    _cost.visible=affordable;_payment_state.visible=not affordable
    _payment_state.position=Vector2(20,first_row_y);_payment_state.size=Vector2(84,22)
    _payment_state.text="" if affordable else _reason(reason);_payment_state.tooltip_text=_payment_state.text
    _payment_state.autowrap_mode=TextServer.AUTOWRAP_OFF;_payment_state.clip_text=true;_payment_state.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_payment_state.mouse_filter=Control.MOUSE_FILTER_PASS
    for index in keys.size():
        var id:String=str(keys[index])
        if not _cost_cells.has(id):continue
        var cell:Dictionary=_cost_cells[id]
        var width:float=308.0
        var x:float=112.0
        var row_y:float=first_row_y+index*22
        cell.icon.position=Vector2(x,row_y+1);cell.icon.show()
        cell.name.position=Vector2(x+24,row_y);cell.name.size=Vector2(78,22)
        cell.amount.position=Vector2(x+106,row_y-3);cell.amount.size=Vector2(width-110,26)
        cell.name.text=RESOURCE_NAMES.get(id,id)
        var formatted:Dictionary=_session.amount_api.apply("to_display",[quote.costs[id]])
        cell.amount.text=PlayerText.number(str(formatted.text)) if formatted.ok else "未知"
        cell.amount.add_theme_color_override("font_color",INK if affordable else Color("a1593b"));cell.name.show();cell.amount.show()
    if not quote.get("ok",false):
        _payment_state.position=Vector2(112,first_row_y);_payment_state.size=Vector2(308,22)
        _payment_state.text=_reason(str(quote.get("reason",quote.get("error","Unknown"))))
    elif not affordable:_purchase.tooltip_text=_reason(reason)+"\n"+_cost_text(quote.costs)

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
    heading.add_theme_font_override("font",_font_strong);heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",CREAM)
    stack.add_child(heading)
    _batch_quantity=_button("每槽 ×1",Rect2(0,0,270,40),_cycle_batch_quantity)
    remove_child(_batch_quantity);_batch_quantity.custom_minimum_size=Vector2(132,40)
    _batch_scroll=ScrollContainer.new();_batch_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    stack.add_child(_batch_scroll)
    var results:=VBoxContainer.new();results.custom_minimum_size.x=554;results.add_theme_constant_override("separation",15);_batch_scroll.add_child(results)
    _batch_results=Label.new();_batch_results.add_theme_font_size_override("font_size",16);_batch_results.add_theme_color_override("font_color",CREAM)
    _batch_results.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_batch_results.custom_minimum_size.x=548;results.add_child(_batch_results)
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);stack.add_child(row)
    row.add_child(_batch_quantity)
    _batch_submit=_button("执行升级",Rect2(0,0,270,44),_buy_all,true,"primary")
    remove_child(_batch_submit);_batch_submit.custom_minimum_size=Vector2(240,44);row.add_child(_batch_submit)
    _batch_close=_button("关闭",Rect2(0,0,270,44),_close_batch,false,"quiet")
    remove_child(_batch_close);_batch_close.custom_minimum_size=Vector2(140,44);row.add_child(_batch_close)
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
    if id==_candidate:return
    _candidate = id
    if _facts.is_empty():_dirty=true;return
    _refresh_choices(_selected_fact(),false)
    _comparison_dirty = true

func _queue_level_values(ids:Array)->void:
    for id in ids:_pending_level_ids[str(id)]=true

func _refresh_level_values()->void:
    presentation_counts.numeric_refreshes+=1
    presentation_counts.slot_fact_reads+=1
    _facts=_session.equipment_slot_facts()
    var selected_changed:bool=_pending_level_ids.has(_selected)
    for row in _facts:
        var id:String=str(row.id)
        if not _pending_level_ids.has(id) or not _slot_buttons.has(id):continue
        var signature:Array=[row.category,row.index,row.equipment_id,row.paid_level,id==_selected]
        if _slot_presentations.get(id)!=signature:
            _slot_presentations[id]=signature
            _slot_buttons[id].meta.text="Lv."+str(row.paid_level) if not str(row.equipment_id).is_empty() else ""
            presentation_counts.slots_updated+=1
    _pending_level_ids.clear()
    if _batch.visible:_refresh_batch()
    _batch_state_dirty=false
    if selected_changed or _comparison_dirty:_refresh_comparison()

func _refresh() -> void:
    _pending_level_ids.clear();_batch_state_dirty=false
    _dirty = false
    presentation_counts.refreshes += 1
    presentation_counts.slot_fact_reads += 1
    _facts = _session.equipment_slot_facts()
    if _batch.visible:_refresh_batch()
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
    _render_wallet()
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
    var replacement:bool=scope and different
    _layout_workbench(different,scope,0 if replacement else quote.get("costs",{}).size() if quote.get("ok",false) else 0)
    _place_current_icon(str(fact.equipment_id))
    _current_title.text = "%s · %s" % [_slot_name(_selected),NAMES.get(str(fact.equipment_id),"装备")]
    _level_label.text = "Lv."+str(fact.paid_level)
    var title_ink:Rect2=_text_ink_bounds(_current_title.text,_current_title.get_theme_font("font"),18)
    var level_ink:Rect2=_text_ink_bounds(_level_label.text,_level_label.get_theme_font("font"),13)
    _place_ink_label(_current_title,Vector2(32+title_ink.size.x*0.5,26))
    _place_ink_label(_level_label,Vector2(44+title_ink.size.x+level_ink.size.x*0.5,26))
    _current_value.text = _value(comparison.current)
    var shown_next = comparison.candidate if replacement else comparison.upgrade
    _next_value.text = _value(shown_next)
    _upgrade_caption.text = "替换后" if replacement else "升级后"
    _upgrade_section_title.text = "装备替换" if replacement else "装备升级"
    _current_value.tooltip_text=str(comparison.current.primary) if comparison.current is Dictionary and comparison.current.get("primary")!=null else _value(comparison.current)
    _next_value.tooltip_text=str(shown_next.primary) if shown_next is Dictionary and shown_next.get("primary")!=null else _value(shown_next)
    _purchase.visible=not replacement;_quantity_button.visible=not replacement
    _purchase.focus_mode=Control.FOCUS_NONE if replacement else Control.FOCUS_ALL
    _quantity_button.focus_mode=Control.FOCUS_NONE if replacement else Control.FOCUS_ALL
    _quantity_button.disabled=replacement
    if replacement:
        _cost.hide();_payment_state.hide()
        for cell in _cost_cells.values():cell.icon.hide();cell.name.hide();cell.amount.hide()
    else:_render_costs(quote,comparison.affordable,str(comparison.payment_reason))
    _cost.tooltip_text = "" if replacement else _cost_text(quote.costs) if quote.get("ok",false) else _payment_state.text
    _purchase.text = "购买%s级" % str(quote.count) if quote.get("ok", false) else "购买"
    if quote.get("ok",false) and _purchase.get_theme_font("font").get_string_size(_purchase.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>_purchase.size.x-20:
        _purchase.tooltip_text=("" if comparison.affordable else _purchase.tooltip_text+"\n")+_purchase.text
    _purchase.disabled = replacement or not comparison.affordable
    _switch_state.text = "换装冷却 %.1f秒" % float(fact.cooldown_remaining) if float(fact.cooldown_remaining)>0 else ""
    _switch_state.visible=(not scope or replacement) and not _switch_state.text.is_empty()

    var primary: String = "容量" if fact.category == "defence" else "攻击力"
    _current_caption.text = "当前" + primary
    _layout_primary_values()
    _install.text = "安装" + str(NAMES.get(_candidate, "装备")) if not _candidate.is_empty() else "选择装备"
    _install.disabled = _candidate.is_empty() or not comparison.switch_admission.ok
    _install.tooltip_text = "" if comparison.switch_admission.ok or str(comparison.switch_admission.get("reason",""))=="EquipmentSwitchLocked" else _reason(str(comparison.switch_admission.reason))
    _comparison_group.visible=_selection_open and different and not scope
    _install.visible=_selection_open and different
    _comparison_title.text = "装备选择"
    _compare_row_label.text=primary
    for column in 2:
        var row = comparison.current if column==0 else comparison.candidate
        _compare_headers[column].text=("现装" if column==0 else "替换后")+(" · "+_interval(row) if fact.category=="weapon" else "")
        _compare_values[column].text=_value(row)
    _period_caption.position=Vector2(0,0)
    _period_caption.visible=fact.category=="weapon"
    if _candidate.is_empty():
        _install.text="选择装备"
        _install.tooltip_text=""
    elif str(comparison.switch_admission.get("reason",""))=="NoChange":_install.text="已装备"
    elif str(comparison.switch_admission.get("reason",""))=="EquipmentLocked":_install.text="尚未解锁"
    _quantity_button.text="MAX" if _maximum else "×"+str(_quantity)

func _cycle_quantity() -> void:
    if _maximum:_maximum=false;_quantity=1
    elif _quantity==1:_quantity=10
    else:_maximum=true;_quantity=1
    _comparison_dirty=true

func _cycle_batch_quantity() -> void:
    _batch_mode=(_batch_mode+1)%3
    _batch_quantity.text=["每槽 ×1","每槽 ×10","逐槽 MAX"][_batch_mode]

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
            title.add_theme_font_override("font",_font_strong)
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

func _refresh_choices(fact: Dictionary, read_options:bool=true) -> void:
    if read_options or _choice_option_slot!=_selected:
        presentation_counts.equipment_option_reads+=1
        _choice_options=_session.equipment.panel_equipment(_selected)
        _choice_option_slot=_selected
    var options: Array=_choice_options
    var live: Array=[]
    var column: int=0
    var defence:bool=str(fact.category)=="defence"
    var cell_width:float=144.0 if defence else 68.0
    var step:float=152.0 if defence else 76.0
    for option in options:
        var id: String=str(option.id)
        if id.is_empty():continue
        live.append(id)
        if not _choices.has(id):
            var button:=_button("",Rect2(0,0,68,88),_select_candidate.bind(id),false,"candidate")
            remove_child(button);_candidate_row.add_child(button)
            button.name="Candidate_"+id
            var icon:=_icon(id,Rect2(16,8,36,32),button)
            var caption:=_label("",Rect2(3,42,62,20),13,INK)
            remove_child(caption);button.add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            caption.add_theme_font_override("font",_font_strong)
            caption.size=Vector2(62,20)
            var status:=_label("",Rect2(3,62,62,18),12,Color("4a6967"))
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
        item.button.position=Vector2(column*step,0)
        item.button.size=Vector2(cell_width,100)
        item.icon.position=Vector2((cell_width-44)*0.5,8)
        item.icon.size=Vector2(44,44)
        item.caption.position=Vector2(3,58);item.caption.size=Vector2(cell_width-6,20)
        item.status.position=Vector2(3,78);item.status.size=Vector2(cell_width-6,18)
        # Keep the catalog column even while its whole control is hidden. Unlocking never compacts the row.
        item.button.visible=_selection_open and option.enabled;item.button.disabled=not option.enabled
        item.button.mouse_filter=Control.MOUSE_FILTER_STOP if option.enabled else Control.MOUSE_FILTER_IGNORE
        item.button.focus_mode=Control.FOCUS_ALL if option.enabled else Control.FOCUS_NONE
        item.button.tooltip_text=""
        item.caption.text=str(NAMES.get(id,option.name))
        item.status.text="已装备" if str(fact.equipment_id)==id else ""
        item.caption.modulate=Color.WHITE if option.enabled else Color("b1beb9")
        item.icon.modulate=Color.WHITE
        item.icon.material=null
        item.status.add_theme_color_override("font_color",Color("4a6967") if option.enabled else Color("856e4b"))
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
        var label: String = RESOURCE_NAMES.get(str(id), str(id))
        parts.append((PlayerText.number(str(result.text)) if result.ok else "未知") + " " + label)
    return " / ".join(parts) if not parts.is_empty() else "0"

func _buy() -> void:
    var inputs: Dictionary = _session.equipment_inputs()
    var result: Dictionary = _session.equipment.buy_max_levels(_selected, inputs, _session.economy.affordable, _session.economy.payment, _session.publish_equipment_levels) if _maximum else _session.equipment.buy_levels(_selected, _quantity, inputs, _session.economy.payment, _session.publish_equipment_levels)
    _accept_result(result,true)

func _equip() -> void:
    _accept_result(_session.equipment.equip_slot(_selected, _candidate, _session.equipment_inputs(), _session.publish_equipment_refit))

func _buy_all() -> void:
    var mode: int = _batch_mode
    var result: Dictionary = _session.equipment.buy_all_levels(10 if mode == 1 else 1, mode == 2, _session.equipment_inputs(), _session.economy.affordable, _session.economy.payment, _session.publish_equipment_levels)
    _last_batch_result = result.duplicate(true)
    _accept_result(result,true)

func _slot_name(id: String) -> String:
    var pieces := id.split(":")
    return ("武器" if pieces[0] == "weapon" else "防御") + str(int(pieces[1]) + 1) if pieces.size() == 2 else id

func _accept_result(result: Dictionary, level_command:bool=false) -> void:
    last_result = result.duplicate(true)
    if level_command:
        _comparison_dirty=true;_batch_state_dirty=true
        for purchase in result.get("purchase_receipt",{}).get("purchases",[]):_pending_level_ids[str(purchase.slot_id)]=true
    else:_dirty = true
    command_finished.emit(last_result)

func _refresh_batch() -> void:
    var result: Dictionary = _last_batch_result
    var receipt: Dictionary = result.get("purchase_receipt", {})
    var status: String = str(receipt.get("commit_status", ""))
    var unknown: bool = status == "fault_unknown" or (result.get("fault", false) and status != "accepted")
    var active:Array=_facts.filter(func(row):return not row.dormant)
    var height:float=clampf(210.0+active.size()*28.0,286.0,500.0)
    var position_y:float=roundf((900.0-height)*0.5)
    _batch.position.y=position_y;_batch.size.y=height
    _batch_frame.position.y=position_y;_batch_frame.size.y=height
    var current: String = "\n".join(_facts.filter(func(row): return not row.dormant).map(func(row): return "%s · %s · Lv.%s" % [_slot_name(str(row.id)), NAMES.get(str(row.equipment_id), "空槽"), str(row.paid_level)]))
    if unknown:
        _batch_results.text = "提交结果未知，会话已停止。\n" + current
    elif not result.is_empty() and not result.get("ok", false):
        _batch_results.text = _reason(str(result.get("reason", result.get("error", "Unknown")))) + "\n" + current
    else:
        _batch_results.text = current
    _batch_submit.disabled = unknown or (status == "accepted" and receipt.get("purchases", []).is_empty()) or not _session.run_state.is_running()

func _process(dt: float) -> void:
    if not is_visible_in_tree(): return
    _clock += dt
    var cooldown: bool = _facts.any(func(row): return float(row.cooldown_remaining) > 0)
    if _dirty:
        _clock = 0.0
        _refresh()
    elif not _pending_level_ids.is_empty():
        _refresh_level_values()
    elif _comparison_dirty:
        _refresh_comparison()
        if _batch_state_dirty and _batch.visible:_refresh_batch()
        _batch_state_dirty=false
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
    _switch_state.visible=(str(fact.category)!="defence" or (not _candidate.is_empty() and _candidate!=str(fact.equipment_id))) and not _switch_state.text.is_empty()


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
    return _batch.visible

func prepare_host_hide(force: bool = false) -> bool:
    if has_exclusive_ui() and not force:return false
    if force:
        _close_batch()
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
