extends SceneTree
class ErrorGame extends BattleGame:
 func _tick_synchronized(_dt: float) -> void:
  var empty: Array=[]
  # Intentional runtime unwind: only this dedicated negative test emits it.
  print(empty[1])
func _initialize() -> void:
 var g:=ErrorGame.new(ShipDatabase.new(),false)
 print("EXPECTED_SCOPE_RUNTIME_ERROR_BEGIN")
 g.tick(0)
 print("EXPECTED_SCOPE_RUNTIME_ERROR_END depth=",g._enhancement_read_scope_depth)
 var ok:=g._enhancement_read_scope_depth==0
 quit(0 if ok else 1)
