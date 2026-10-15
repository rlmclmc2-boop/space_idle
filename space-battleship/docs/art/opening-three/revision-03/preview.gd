extends SceneTree
## Standalone art stage. No BattleGame, entities, hit geometry or event emission.
const PULSE=preload("res://dev/toon_ship/pulse_vfx.gd")
const MISSILE=preload("res://dev/toon_ship/missile_vfx.gd")
const RAIL=preload("res://dev/toon_ship/rail_vfx.gd")
class BattleView extends Node2D:
	var host
	func _draw()->void:host.paint_battlefield(self)
class Review extends Node2D:
	var background:Texture2D
	var ships:Texture2D
	var font=ThemeDB.fallback_font
	var rail=RAIL.new()
	var effects:=true
	var regions=[Rect2(26,145,608,614),Rect2(638,125,568,635),Rect2(1220,140,536,635)]
	func label(value:String,pos:Vector2,size:int=17,color:Color=Color("d6e1e5"))->void:
		draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func hull(kind:int,center:Vector2,pixel_height:float,surface:CanvasItem=null)->void:
		if surface==null:surface=self
		var region:Rect2=regions[kind]
		var size=Vector2(region.size.x/region.size.y,1)*pixel_height
		surface.draw_texture_rect_region(ships,Rect2(center-size*0.5,size),region)
	func _draw()->void:
		draw_rect(Rect2(0,0,1200,900),Color("0d1823"))
		label("R03 / ONE VIEWPORT — TOP-DOWN ART & OCCLUSION REVIEW",Vector2(30,38),23)
		label("Standalone presentation fixture. New hull art; no live actors, hits, damage or mechanism states.",Vector2(30,66),16,Color("96aebd"))
		label("400 x 672 physical pixels",Vector2(30,100),17)
		label("Upper 30px / middle 50px / lower 80px",Vector2(30,815),16)
		label("No global darkening (texture modulation = 1).",Vector2(30,840),15,Color("96aebd"))
		label("100% PIXELS / LIGHT DECK — RIGHT METAL — LOWER CLOUD",Vector2(470,100),16)
		var source_regions=[Rect2(40,110,700,200),Rect2(260,700,700,200),Rect2(40,1300,700,200)]
		var names=["NEEDLE / triangle + pale wing blocks","ANVIL / slab + broad pale armor","CROWN / open U + two pale tips"]
		for row in 3:
			var top=132.0+float(row)*204.0
			label(names[row],Vector2(470,top),17,Color("cbbba6"))
			for col in 3:
				var x=470.0+float(col)*230.0
				draw_texture_rect_region(background,Rect2(x,top+15,216,145),source_regions[col])
				for i in 3:hull(row,Vector2(x+38.0+float(i)*69.0,top+85),[30.0,50.0,80.0][i])
				label("30 / 50 / 80 px",Vector2(x+44,top+182),14,Color("96aebd"))
		label("VFX ON: pulse / missile / rail + contact shapes" if effects else "VFX OFF: same hulls, scales, positions and background",Vector2(470,782),17)
		label("Existing painters; fixed ages; no damage / shield / charge claims.",Vector2(470,809),15,Color("96aebd"))
		label("2D generated art. No 3D hull models have been introduced.",Vector2(470,840),15,Color("96aebd"))
	func paint_battlefield(surface:CanvasItem)->void:
		# Same 572x960 logical battlefield and ~0.70 display scale as the game.
		var scale_value=400.0/572.0
		surface.draw_texture_rect(background,Rect2(0,0,572,960),false)
		var positions=[Vector2(100,160),Vector2(286,160),Vector2(470,160),Vector2(100,450),Vector2(286,450),Vector2(470,450),Vector2(100,790),Vector2(286,790),Vector2(470,790)]
		for row in 3:
			for col in 3:hull(col,positions[row*3+col],[30.0,50.0,80.0][row]/scale_value,surface)
		# Existing presentation painters, sampled at explicit fixed visual ages.
		# Static art specimens only: these calls do not manufacture gameplay events.
		if effects:
			PULSE.flight(surface,Vector2(240,360),Vector2.UP)
			PULSE.impact(surface,positions[1]+Vector2(0,18),Vector2.UP,0.05,false)
			MISSILE.flight(surface,Vector2(435,615),Vector2(-0.3,-1).normalized(),0.5,7,1.0,true,true)
			MISSILE.impact(surface,positions[5]+Vector2(0,28),Vector2.UP,0.14,false,1.0,7)
			rail.penetration(surface,Vector2(330,940),positions[7],Vector2.UP,0.09,1.0,Vector2(572,960))
			rail.impact(surface,positions[7]+Vector2(0,50),Vector2.UP,0.02,false,1.0)

func _initialize()->void:call_deferred("run")
func run()->void:
	var directory=OS.get_environment("OPENING_REVIEW_DIR")
	if directory.is_empty():push_error("Set OPENING_REVIEW_DIR to revision-03 directory");quit(1);return
	var view=Review.new()
	view.background=ImageTexture.create_from_image(Image.load_from_file(directory+"/orbit-topdown-source.png"))
	view.ships=ImageTexture.create_from_image(Image.load_from_file(directory+"/enemies-topdown-source.png"))
	root.size=Vector2i(1200,900)
	root.add_child(view)
	var clip=Control.new();clip.position=Vector2(30,116);clip.size=Vector2(400,672);clip.clip_contents=true
	view.add_child(clip)
	var battlefield=BattleView.new();battlefield.host=view;battlefield.scale=Vector2.ONE*(400.0/572.0)
	clip.add_child(battlefield)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/viewport-review.png")
	view.effects=false;view.queue_redraw();battlefield.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/viewport-without-effects.png")
	print("ART_REVIEW_OK / two framebuffer captures / zero combat state")
	quit()
