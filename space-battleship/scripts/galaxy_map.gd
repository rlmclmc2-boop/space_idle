extends Control
## Independent, bounded 3D presentation. No gameplay mutation or saved visual state.
signal slot_selected(id: int)
var region
var settings := {}
var view := SubViewport.new()
var container := SubViewportContainer.new()
var world := Node3D.new()
var camera := Camera3D.new()
var models := Node3D.new()
var core: Node3D
var slot_nodes := {}
var model_paths := {}
var scene_cache := {}
var material_cache := {}
var construction := {}
var activity: Array[Node3D] = []
var transports: Array = []
var explorers: Array = []
var pulses: Array = []
var rng := RandomNumberGenerator.new()
var fog_image: Image
var fog_texture: ImageTexture
var space_material := ShaderMaterial.new()
var building_revision := -1
var draw_updates := 0
var visual_ticks := 0
var visual_clock := 0.0
var explorer_tick := 0.0
var crew_count := 0
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var drag_distance := 0.0
var selected_slot := -1
var hover_slot := -1
var running := true
var highlight: MeshInstance3D
var cyan: StandardMaterial3D
var amber: StandardMaterial3D

func _ready() -> void:
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	container.stretch=true
	add_child(container)
	view.own_world_3d=true
	view.handle_input_locally=false
	view.msaa_3d=Viewport.MSAA_4X
	container.add_child(view)
	view.add_child(world)
	world.add_child(models)
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=600
	camera.current=true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("040a15")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("9ebcdb")
	env.ambient_light_energy=0.32
	environment.environment=env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-38,0)
	light.light_color=Color("fff1df")
	light.light_energy=1.05
	light.shadow_enabled=true
	light.directional_shadow_max_distance=260
	world.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-25,140,0)
	rim.light_color=Color("81bfff")
	rim.light_energy=0.4
	world.add_child(rim)
	cyan=material(Color("46cdea"))
	amber=material(Color("eaaa53"))
	space_material.shader=preload("res://scripts/galaxy_space.gdshader")
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(260,260)
	backdrop.mesh=plane
	backdrop.material_override=space_material
	backdrop.position.y=-5
	world.add_child(backdrop)
	highlight=ring(6.0,cyan)
	world.add_child(highlight)
	highlight.visible=false
	resized.connect(layout)
	visibility_changed.connect(sync_visibility)
	layout()
	sync_visibility()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.emission_enabled=true
	result.emission=color*0.35
	result.roughness=0.65
	return result
func ring(radius: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius=radius-0.10
	mesh.outer_radius=radius+0.10
	mesh.rings=32
	mesh.ring_segments=6
	node.mesh=mesh
	node.material_override=mat
	return node
func fallback_model() -> Node3D:
	var node := Node3D.new()
	var shape := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=2
	mesh.bottom_radius=3
	mesh.height=2
	mesh.radial_segments=8
	shape.mesh=mesh
	shape.position.y=1
	shape.material_override=cyan
	node.add_child(shape)
	var socket := Marker3D.new()
	socket.name="DockSocket"
	socket.position=Vector3(0,2,4)
	node.add_child(socket)
	return node
func asset(path: String) -> Node3D:
	var uri := path if path.begins_with("res://") else "res://"+path
	if not scene_cache.has(uri):scene_cache[uri]=load(uri) if not path.is_empty() and ResourceLoader.exists(uri,"PackedScene") else null
	var packed=scene_cache[uri]
	if not packed is PackedScene:return fallback_model()
	var node=packed.instantiate()
	if not node is Node3D:node.free();return fallback_model()
	share_materials(node)
	return node
func share_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for index in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(index)
			if mat==null:continue
			var key := mat.resource_name
			if key.is_empty():continue
			# The detailed core carries its albedo and baked occlusion in COLOR_0.
			# Some imported surfaces disable that material flag despite keeping colors.
			if key.begins_with("Core") and mat is StandardMaterial3D:
				# Soft baked occlusion fits the rounded core; avoid jagged self-shadows.
				node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var colors=node.mesh.surface_get_arrays(index)[Mesh.ARRAY_COLOR]
				if colors is PackedColorArray and not colors.is_empty():mat.vertex_color_use_as_albedo=true
			if not material_cache.has(key):material_cache[key]=mat
			node.set_surface_override_material(index,material_cache[key])
	for child in node.get_children():share_materials(child)
func configure(config: Dictionary) -> void:
	settings=config
func setting(key: String, default: float) -> float:return float(settings.get(key,{}).get("value",default))
func select(value) -> void:
	if region==value:return
	region=value
	for child in models.get_children():child.free()
	for pool in [transports,explorers,pulses]:
		for item in pool:item.node.free()
		pool.clear()
	slot_nodes.clear()
	model_paths.clear()
	construction.clear()
	activity.clear()
	building_revision=-1
	selected_slot=-1
	hover_slot=-1
	zoom=1
	pan=Vector2.ZERO
	if region==null:return
	rng.seed=int(region.row.slot_seed)+12345
	core=asset(str(region.row.core_asset))
	core.scale=Vector3.ONE*1.2
	models.add_child(core)
	fog_image=Image.create(int(region.row.map_w),int(region.row.map_h),false,Image.FORMAT_R8)
	for y in fog_image.get_height():
		for x in fog_image.get_width():fog_image.set_pixel(x,y,Color(float(region.cells[y*int(region.row.map_w)+x]),0,0))
	fog_texture=ImageTexture.create_from_image(fog_image)
	space_material.set_shader_parameter("explored",fog_texture)
	for slot in region.slots:
		var node := Node3D.new()
		node.name="Slot%d"%int(slot.id)
		node.position=Vector3(float(slot.world_pos[0]),0,float(slot.world_pos[1]))
		models.add_child(node)
		slot_nodes[int(slot.id)]=node
		var scaffold := ring(5.2,amber)
		scaffold.name="Scaffold"
		scaffold.position.y=0.3
		node.add_child(scaffold)
		var drone := MeshInstance3D.new()
		var drone_mesh := BoxMesh.new()
		drone_mesh.size=Vector3(0.5,0.3,0.7)
		drone.mesh=drone_mesh
		drone.material_override=amber
		scaffold.add_child(drone)
		construction[int(slot.id)]={"ring":scaffold,"drone":drone,"flash":0.0,"level":int(slot.level)}
		var upper := ring(5.2,amber)
		upper.position.y=4.0
		scaffold.add_child(upper)
		for corner in 4:
			var post := MeshInstance3D.new()
			var beam := BoxMesh.new()
			beam.size=Vector3(0.12,4,0.12)
			post.mesh=beam
			post.material_override=amber
			post.position=Vector3(cos(corner*PI/2)*5.2,2,sin(corner*PI/2)*5.2)
			scaffold.add_child(post)
	for _i in int(setting("max_transport_ships",12)):
		var ship := asset("assets/galaxy/v3/ships/transport_shuttle.glb")
		ship.visible=false
		world.add_child(ship)
		transports.append({"node":ship,"curve":Curve3D.new(),"phase":1.0,"duration":1.0})
	for _i in int(setting("max_visual_pulses",4)):
		var pulse := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius=0.22
		mesh.height=0.44
		pulse.mesh=mesh
		pulse.material_override=cyan
		pulse.visible=false
		world.add_child(pulse)
		pulses.append({"node":pulse})
	layout()
	refresh()
	sync_visibility()
func set_running(value: bool) -> void:
	if running==value:return
	running=value
	sync_visibility()
func sync_visibility() -> void:
	var active := is_visible_in_tree() and running and region!=null
	set_process(active)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	world.process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active:refresh()
func layout() -> void:
	if not is_inside_tree():return
	camera.size=120.0/zoom
	# Fixed isometric framing: 45-degree azimuth, 35.26-degree downward pitch.
	camera.position=Vector3(pan.x+130,130,pan.y+130)
	camera.look_at(Vector3(pan.x,0,pan.y),Vector3.UP)
func refresh() -> void:
	if region==null or not is_visible_in_tree():return
	if not region.dirty_chunks.is_empty():
		var width := ceili(float(region.row.map_w)/region.chunk_size)
		for id in region.dirty_chunks:
			var origin := Vector2i(int(id)%width,int(id)/width)*int(region.chunk_size)
			for y in range(origin.y,mini(origin.y+region.chunk_size,int(region.row.map_h))):
				for x in range(origin.x,mini(origin.x+region.chunk_size,int(region.row.map_w))):fog_image.set_pixel(x,y,Color(float(region.cells[y*int(region.row.map_w)+x]),0,0))
		fog_texture.update(fog_image)
		region.dirty_chunks.clear()
		draw_updates+=1
	if building_revision==region.building_revision:return
	building_revision=region.building_revision
	activity.clear()
	var core_ring=core.find_child("ActivityRing",true,false)
	if core_ring is Node3D:activity.append(core_ring)
	for slot in region.slots:
		var id := int(slot.id)
		var node: Node3D=slot_nodes[id]
		var path := str(region.builds[slot.type].get("asset_lv%d"%int(slot.level),"")) if slot.status!="empty" else "empty"
		if model_paths.get(id)!=path:
			var old=node.get_node_or_null("Building")
			if old!=null:old.free()
			if path!="empty":
				var model := asset(path)
				model.name="Building"
				model.scale=Vector3.ONE*1.2
				node.add_child(model)
			model_paths[id]=path
		if int(construction[id].level)<int(slot.level):construction[id].flash=0.8
		construction[id].level=int(slot.level)
		var building=node.get_node_or_null("Building")
		if building!=null:
			building.visible=slot.status!="constructing"
			var part=building.find_child("ActivityRing",true,false)
			if part is Node3D:activity.append(part)
		construction[id].ring.visible=slot.status in ["constructing","upgrading"]
		draw_updates+=1
func dock(id: int) -> Vector3:
	var node: Node3D=core if id<0 else slot_nodes[id]
	var socket=node.find_child("DockSocket",true,false)
	return socket.global_position if socket is Node3D else node.global_position+Vector3(0,2,0)
func new_route(item: Dictionary) -> void:
	var candidates: Array=region.slots.filter(func(slot):return slot.status!="empty")
	if candidates.is_empty():item.node.visible=false;item.phase=0.0;item.duration=1.0;return
	var source: Dictionary=candidates[rng.randi_range(0,candidates.size()-1)]
	var preferred := {"colony_ring":"orbital_shipyard","interstellar_refinery":"orbital_shipyard","crystal_refinery":"colony_ring","heavy_element_refinery":"orbital_shipyard"}
	var targets := candidates.filter(func(slot):return slot.id!=source.id and (source.type=="stellar_energy_array" or slot.type==preferred.get(source.type,"")))
	var a := int(source.id)
	var b := int(targets[rng.randi_range(0,targets.size()-1)].id) if not targets.is_empty() else -1
	if rng.randf()<0.35:b=a;a=-1
	var curve := Curve3D.new()
	var start := dock(a)
	var finish := dock(b)
	var middle := (start+finish)*0.5+Vector3(rng.randf_range(-4,4),4,rng.randf_range(-4,4))
	curve.add_point(start,Vector3.ZERO,(middle-start)*0.45)
	curve.add_point(middle,(start-middle)*0.3,(finish-middle)*0.3)
	curve.add_point(finish,(middle-finish)*0.45,Vector3.ZERO)
	item.curve=curve
	item.phase=0.0
	item.duration=maxf(5,curve.get_baked_length()/5)
	item.node.visible=true
func update_explorers() -> void:
	var count := mini(12,crew_count*int(region.row.ship_per_crew)) if region.state.status=="exploring" else 0
	while explorers.size()>count:explorers.pop_back().node.free()
	while explorers.size()<count:
		var ship := asset("assets/galaxy/v3/ships/transport_shuttle.glb")
		ship.scale=Vector3.ONE*1.25
		world.add_child(ship)
		explorers.append({"node":ship,"from":dock(-1),"to":dock(-1),"phase":0.0})
	for item in explorers:
		if region.frontier.is_empty():continue
		var cell: int=region.frontier[rng.randi_range(0,region.frontier.size()-1)]
		item.from=item.node.position if item.phase>0 else dock(-1)
		item.to=Vector3((float(cell%int(region.row.map_w))/float(region.row.map_w)-0.5)*260,3,(float(cell/int(region.row.map_w))/float(region.row.map_h)-0.5)*260)
		item.phase=0.0
func _process(dt: float) -> void:
	if not running or not is_visible_in_tree() or region==null:return
	visual_ticks+=1
	visual_clock+=dt
	space_material.set_shader_parameter("drift",visual_clock)
	for i in activity.size():
		if i%3==0:activity[i].rotate_y(dt*0.08)
	for slot in region.slots:
		var item: Dictionary=construction[int(slot.id)]
		if float(item.flash)>0:item.flash=maxf(0,float(item.flash)-dt)
		var busy: bool=slot.status in ["constructing","upgrading"]
		var frame_visible := busy or float(item.flash)>0
		if item.ring.visible!=frame_visible:item.ring.visible=frame_visible
		if item.drone.visible!=busy:item.drone.visible=busy
		if busy:
			item.drone.position=Vector3(cos(visual_clock*0.7+slot.id)*5,2.5+sin(visual_clock)*0.4,sin(visual_clock*0.7+slot.id)*5)
	for i in transports.size():
		var item: Dictionary=transports[i]
		item.phase+=dt/float(item.duration)
		if item.phase>=1:new_route(item)
		if not item.node.visible:continue
		var curve: Curve3D=item.curve
		var distance := float(item.phase)*curve.get_baked_length()
		item.node.position=curve.sample_baked(distance)
		var next := curve.sample_baked(minf(distance+0.3,curve.get_baked_length()))
		if next.distance_squared_to(item.node.position)>0.00001:item.node.look_at(next,Vector3.UP)
		if i<pulses.size():
			pulses[i].node.visible=float(item.phase)<0.18
			pulses[i].node.position=curve.sample_baked(minf(float(item.phase)*5,1)*curve.get_baked_length())
	explorer_tick+=dt
	if explorer_tick>=setting("visible_tick",1):explorer_tick=0;update_explorers()
	for item in explorers:
		item.phase=minf(1,float(item.phase)+dt/setting("visible_tick",1))
		item.node.position=item.from.lerp(item.to,float(item.phase))
		if item.node.position.distance_squared_to(item.to)>0.01:item.node.look_at(item.to,Vector3.UP)
func ground_at(position_in_control: Vector2):
	var origin := camera.project_ray_origin(position_in_control*Vector2(view.size)/size)
	var direction := camera.project_ray_normal(position_in_control*Vector2(view.size)/size)
	return Plane(Vector3.UP,0).intersects_ray(origin,direction)
func pick(position_in_control: Vector2) -> int:
	if region==null:return -1
	var hit=ground_at(position_in_control)
	if hit==null:return -1
	var nearest := 6.0
	var result := -1
	for slot in region.slots:
		if slot.status=="empty":continue
		var node: Node3D=slot_nodes[int(slot.id)]
		var distance: float=Vector2(hit.x,hit.z).distance_to(Vector2(node.position.x,node.position.z))
		if distance<nearest:nearest=distance;result=int(slot.id)
	return result
func update_highlight() -> void:
	var id := hover_slot if hover_slot>=0 else selected_slot
	highlight.visible=id>=0
	if id>=0:highlight.position=slot_nodes[id].position+Vector3(0,0.1,0)
func _gui_input(input: InputEvent) -> void:
	if region==null:return
	if input is InputEventMouseButton:
		if input.button_index==MOUSE_BUTTON_LEFT:
			dragging=input.pressed
			if input.pressed:drag_distance=0
			elif drag_distance<5:selected_slot=pick(input.position);slot_selected.emit(selected_slot);update_highlight()
		if input.pressed and input.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom*(1.15 if input.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),setting("camera_zoom_min",0.6),setting("camera_zoom_max",2.8))
			layout()
		accept_event()
	elif input is InputEventMouseMotion:
		if dragging:
			drag_distance+=input.relative.length()
			var previous=ground_at(input.position-input.relative)
			var current=ground_at(input.position)
			if previous!=null and current!=null:
				pan+=Vector2(previous.x-current.x,previous.z-current.z)
			pan=pan.clamp(Vector2(-100,-100),Vector2(100,100))
			layout()
		hover_slot=pick(input.position)
		update_highlight()
		if hover_slot>=0:slot_selected.emit(hover_slot)
