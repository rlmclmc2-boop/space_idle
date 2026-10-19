extends SceneTree
const VIEW:=preload("res://scripts/presented_ship_view.gd")
const PULSE:=preload("res://dev/toon_ship/pulse_vfx.gd")
const RAIL:=preload("res://dev/toon_ship/rail_vfx.gd")
const MISSILE:=preload("res://dev/toon_ship/missile_vfx.gd")
const BEAM:=preload("res://dev/toon_ship/continuous_beam_vfx.gd")
class FX extends Node2D:
	var view
	func _draw()->void:
		for module in view.modules:
			var point:Vector2=view.screen_visual_muzzle_for_slot(int(module.slot))
			var ahead:Vector2=view.camera.unproject_position(view.visual_port_for_slot(int(module.slot)).to_global(Vector3(0,0,-1)))
			var axis:Vector2=(ahead-point).normalized()
			match str(module.key):
				"cannon":
					var rail:=RAIL.new();rail.flash(self,point,axis,0.025,1.0);rail.penetration(self,point,point+axis*150,axis,0.025,1.0,Vector2(600,700))
				"missile":MISSILE.flash(self,point,axis,0.025);MISSILE.flight(self,point+axis*85,axis,0.45)
				"laser":PULSE.flash(self,point,axis,0.025);PULSE.flight(self,point+axis*70,axis);PULSE.flight(self,point+axis*120,axis)
				"longLaser":BEAM.active(self,point,point+axis*160,0.5,4.0,0.65)
class Packet extends Node2D:
	var point:=Vector2(32,32)
	func _draw()->void:PULSE.flight(self,point,Vector2.UP)
func _initialize()->void:call_deferred("run")
func label(text:String,point:Vector2)->void:
	var field:=Label.new();field.text=text;field.position=point;field.add_theme_font_size_override("font_size",20);root.add_child(field)
func gpu_packet()->MultiMeshInstance2D:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	# Reproduce the retained native stream's pulse tag and first indexed quad.
	var positions:=PackedVector3Array();var tags:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	for i in 54:
		positions.append(Vector3((i%3)*2,(i%2)*2,0));tags.append(Vector2.ZERO);colors.append(Color.CYAN);indices.append(i)
	arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=tags;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_2D;multi.use_custom_data=true;multi.mesh=mesh;multi.instance_count=1
	multi.set_instance_transform_2d(0,Transform2D(-PI*0.5,Vector2(32,32)));multi.set_instance_custom_data(0,Color(32,0,0,0))
	var node:=MultiMeshInstance2D.new();node.multimesh=multi
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/retained_flights.gdshader");material.set_shader_parameter("pulse_texture",PULSE.BOLT);node.material=material
	return node
func packet_view(cpu:bool)->SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	if cpu:viewport.add_child(Packet.new())
	else:viewport.add_child(gpu_packet())
	return viewport
func run()->void:
	var output:=OS.get_environment("STATIC_WEAPON_EVIDENCE")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1800,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE;root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1800,900)
	var bg:=ColorRect.new();bg.size=Vector2(1800,900);bg.color=Color("102b42");root.add_child(bg)
	var max_anchor_error:=0.0
	var max_art_muzzle_error:=0.0
	for column in 3:
		label(["NEW WEAPONS / REST","TURN / fixed bearing","FIRE / existing visual effects"][column],Vector2(column*600+15,10))
		var view:=VIEW.new();view.position=Vector2(column*600,45);view.size=Vector2(600,700);root.add_child(view)
		assert(view.set_hull("Battleship"));assert(view.set_loadout([{"key":"cannon"},{"key":"missile"},{"key":"laser"},{"key":"longLaser"}],4))
		view.set_pose(Vector2(300,350),510,0,Vector2(300,-100),0,false,false)
		view.set_slot_angles([0.0,0.0,0.0,0.0] if column==0 else [-0.35,0.35,-0.25,0.25])
		for module in view.modules:
			var plane:MeshInstance3D=module.node.find_child("StaticWeaponArt",true,false)
			assert(plane!=null)
			var row:Dictionary=view.static_weapon_art[str(module.key)]
			var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
			var size:Vector2=(plane.mesh as PlaneMesh).size
			var local:=Vector3((float(row.anchor[0])/texture.get_width()-.5)*size.x,0,(float(row.anchor[1])/texture.get_height()-.5)*size.y)
			var art:Vector2=view.camera.unproject_position(plane.to_global(local))
			var axis:Vector2=view.camera.unproject_position(module.pivot.global_position)
			max_anchor_error=maxf(max_anchor_error,art.distance_to(axis));assert(art.distance_to(axis)<0.01,"Static base anchor left rotation axis")
			for ordinal in row.emission_pixels.size():
				var pixel:Array=row.emission_pixels[ordinal]
				var port:=Vector3((float(pixel[0])/texture.get_width()-.5)*size.x,0,(float(pixel[1])/texture.get_height()-.5)*size.y)
				var visible_port:Vector2=view.camera.unproject_position(plane.to_global(port))
				var actual_port:Vector2=view.screen_visual_muzzle_for_slot(int(module.slot),ordinal)
				max_art_muzzle_error=maxf(max_art_muzzle_error,visible_port.distance_to(actual_port))
				assert(visible_port.distance_to(actual_port)<0.1,"Static visible port differs from retained muzzle node")
		if column==2:
			var clip:=Control.new();clip.position=view.position;clip.size=view.size;clip.clip_contents=true;root.add_child(clip)
			var fx:=FX.new();fx.view=view;clip.add_child(fx);fx.queue_redraw()
	var cpu:=packet_view(true);var gpu:=packet_view(false)
	for item in [[cpu,Vector2(600,780),"CPU / actual size"],[gpu,Vector2(900,780),"retained GPU / actual size"]]:
		var picture:=TextureRect.new();picture.texture=item[0].get_texture();picture.position=item[1];picture.size=Vector2(64,64);root.add_child(picture);label(item[2],item[1]-Vector2(0,25))
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	var a:Image=cpu.get_texture().get_image();var b:Image=gpu.get_texture().get_image()
	assert(a.save_png(output.path_join("pulse-cpu.png"))==OK);assert(b.save_png(output.path_join("pulse-gpu.png"))==OK)
	var max_alpha_error:=0.0;var solid_count:=0
	for y in 64:
		for x in 64:
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			max_alpha_error=maxf(max_alpha_error,absf(ca.a-cb.a))
			if ca.a>.5:solid_count+=1
	assert(solid_count>0,"CPU packet missing")
	assert(max_alpha_error<0.025,"CPU/GPU packet orientation or coverage differs")
	assert(root.get_texture().get_image().save_png(output.path_join("four-weapons-rest-turn-fire.png"))==OK)
	# The retained shader must preserve the native clock/speed displacement.
	var cpu_node:Packet=cpu.get_child(0);cpu_node.point=Vector2(32,24);cpu_node.queue_redraw()
	var gpu_node:MultiMeshInstance2D=gpu.get_child(0)
	gpu_node.multimesh.set_instance_custom_data(0,Color(32,0,0,40))
	(gpu_node.material as ShaderMaterial).set_shader_parameter("simulation_clock",0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	var moved_a:Image=cpu.get_texture().get_image();var moved_b:Image=gpu.get_texture().get_image()
	var motion_error:=0.0
	for y in 64:
		for x in 64:motion_error=maxf(motion_error,absf(moved_a.get_pixel(x,y).a-moved_b.get_pixel(x,y).a))
	assert(motion_error<0.025,"Retained packet changed clock/speed displacement")
	assert(moved_b.save_png(output.path_join("pulse-gpu-clock-step.png"))==OK)
	var result:=FileAccess.open(output.path_join("visual-validation.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"weapons":4,"poses":3,"max_static_anchor_error":max_anchor_error,"max_art_muzzle_error":max_art_muzzle_error,"pulse_size":[14,34],"max_cpu_gpu_alpha_error":max_alpha_error,"pulse_solid_pixels":solid_count,"gpu_clock_step_seconds":0.2,"gpu_test_speed":40,"gpu_expected_displacement":8,"gpu_clock_alpha_error":motion_error,"native_compiled":false},"  "))
	print("STATIC_WEAPONS max_anchor_error=",max_anchor_error," max_art_muzzle_error=",max_art_muzzle_error," cpu_gpu_alpha_error=",max_alpha_error," pulse_solid_pixels=",solid_count)
	quit()
