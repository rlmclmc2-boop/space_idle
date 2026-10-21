extends SceneTree
const S=preload("res://scripts/sparse_wallet.gd")
func _initialize() -> void:
	var value: Dictionary={"v":1,"i":"9".repeat(5000)}
	var raw=S.blocks(value)
	var normalized=S._encode(raw) if raw!=null else null
	var fee:Dictionary={"v":3,"blocks":[{"p":"0","d":65}]}
	print(JSON.stringify({"blocks":raw.size() if raw!=null else -1,"valid":S.valid(normalized) if normalized!=null and normalized is Dictionary else false,"compare":S.compare(normalized,fee) if normalized!=null else null,"head":raw[-1] if raw!=null and raw.size()>0 else null,"tail":raw[0] if raw!=null and raw.size()>0 else null}))
	quit()
