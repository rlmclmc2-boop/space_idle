extends SceneTree
const T=preload("res://scripts/save_transfer.gd")
func _initialize():
 var spec=T.schema().reactorAllocation["*"]
 for bad in [-1,1.5,INF,NAN,{"i":"05"},{"i":"5"},{"i":"9007199254740993","x":0},{"m":1.0,"e":400.0},"123"]:
  print("BAD ",bad," ACCEPTED ",T.shape(bad,spec))
 quit()
