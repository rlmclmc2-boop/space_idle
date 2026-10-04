extends RefCounted
## QA-only input adapter. Native input owns action dispatch; never emit signals.
var scene
var tree:SceneTree
var cursor:=Vector2.ZERO
var last_gate:Dictionary={}
func setup(owner,root_tree:SceneTree)->void:
	scene=owner;tree=root_tree
func modal_windows()->Array:
	var windows:Array=tree.root.find_children("*","Window",true,false)
	for window in scene.get_viewport().get_embedded_subwindows():
		if not windows.has(window):windows.append(window)
	return windows.filter(func(window):return window.visible and (window.exclusive or window.popup_window))
func available(control)->bool:
	return is_instance_valid(control) and control is Control and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled)
func clipped_rect(control:Control)->Rect2:
	var result:Rect2=control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
	result=result.intersection(control.get_viewport_rect())
	var parent=control.get_parent()
	while parent is Control:
		if parent.clip_contents:result=result.intersection(parent.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,parent.size))
		parent=parent.get_parent()
	return result
func scroll_needed(control:Control)->ScrollContainer:
	if clipped_rect(control).size.x>2 and clipped_rect(control).size.y>2:return null
	var parent=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:return parent
		parent=parent.get_parent()
	return null
func gate(control)->Dictionary:
	var state:Dictionary={"visible":false,"enabled":false,"modal":not modal_windows().is_empty(),"in_viewport":false}
	if not is_instance_valid(control):return state
	state["path"]=str(control.get_path());state.visible=control.is_visible_in_tree()
	state.enabled=not control is BaseButton or not control.disabled
	state.in_viewport=clipped_rect(control).size.x>2 and clipped_rect(control).size.y>2
	return state
func motion(point:Vector2)->void:
	var event:=InputEventMouseMotion.new()
	event.position=tree.root.get_final_transform()*point
	event.relative=tree.root.get_final_transform().basis_xform(point-cursor)
	cursor=point;Input.parse_input_event(event)
	await tree.process_frame
func press(control)->bool:
	# Container relayout is deferred by the engine. Settle its actual frame;
	# do not use stale or zero rectangles after an unlock/page/hull change.
	await tree.process_frame
	last_gate=gate(control)
	if not last_gate.visible or not last_gate.enabled or last_gate.modal or not last_gate.in_viewport:return false
	var point:=clipped_rect(control).get_center()
	await motion(point)
	var hovered=tree.root.gui_get_hovered_control()
	last_gate["hovered"]=str(hovered.get_path()) if is_instance_valid(hovered) else ""
	last_gate["hit"]=hovered==control or (is_instance_valid(hovered) and control.is_ancestor_of(hovered))
	if not last_gate.hit:return false
	var current:=gate(control)
	last_gate["enabled_at_dispatch"]=current.enabled
	if not current.visible or not current.enabled or current.modal or not current.in_viewport:return false
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		event.position=tree.root.get_final_transform()*point
		Input.parse_input_event(event);await tree.process_frame
	return true
func popup_choice(menu:PopupMenu,index:int)->bool:
	last_gate={"path":str(menu.get_path()),"visible":menu.visible,"enabled":index>=0 and index<menu.item_count and not menu.is_item_disabled(index),"modal_owner":modal_windows().has(menu),"index":index}
	if not last_gate.visible or not last_gate.enabled or not last_gate.modal_owner:return false
	var style:=menu.get_theme_stylebox("panel")
	var row_height:float=(menu.get_contents_minimum_size().y-style.get_minimum_size().y)/menu.item_count
	var point:=Vector2(menu.size.x*.5,style.get_content_margin(SIDE_TOP)+row_height*(index+.5))
	last_gate["in_viewport"]=Rect2(Vector2.ZERO,Vector2(menu.size)).has_point(point)
	if not last_gate.in_viewport:return false
	# Route via the real window input path. push_input on PopupMenu's viewport
	# does not deliver Window's native window_input notification.
	var window_id:int=tree.root.get_window_id() if menu.is_embedded() else menu.get_window_id()
	var input_point:Vector2=tree.root.get_final_transform()*(Vector2(menu.position)+point) if menu.is_embedded() else menu.get_final_transform()*point
	last_gate["point"]=point;last_gate["input_point"]=input_point;last_gate["embedded"]=menu.is_embedded();last_gate["position"]=menu.position
	var motion_event:=InputEventMouseMotion.new();motion_event.position=input_point;motion_event.window_id=window_id
	Input.parse_input_event(motion_event);await tree.process_frame
	if menu.is_embedded():cursor=Vector2(menu.position)+point
	last_gate["focused_after_motion"]=menu.get_focused_item()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=input_point;event.window_id=window_id
		Input.parse_input_event(event);await tree.process_frame
	last_gate["closed_after_input"]=not menu.visible
	return not menu.visible
func scroll(control:Control,container:ScrollContainer)->bool:
	await tree.process_frame
	if not modal_windows().is_empty() or not available(container):return false
	var point:=clipped_rect(container).get_center()
	await motion(point)
	var target:Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var before:=Vector2(container.scroll_horizontal,container.scroll_vertical)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_WHEEL_DOWN if target.y>point.y else MOUSE_BUTTON_WHEEL_UP
	event.pressed=true;event.position=tree.root.get_final_transform()*point
	Input.parse_input_event(event);await tree.process_frame
	last_gate={"path":str(container.get_path()),"scroll_before":before,"scroll_after":Vector2(container.scroll_horizontal,container.scroll_vertical)}
	return before!=Vector2(container.scroll_horizontal,container.scroll_vertical)
func pickup_point(drop:Dictionary)->Variant:
	if scene.resource_input_blocked() or not modal_windows().is_empty():return null
	var point:Vector2=scene.battle_layer.get_global_transform_with_canvas()*scene.drop_render_position(drop)
	var field:Rect2=scene.battle_clip.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,scene.battle_clip.size)
	field=field.intersection(scene.get_viewport_rect())
	if not field.has_point(point):return null
	var covers:Array[Rect2]=[]
	for child in scene.get_children():
		if child is Control:scene.pickup_control_rects(child,field,field,covers)
	if covers.any(func(rect):return rect.has_point(point)):return null
	return point
func pickup(drop:Dictionary)->bool:
	var point=pickup_point(drop)
	last_gate={"uid":drop.uid,"actual_viewport_point":point,"modal":not modal_windows().is_empty(),"resource_input_blocked":scene.resource_input_blocked()}
	if point==null:return false
	await motion(point)
	return not scene.game.drops.any(func(item):return item.uid==drop.uid)
