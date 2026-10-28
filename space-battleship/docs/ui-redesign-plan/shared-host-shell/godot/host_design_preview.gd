extends SceneTree
## H2 design presentation only. Does not load main, Session, native, config or saves.
const BASE := "res://docs/ui-redesign-plan/shared-host-shell/"
const NAV := [["装备",80,"equipment"],["反应炉",96,"reactor"],["科研",80,"research"],["强化",80,"enhancement"],["船员",80,"crew"],["星球",80,"planet"],["星系",80,"galaxy"],["超空间",96,"hyperspace"],["更多",80,""]]
var host: Control
var body: Control
var header: Control
var menu: Control
var folded: Control
var detail: Control
var popup_blocker: Control
var collapse_button: Button
var font: FontVariation
var body_font: FontVariation
var font_file: FontFile
var texture_cache := {}
var nav_buttons: Array[Button] = []
var money_labels: Array[Label] = []
var save_label: Label
var snapshots: Array = []
var output_dir := ""
var interactive := false

func _initialize() -> void:
	call_deferred("_build")

func _texture(path: String) -> Texture2D:
	if texture_cache.has(path): return texture_cache[path]
	var source := Image.new()
	var error := source.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Design asset load failed: " + path)
		return null
	var texture := ImageTexture.create_from_image(source)
	texture_cache[path] = texture
	return texture

func _surface(parent: Node, rect: Rect2, colour: Color) -> ColorRect:
	var surface := ColorRect.new()
	surface.position = rect.position
	surface.size = rect.size
	surface.color = colour
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	return surface

func _picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture = _texture(path)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _label(parent: Node, text: String, rect: Rect2, px: int = 16, colour: Color = Color("ecebdc")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _box(colour: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _button(parent: Node, text: String, rect: Rect2, selected: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("h_separation",6)
	button.add_theme_constant_override("icon_max_width",18)
	button.expand_icon = true
	button.add_theme_stylebox_override("normal", _box(Color("e9e3ce") if selected else Color("173847"), Color("c6c0a7") if selected else Color("365d69")))
	button.add_theme_stylebox_override("hover", _box(Color("f3ecd7") if selected else Color("2b5360"), Color("87b7b9")))
	button.add_theme_stylebox_override("pressed", _box(Color("d6dfcd") if selected else Color("315b67"), Color("83cfcb")))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("a3eee3")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("183d4a") if selected else Color("e1ebe3"))
	parent.add_child(button)
	button.size = rect.size
	return button

func _build() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--interactive": interactive = true
		if argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
	if output_dir.is_empty(): output_dir = ProjectSettings.globalize_path(BASE + "godot/evidence")
	DirAccess.make_dir_recursive_absolute(output_dir)
	font_file = FontFile.new()
	font_file.data = FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansSC.ttf")
	font_file.allow_system_fallback = false
	font = FontVariation.new()
	font.base_font = font_file
	font.variation_opentype = {2003265652:450.0}
	body_font = FontVariation.new()
	body_font.base_font = font_file
	body_font.variation_opentype = {2003265652:400.0}
	root.title = "H2 shared-host design preview | module placeholders | no Session"
	root.size = Vector2i(1440,900)
	root.position = Vector2i.ZERO
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.mode = Window.MODE_WINDOWED
	root.close_requested.connect(quit)
	host = Control.new()
	host.size = Vector2(1440,900)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	host.theme = theme
	root.add_child(host)
	_surface(host,Rect2(0,0,1440,900),Color("071723"))
	_build_module_placement()
	_build_battle_placement()
	_surface(host,Rect2(807,65,1,835),Color("457d81"))
	_build_header()
	_build_more()
	_build_folded()
	_build_detail()
	if not interactive: _capture_design_states()

func _build_module_placement() -> void:
	body = Control.new()
	body.size = Vector2(808,900)
	body.clip_contents = true
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	body.theme = theme
	host.add_child(body)
	_surface(body,Rect2(0,0,808,900),Color("0e3440"))
	_picture(body,BASE+"references/shared-backdrop-h2.png",Rect2(0,0,808,900))
	_picture(body,BASE + "references/reactor-quality-four.png",Rect2(96.8,20,614.4,921.6))
	# Local level is carried by the proposed shared context slot, not by a side gap.
	for item in [[140.0,235.2,"武器","38"],[512.0,235.2,"盾甲","38"],[140.0,726.0,"铁产出","37"],[512.0,726.0,"碎片","37"]]:
		var point := Vector2(float(item[0]),float(item[1]))
		_surface(body,Rect2(point,Vector2(166,78)),Color("082f3ae6"))
		_surface(body,Rect2(point + Vector2(8,0),Vector2(150,1)),Color("79c4ba"))
		_label(body,str(item[2])+" ×1.18",Rect2(point+Vector2(12,4),Vector2(150,28)),18)
		_label(body,"手 "+str(item[3])+"　效 "+str(item[3]),Rect2(point+Vector2(12,30),Vector2(150,23)),14,Color("c1dfd9"))
		_surface(body,Rect2(point+Vector2(28,62),Vector2(100,8)),Color("214853"))
		_surface(body,Rect2(point+Vector2(28,62),Vector2(30,8)),Color("67bdb2"))
		var knob := Panel.new()
		knob.position = point+Vector2(51,58)
		knob.size=Vector2(16,16)
		knob.mouse_filter=Control.MOUSE_FILTER_IGNORE
		knob.add_theme_stylebox_override("panel",_box(Color("edf0df"),Color("90d9cf"),8))
		body.add_child(knob)
	_surface(body,Rect2(24,809,760,77),Color("092d38ee"))
	_surface(body,Rect2(36,810,736,1),Color("56a5a7"))
	_label(body,"容量 150　已配 150　剩余 0",Rect2(44,833,365,28))
	_button(body,"升级 · 14 铀",Rect2(427,828,151,44),true)
	_button(body,"均分",Rect2(586,833,62,36))
	var apply := _button(body,"确认",Rect2(656,833,66,36))
	apply.disabled=true
	_button(body,"还原",Rect2(729,833,53,36))

func _build_battle_placement() -> void:
	var projection := SubViewportContainer.new()
	projection.position = Vector2(855.875,0)
	projection.size = Vector2(572,960)
	projection.scale = Vector2.ONE * 0.9375
	host.add_child(projection)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(572,960)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	projection.add_child(viewport)
	var stage := Control.new()
	stage.size=Vector2(572,960)
	stage.clip_contents=true
	stage.theme=host.theme
	viewport.add_child(stage)
	_picture(stage,"res://assets/backgrounds/opening/stage_01.png",Rect2(0,-500,572,1684))
	_label(stage,"关卡 1 · 航行 · 417",Rect2(18,6,390,30))
	_button(stage,"暂停",Rect2(420,18,58,30))
	_picture(stage,"res://assets/ships/fleet_20261019/player/01-frigate.png",Rect2(228.85,445.075,114.3,149.85))
	_picture(stage,"res://assets/weapons/fleet_20261019/laser.png",Rect2(268.97,483.47,34,38.97))
	var hud := Panel.new()
	hud.position=Vector2(12,708)
	hud.size=Vector2(548,122)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_theme_stylebox_override("panel",_box(Color("091a29f0"),Color("31546a"),8))
	stage.add_child(hud)
	_label(stage,"舰船防御",Rect2(28,711,500,24),15,Color("e9f4fa"))
	_label(stage,"装甲 1,000 / 1,184",Rect2(28,735,440,25))
	var percent := _label(stage,"84%",Rect2(484,735,60,25),15,Color("edc878"))
	percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_surface(stage,Rect2(28,760,516,11),Color("1b3547"))
	_surface(stage,Rect2(28,760,433.44,11),Color("edc878"))
	_label(stage,"护盾 0 / 0",Rect2(28,777,440,25))
	percent=_label(stage,"0%",Rect2(484,777,60,25),15,Color("69d8ec"))
	percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_surface(stage,Rect2(28,802,516,11),Color("1b3547"))
	_label(stage,"累计伤害 1,040 · 主力 武器1",Rect2(20,902,532,25),14,Color("c1d5f0"))

func _build_header() -> void:
	header=Control.new()
	header.size=Vector2(808,65)
	header.z_index=10
	host.add_child(header)
	_surface(header,Rect2(0,0,808,32),Color("243f4e"))
	_surface(header,Rect2(0,32,808,33),Color("102d3a"))
	_surface(header,Rect2(0,31,808,1),Color("518b8d"))
	_surface(header,Rect2(0,64,808,1),Color("5b9a9e"))
	_label(header,"反应炉2级",Rect2(12,3,96,26))
	for item in [[116,160,"铁：45"],[284,160,"铀：1,976"],[452,208,"时空微粒：8,147"]]:
		_surface(header,Rect2(int(item[0]),3,1,26),Color("486c74"))
		var label:=_label(header,str(item[2]),Rect2(int(item[0])+7,3,int(item[1])-8,26),16,Color("f1e5bc"))
		money_labels.append(label)
	var resources:=_button(header,"⋯",Rect2(668,3,32,26))
	resources.pressed.connect(func(): _show_detail("全部资源 · 公开显示文本",[money_labels[0].text,money_labels[1].text,money_labels[2].text,"强化碎片：1.235×10^123"]))
	save_label=_label(header,"已保存",Rect2(708,3,88,26),16,Color("b8d3ca"))
	save_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var x:=12.0
	for item in NAV:
		var button:=_button(header,str(item[0]),Rect2(x,34,int(item[1]),30),str(item[0])=="反应炉")
		if not str(item[2]).is_empty(): button.icon=_texture("res://assets/ui/shell/"+str(item[2])+".svg")
		if str(item[0])=="更多": button.pressed.connect(_toggle_more)
		if str(item[0])=="反应炉": button.pressed.connect(_restore)
		button.size=Vector2(int(item[1]),30)
		nav_buttons.append(button)
		x+=int(item[1])+4

func _build_more() -> void:
	popup_blocker=Control.new()
	popup_blocker.size=Vector2(1440,900)
	popup_blocker.z_index=18
	popup_blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	popup_blocker.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			menu.hide()
			detail.hide()
			popup_blocker.hide()
			popup_blocker.accept_event()
			nav_buttons[8].grab_focus())
	host.add_child(popup_blocker)
	popup_blocker.hide()
	menu=Panel.new()
	menu.z_index=19
	menu.position=Vector2(500,65)
	menu.size=Vector2(296,384)
	menu.add_theme_stylebox_override("panel",_box(Color("0d2635f5"),Color("6b999c"),6))
	host.add_child(menu)
	_label(menu,"更多 · 当前反应炉",Rect2(16,6,264,30),14,Color("9bbfbe"))
	var index:=0
	for caption in ["舰船","航程与驻守","属性","档案 · 敌情 / 统计","通知","设置与保存","重铸远征","收起工作区"]:
		var button:=_button(menu,caption,Rect2(12,38+index*41,272,40))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if index==7:
			collapse_button=button
			button.pressed.connect(func():
				if folded.visible:_restore()
				else:_collapse())
		index+=1
	menu.hide()

func _build_folded() -> void:
	folded=Control.new()
	folded.position=Vector2(0,65)
	folded.size=Vector2(808,835)
	folded.z_index=4
	host.add_child(folded)
	_surface(folded,Rect2(0,0,808,835),Color("103540"))
	_picture(folded,BASE+"references/shared-backdrop-h2.png",Rect2(0,-65,808,900))
	var title:=_label(folded,"反应炉工作区已收起",Rect2(104,320,600,46),26)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var text:=_label(folded,"原工作上下文已保留",Rect2(104,374,600,28),16,Color("a9c7c4"))
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var restore:=_button(folded,"恢复反应炉工作区",Rect2(294,426,220,46),true)
	restore.pressed.connect(_restore)
	text=_label(folded,"也可点击顶部“反应炉”恢复",Rect2(104,484,600,28),14,Color("91b8b7"))
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	folded.hide()

func _toggle_more() -> void:
	menu.visible=not menu.visible
	detail.hide()
	collapse_button.text="恢复反应炉工作区" if folded.visible else "收起工作区"
	popup_blocker.visible=menu.visible

func _restore() -> void:
	menu.hide()
	detail.hide()
	popup_blocker.hide()
	folded.hide()
	body.show()
	nav_buttons[1].text="反应炉"
	nav_buttons[1].icon=_texture("res://assets/ui/shell/reactor.svg")
	nav_buttons[1].size=Vector2(96,30)
	nav_buttons[1].grab_focus()

func _collapse() -> void:
	popup_blocker.hide()
	menu.hide()
	detail.hide()
	var focused:=root.gui_get_focus_owner()
	if focused!=null:focused.release_focus()
	body.hide()
	folded.show()
	nav_buttons[1].text="反应炉·收"
	nav_buttons[1].icon=null
	nav_buttons[1].grab_focus()

func _build_detail() -> void:
	detail=Panel.new()
	detail.z_index=20
	detail.position=Vector2(12,65)
	detail.size=Vector2(784,300)
	detail.add_theme_stylebox_override("panel",_box(Color("173846f5"),Color("65969b"),6))
	host.add_child(detail)
	detail.hide()

func _show_detail(title: String, rows: Array) -> void:
	for child in detail.get_children():child.queue_free()
	_label(detail,title,Rect2(16,10,744,30),18)
	var y:=52.0
	for value in rows:
		var row:=_label(detail,str(value),Rect2(16,y,744,48))
		row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		y+=54
	detail.size.y=y+12
	detail.show()
	popup_blocker.show()
	menu.hide()

func _save_state(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture:=root.get_texture().get_image()
	var result:=capture.save_png(output_dir+"/"+name+"-1440x900.png")
	var record:={"name":name,"pixel_size":[capture.get_width(),capture.get_height()],"write_error":result,"window_size":DisplayServer.window_get_size(),"viewport_visible_rect":root.get_visible_rect(),"header_rect":header.get_rect(),"module_rect":body.get_rect(),"battle_logical_size":[572,960],"battle_projection_origin":[855.875,0],"battle_projection_scale":0.9375,"no_session":true,"module_placement_only":true}
	snapshots.append(record)
	print("H2_DESIGN_CAPTURE ",name," ",capture.get_size()," write=",result)

func _capture_design_states() -> void:
	await process_frame
	for i in NAV.size(): nav_buttons[i].size=Vector2(int(NAV[i][1]),30)
	await _save_state("normal")
	_toggle_more()
	await _save_state("more")
	_collapse()
	await _save_state("collapsed")
	_restore()
	await _save_state("restored")
	nav_buttons[1].release_focus()
	var large:=["铁：1.235×10^123","铀：9.999×10^999","时空微粒：1.235×10^123"]
	for i in 3:money_labels[i].text=large[i]
	save_label.text="待写入"
	await _save_state("large-values")
	var extreme:=["铁：1.234567890123456789×10^123456789012345678901234567890","铀：9.999×10^12345678901234567890","时空微粒：1.235×10^12345678901234567890"]
	for i in 3:money_labels[i].text=["铁：查看完整值","铀：查看完整值","微粒：查看完整值"][i]
	_show_detail("全部资源 · 完整公开显示文本",extreme+["强化碎片：1.235×10^123"])
	await _save_state("extreme-values")
	detail.hide()
	for i in 3:money_labels[i].text=["铁：45","铀：1,976","时空微粒：8,147"][i]
	save_label.text="保存失败"
	save_label.modulate=Color("ffce9f")
	_show_detail("保存失败",["当前进度尚未写入文件。请在“更多→设置与保存”查看真实状态并重试。","此处为设计故障样例；实际原因由既有SaveFiles结果提供。"])
	await _save_state("save-failure")
	for child in detail.get_children():child.queue_free()
	_label(detail,"活动上下文位 · 所有者交接示例（不是三模块接入）",Rect2(16,8,744,34),18)
	var captions:=["远航舰桥","反应炉2级","星球探索"]
	var caption_names:=["装备默认","反应炉等级","星球身份"]
	for i in 3:
		_label(detail,caption_names[i],Rect2(16,58+i*48,112,26))
		_surface(detail,Rect2(132,58+i*48,96,26),Color("243f4e"))
		_label(detail,captions[i],Rect2(132,58+i*48,96,26))
		_label(detail,"96×26 / 16px · 原组提供文字，不挤主体",Rect2(248,58+i*48,490,26),14)
	detail.size.y=220
	save_label.text="已保存"
	save_label.modulate=Color.WHITE
	await _save_state("context-captions")
	var caption_metrics:=[]
	for caption in captions:
		var advance:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		caption_metrics.append({"text":caption,"advance":advance,"slot_size":[96,26],"fits":advance.x<=96 and advance.y<=26})
	var nav_metrics:=[]
	for button in nav_buttons:
		nav_metrics.append({"text":button.text,"rect":button.get_rect(),"minimum_size":button.get_combined_minimum_size(),"font_size":button.get_theme_font_size("font_size"),"fits_width":button.get_combined_minimum_size().x<=button.size.x,"fits_height":button.get_combined_minimum_size().y<=button.size.y,"inside_65px_header":button.position.y>=32 and button.position.y+button.size.y<=65})
	var money_metrics:=[]
	for i in 3:
		var measured:=font.get_string_size(large[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		money_metrics.append({"text":large[i],"advance":measured,"available_width":money_labels[i].size.x,"fits_width":measured.x<=money_labels[i].size.x})
	var ts:=TextServerManager.get_primary_interface()
	var actual_axes: Dictionary=ts.call("font_get_variation_coordinates",font.get_rids()[0])
	var report:={"kind":"Godot 4.7.2 design preview, not gameplay integration", "engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"video_adapter":RenderingServer.get_video_adapter_name(),"window_size":DisplayServer.window_get_size(),"window_position":DisplayServer.window_get_position(),"window_mode":DisplayServer.window_get_mode(),"screen_size":DisplayServer.screen_get_size(),"screen_scale":DisplayServer.screen_get_scale(),"font_variation_requested":font.variation_opentype,"font_variation_actual":actual_axes,"font_height_16":font.get_height(16),"font_ascent_16":font.get_ascent(16),"font_descent_16":font.get_descent(16),"nav":nav_metrics,"money":money_metrics,"context_captions":caption_metrics,"active_context":"反应炉2级","captures":snapshots,"state_values":"static design strings, not native wallets or live progress","no_game_session":true,"no_native_loaded":not ClassDB.class_exists("SpaceCombatKernel"),"module_internal_design":"owner source asset placement only; level placed in shared 96px context slot as minimum collaboration proposal; no producer implementation"}
	var file:=FileAccess.open(output_dir+"/godot-design-record.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("H2_DESIGN_REPORT ",JSON.stringify(report))
	quit()
