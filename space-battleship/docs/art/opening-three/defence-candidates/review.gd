extends SceneTree
const ROOT := "res://docs/art/opening-three/defence-candidates/"
const RECOGNITION = preload("res://scripts/enemy_recognition_visual.gd")
const GEOMETRY = preload("res://scripts/enemy_protection_geometry.gd")
var visual = RECOGNITION.new()
var records: Array = []

class Sheet extends Node2D:
	var host
	func label_at(p:Vector2,s:String,size:=18,color:=Color("c4ccd5")):
		draw_string(ThemeDB.fallback_font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func hull(record:Dictionary,p:Vector2,h:float,gray:=false):
		var bounds:Rect2=record.rect
		var k=h/bounds.size.y
		draw_set_transform(p,PI,Vector2.ONE*k)
		draw_texture_rect_region(record.gray if gray else record.image,Rect2(-bounds.size*0.5,bounds.size),bounds)
		draw_set_transform(Vector2.ZERO)
	func _draw():
		draw_rect(Rect2(0,0,1500,1130),Color("101820"))
		label_at(Vector2(30,32),"DEFENCE FIRST / six unbound asset candidates",25)
		label_at(Vector2(30,58),"Bow down in combat preview. Heights are actual visible pixels; 100% screenshot. No weapons installed.",16)
		for pair in [[300,"30 px"],[430,"50 px"],[580,"80 px"],[770,"110 px"],[960,"80 px / grayscale"],[1200,"shared mount audit"]]:
			label_at(Vector2(pair[0]-25,90),pair[1],16)
		for i in host.records.size():
			var r:Dictionary=host.records[i]
			var y:float=165+i*125
			draw_line(Vector2(25,y+61),Vector2(1475,y+61),Color("28323c"))
			label_at(Vector2(30,y-5),r.name,20)
			label_at(Vector2(30,y+20),"armourType = "+str(r.armourType),16)
			for pair in [[300,30],[430,50],[580,80],[770,110]]:hull(r,Vector2(pair[0],y),pair[1])
			hull(r,Vector2(990,y),80,true)
			hull(r,Vector2(1280,y),90)
			var k=90.0/r.rect.size.y
			for point in r.hardpoints:
				var offset=Vector2(point.pos[0],point.pos[1]*2)*887*k
				draw_circle(Vector2(1280,y)-offset,3,Color("f9b650"))
			label_at(Vector2(1360,y),r.reference_key,13)
		label_at(Vector2(30,960),"Separate state layer / existing renderer, synthetic read-only inputs",22)
		var descriptions=["No shield capacity","Physical shield active","Shield depleted","Actual shield increase","Energy shield active"]
		for i in 5:
			var r:Dictionary=host.records[5]
			var p:=Vector2(160+i*285,1040)
			hull(r,p,52)
			var enemy={"hp":100,"max_shield":0 if i==0 else 100,"shield":0 if i in [0,2] else 50,"shieldRecovery":0 if i==0 else 1,"shield_hit_at":0,"shieldDelay":1,"armourType":1,"shieldType":1 if i==4 else 2,"size":6}
			var cache={"recognition_shield_clock":1.0,"recognition_shield_amount":40 if i==3 else enemy.shield,"recognition_recovering":false}
			var status=host.visual.state(enemy,2.0,false,cache)
			var width=52*887.0/r.rect.size.y
			var packet=host.visual.geometry(r.image,width,[],i!=0,{},1.0,true)
			draw_set_transform(p)
			host.visual.draw_protection(self,enemy,width,packet,status,2.0,true)
			draw_set_transform(Vector2.ZERO)
			label_at(Vector2(p.x-120,1112),descriptions[i],16)

func _initialize():
	call_deferred("run")

func run():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"candidates.json"))
	var audit=[]
	for item in manifest.records:
		var im=Image.load_from_file(ROOT+item.texture)
		var tex=ImageTexture.create_from_image(im)
		var profile=visual.hull_profile(tex)
		var old=Image.load_from_file(item.reference_texture)
		var old_profile=visual.hull_profile(ImageTexture.create_from_image(old))
		var delta:=0.0
		for j in 360:
			var normal=Vector2.from_angle(j*TAU/360)
			var a:float=-INF
			var b:float=-INF
			for v in profile:a=maxf(a,v.dot(normal))
			for v in old_profile:b=maxf(b,v.dot(normal))
			delta=maxf(delta,absf(a-b))
		var mounts=[]
		var center=GEOMETRY.image_center(im)
		for hp in item.hardpoints:
			var point=center+Vector2(hp.pos[0],hp.pos[1]*2)*im.get_width()
			mounts.append({"source_pixel":[point.x,point.y],"alpha":im.get_pixelv(Vector2i(point)).a})
		var serialized=[]
		for v in profile:serialized.append([v.x,v.y])
		audit.append({"name":item.name,"bounds":[im.get_used_rect().position.x,im.get_used_rect().position.y,im.get_used_rect().size.x,im.get_used_rect().size.y],"old_bounds":str(old.get_used_rect()),"profile":serialized,"reference_key":item.reference_key,"maximum_support_difference_normalized_by_canvas_width":delta,"mount_center_alpha":mounts,"center_alpha":im.get_pixelv(Vector2i(center)).a,"convex_profile_does_not_preserve_notches":true})
		var gray=im.duplicate()
		for y in gray.get_height():
			for x in gray.get_width():
				var c=gray.get_pixel(x,y)
				var l=c.r*0.2126+c.g*0.7152+c.b*0.0722
				gray.set_pixel(x,y,Color(l,l,l,c.a))
		item.image=tex;item.gray=ImageTexture.create_from_image(gray);item.rect=Rect2(im.get_used_rect())
		records.append(item)
	FileAccess.open(ROOT+"geometry-audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"  ")+"\n")
	root.size=Vector2i(1500,1130);root.content_scale_size=root.size
	var sheet=Sheet.new();sheet.host=self;root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROOT+"review.png")
	quit()
