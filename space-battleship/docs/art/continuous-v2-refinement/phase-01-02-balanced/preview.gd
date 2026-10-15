extends SceneTree
## Continuous V2 first transition. Production scenery shader; no combat state.
const PULSE=preload("res://dev/toon_ship/pulse_vfx.gd")
const MISSILE=preload("res://dev/toon_ship/missile_vfx.gd")
const RAIL=preload("res://dev/toon_ship/rail_vfx.gd")
class Backdrop extends Node2D:
	var mesh:ArrayMesh
	func _init()->void:
		mesh=ArrayMesh.new()
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,0),Vector3(572,0,0),Vector3(572,960,0),Vector3(0,960,0)])
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0)])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	func _draw()->void:draw_mesh(mesh,null)
class Specimens extends Node2D:
	var ships:Texture2D
	var rail=RAIL.new()
	var enabled:=true
	var regions=[Rect2(26,145,608,614),Rect2(638,125,568,635),Rect2(1220,140,536,635)]
	func _draw()->void:
		if not enabled:return
		var positions=[Vector2(100,160),Vector2(286,160),Vector2(470,160),Vector2(100,450),Vector2(286,450),Vector2(470,450),Vector2(100,790),Vector2(286,790),Vector2(470,790)]
		for row in 3:
			for col in 3:
				var region:Rect2=regions[col]
				var h:float=[30.0,50.0,80.0][row]/(400.0/572.0)
				var size=Vector2(region.size.x/region.size.y,1)*h
				draw_texture_rect_region(ships,Rect2(positions[row*3+col]-size*0.5,size),region)
		PULSE.flight(self,Vector2(240,360),Vector2.UP)
		PULSE.impact(self,positions[1]+Vector2(0,18),Vector2.UP,0.05,false)
		MISSILE.flight(self,Vector2(435,615),Vector2(-0.3,-1).normalized(),0.5,7,1.0,true,true)
		MISSILE.impact(self,positions[5]+Vector2(0,28),Vector2.UP,0.14,false,1.0,7)
		rail.penetration(self,Vector2(330,940),positions[7],Vector2.UP,0.09,1.0,Vector2(572,960))
		rail.impact(self,positions[7]+Vector2(0,50),Vector2.UP,0.02,false,1.0)
class Labels extends Node2D:
	var font=ThemeDB.fallback_font
	var overview:=false
	var parent_map:Texture2D
	var refined:Texture2D
	func label(value:String,p:Vector2,size:=17,c:=Color("d6e1e5"))->void:draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)
	func _draw()->void:
		if overview:
			label("APPROVED WORLD → REFINED FIRST TRANSITION",Vector2(25,35),23)
			draw_texture_rect(parent_map,Rect2(25,70,108,927),false)
			draw_rect(Rect2(25,70+1538.0/2172*927,108,634.0/2172*927),Color("dfb875"),false,2)
			label("10-stage master",Vector2(155,92),17)
			label("Same world / light / landmark order",Vector2(155,120),16)
			draw_texture_rect(refined,Rect2(480,70,319,1174),false)
			label("Repainted 747 x 2104 source (+2 edge rows)",Vector2(865,95),17)
			label("253px layout is reference only",Vector2(865,125),16)
			label("Native crop: 572 x 2106 master",Vector2(865,175),16)
			label("Stage 1: 720px / stage 2: 426px travel",Vector2(865,205),16)
			label("960 shared rows + 2px filter gutters",Vector2(865,235),16)
			label("No per-stage regeneration or crossfade",Vector2(865,280),16)
			label("Stages 3–10 await this transition review",Vector2(865,325),16)
			label("DOCK → PYLONS → ORBIT",Vector2(865,720),20)
			label("Layout coordinates are not game distances",Vector2(865,755),16)
		else:
			label("CONTINUOUS V2 / DOCK EXIT TO NEAR-ORBIT SPACE",Vector2(20,34),24)
			label("Actual scenery shader / 400 x 672 physical pixels / static hull + VFX specimens, not gameplay",Vector2(20,62),16)
			for i in 3:label(["01 / START INSIDE THE DOCK","01 → 02 / SHARED BOUNDARY","02 / CLEAR OF THE DOCK"][i],Vector2(20+i*420,95),17)
			label("Same 30 / 50 / 80px identity studies and existing VFX. No new combat actors, events or mechanics.",Vector2(20,808),16)
			label("Texture modulation = 1; all new details are offline assets. Native full-frame performance acceptance pending.",Vector2(20,835),15,Color("96aebd"))
func _initialize()->void:call_deferred("run")
func sampling(texture:Texture2D)->Vector3:
	var height:float=texture.get_height()
	return Vector3(2.0/height,960.0/height,(height-4.0-960.0)/height)
func run()->void:
	var dir=OS.get_environment("OPENING_REVIEW_DIR")
	var project=OS.get_environment("OPENING_PROJECT_DIR")
	if dir.is_empty() or project.is_empty():quit(1);return
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	var labels=Labels.new();root.add_child(labels)
	var actors=[];var backgrounds=[];var materials=[];var clips=[]
	var textures=[load("res://assets/backgrounds/opening/stage_01.png"),load("res://assets/backgrounds/opening/stage_02.png")]
	var ships=ImageTexture.create_from_image(Image.load_from_file(project+"/docs/art/opening-three/revision-03/enemies-topdown-source.png"))
	for i in 3:
		var clip=Control.new();clip.position=Vector2(20+i*420,110);clip.size=Vector2(400,672);clip.clip_contents=true;root.add_child(clip);clips.append(clip)
		var background=Backdrop.new();background.scale=Vector2.ONE*(400.0/572.0)
		var mat=ShaderMaterial.new();mat.shader=load("res://scripts/starfield.gdshader")
		var texture:Texture2D=textures[0 if i<2 else 1]
		mat.set_shader_parameter("opening_enabled",true);mat.set_shader_parameter("opening_progress",0.0 if i==0 else 1.0)
		mat.set_shader_parameter("opening_texture",texture);mat.set_shader_parameter("opening_sample",sampling(texture))
		background.material=mat;materials.append(mat);clip.add_child(background);backgrounds.append(background)
		var specimen=Specimens.new();specimen.ships=ships;specimen.scale=background.scale;clip.add_child(specimen);actors.append(specimen)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir+"/transition-viewports.png")
	# Art-only pan: does not change or model gameplay time/distance.
	DirAccess.make_dir_recursive_absolute("/tmp/opening-v2/frames")
	for frame in 81:
		var phase:float=float(frame)/40.0
		var next:int=0 if phase<=1.0 else 1
		materials[0].set_shader_parameter("opening_texture",textures[next])
		materials[0].set_shader_parameter("opening_sample",sampling(textures[next]))
		materials[0].set_shader_parameter("opening_progress",phase-float(next))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(20,110,400,672)).save_png("/tmp/opening-v2/frames/%03d.png"%frame)
	for actor in actors:actor.enabled=false;actor.queue_redraw()
	materials[0].set_shader_parameter("opening_texture",textures[0]);materials[0].set_shader_parameter("opening_sample",sampling(textures[0]));materials[0].set_shader_parameter("opening_progress",0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir+"/transition-backgrounds.png")
	# End/start comparison through the real shader at two physical sampling scales.
	materials[0].set_shader_parameter("opening_progress",1.0)
	materials[1].set_shader_parameter("opening_texture",textures[1]);materials[1].set_shader_parameter("opening_sample",sampling(textures[1]));materials[1].set_shader_parameter("opening_progress",0.0)
	for width in [400,572]:
		root.size=Vector2i((width+20)*3+20,int(width*960.0/572.0)+160);root.content_scale_size=root.size
		for i in 3:
			clips[i].position=Vector2(20+i*(width+20),110);clips[i].size=Vector2(width,width*960.0/572.0)
			backgrounds[i].scale=Vector2.ONE*(float(width)/572.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot=root.get_texture().get_image()
		shot.get_region(Rect2i(20,110,width,int(width*960.0/572.0))).save_png("/tmp/opening-v2/seam-%d-end.png"%width)
		shot.get_region(Rect2i(40+width,110,width,int(width*960.0/572.0))).save_png("/tmp/opening-v2/seam-%d-start.png"%width)
	for child in root.get_children():child.queue_free()
	await process_frame
	root.size=Vector2i(1280,1300);root.content_scale_size=root.size
	var overview=Labels.new();overview.overview=true
	var image=Image.load_from_file(project+"/docs/art/parent-continuous-v2/source-master.png")
	overview.parent_map=ImageTexture.create_from_image(image.get_region(Rect2i(235,0,253,2172)))
	overview.refined=ImageTexture.create_from_image(Image.load_from_file(dir+"/source/refined-master.png"));root.add_child(overview)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir+"/master-to-refinement.png")
	print("V2_RENDER_OK / 81 art-pan frames / 2 sampling scales / no combat state")
	quit()
