extends SceneTree
const ROOT="res://docs/art/opening-three/defence-candidates/"
const SHIELD=preload("res://docs/art/opening-three/defence-candidates/shield_shape_proposal.gd")
const GEOMETRY=preload("res://scripts/enemy_protection_geometry.gd")
var records:Array=[]
var authority=AuditAuthority.new()
var painter=AuditPainter.new()
var shield=SHIELD.new()
var audits:Array=[]

class AuditAuthority extends "res://scripts/simulation_geometry_authority.gd":
	var aim_value:float=0.0
	func enemy_weapon_angle(_enemy:Dictionary,_index:int,_render_position:=Vector2.INF)->float:
		return aim_value

class AuditPainter extends "res://scripts/main.gd":
	var review_components:Array=[]
	var review_poses:Dictionary={}
	func enemy_weapon_components(_enemy:Dictionary)->Array:return review_components
	func enemy_component_pose(_enemy:Dictionary,component,_render_position:=Vector2.INF)->Dictionary:return review_poses[component.owner_slot]
	func enemy_recognition_screen_scale()->float:return 1.0

class Board extends Node2D:
	var host
	var states:=false
	func label_at(p:Vector2,s:String,size:=16):draw_string(ThemeDB.fallback_font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("ced8df"))
	func hull(r:Dictionary,p:Vector2,height:float,angle:=PI):
		draw_set_transform(p,angle,Vector2.ONE*(height/r.rect.size.y))
		draw_texture_rect_region(r.texture,Rect2(-r.rect.size*0.5,r.rect.size),r.rect)
		draw_set_transform(Vector2.ZERO)
	func _draw():
		draw_rect(Rect2(0,0,1600,1100),Color("101820"))
		if states:draw_states();return
		label_at(Vector2(25,30),"REAL COMPONENTS / same mount descriptions, production muzzle & paint",24)
		label_at(Vector2(25,58),"Rows: two materials per family. Actual hull height 30 / 50 / 80px. Green: canonical inner envelope; amber: muzzle.",16)
		for group in 3:
			label_at(Vector2(230+group*450,94),["cannon-mon", "laser_mon", "missile-mon"][group],20)
			for size_index in 3:label_at(Vector2(245+group*450+size_index*140,120),str([30,50,80][size_index])+"px",14)
		for row in host.records.size():
			var r:Dictionary=host.records[row]
			var y:float=205+row*130
			label_at(Vector2(20,y),r.name,17)
			for group in 3:
				for size_index in 3:
					var height:float=[30,50,80][size_index]
					var p=Vector2(265+group*450+size_index*140,y)
					var sample:Dictionary=r.samples[group*3+size_index]
					hull(r,p,height)
					draw_set_transform(p,PI)
					host.authority.enemy_recognition.closed(self,sample.packet.inner,Color("598b79",0.5),1.0)
					draw_set_transform(Vector2.ZERO)
					host.painter.draw_surface=self
					host.painter.review_components=sample.components
					host.painter.review_poses=sample.poses
					host.painter.draw_enemy_weapon_components({},p,0,sample.width,false)
					for pose in sample.poses.values():
						draw_circle(p+pose.muzzle,1.5,Color("ffcd7b"))
					for path in sample.muzzle_paths:draw_muzzle_path(path,p)
		label_at(Vector2(25,1015),"Faint amber arcs: legal muzzle sweep. Audit samples 181 angles per mount at each size, with existing minimum weapon width.",16)
		label_at(Vector2(25,1045),"Review fixtures only: no old enemy binding, loadout changes, firing, damage, or simulation ticks. Envelopes are not copied from old hulls.",16)
	func draw_muzzle_path(path:PackedVector2Array,p:Vector2):
		if path.size()>1:
			draw_set_transform(p);draw_polyline(path,Color("d9aa63",0.35),1.0);draw_set_transform(Vector2.ZERO)
	func draw_states():
		label_at(Vector2(25,30),"30px DIRECTION & SHIELD STATE / review-only shape marks",24)
		label_at(Vector2(25,58),"Left: source bow UP / combat bow DOWN. State cells: 30px + 50px hull, independent of armour material.",16)
		var names=["No capacity","Physical active =","Energy diamond","Depleted","Actual increase =","Paused increase"]
		for j in 6:label_at(Vector2(350+j*205,106),names[j],16)
		for row in host.records.size():
			var r:Dictionary=host.records[row]
			var y:float=200+row*130
			label_at(Vector2(15,y-32),r.name,16)
			hull(r,Vector2(85,y),30,0);hull(r,Vector2(165,y),30)
			for j in 6:
				for mini in 2:
					var height:float=30 if mini==0 else 50
					var width=height*887/r.rect.size.y
					var p=Vector2(370+j*205+mini*85,y)
					hull(r,p,height)
					var enemy={"hp":100,"max_shield":0 if j==0 else 100,"shield":0 if j in [0,3] else 50,"shieldRecovery":0 if j==0 else 1,"shield_hit_at":0,"shieldDelay":1,"armourType":int(r.armourType),"shieldType":1 if j==2 else 2,"size":int(r.reference_key.trim_prefix("enemy_"))}
					var cache={"recognition_shield_clock":1.0,"recognition_shield_amount":40 if j in [4,5] else enemy.shield,"recognition_recovering":false}
					var status=host.shield.state(enemy,2.0,j==5,cache)
					var packet=host.authority.geometry_from_descriptor(r.descriptor,width,[],j!=0,{},1.0,enemy.size>=4)
					draw_set_transform(p,PI)
					host.shield.draw_protection(self,enemy,width,packet,status,2.0,true)
					draw_set_transform(Vector2.ZERO)
		label_at(Vector2(25,1010),"Paired flat ribs: physical-resistant shield. Hollow diamond: energy-resistant shield. Marks only exist while shield > 0.",16)
		label_at(Vector2(25,1040),"No shield and depleted shield retain hull material. Recovery follows actual amount increase; pause suppresses flow. No timing rule added.",16)

func _initialize():call_deferred("run")

func run():
	authority.db=ShipDatabase.new()
	authority.visual_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	for r in JSON.parse_string(FileAccess.get_file_as_string(ROOT+"candidates.json")).records:
		var image=Image.load_from_file(ROOT+r.texture)
		r.texture=ImageTexture.create_from_image(image);r.rect=Rect2(image.get_used_rect())
		r.descriptor={"identity":r.texture.get_instance_id(),"profile":authority.enemy_recognition.hull_profile(r.texture)}
		r.samples=[]
		for weapon in ["cannon-mon","laser_mon","missile-mon"]:
			var entries=[]
			for ignored in r.slot_map:entries.append({"key":weapon})
			var components=authority.compose_weapon_components(r.reference_key,entries,"enemy")
			var mounts=authority.enemy_recognition.descriptors(components)
			for height in [30,50,80]:
				var width:float=height*887.0/r.rect.size.y
				var packet=authority.geometry_from_descriptor(r.descriptor,width,mounts,false,{},1.0,int(r.reference_key.trim_prefix("enemy_"))>=4)
				var hull_points=PackedVector2Array()
				for point in r.descriptor.profile:hull_points.append(point*width)
				var hull_clearance=GEOMETRY.min_clearance(hull_points,packet.inner)
				var poses={};var paths=[];var minimum:float=INF
				for index in components.size():
					var component=components[index]
					var mount:Dictionary=mounts[index]
					var points=PackedVector2Array();var path=PackedVector2Array()
					var limit:float=mount.limit if component.mode() in ["main","secondary"] else 0.0
					for step in 181:
						authority.aim_value=lerpf(-limit,limit,step/180.0)
						var pose=authority._source_enemy_component_pose({},component,Vector2.ZERO,width,0.0)
						path.append(pose.muzzle)
						for corner in authority.enemy_recognition.mount_corners(mount,width,15.0):
							points.append((pose.origin+corner.rotated(pose.angle)).rotated(PI))
					minimum=minf(minimum,GEOMETRY.min_clearance(points,packet.inner))
					paths.append(path)
					authority.aim_value=0
					poses[component.owner_slot]=authority._source_enemy_component_pose({},component,Vector2.ZERO,width,0.0)
				r.samples.append({"width":width,"components":components,"packet":packet,"poses":poses,"muzzle_paths":paths})
				audits.append({"name":r.name,"weapon":weapon,"visible_height":height,"canonical_width":width,"logical_slots":entries.size(),"physical_mounts":components.size(),"minimum_weapon_clearance_px":minimum,"minimum_hull_clearance_px":hull_clearance,"angles_per_mount":181,"passed":minimum>=0 and hull_clearance>=0})
		records.append(r)
	FileAccess.open(ROOT+"mounted-audit.json",FileAccess.WRITE).store_string(JSON.stringify(audits,"  ")+"\n")
	root.size=Vector2i(1600,1100);root.content_scale_size=root.size
	var board=Board.new();board.host=self;root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROOT+"mounted-review.png")
	board.states=true;board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROOT+"state-review.png")
	var material=ShaderMaterial.new()
	material.shader=Shader.new()
	material.shader.code="shader_type canvas_item; void fragment(){ float l=dot(COLOR.rgb,vec3(0.2126,0.7152,0.0722)); COLOR=vec4(vec3(l),COLOR.a); }"
	board.material=material;board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROOT+"state-review-grayscale.png")
	painter.free()
	quit()
