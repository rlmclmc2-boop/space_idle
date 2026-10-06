extends SceneTree
const CP=preload("res://qa/hyperspace_checkpoint.gd")
class Holder:
 extends RefCounted
 var reforge_checkpoint_pending:Array=[]
func _initialize()->void:
 var holder=Holder.new()
 CP.apply_fields(holder,{"reforge_checkpoint_pending":{}},["reforge_checkpoint_pending"])
 print("POST_APPLY_TYPE=",typeof(holder.reforge_checkpoint_pending)," VALUE=",holder.reforge_checkpoint_pending)
 quit()
