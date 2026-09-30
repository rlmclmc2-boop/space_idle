extends SceneTree
const STRIP := preload("res://scripts/resource_strip_presentation.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var samples: Array=[0.0,999.0,1000.0,1e18,1e30,{"m":9.99,"e":33.0},{"m":9.99,"e":1234567.0}]
	for value in samples:
		for rate_mode in [false,true]:
			var shown: String=NumberFormat.compact(value) if not rate_mode else UIText.t("inventory.rate",{"rate":NumberFormat.rate(value)})
			var font_size: int=STRIP.value_size(shown)
			check(font_size>=20,"All quantity and suffix text remains readable: "+shown)
			check(STRIP.SHELL.face(700).get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=STRIP.VALUE_WIDTH,"Complete formatted value fits: "+shown)
	check(UIText.data_text("resources","1")=="铁" and UIText.data_text("resources","2")=="铀","Existing explicit Chinese resource identities retained")
	check(STRIP.ICONS[0]!=STRIP.ICONS[1] and STRIP.ICONS[0].get_size()==Vector2(64,64),"Resource icons are distinct cached SVG textures")
	check(not STRIP.RECTS[0].intersects(STRIP.RECTS[1]) and STRIP.RECTS[1].end.x<500,"Resource capsules avoid each other and existing music controls")
	print("Resource strip art: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
