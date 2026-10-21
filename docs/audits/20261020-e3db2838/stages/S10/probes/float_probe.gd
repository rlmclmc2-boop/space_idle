extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():
 for x in [1.0,1.5,9007199254740992.0,1e20,1e20+16384.0]:print("FLOAT ",x," FLOOR ",R.digits(R.float_floor(x)))
 quit()
