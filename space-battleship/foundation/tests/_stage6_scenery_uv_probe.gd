extends SceneTree
class FakeBattle:
	extends RefCounted
	func view_size() -> Vector2i: return Vector2i(572,960)
class FakeCampaign:
	extends RefCounted
	var facts:Dictionary={"stage":1,"progress":0.5,"state":"combat"}
	func scenery_facts()->Dictionary:return facts
class FakeSession:
	extends RefCounted
	var battle=FakeBattle.new()
	var campaign_system=FakeCampaign.new()
	var game_time:float=90.0
func _initialize()->void:call_deferred("_run")
func _run()->void:
	if DisplayServer.get_name()=="headless":
		printerr("Real renderer required for scenery UV pixel mapping");quit(1);return
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(572,960)
	RenderingServer.set_default_clear_color(Color("071423"))
	var session=FakeSession.new()
	var scenery=load("res://src/ui/battle_scenery.gd").new(session)
	root.add_child(scenery)
	scenery._stars.hide()
	var maximum:float=0
	var failures:int=0
	for stage in [1,2]:
		var original:Image=load("res://assets/backgrounds/opening/stage_%02d.png" % stage).get_image()
		for progress in [0.0,0.5,1.0]:
			session.campaign_system.facts={"stage":stage,"progress":progress,"state":"combat"}
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered:Image=root.get_texture().get_image()
			for y in [32,240,480,720,920]:
				for x in [16,143,286,429,555]:
					var source_y:int=y+2+roundi((1.0-progress)*(original.get_height()-964))
					var expected:Color=original.get_pixel(x,source_y)
					var actual:Color=rendered.get_pixel(x,y)
					var error:float=maxf(absf(expected.r-actual.r),maxf(absf(expected.g-actual.g),absf(expected.b-actual.b)))*255.0
					maximum=maxf(maximum,error)
					if error>2.0:failures+=1
			if stage==1 and progress==0.5:
				var unchanged:PackedByteArray=rendered.get_data()
				for frame in 30:
					await process_frame
					await RenderingServer.frame_post_draw
					if root.get_texture().get_image().get_data()!=unchanged:failures+=1
	# The same background surface carries third-stage procedural fog and the route atlas.
	for state in ["combat","hyperspace"]:
		session.campaign_system.facts={"stage":3,"progress":0.5,"state":state}
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered:Image=root.get_texture().get_image()
		var atlas:Image=load("res://assets/backgrounds/hyperspace/routes_atlas.png").get_image()
		for y in [32,240,480,720,920]:
			for x in [16,143,286,429,555]:
				var uv:=Vector2((x+0.5)/572.0,(y+0.5)/960.0)
				var expected:Color=Color("071423")
				if state=="combat":
					var p:Vector2=uv*Vector2(3,5)-Vector2(0,session.game_time*3.0/960.0)
					var cloud:float=sin(p.x*1.7+sin(p.y*1.3))*sin(p.y*0.8+p.x*0.4)
					var haze:float=clampf(cloud*0.5+0.5,0,1)
					var fog:Color=Color(0.055,0.10,0.18).lerp(Color(0.14,0.11,0.24),uv.y)
					expected=expected.lerp(fog,haze*haze*haze*0.22)
				else:
					var location:Vector2=(Vector2(0.025,0.025)+uv*0.95)*0.5*Vector2(atlas.get_size())-Vector2(0.5,0.5)
					var corner:Vector2i=Vector2i(location.floor())
					var part:Vector2=location-Vector2(corner)
					var tint:Color=atlas.get_pixelv(corner).lerp(atlas.get_pixelv(corner+Vector2i(1,0)),part.x).lerp(atlas.get_pixelv(corner+Vector2i(0,1)).lerp(atlas.get_pixelv(corner+Vector2i(1,1)),part.x),part.y)
					expected=expected.lerp(tint*0.52,0.94)
				var actual:Color=rendered.get_pixel(x,y)
				var error:float=maxf(absf(expected.r-actual.r),maxf(absf(expected.g-actual.g),absf(expected.b-actual.b)))*255.0
				maximum=maxf(maximum,error)
				if error>2.0:failures+=1
		print("SCENERY_SHARED_UV_PATH state=",state," cumulative_failures=",failures)
	print("STAGE6_SCENERY_SOURCE_PIXEL_MAPPING samples=200 failures=",failures," max_error_255=",maximum)
	quit(0 if failures==0 else 1)
