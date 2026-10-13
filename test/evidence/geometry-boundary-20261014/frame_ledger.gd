extends RefCounted
static var active:=false
static var spans:Array=[]
static var gui_draws:Array=[]
static var sorts:Dictionary={}
static func begin()->int:
 return Time.get_ticks_usec() if active else 0
static func finish(start:int,label:String)->void:
 if start>0:spans.append([start,Time.get_ticks_usec(),label])
static func sort_begin(id:int)->void:
 if active:sorts[id]=Time.get_ticks_usec()
static func sort_end(id:int,label:String)->void:
 if active and sorts.has(id):
  spans.append([sorts[id],Time.get_ticks_usec(),"gui_layout:"+label]);sorts.erase(id)
static func gui_draw(label:String)->void:
 if active:gui_draws.append([Time.get_ticks_usec(),label])

static func clear_for_redraw(item:CanvasItem,label:String)->void:
 if active:
  var start=Time.get_ticks_usec()
  RenderingServer.canvas_item_clear(item.get_canvas_item())
  spans.append([start,Time.get_ticks_usec(),"canvas_clear:"+label])

static var records:Array=[]
