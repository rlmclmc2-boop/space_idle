extends RefCounted
## Session-only time ownership: undispatched paid segments and one reserved step.
## This record is never serialized and never duplicates domain pending work.
var segments:Array[Dictionary]=[]
var next_budget:=1
var next_step:=1
var active:=false
var identity:=0
var duration:=0.0
var completed:=0.0
var substep:=0.0
var phase:="idle"
var stage:=0
var items:Array=[]
var item:=0
var accepted:=false
var motion_end:=0.0
var motion_set:=false
var boss_survivors:Array=[]
var before_presented:=false
var source_segments:Array=[]
var reason:=""
var frozen:=false
var blocked_context:Array=[]

func available()->float:
	var total:=0.0
	for segment in segments:total+=float(segment.remaining)
	return total

func accept(seconds:float,multiplier:float,cost:float)->void:
	if seconds<=0:return
	segments.append({"id":next_budget,"seconds":seconds,"multiplier":multiplier,"cost":cost,"remaining":seconds*multiplier})
	next_budget+=1

func begin(dt:float,paid:=false)->bool:
	if active or not is_finite(dt) or dt<=0:return false
	if paid and available()+0.0000000001<dt:return false
	active=true;identity=next_step;next_step+=1;duration=dt;completed=0.0
	phase="prepare";reason="";frozen=false;blocked_context=[];before_presented=false
	source_segments=[]
	if paid:
		var left:=dt
		while left>0.0000000001 and not segments.is_empty():
			var segment:Dictionary=segments[0]
			var taken:=minf(left,float(segment.remaining))
			source_segments.append({"id":segment.id,"duration":taken,"multiplier":segment.multiplier,"cost":segment.cost})
			segment.remaining=maxf(0.0,float(segment.remaining)-taken);left=maxf(0.0,left-taken)
			if float(segment.remaining)<=0.0000000001:segments.pop_front()
	return true

func open_substep(dt:float)->void:
	assert(active and substep==0.0)
	substep=dt;phase="prepare";stage=0;items=[];item=0;accepted=false
	motion_set=false;boss_survivors=[]

func next_stage()->void:
	stage+=1;items=[];item=0;accepted=false

func retire_item(expected_stage:int)->void:
	if active and phase=="shared" and stage==expected_stage:item+=1

func retire_substep()->void:
	completed+=substep;substep=0.0;phase="prepare";stage=0;items=[];item=0;accepted=false;boss_survivors=[]

func finish()->void:
	assert(active and not frozen)
	active=false;duration=0.0;completed=0.0;substep=0.0;phase="idle";stage=0
	items=[];item=0;accepted=false;source_segments=[];blocked_context=[];reason="";boss_survivors=[]

func block(message:String,context:Array=[])->void:
	reason=message;blocked_context=context.duplicate()

func freeze(message:String)->void:
	frozen=true;reason=message

func reset()->void:
	assert(not active,"An incomplete step cannot be discarded by lifecycle replacement")
	segments=[];substep=0.0;phase="idle";reason="";frozen=false;blocked_context=[]
