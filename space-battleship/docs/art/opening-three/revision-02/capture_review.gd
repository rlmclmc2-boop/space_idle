extends SceneTree
## Isolated art review only. Uses existing actual UI; no runtime asset binding.
const REVIEW := "/workspace/opening-three-art/space-battleship/docs/art/opening-three/revision-02/"
class ScaleBoard extends Node2D:
	var atlas:Texture2D
	var backdrop:Texture2D
	var font=ThemeDB.fallback_font
	var regions=[Rect2(8,145,620,600),Rect2(632,127,598,620),Rect2(1240,103,522,650)]
	func _draw()->void:
		draw_rect(Rect2(0,0,1100,760),Color("101a26"))
		draw_string(font,Vector2(30,38),"REVISION 02  /  ENEMY SILHOUETTE REVIEW",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("dce6e9"))
		draw_string(font,Vector2(30,66),"New art only. Not bound to live enemies or hit geometry.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("95a8b8"))
		for i in 3:
			var region:Rect2=regions[i]
			var ratio=region.size.x/region.size.y
			var x=180.0+float(i)*350.0
			draw_string(font,Vector2(x-80,110),["NEEDLE / DELTA","ANVIL / SLAB","CROWN / OPEN U"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d6b296"))
			draw_texture_rect_region(atlas,Rect2(x-110*ratio,135,220*ratio,220),region)
			for row in 3:
				var height:float=[80.0,50.0,30.0][row]
				var y=415.0+float(row)*100.0
				draw_texture_rect_region(backdrop,Rect2(x-135,y-10,270,95),Rect2(290,300,420,148),Color(0.42,0.42,0.42))
				draw_texture_rect_region(atlas,Rect2(x-height*ratio/2,y,height*ratio,height),region)
				if i==0:draw_string(font,Vector2(20,y+20),str(int(height))+" px",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("dce6e9"))
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false);scene.capture_frame=-10000
	scene.game.save_enabled=false;scene.game.profile.onboarding.completed=true
	scene.game.start(1,false);scene.game.spawn_group();scene.game.pending_unlocks.clear()
	for frame in 24:scene._process(0.02)
	scene.game.paused=true;scene.game.profile.onboarding.dismissed=true;scene.refresh_structure()
	var source=ImageTexture.create_from_image(Image.load_from_file(REVIEW+"broken-orbit-source.png"))
	var shader=Shader.new()
	shader.code=FileAccess.get_file_as_string("res://scripts/starfield.gdshader").replace("((1.0-opening_progress)*2112.0+UV.y*960.0)/3072.0","UV.y").replace("texture(opening_texture,opening_uv).rgb,1.0","texture(opening_texture,opening_uv).rgb*0.42,1.0")
	scene.opening_scenery_stage=1
	scene.stars_layer.material.shader=shader
	scene.stars_layer.material.set_shader_parameter("opening_texture",source)
	scene.stars_layer.material.set_shader_parameter("opening_enabled",true)
	root.size=Vector2i(1373,883)
	scene.refresh_draw_layers(0.0);scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW+"actual-battlefield-review.png")
	scene.queue_free()
	await process_frame
	root.content_scale_size=Vector2i(1100,760);root.size=Vector2i(1100,760)
	var board=ScaleBoard.new();board.atlas=ImageTexture.create_from_image(Image.load_from_file(REVIEW+"enemy-identities-source.png"));board.backdrop=source
	root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW+"enemy-actual-pixel-review.png")
	print("REVIEW_CAPTURE_COMPLETE; native performance not assessed")
	quit()
