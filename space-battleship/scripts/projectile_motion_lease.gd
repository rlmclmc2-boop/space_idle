extends RefCounted
## No duplicated motion fields; references pin a slot through final visual use.
var store:RefCounted
var offset:int
var missile_fields:=false
func _init(owner:RefCounted,slot:int)->void:
	store=owner;offset=slot*owner.STRIDE
func _notification(what:int)->void:
	if what==NOTIFICATION_PREDELETE and store!=null:
		store.release(offset/store.STRIDE)
