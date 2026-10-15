extends SceneTree
class Board extends Node2D:
 var before:Texture2D
 var after:Texture2D
 var index:=0
 func _draw()->void:
  draw_string(ThemeDB.fallback_font,Vector2(20,28),"BEFORE / d2826efe                     AFTER / HIERARCHY + DOCK EXIT",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
  for i in 2:
   draw_texture_rect_region(before if i==0 else after,Rect2(20+i*420,50,400,672),Rect2(20+index*420,110,400,672))
  draw_string(ThemeDB.fallback_font,Vector2(20,748),["STAGE 1 START","STAGE 1 END = STAGE 2 START","STAGE 2 END"][index]+" / SAME SHIPS, VFX, POSITIONS AND SCALE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func _initialize()->void:call_deferred("run")
func run()->void:
 var dir=OS.get_environment("OPENING_REVIEW_DIR")
 var project=OS.get_environment("OPENING_PROJECT_DIR")
 root.size=Vector2i(860,770);root.content_scale_size=root.size
 var board=Board.new()
 board.before=ImageTexture.create_from_image(Image.load_from_file(project+"/docs/art/continuous-v2-refinement/phase-01-02/transition-viewports.png"))
 board.after=ImageTexture.create_from_image(Image.load_from_file(dir+"/transition-viewports.png"));root.add_child(board)
 for i in 3:
  board.index=i;board.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(dir+"/comparison-%d.png"%(i+1))
 quit()
