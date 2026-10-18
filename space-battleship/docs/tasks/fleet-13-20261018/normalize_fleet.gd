extends SceneTree

# Reproducible alpha-preserving placement of the approved isolated source PNGs.
# Input files are decoded from the reference commit outside the production tree.
const NAMES:=[
	"01-frigate","02-destroyer","03-cruiser","04-battleship","05-heavy-battleship",
	"06-scout","07-sentry","08-interceptor","09-swarm","10-anchor",
	"11-reactive","12-shielded","13-command",
]
const HULL_SIZE:=Vector2i(887,1774)
const UI_SIZE:=Vector2i(768,768)

func solid_bounds(image:Image)->Rect2i:
	var lo:=Vector2i(image.get_width(),image.get_height())
	var hi:=Vector2i(-1,-1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a<0.05:continue
			lo.x=mini(lo.x,x);lo.y=mini(lo.y,y)
			hi.x=maxi(hi.x,x);hi.y=maxi(hi.y,y)
	assert(hi.x>=lo.x and hi.y>=lo.y)
	return Rect2i(lo,hi-lo+Vector2i.ONE)

func crop_with_margin(image:Image,bounds:Rect2i)->Image:
	var margin:=maxi(20,roundi(maxf(bounds.size.x,bounds.size.y)*0.018))
	var first:=Vector2i(maxi(0,bounds.position.x-margin),maxi(0,bounds.position.y-margin))
	var end:=Vector2i(mini(image.get_width(),bounds.end.x+margin),mini(image.get_height(),bounds.end.y+margin))
	return image.get_region(Rect2i(first,end-first))

func place(source:Image,canvas_size:Vector2i,width_ratio:float,height_ratio:float)->Image:
	var max_w:=canvas_size.x*width_ratio
	var max_h:=canvas_size.y*height_ratio
	var scale:=minf(max_w/source.get_width(),max_h/source.get_height())
	var scaled:=source.duplicate()
	scaled.resize(maxi(1,roundi(source.get_width()*scale)),maxi(1,roundi(source.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	var result:=Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var offset:Vector2i=(canvas_size-scaled.get_size())/2
	result.blit_rect(scaled,Rect2i(Vector2i.ZERO,scaled.get_size()),offset)
	return result

func _initialize()->void:
	var source_dir:=OS.get_environment("FLEET_SOURCE_DIR")
	assert(not source_dir.is_empty())
	var hull_base:="res://assets/ships/approved_fleet_20261018"
	var ui_base:="res://assets/ui/ships/approved_fleet_20261018"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(hull_base+"/player"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(hull_base+"/enemy"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ui_base))
	var report:Dictionary={"reference_commit":"96332dd117c7661a6439fb546af35b5d8dd668fe","canvas":[HULL_SIZE.x,HULL_SIZE.y],"ui_canvas":[UI_SIZE.x,UI_SIZE.y],"assets":[]}
	for i in NAMES.size():
		var key:String=NAMES[i]
		var input:=Image.load_from_file(source_dir.path_join(key+".png"))
		assert(input!=null and input.get_width()>0)
		input.convert(Image.FORMAT_RGBA8)
		var body:=solid_bounds(input)
		var cropped:=crop_with_margin(input,body)
		# Enemy actors use the full 1:2 canvas at battle scale. Reduce transparent
		# margins without changing the approved silhouette's aspect ratio.
		var hull:=place(cropped,HULL_SIZE,0.83 if i<5 else 0.93,0.74 if i<5 else 0.92)
		var hull_path:=hull_base+("/player/" if i<5 else "/enemy/")+key+".png"
		assert(hull.save_png(hull_path)==OK)
		var hull_body:=solid_bounds(hull)
		var source_ratio:=float(body.size.x)/float(body.size.y)
		var output_ratio:=float(hull_body.size.x)/float(hull_body.size.y)
		assert(absf(output_ratio/source_ratio-1.0)<0.025,key+": aspect changed")
		assert(hull_body.position.x>=30 and hull_body.position.y>=30 and HULL_SIZE.x-hull_body.end.x>=30 and HULL_SIZE.y-hull_body.end.y>=30,key+": unsafe edge")
		assert(hull.get_pixel(0,0).a==0.0 and hull.get_pixel(HULL_SIZE.x-1,HULL_SIZE.y-1).a==0.0)
		var row:Dictionary={"name":key,"source_size":[input.get_width(),input.get_height()],"source_body":[body.position.x,body.position.y,body.size.x,body.size.y],"hull_body":[hull_body.position.x,hull_body.position.y,hull_body.size.x,hull_body.size.y],"hull_path":hull_path}
		if i<5:
			var thumbnail:=place(cropped,UI_SIZE,0.82,0.82)
			var ui_path:=ui_base+"/"+key+".png"
			assert(thumbnail.save_png(ui_path)==OK)
			var ui_body:=solid_bounds(thumbnail)
			assert(ui_body.position.x>=25 and ui_body.position.y>=25 and UI_SIZE.x-ui_body.end.x>=25 and UI_SIZE.y-ui_body.end.y>=25)
			row.ui_body=[ui_body.position.x,ui_body.position.y,ui_body.size.x,ui_body.size.y]
			row.ui_path=ui_path
		report.assets.append(row)
		print("FLEET_NORMALIZED ",key," source=",body," hull=",hull_body," ui=",row.get("ui_body",[]))
	FileAccess.open("res://docs/tasks/fleet-13-20261018/normalization.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FLEET_NORMALIZE_DONE ",report.assets.size())
	quit()
