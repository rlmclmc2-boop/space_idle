extends Control
## Presentation only: shared artwork and assembly maps; per-bay uniforms and FX.
## No research state or independent construction clock is stored here.
const PROFILES := {
	BattleGame.FURNACE: {"shape":"furnace", "cell":Vector2i(0,0), "color":Color("ffb865")},
	BattleGame.ENERGY_FOCUS: {"shape":"focus", "cell":Vector2i(1,0), "color":Color("67dcec")},
	BattleGame.DENSE_ARMOUR: {"shape":"armour", "cell":Vector2i(0,1), "color":Color("86b5ff")},
	BattleGame.JEWEL_FURNACE: {"shape":"crystal", "cell":Vector2i(1,1), "color":Color("bf9aff")}
}
const ART := preload("res://assets/hightech/orbital-atlas.png")
const ASSEMBLY_SHADER := preload("res://scripts/hightech_assembly.gdshader")
const ART_SIZE := Vector2(296,296)
const MAP_SIZE := Vector2i(192,192)
const FRONTIER_STEPS := 12
const WORKER_SPEED := 140.0
# Three persistent visual identities, owned by this bay, never research state.
# Progress/assignment updates change destinations, not their current positions.
var worker_positions := PackedVector2Array([Vector2(70,282),Vector2(148,282),Vector2(226,282)])
var worker_targets := PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
var worker_settled := PackedFloat32Array([0,0,0])
# Immutable presentation plans, bounded by PROFILES; generated once from the
# shared atlas, invalidated on script/resource reload. No game data is cached.
static var plans: Dictionary = {}
var art: TextureRect
var art_material: ShaderMaterial
var work_sites: Array = []
var order_map: Image
var atlas_cell := Vector2i.ZERO
var progress_writes := 0
var energy_writes := 0
var shown_progress := -1.0
var completion_start_progress := 0.0
var shown_completion := Vector3(0,1,0)
var shape := "prototype"
var accent := Color("74dad4")
var fraction := 0.0
var assigned := 0
var completed := 0.0
var completion_cooldown := 0.0
var phase := 0.0
var sample := 0.0
var built := -1
var parts: Array[PackedVector2Array] = []
var effects: Control

class Effects extends Control:
	var construction: Control
	func _draw() -> void:
		construction.draw_effects(self)

func setup(key: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile: Dictionary = PROFILES.get(key,{"shape":"prototype","color":Color("74dad4")})
	shape = profile.shape
	accent = profile.color
	if profile.has("cell"):
		atlas_cell = profile.cell
		setup_art(key,profile)
	else:
		make_parts()
	effects = Effects.new()
	effects.construction = self
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effects)
	set_fraction(0)

func active_in_view() -> bool:
	if not is_visible_in_tree():return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor.get_global_rect().intersects(get_global_rect())
		ancestor = ancestor.get_parent()
	return true

func set_fraction(value: float) -> void:
	var previous_frontier := frontier_step()
	var previous_built := built
	fraction = clampf(value,0,1)
	var count := parts.size() if completed>0 else int(floorf(fraction*parts.size()))
	if built != count:
		built = count
		if art==null:queue_redraw()
		# Invalidate the old welding beam immediately, but retain worker positions
		# until visible, unpaused animation can fly them to the new component.
		if is_instance_valid(effects) and (assigned>0 or completed>0):effects.queue_redraw()

	if art!=null:
		if built==previous_built and previous_frontier!=frontier_step() and assigned>0:
			effects.queue_redraw()
		var shown := fraction
		if shown_progress!=shown:
			shown_progress=shown
			art_material.set_shader_parameter("progress",shown)
			progress_writes+=1
		var transition := Vector3(completion_start_progress,smoothstep(0.0,0.2,1.25-completed),smoothstep(0.0,0.4,completed)) if completed>0 else Vector3(0,1,0)
		if shown_completion!=transition:
			shown_completion=transition
			art_material.set_shader_parameter("completion_state",transition)
			progress_writes+=1

func set_workers(value: int) -> void:
	if assigned == value:return
	for i in range(mini(3,maxi(0,value)),3):
		worker_targets[i]=Vector2.ZERO
		worker_settled[i]=0
	assigned = value
	effects.queue_redraw()

func celebrate() -> void:
	# Fast/bulk research must not perpetually restart the completion pose.
	if not active_in_view() or completed>0 or completion_cooldown>0:return
	completion_start_progress=fraction
	completed = 1.25
	completion_cooldown = 2.75
	set_fraction(fraction)
	effects.queue_redraw()

func advance(delta: float, paused: bool) -> void:
	if paused or not active_in_view():return
	if assigned<=0 and completed<=0 and completion_cooldown<=0:return
	completion_cooldown = maxf(0,completion_cooldown-delta)
	# Acceptance fades are brief, image-wide changes. Interpolate their uniforms
	# each visible frame; keep ordinary energy/workers at the existing 24 Hz cap.
	# The unchanged hold pose produces no repeated uniform writes.
	if completed>0:
		completed=maxf(0,completed-delta)
		set_fraction(fraction)
		if completed<=0:effects.queue_redraw()
	if (assigned<=0 or built>=parts.size()) and completed<=0:return
	sample += delta
	if sample < 1.0/24.0:return
	phase += sample
	# A stalled frame must not cause a catch-up teleport across the whole bay.
	advance_workers(minf(sample,0.1))
	if art!=null:
		art_material.set_shader_parameter("energy_phase",phase)
		energy_writes+=1
	sample = 0
	effects.queue_redraw()

func rect_part(x: float,y: float,w: float,h: float) -> void:
	parts.append(PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)]))

func ring_part(center: Vector2, radius: Vector2, segments := 12) -> void:
	for i in segments:
		var a := TAU*i/segments
		var b := TAU*(i+1)/segments
		parts.append(PackedVector2Array([center+Vector2(cos(a),sin(a))*radius,center+Vector2(cos(b),sin(b))*radius,center+Vector2(cos(b),sin(b))*(radius-Vector2(7,4)),center+Vector2(cos(a),sin(a))*(radius-Vector2(7,4))]))

func setup_art(key: String,profile: Dictionary) -> void:
	if plans.is_empty():
		# One readback during first setup, then release CPU atlas pixels. Both the
		# imported texture and these four tiny order maps are shared by all bays.
		var sources: Dictionary={}
		for profile_key in PROFILES:
			var entry: Dictionary=PROFILES[profile_key]
			var texture: Texture2D=entry.get("texture",ART)
			if not sources.has(texture):sources[texture]=texture.get_image()
			plans[profile_key]=bake_plan(sources[texture],entry.cell,entry.get("grid",Vector2i(2,2)),entry.shape)
	var plan: Dictionary=plans[key]
	parts.assign(plan.parts)
	work_sites=plan.sites
	order_map=plan.order
	art_material=ShaderMaterial.new()
	art_material.shader=ASSEMBLY_SHADER
	art_material.set_shader_parameter("atlas_cell",Vector2(atlas_cell))
	art_material.set_shader_parameter("atlas_grid",Vector2(profile.get("grid",Vector2i(2,2))))
	art_material.set_shader_parameter("assembly_order",plan.texture)
	art_material.set_shader_parameter("part_count",float(parts.size()))
	art=TextureRect.new()
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.texture=profile.get("texture",ART)
	art.material=art_material
	art.size=ART_SIZE
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(art)

func assembly_region(uv: Vector2,recipe: String) -> int:
	# These masks follow the approved sprite's component locations. They never
	# draw substitute geometry. Armour cells/crystals appear as whole objects;
	# rings assemble in sectors, supports precede the active energy core.
	var x := uv.x
	var y := uv.y
	var half := 0 if x<0.5 else 1
	match recipe:
		"armour":
			if y>=0.825:return mini(7,int(x*8))
			if x<0.17 or x>0.86:return 8+half*2+(0 if y>0.6 else 1)
			var nearest := 12
			var distance := INF
			var index := 12
			for row in range(4,-1,-1):
				for col in (4 if row%2==0 else 3):
					var center := Vector2(0.263+col*0.164+(0.082 if row%2 else 0.0),0.212+row*0.135)
					var d := uv.distance_squared_to(center)
					if d<distance:
						distance=d
						nearest=index
					index+=1
			return nearest
		"furnace":
			if y>0.755:return half*2+(0 if y>0.865 else 1)
			if y<0.175:return 18+half*2+(0 if y>0.10 else 1)
			if y>=0.495 and y<0.705 and x>0.29 and x<0.71:
				return 10+half*2+(0 if y>0.59 else 1)
			if y>0.525 and y<0.65:return 8+half
			if y>0.25 and y<0.5:return 14+half*2+(0 if y>0.385 else 1)
			return 4+half*2+(0 if y>0.5 else 1)
		"focus":
			if y>0.765:return half*2+(0 if y>0.87 else 1)
			if y<0.18:return 18+half*2+(0 if y>0.10 else 1)
			if uv.distance_to(Vector2(0.497,0.445))<0.085:return 22
			if y>0.65 and x>0.28 and x<0.72:return 8+half
			if y>0.59 and (x<0.285 or x>0.72):return 4+half*2
			if y>0.295 and y<0.61 and (x<0.29 or x>0.715):return 10+half*2+(0 if y>0.45 else 1)
			if x>0.44 and x<0.55 and y>0.55:return 5+half*2
			return 14+half*2+(0 if y>0.45 else 1)
		"crystal":
			if y>0.81:return half*2+(0 if y>0.90 else 1)
			# Keep all facets of each crystal in one construction component.
			if x>0.392 and x<0.61 and y>0.095 and y<0.59:return 18
			if x>0.21 and x<0.345 and y>0.37 and y<0.69:return 16
			if x>0.66 and x<0.80 and y>0.37 and y<0.69:return 17
			if y>0.625 and x>0.27 and x<0.73:return 8+half
			if y<0.36:return 12+half*2+(0 if y>0.20 else 1)
			if x<0.24 or x>0.80:return 4+half*2+(0 if y>0.58 else 1)
			return 10+half
		_:
			return (9-mini(9,int(y*10)))*6+mini(5,int(x*6))

func bake_plan(pixels: Image,cell: Vector2i,grid: Vector2i,recipe: String) -> Dictionary:
	var cell_size := pixels.get_size()/grid
	var candidates: Dictionary={}
	var raw := PackedInt32Array()
	var grain := PackedFloat32Array()
	var noise := FastNoiseLite.new()
	noise.seed=1729
	noise.frequency=0.13
	noise.fractal_octaves=2
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var uv := (Vector2(x,y)+Vector2(0.5,0.5))/Vector2(MAP_SIZE)
			var ink := pixels.get_pixelv(cell*cell_size+Vector2i(uv*Vector2(cell_size)))
			var mask_uv := uv
			if recipe in ["furnace","focus"]:
				# Disturb the assembly mask only, never the source artwork. A
				# straight logical boundary must not look like a rectangle cutout.
				mask_uv+=Vector2(sin(uv.y*49+sin(uv.x*31)),sin(uv.x*43+uv.y*17))*0.014
			var region := assembly_region(mask_uv,recipe)
			var local_phase := clampf(0.5+noise.get_noise_2dv(uv*ART_SIZE)*0.8,0.08,0.92)
			# The furnace's final task ignites scattered filament highlights;
			# it must never hide an entire rectangular column through the rings.
			if recipe=="furnace" and uv.y<0.76 and uv.x>0.32 and uv.x<0.68 and ink.a>0.90 and ink.r>0.85 and ink.g>0.55 and local_phase>0.50:
				region=22
			raw.append(region)
			grain.append(local_phase)
			if ink.a>0.55 and maxf(ink.r,maxf(ink.g,ink.b))>0.5:
				if not candidates.has(region):candidates[region]=PackedVector2Array()
				candidates[region].append(uv*ART_SIZE)
	var keys := candidates.keys()
	keys.sort()
	var regions: Array[PackedVector2Array]=[]
	var sites: Array=[]
	var remap: Dictionary={}
	for key in keys:
		remap[key]=regions.size()
		var points: PackedVector2Array=candidates[key]
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point in points:bounds=bounds.expand(point)
		regions.append(PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]))
		var anchors := PackedVector2Array()
		var phases := PackedFloat32Array()
		for point in points:
			var pixel := Vector2i(point/ART_SIZE*Vector2(MAP_SIZE))
			phases.append(grain[pixel.y*MAP_SIZE.x+pixel.x])
		for step in FRONTIER_STEPS:
			var target_phase := (step+0.5)/FRONTIER_STEPS
			var distance := INF
			for value in phases:distance=minf(distance,absf(value-target_phase))
			var near := PackedVector2Array()
			for i in points.size():
				if absf(phases[i]-target_phase)<=distance+0.055:near.append(points[i])
			for worker in 3:anchors.append(near[mini(near.size()-1,int(near.size()*(worker+0.5)/3.0))])
		sites.append(anchors)
	var order := Image.create(MAP_SIZE.x,MAP_SIZE.y,false,Image.FORMAT_RF)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var region := raw[y*MAP_SIZE.x+x]
			# Empty regions contain only transparency/soft glow; reveal them with
			# the closest populated assembly stage, never create an empty AI target.
			if not remap.has(region):
				var distance := 1000000
				var nearest: int=keys[0]
				for key: int in keys:
					if absi(key-region)<distance:
						distance=absi(key-region)
						nearest=key
				region=nearest
			order.set_pixel(x,y,Color(float(remap[region])+grain[y*MAP_SIZE.x+x],0,0,1))
	return {"parts":regions,"sites":sites,"order":order,"texture":ImageTexture.create_from_image(order)}

func make_parts() -> void:
	# New data rows receive a cheap generic blueprint until dedicated artwork
	# and a profile are supplied. No page or research-business branch is needed.
	parts.clear()
	last_mesh_built=-2
	for i in 8:rect_part(55+i*24,258,22,12)
	for layer in 8:
		for col in 5:rect_part(86+col*25,238-layer*22,23,20)
	ring_part(Vector2(148,65),Vector2(66,18),12)

# Flat assembly geometry is batched without deciding research progress.
var mesh: ArrayMesh
var last_mesh_built := -2

class MeshBatch:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	func polygon(poly: PackedVector2Array, tint: Color) -> void:
		var offset := vertices.size()
		for point in poly:
			vertices.append(Vector3(point.x,point.y,0))
			colors.append(tint)
		for i in range(1,poly.size()-1):
			indices.append_array(PackedInt32Array([offset,offset+i,offset+i+1]))
	func strip(a: Vector2,b: Vector2,c: Vector2,d: Vector2,inside: Color,outside: Color) -> void:
		var offset := vertices.size()
		for point in [a,b,c,d]:vertices.append(Vector3(point.x,point.y,0))
		colors.append_array(PackedColorArray([inside,inside,outside,outside]))
		indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	func line(a: Vector2,b: Vector2,tint: Color,width: float) -> void:
		var normal := (b-a).orthogonal().normalized()
		var inner := normal*width*0.5
		var outer := normal*(width*0.5+0.6)
		polygon(PackedVector2Array([a+inner,b+inner,b-inner,a-inner]),tint)
		strip(a+inner,b+inner,b+outer,a+outer,tint,Color(tint,0))
		strip(b-inner,a-inner,a-outer,b-outer,tint,Color(tint,0))
	func outline(poly: PackedVector2Array,tint: Color,width: float) -> void:
		for i in poly.size():line(poly[i],poly[(i+1)%poly.size()],tint,width)
	func finish() -> ArrayMesh:
		var result := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

func rebuild_mesh() -> void:
	if last_mesh_built==built:return
	last_mesh_built = built
	var batch := MeshBatch.new()
	# Future geometry stays behind installed components, never cutting across
	# a finished panel. New recipes share exact joints and need no offset shadows.
	for i in range(built,parts.size()):
		batch.outline(parts[i],Color(0.27,0.50,0.64,0.26),1)
	for i in parts.size():
		var poly := parts[i]
		if i<built:
			if shape in ["armour","prototype"]:
				var shadow := PackedVector2Array()
				for point in poly:shadow.append(point+Vector2(3,4))
				batch.polygon(shadow,Color("030a13"))
			batch.polygon(poly,Color("1c3448").lerp(accent,0.09+0.05*(i%3)))
			batch.outline(poly,accent.darkened(0.27),1.1)
	mesh = batch.finish()

func _draw() -> void:
	if art==null:rebuild_mesh()
	draw_rect(Rect2(0,0,296,304),Color("07121f"))
	var grid := PackedVector2Array()
	for i in 9:
		var x := 16.0+i*33
		grid.append_array(PackedVector2Array([Vector2(x,290),Vector2(148+(x-148)*0.55,226)]))
	for y in [240.0,253.0,268.0,287.0]:
		grid.append_array(PackedVector2Array([Vector2(17,y),Vector2(279,y)]))
	draw_multiline(grid,Color("142a3c"),1)
	if art!=null:return
	var deck := PackedVector2Array([Vector2(28,260),Vector2(91,237),Vector2(242,241),Vector2(274,265),Vector2(218,290),Vector2(74,286)])
	draw_colored_polygon(deck,Color("102435"))
	draw_polyline(closed(deck),Color("355468"),1.5,true)
	var ticks := PackedVector2Array()
	for y in range(24,251,15):
		ticks.append_array(PackedVector2Array([Vector2(12,y),Vector2(18 if y%3==0 else 15,y)]))
	draw_multiline(ticks,Color("375066"),1)
	draw_mesh(mesh,null)
	draw_multiline(PackedVector2Array([Vector2(31,56),Vector2(31,255),Vector2(264,56),Vector2(264,255)]),Color("243b4c"),3)
	draw_multiline(PackedVector2Array([Vector2(31,65),Vector2(31,104),Vector2(264,65),Vector2(264,104)]),accent.darkened(0.5),2)

func closed(poly: PackedVector2Array) -> PackedVector2Array:
	var result := poly.duplicate()
	result.append(poly[0])
	return result

func frontier_step() -> int:
	return mini(FRONTIER_STEPS-1,int(fposmod(fraction*parts.size(),1.0)*FRONTIER_STEPS))

func work_target(worker: int) -> Vector2:
	# built is the installed count, hence also the next component's index.
	# All workers share this actual component, never a speculative later index.
	if assigned<=0 or built<0 or built>=parts.size() or completed>0:return Vector2.ZERO
	if art!=null:return work_sites[built][frontier_step()*3+worker%3]
	var poly := parts[built]
	var perimeter := 0.0
	for i in poly.size():perimeter+=poly[i].distance_to(poly[(i+1)%poly.size()])
	var distance := perimeter*(worker%3+0.5)/3.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		if distance<=length:return a.lerp(b,distance/maxf(length,0.0001))
		distance-=length
	return poly[0]

func worker_destination(worker: int, target: Vector2) -> Vector2:
	# Identity-based approach offsets stay unchanged when colleagues are added.
	var offset := Vector2((worker-1)*17,-18)
	var hover := Vector2(sin(phase*1.4+worker*2.1)*2,cos(phase*1.1+worker*2.1)*1.5)
	return (target+offset+hover).clamp(Vector2(10,10),Vector2(286,286))

func advance_workers(delta: float) -> void:
	for i in mini(3,assigned):
		var target := work_target(i)
		if worker_targets[i]!=target:
			worker_targets[i]=target
			worker_settled[i]=0
		# During acceptance retain the same units in place; next round departs
		# from here instead of hiding and respawning at the new blueprint.
		if target==Vector2.ZERO:continue
		var destination := worker_destination(i,target)
		var distance := worker_positions[i].distance_to(destination)
		var travel := minf(WORKER_SPEED*delta,distance*(1.0-exp(-8.0*delta)))
		worker_positions[i]=worker_positions[i].move_toward(destination,travel)
		if worker_positions[i].distance_to(destination)<=2.0:
			worker_settled[i]+=delta
		else:
			worker_settled[i]=0

func worker_welding(worker: int) -> bool:
	if worker>=mini(3,assigned):return false
	var target := work_target(worker)
	return target!=Vector2.ZERO and target==worker_targets[worker] and worker_settled[worker]>=0.12 and worker_positions[worker].distance_to(worker_destination(worker,target))<=2.0

func draw_effects(layer: Control) -> void:
	if completed>0:
		var y := 270.0-(1.25-completed)/1.25*220
		var fade := smoothstep(0.0,0.16,1.25-completed)*smoothstep(0.0,0.3,completed)
		layer.draw_line(Vector2(38,y),Vector2(258,y),Color(accent,0.22*fade),8,true)
		layer.draw_line(Vector2(38,y),Vector2(258,y),Color(accent,0.85*fade),1.5,true)
	if assigned<=0:return
	var count := mini(3,assigned)
	if art==null and built>=0 and built<parts.size():layer.draw_polyline(closed(parts[built]),Color(accent,0.58),1.3,true)
	for i in count:
		var target := work_target(i)
		var pos := worker_positions[i]
		var welding := worker_welding(i)
		if welding:layer.draw_line(pos,target,Color(accent,0.42),1,true)
		layer.draw_circle(pos,8,Color(accent,0.09))
		layer.draw_circle(pos,4,Color("213b51"))
		layer.draw_arc(pos,4,0,TAU,12,accent,1,true)
		layer.draw_circle(pos,1.5,Color("e3faff"))
		if welding and sin(phase*11+i)>0:
			layer.draw_line(target-Vector2(3,0),target+Vector2(3,0),Color("ffe3aa"),1,true)
			layer.draw_line(target-Vector2(0,3),target+Vector2(0,3),Color("ffe3aa"),1,true)
