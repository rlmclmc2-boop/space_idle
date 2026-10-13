extends RefCounted
static var active:=false
static var spans:Array=[]
static func begin()->int:return Time.get_ticks_usec() if active else 0
static func finish(start:int,label:String,extra:int=-1)->void:
 if start>0:spans.append([start,Time.get_ticks_usec(),label,Engine.get_process_frames(),extra])
