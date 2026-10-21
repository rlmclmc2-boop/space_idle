extends SceneTree
const T=preload("res://scripts/save_transfer.gd")
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():
 var source='{"reactorAllocation":{"weapons":9007199254740993,"defence":5}}'
 var raw=JSON.parse_string(source)
 print("PARSED ",raw.reactorAllocation.weapons)
 print("RESTORE ",T.restore_legacy_reactor_integers(source,raw)," DIGITS ",R.digits(raw.reactorAllocation.weapons))
 quit(0 if R.digits(raw.reactorAllocation.weapons)=="9007199254740993" else 1)
