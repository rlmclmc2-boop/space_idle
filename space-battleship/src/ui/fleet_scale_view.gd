extends Control
## One common scale; this comparison does not change combat dimensions.
const KEYS=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
const NAMES=["护卫艇","驱逐舰","巡洋舰","战列舰","重型战列舰"]
var models:Array=[]
func _init(provider:Callable)->void:
	custom_minimum_size=Vector2(900,335)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for key in KEYS:models.append(provider.call(key))
func _draw()->void:
	var font:Font=ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1b2b"))
	draw_string(font,Vector2(16,25),"五档同尺度 · 统一 0.8×展示；数值为战场实际高度",HORIZONTAL_ALIGNMENT_LEFT,865,17,Color("cce8ec"))
	for i in models.size():
		var row:Dictionary=models[i]
		var center:=Vector2(90+i*178,160)
		var dimensions:Vector2=Vector2(row.dimensions)*0.8
		draw_texture_rect(row.texture,Rect2(center-dimensions*0.5,dimensions),false)
		draw_string(font,Vector2(i*178+12,305),NAMES[i],HORIZONTAL_ALIGNMENT_CENTER,160,18,Color("e0eff2"))
		draw_string(font,Vector2(i*178+12,329),"%.1f"%row.height,HORIZONTAL_ALIGNMENT_CENTER,160,16,Color("87cbd0"))
