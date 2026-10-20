extends SceneTree
func _initialize():
 call_deferred("broken")
 call_deferred("finish")
func broken():
 var value:Variant={}
 print(value.required_field)
func finish():
 print("AUDIT_PROCESS_CONTINUED_AFTER_SCRIPT_ERROR")
 quit(0)
