extends Control
## Reflowed mechanical room; approved static housings and local effects are retained.
signal module_selected(id:String)
const Visual=preload("res://scripts/reactor_visual.gd")
var model:Dictionary={}
var editor:Control
var core_controls:Control
var selected:String=""
var _layout_selection:String=""
var _core
var _phase:float=0.0
var _running:bool=false
var _devices:Dictionary={}
var _panel_style:StyleBox
var _room:Texture2D
const TEXTURES={"weapons":"res://assets/ui/reactor/toon-weapons.svg","defence":"res://assets/ui/reactor/toon-defence.svg","smelting":"res://assets/ui/reactor/toon-smelting.svg","condensation":"res://assets/ui/reactor/toon-condensation.svg"}
func _ready()->void:
	custom_minimum_size.y=740
	_panel_style=load("res://src/ui/bridge_theme.gd").create().get_stylebox("panel","PanelContainer")
	_room=load("res://assets/ui/reactor/toon-console.svg")
	resized.connect(_update_height)
	clip_contents=true
	_core=Visual.new();_core.mode="core";_core.position=Vector2(22,46);_core.size=Vector2(230,230)
	add_child(_core)
	for id in TEXTURES:
		_devices[id]=load(TEXTURES[id])
func set_model(value:Dictionary,running:bool,time:float)->void:
	var layout_changed:bool=value!=model or selected!=_layout_selection
	_layout_selection=selected
	if value!=model or running and time!=_phase:
		model=value;_phase=time;queue_redraw()
	if layout_changed:_update_height()
	_running=running
	if _core!=null:
		_core.set_ratio(float(model.get("load",0.0)))
		_core.set_process(running and is_visible_in_tree() and float(model.get("load",0.0))>0.0)
func _editor_height()->float:
	return editor.get_combined_minimum_size().y+16 if editor!=null else 180.0
func _update_height()->void:
	var modules:Array=model.get("modules",[])
	var selected_index:int=-1
	for i in modules.size():
		if modules[i].id==selected:selected_index=i
	custom_minimum_size.y=maxf(590,(340 if size.x<700 else 18)+modules.size()*176+(_editor_height() if selected_index>=0 else 0)+16)
	if core_controls!=null:
		core_controls.position=Vector2(265,180) if size.x<700 else Vector2(22,420)
		core_controls.size=Vector2(235,180) if size.x<700 else Vector2(230,180)
	if editor!=null:
		editor.visible=selected_index>=0
		if selected_index>=0:
			var bay:Rect2=_bay(selected_index)
			editor.position=bay.position+Vector2(12,152)
			editor.size=Vector2(bay.size.x-24,_editor_height()-12)
	queue_redraw()
func _bay(index:int)->Rect2:
	var y:float=(340 if size.x<700 else 18)+index*176
	var height:float=164.0
	for i in model.get("modules",[]).size():
		if model.modules[i].id==selected:
			if i<index:y+=_editor_height()
			if i==index:height+=_editor_height()
	return Rect2(12,y,size.x-24,height) if size.x<700 else Rect2(316,y,size.x-328,height)
func _draw()->void:
	var font:Font=ThemeDB.fallback_font
	if _panel_style!=null:draw_style_box(_panel_style,Rect2(Vector2.ZERO,size))
	if _room!=null:draw_texture_rect_region(_room,Rect2(22,46,230,230),Rect2(187,70,350,350))
	if model.is_empty():return
	draw_string(font,Vector2(26,32),"反应炉  Lv.%s"%model.level,HORIZONTAL_ALIGNMENT_LEFT,270,23,Color("e3f2f4"))
	var trunk:float=24.0 if size.x<700 else 289.0
	var end:float=_bay(maxi(0,model.modules.size()-1)).end.y-16
	var pipe:=PackedVector2Array([Vector2(137,274),Vector2(137,330),Vector2(trunk,330),Vector2(trunk,end)])
	draw_polyline(pipe,Color("1e3c4c"),18,true);draw_polyline(pipe,Color("548493"),3,true)
	for index in model.modules.size():
		var row:Dictionary=model.modules[index]
		var bay:Rect2=_bay(index)
		draw_line(Vector2(trunk,bay.get_center().y),Vector2(bay.position.x+50,bay.get_center().y),Color("4b7f8a"),12,true)
		draw_texture_rect(load("res://assets/ui/reactor/toon-bay.svg"),bay,false,Color.WHITE if row.enabled else Color(0.45,0.5,0.54))
		if row.id==selected:draw_rect(bay.grow(-3),Color("6edbdf"),false,2,true)
		var device:Texture2D=_devices[row.id]
		var span:Vector2=device.get_size()*minf(130.0/device.get_width(),130.0/device.get_height())
		draw_texture_rect(device,Rect2(bay.position+Vector2(18,17)+(Vector2(130,130)-span)*0.5,span),false)
		var x:float=bay.position.x+164
		draw_string(font,Vector2(x,bay.position.y+35),row.name+ ("" if row.enabled else " · 未开放"),HORIZONTAL_ALIGNMENT_LEFT,bay.size.x-180,21,Color("243d50"))
		draw_string(font,Vector2(x,bay.position.y+67),"手动 %s  ·  免费 %s"%[row.allocation,row.free],HORIZONTAL_ALIGNMENT_LEFT,bay.size.x-180,16,Color("506878"))
		draw_string(font,Vector2(x,bay.position.y+96),"有效 %s · 最终 ×%s"%[row.effective,row.factor],HORIZONTAL_ALIGNMENT_LEFT,bay.size.x-180,18,Color("286b73"))
		var width:float=maxf(50,bay.size.x-180)
		draw_rect(Rect2(x,bay.position.y+117,width,12),Color("071923"))
		draw_rect(Rect2(x,bay.position.y+117,width*row.ratio,12),Color("47bdc8"))
		if row.enabled and row.load>0 and _running:
			var pulse:float=fposmod(_phase*65.0,150.0)
			draw_circle(Vector2(trunk,bay.position.y+12+pulse),3,Color("a1ffff"))
	var summary:Vector2=Vector2(265,100) if size.x<700 else Vector2(25,335)
	draw_string(font,summary,"总能源  %s"%model.capacity,HORIZONTAL_ALIGNMENT_LEFT,245,21,Color("c6e8ef"))
	draw_string(font,summary+Vector2(0,37),"可分配  %s"%model.remaining,HORIZONTAL_ALIGNMENT_LEFT,245,21,Color("7bdfdc"))

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for i in model.get("modules",[]).size():
			if _bay(i).has_point(event.position):
				selected=model.modules[i].id;module_selected.emit(selected);_update_height();accept_event();return
