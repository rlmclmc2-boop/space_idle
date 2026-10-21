extends SceneTree
const T=preload("res://scripts/save_transfer.gd")
func _initialize():
 var source='{"reactorAllocation":{"weapons":9007199254740993},"reactorAllocation":{"weapons":5}}'
 var raw=JSON.parse_string(source)
 print("DUPLICATE_ACCEPT ",T.restore_legacy_reactor_integers(source,raw))
 quit(0 if not T.restore_legacy_reactor_integers(source,raw) else 1)
