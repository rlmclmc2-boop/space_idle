extends Control
## Independent, bounded 3D presentation. No gameplay mutation or saved visual state.
signal slot_selected(id: int)
const BUILDING_SCALE := 1.4
var region
var settings := {}
var view := SubViewport.new()
var container := TextureRect.new()
var world := Node3D.new()
var camera := Camera3D.new()
var models := Node3D.new()
var core: Node3D
var slot_nodes := {}
var model_paths := {}
var slot_snapshots := {}
var lane_states: Array=[]
var scene_cache := {}
var material_cache := {}
var construction_material_cache := {}
var asset_bounds := {}
var transit := preload("res://scripts/galaxy_transit.gd").new()
var route_revision := -1
var frame_size := 120.0
var frame_origin := Vector2.ZERO
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
var crew_count := 0:
	set(value):
		if crew_count==value:return
		crew_count=value
		if is_inside_tree() and region!=null:update_explorers()
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var drag_distance := 0.0
var selected_slot := -1
var hover_slot := -1
var inspected_slot := -1
var running := true
var highlight: MeshInstance3D
var cyan: StandardMaterial3D
var amber: StandardMaterial3D
var planned_material: StandardMaterial3D
var frame_material: StandardMaterial3D

func _ready() -> void:
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	container.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	container.stretch_mode=TextureRect.STRETCH_SCALE
	add_child(container)
	view.own_world_3d=true
	view.handle_input_locally=false
	view.msaa_3d=Viewport.MSAA_4X
	add_child(view)
	container.texture=view.get_texture()
	view.add_child(world)
	world.add_child(models)
	world.add_child(transit)
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=600
	camera.current=true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("0c1d2b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("adc2cb")
	env.ambient_light_energy=0.65
	environment.environment=env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-38,0)
	light.light_color=Color("fff1df")
	light.light_energy=1.1
	light.shadow_enabled=false
	light.directional_shadow_max_distance=260
	world.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-25,140,0)
	rim.light_color=Color("9acbc9")
	rim.light_energy=0.4
	world.add_child(rim)
	cyan=material(Color("83cfcb"))
	amber=material(Color("d8aa68"))
	planned_material=material(Color("2c4656"))
	frame_material=material(Color("8fa7a5"))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/galaxy/v3/manifest.json"))
	if manifest is Dictionary:
		for row in manifest.get("assets",[]):asset_bounds[str(row.path)]=row.bounds_godot_xyz
	space_material.shader=preload("res://scripts/galaxy_space.gdshader")
	space_material.set_shader_parameter("field",preload("res://assets/galaxy/v3/galaxy_field.svg"))
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(1200,1200)
	backdrop.mesh=plane
	backdrop.material_override=space_material
	backdrop.position.y=-5
	world.add_child(backdrop)
	highlight=ring(7.6,cyan,0.35)
	world.add_child(highlight)
	highlight.visible=false
	resized.connect(layout)
	get_viewport().size_changed.connect(layout)
	visibility_changed.connect(sync_visibility)
	mouse_exited.connect(clear_hover)
	layout()
	sync_visibility()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.emission_enabled=false
	result.roughness=0.78
	return result
func ring(radius: float, mat: Material, thickness: float = 0.12) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
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
			if (key.begins_with("Core") or key.begins_with("GalaxyToon")) and mat is StandardMaterial3D:
				# Soft baked occlusion fits the rounded core; avoid jagged self-shadows.
				node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var colors=node.mesh.surface_get_arrays(index)[Mesh.ARRAY_COLOR]
				if colors is PackedColorArray and not colors.is_empty() and not mat.vertex_color_use_as_albedo:mat.vertex_color_use_as_albedo=true
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
	slot_snapshots.clear()
	lane_states.clear()
	construction.clear()
	activity.clear()
	building_revision=-1
	route_revision=-1
	transit.clear()
	selected_slot=-1
	hover_slot=-1
	inspected_slot=-1
	highlight.visible=false
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
		node.rotation.y=float(region.blueprint.nodes[int(slot.id)].rotation_y)
		models.add_child(node)
		slot_nodes[int(slot.id)]=node
		var footprint := ring(5.7,planned_material)
		footprint.name="SurveyFootprint"
		footprint.position.y=-0.45
		node.add_child(footprint)
		var scaffold := Node3D.new()
		scaffold.name="Scaffold"
		node.add_child(scaffold)
		var foundation := ring(6.7,amber)
		foundation.position.y=0.2
		scaffold.add_child(foundation)
		var upper := ring(6.7,frame_material)
		scaffold.add_child(upper)
		var posts: Array[MeshInstance3D]=[]
		for corner in 4:
			var post := MeshInstance3D.new()
			var beam := BoxMesh.new()
			beam.size=Vector3(0.14,1,0.14)
			post.mesh=beam
			post.material_override=frame_material
			post.position=Vector3(cos(corner*PI/2+PI/4)*6.7,0.5,sin(corner*PI/2+PI/4)*6.7)
			scaffold.add_child(post)
			posts.append(post)
		var drone := asset("assets/galaxy/v3/ships/transport_shuttle.glb")
		drone.scale=Vector3.ONE*0.46
		scaffold.add_child(drone)
		construction[int(slot.id)]={"ring":scaffold,"drone":drone,"upper":upper,"posts":posts,"height":-1.0,"flash":0.0,"level":int(slot.level)}
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
	frame_size=fit_size()
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
	if not is_visible_in_tree():clear_hover()
	elif region!=null:
		refresh()
		request_visual_frame()
func layout() -> void:
	if not is_inside_tree():return
	# Match displayed pixels up to the original logical-size budget. Integer shrink
	# thresholds accidentally supersampled mid-size windows by almost 3x.
	# Keep 4x MSAA and let imported mesh LOD use the true projected pixel size.
	var screen_scale := (get_viewport().get_final_transform()*get_screen_transform()).get_scale().abs()
	var pixel_size := Vector2i((size*screen_scale.min(Vector2.ONE)).ceil()).max(Vector2i.ONE)
	if view.size!=pixel_size:view.size=pixel_size
	# Keep the configured overview cap for wheel input, resize and restored views.
	zoom=clampf(zoom,setting("camera_zoom_min",0.4),setting("camera_zoom_max",0.6))
	view.mesh_lod_threshold=clampf(4.0/(zoom*zoom),1.0,4.0)
	frame_size=fit_size()
	camera.size=frame_size/zoom
	# Fixed isometric framing: 45-degree azimuth, 35.26-degree downward pitch.
	var target := Vector3(frame_origin.x+pan.x,0,frame_origin.y+pan.y)
	camera.position=target+Vector3(130,130,130)
	camera.look_at(target,Vector3.UP)
	request_visual_frame()
func fit_size() -> float:
	if region==null:frame_origin=Vector2.ZERO;return 120.0
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for plan in [region.blueprint.core]+region.blueprint.nodes:
		var position := Vector2(float(plan.world_pos[0]),float(plan.world_pos[1]))
		var half := Vector2(float(plan.footprint[0]),float(plan.footprint[1]))*0.5
		var core_bounds: Array=asset_bounds.get(str(region.row.core_asset),[25.0,11.16,25.0])
		var height := float(core_bounds[1])*1.2
		if int(plan.id)>=0:
			var definition: Dictionary=region.builds[str(plan.planned_type)]
			var bounds: Array=asset_bounds.get(str(definition.asset_lv5),[10.0,6.0,10.0])
			height=float(bounds[1])*BUILDING_SCALE
		for x in [-half.x,half.x]:
			for z in [-half.y,half.y]:
				var point := position+Vector2(x,z)
				for y in [0.0,height]:
					var projected := Vector2((point.x-point.y)*0.707107,(point.x+point.y)*0.408248-y*0.816497)
					low=low.min(projected);high=high.max(projected)
	# Center the actual asymmetric saved plan, including upper model bounds.
	var center := (low+high)*0.5
	frame_origin=Vector2(center.x*0.707107+center.y*1.224745,-center.x*0.707107+center.y*1.224745)
	var half_extent := (high-low)*0.5+Vector2(5,6)
	var aspect := maxf(0.5,size.x/maxf(1,size.y))
	return maxf(95,2.0*maxf(half_extent.y,half_extent.x/aspect))

func visual_path(slot: Dictionary) -> String:
	var key := str(slot.get("type",""))
	if key.is_empty():key=str(slot.get("planned_type",""))
	if not region.builds.has(key):return ""
	return str(region.builds[key].get("asset_lv%d"%maxi(1,int(slot.level)),""))

func construction_material(mat: StandardMaterial3D) -> ShaderMaterial:
	var key := mat.resource_name
	if not construction_material_cache.has(key):
		var result := ShaderMaterial.new()
		result.resource_name=key
		result.shader=preload("res://scripts/galaxy_construction.gdshader")
		result.set_shader_parameter("tint",mat.albedo_color)
		result.set_shader_parameter("lamp",mat.emission*mat.emission_energy_multiplier if mat.emission_enabled else Color.BLACK)
		result.set_shader_parameter("roughness_value",mat.roughness)
		result.set_shader_parameter("metallic_value",mat.metallic)
		result.set_shader_parameter("vertex_tint",mat.vertex_color_use_as_albedo)
		construction_material_cache[key]=result
	return construction_material_cache[key]

func set_construction_material(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		for index in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(index)
			if mat==null:continue
			var original: Material=material_cache.get(mat.resource_name,mat)
			var target: Material=construction_material(original) if enabled and original is StandardMaterial3D else original
			if node.get_surface_override_material(index)!=target:node.set_surface_override_material(index,target)
	for child in node.get_children():set_construction_material(child,enabled)

func set_construction_height(node: Node, height: float) -> void:
	if node is MeshInstance3D:node.set_instance_shader_parameter("construction_height",height)
	for child in node.get_children():set_construction_height(child,height)

func refresh_construction() -> void:
	for slot in region.slots:
		var item: Dictionary=construction[int(slot.id)]
		if slot.status!="constructing":continue
		var path := visual_path(slot)
		var bounds: Array=asset_bounds.get(path,[10.0,6.0,10.0])
		var progress: float=region.node_progress(slot)
		var height := float(bounds[1])*BUILDING_SCALE*clampf(progress,0.07,1.0)
		if is_equal_approx(height,float(item.height)):continue
		item.height=height
		item.upper.position.y=height+0.3
		for post in item.posts:
			post.position.y=(height+0.3)*0.5
			post.scale.y=height+0.3
		var model=slot_nodes[int(slot.id)].get_node_or_null("Building")
		if model!=null:set_construction_height(model,height)
		draw_updates+=1

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
	if building_revision!=region.building_revision:
		building_revision=region.building_revision
		activity.clear()
		var core_ring=core.find_child("ActivityRing",true,false)
		if core_ring is Node3D:activity.append(core_ring)
		var next_lane_states: Array=[]
		for slot in region.slots:
			var id := int(slot.id)
			var node: Node3D=slot_nodes[id]
			var path := visual_path(slot) if slot.status!="empty" else "empty"
			var snapshot := [str(slot.status),int(slot.level),path]
			var changed: bool=slot_snapshots.get(id,[])!=snapshot
			if model_paths.get(id)!=path:
				var old=node.get_node_or_null("Building")
				if old!=null:old.free()
				if path!="empty":
					var model := asset(path)
					model.name="Building"
					model.scale=Vector3.ONE*BUILDING_SCALE
					node.add_child(model)
				model_paths[id]=path
			var building=node.get_node_or_null("Building")
			if changed:
				if int(construction[id].level)<int(slot.level):construction[id].flash=0.55
				construction[id].level=int(slot.level)
				construction[id].height=-1.0
				if building!=null:set_construction_material(building,slot.status=="constructing")
				node.get_node("SurveyFootprint").visible=slot.status=="empty"
				construction[id].ring.visible=slot.status in ["constructing","upgrading"]
				if slot.status=="upgrading":construction[id].upper.position.y=0.4
				for post in construction[id].posts:post.visible=slot.status!="upgrading"
				slot_snapshots[id]=snapshot
				draw_updates+=1
			if building!=null:
				var part=building.find_child("ActivityRing",true,false)
				if part is Node3D and slot.status!="constructing":activity.append(part)
			next_lane_states.append("planned" if slot.status=="empty" else "building" if slot.status=="constructing" else "operating")
		if next_lane_states!=lane_states:
			transit.rebuild(region.layout_snapshot(),float(asset_bounds[str(region.row.core_asset)][0])*1.2*0.43)
			lane_states=next_lane_states
			route_revision=building_revision
	sync_transports()
	refresh_construction()
func desired_transport_count(built_count: int) -> int:
	return mini(maxi(0,int(setting("max_transport_ships",12))),ceili(maxi(0,built_count)/maxf(1,setting("transport_buildings_per_ship",3))))
func sync_transports() -> void:
	var built_count: int=region.slots.filter(func(slot):return slot.status in ["active","upgrading"]).size()
	var count := desired_transport_count(built_count) if built_count>0 else 0
	while transports.size()>count:transports.pop_back().node.free()
	var first := transports.size()
	while transports.size()<count:
		var ship := asset("assets/galaxy/v3/ships/transport_shuttle.glb")
		ship.visible=false
		ship.scale=Vector3.ONE*2.0
		world.add_child(ship)
		var delay := maxf(0,setting("transport_initial_delay",1.4))+(transports.size()-first)*maxf(0,setting("transport_departure_interval",0.8))
		transports.append({"node":ship,"curve":Curve3D.new(),"phase":1.0,"duration":1.0,"reverse":false,"depart_at":visual_clock+delay})
func dock(id: int) -> Vector3:
	var node: Node3D=core if id<0 else slot_nodes[id]
	var socket=node.find_child("DockSocket",true,false)
	return socket.global_position if socket is Node3D else node.global_position+Vector3(0,2,0)
func new_route(item: Dictionary) -> void:
	var destinations: Array[int]=[-1]
	var roof := float(asset_bounds.get(str(region.row.core_asset),[25.0,11.16,25.0])[1])*1.2
	for slot in region.slots:
		if slot.status not in ["active","upgrading"]:continue
		destinations.append(int(slot.id))
		roof=maxf(roof,float(asset_bounds[visual_path(slot)][1])*BUILDING_SCALE)
	if destinations.size()<2:
		item.node.visible=false;item.phase=0.0;item.duration=1.0
		return
	var source: int=int(item.get("destination",destinations[rng.randi_range(0,destinations.size()-1)]))
	if not destinations.has(source):source=destinations[0]
	destinations.erase(source)
	var target: int=destinations[rng.randi_range(0,destinations.size()-1)]
	var start:=dock(source);var finish:=dock(target)
	var across:=(finish-start).cross(Vector3.UP).normalized()*rng.randf_range(-4.0,4.0)
	var cruise:=roof+7.0+rng.randf_range(0.0,3.0)
	var first:=start.lerp(finish,0.28)+across;first.y=cruise*1.4
	var last:=start.lerp(finish,0.72)+across;last.y=cruise*1.4
	# Reuse one curve per boat; rebuild only on departure, independently of pipes.
	item.curve.clear_points()
	item.curve.add_point(start,Vector3.ZERO,first-start)
	item.curve.add_point(finish,last-finish,Vector3.ZERO)
	item.source=source;item.destination=target;item.cruise_height=cruise
	item.reverse=false;item.phase=0.0
	item.duration=maxf(6.0,item.curve.get_baked_length()/7.0)
	item.node.visible=true

func update_explorers() -> void:
	var targets: Array=region.slots.filter(func(slot):return slot.status=="constructing")
	var count := mini(12,crew_count*int(region.row.ship_per_crew)) if not targets.is_empty() else 0
	while explorers.size()>count:explorers.pop_back().node.free()
	while explorers.size()<count:
		var ship := asset("assets/galaxy/v3/ships/transport_shuttle.glb")
		ship.scale=Vector3.ONE*0.7
		world.add_child(ship)
		explorers.append({"node":ship,"curve":Curve3D.new(),"target":-1,"phase":1.0,"duration":4.0})
	for item in explorers:
		if float(item.phase)<1.0 and targets.any(func(slot):return int(slot.id)==int(item.target)):continue
		var target: Dictionary=targets[rng.randi_range(0,targets.size()-1)]
		item.target=int(target.id)
		item.curve=transit.curves[int(target.id)]
		item.duration=maxf(3.0,item.curve.get_baked_length()/4.0)
		item.phase=0.0
func _process(dt: float) -> void:
	if not running or not is_visible_in_tree() or region==null:return
	visual_ticks+=1
	visual_clock+=dt
	for i in activity.size():
		if i%3==0:activity[i].rotate_y(dt*0.08)
	for slot in region.slots:
		var item: Dictionary=construction[int(slot.id)]
		if float(item.flash)>0:item.flash=maxf(0,float(item.flash)-dt)
		var busy: bool=slot.status in ["constructing","upgrading"] and crew_count>0
		var frame_visible: bool=slot.status in ["constructing","upgrading"] or float(item.flash)>0
		if item.ring.visible!=frame_visible:item.ring.visible=frame_visible
		if item.drone.visible!=busy:item.drone.visible=busy
		if busy:
			item.drone.position=Vector3(cos(visual_clock*0.7+slot.id)*5,2.5+sin(visual_clock)*0.4,sin(visual_clock*0.7+slot.id)*5)
	for i in transports.size():
		var item: Dictionary=transports[i]
		if visual_clock<float(item.depart_at):continue
		item.phase+=dt/float(item.duration)
		if item.phase>=1:new_route(item)
		if not item.node.visible:continue
		var curve: Curve3D=item.curve
		var phase: float=1.0-float(item.phase) if item.reverse else float(item.phase)
		var distance := phase*curve.get_baked_length()
		item.node.position=curve.sample_baked(distance)
		var next := curve.sample_baked(clampf(distance+(-0.3 if item.reverse else 0.3),0,curve.get_baked_length()))
		if next.distance_squared_to(item.node.position)>0.00001:item.node.look_at(next,Vector3.UP)
		if i<pulses.size():pulses[i].node.visible=false
	explorer_tick+=dt
	if explorer_tick>=setting("visible_tick",1):explorer_tick=0;update_explorers()
	for item in explorers:
		item.phase=minf(1,float(item.phase)+dt/float(item.duration))
		var curve: Curve3D=item.curve
		var distance := float(item.phase)*curve.get_baked_length()
		item.node.position=curve.sample_baked(distance)+Vector3(0,0.45,0)
		var next := curve.sample_baked(minf(distance+0.2,curve.get_baked_length()))+Vector3(0,0.45,0)
		if next.distance_squared_to(item.node.position)>0.001:item.node.look_at(next,Vector3.UP)
func ground_at(position_in_control: Vector2):
	var origin := camera.project_ray_origin(position_in_control*Vector2(view.size)/size)
	var direction := camera.project_ray_normal(position_in_control*Vector2(view.size)/size)
	return Plane(Vector3.UP,0).intersects_ray(origin,direction)
func model_hit(node: Node3D, bounds: Array, scale_factor: float, origin: Vector3, direction: Vector3, height: float = -1.0):
	var extent := Vector3(float(bounds[0]),float(bounds[1]),float(bounds[2]))*scale_factor
	if height>=0:extent.y=minf(extent.y,height)
	var box := AABB(Vector3(-extent.x*0.5,0,-extent.z*0.5),extent)
	var inverse := node.global_transform.affine_inverse()
	var hit=box.intersects_ray(inverse*origin,inverse.basis*direction)
	return node.global_transform*hit if hit!=null else null

func pick(position_in_control: Vector2) -> int:
	if region==null:return -1
	var pixel := position_in_control*Vector2(view.size)/size
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	var closest := INF
	var result := -1
	# Test building volume before the ground footprint. Nearest volume wins;
	# the hollow headquarters is not an opaque box that masks nearby buildings.
	for slot in region.slots:
		if slot.status=="empty":continue
		var id := int(slot.id)
		var height := float(construction[id].height) if slot.status=="constructing" else -1.0
		var hit=model_hit(slot_nodes[id],asset_bounds.get(visual_path(slot),[10.0,6.0,10.0]),BUILDING_SCALE,origin,direction,height)
		if hit!=null and origin.distance_squared_to(hit)<closest:
			closest=origin.distance_squared_to(hit)
			result=id
	if closest<INF:return result
	var ground=ground_at(position_in_control)
	if ground==null:return -1
	for plan in region.blueprint.nodes:
		var node: Node3D=slot_nodes[int(plan.id)]
		var half := Vector2(float(plan.footprint[0]),float(plan.footprint[1]))*0.5
		if absf(ground.x-node.position.x)<=half.x and absf(ground.z-node.position.z)<=half.y:return int(plan.id)
	return -1

func request_visual_frame() -> void:
	# Paused input still needs one image, without restarting animation.
	if not running and is_visible_in_tree() and region!=null:
		view.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not running:view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func clear_hover() -> void:
	hover_slot=-1
	update_highlight()

func update_highlight() -> void:
	var id := selected_slot if selected_slot>=0 else hover_slot
	if inspected_slot==id:return
	inspected_slot=id
	highlight.visible=id>=0
	if id>=0:highlight.position=slot_nodes[id].position+Vector3(0,0.1,0)
	request_visual_frame()
	slot_selected.emit(id)
func _gui_input(input: InputEvent) -> void:
	if region==null:return
	if input is InputEventMouseButton:
		if input.button_index==MOUSE_BUTTON_LEFT:
			dragging=input.pressed
			if input.pressed:drag_distance=0
			elif drag_distance<5:
				selected_slot=pick(input.position)
				hover_slot=selected_slot
				update_highlight()
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
			return
		hover_slot=pick(input.position)
		update_highlight()
