extends RefCounted
## Two durable independent streams: exploration and each drone's forge table.
static func initial_state() -> String:
	var rng:=RandomNumberGenerator.new();rng.randomize();return str(rng.state)

static func valid_state(value: Variant) -> bool:
	return value is String and value.length()<=20 and value.is_valid_int() and str(value.to_int())==value

static func restore(value: String) -> RandomNumberGenerator:
	var rng:=RandomNumberGenerator.new();rng.state=value.to_int();return rng

static func weighted(rng: RandomNumberGenerator,weights: Dictionary) -> String:
	var total:=0.0
	for value in weights.values():total+=float(value)
	var draw:=rng.randf()*total
	for key in weights:
		draw-=float(weights[key])
		if draw<0:return str(key)
	return str(weights.keys().back()) if total>0 else ""

static func quantized(rng: RandomNumberGenerator,bounds: Array,precision: float) -> float:
	var low:=ceili(float(bounds[0])/precision-0.0000001)
	var high:=floori(float(bounds[1])/precision+0.0000001)
	return snappedf(float(rng.randi_range(low,high))*precision,precision)
