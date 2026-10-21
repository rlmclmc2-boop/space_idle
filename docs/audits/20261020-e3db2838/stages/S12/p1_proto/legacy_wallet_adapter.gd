extends RefCounted
const S=preload("res://scripts/sparse_wallet.gd")

static func normalize_old(value:Variant)->Variant:
	var blocks:Variant=S.blocks(value)
	if blocks==null:return null
	var canonical:Array=S._normalized(blocks)
	return S._encode(canonical) if S._positive(canonical) else null
