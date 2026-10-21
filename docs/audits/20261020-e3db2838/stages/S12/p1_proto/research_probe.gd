extends SceneTree

# Exploratory copy of main ai_tech_tree.advance order for the fixed finite
# fractional scenes. No game profile or personal save is opened.
func advance(balance: float, progress: float, dt: float, amount: int) -> Dictionary:
	var remaining := dt
	var paid_seconds := 0.0
	var iterations := 0
	var trace: Array = []
	while remaining > 0.0000000001 and iterations < 256:
		iterations += 1
		var step := remaining
		var speed := 1.0
		var uses_input := amount > 0 and balance > 0.0
		if uses_input:
			if balance < float(amount) * remaining:
				step = minf(step, balance / float(amount))
			speed *= 1.0 + log(float(amount)) / log(10.0) / 4.0
		step = minf(step, maxf(0.0, 100.0 - progress) / speed)
		if step <= 0.0000000001:
			if uses_input and balance < float(amount) * 0.0000000001:
				balance = 0.0
			trace.append({"microclear": true, "balance": balance, "remaining": remaining})
			continue
		var expense := float(amount) * step if uses_input else 0.0
		balance = balance - expense if balance > expense else 0.0
		if uses_input:
			paid_seconds += step
		progress += step * speed
		remaining -= step
		trace.append({"step": step, "expense": expense, "balance": balance, "progress": progress, "remaining": remaining})
	return {"balance": balance, "progress": progress, "paid_seconds": paid_seconds, "iterations": iterations, "trace": trace}

func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return "%016x" % bytes.decode_u64(0)

func _initialize() -> void:
	var half := advance(0.5, 0.0, 1.0, 1)
	var one_half := advance(1.5, 0.0, 1.0, 1)
	var second := advance(one_half.balance, one_half.progress, 1.0, 1)
	var ten_input := advance(5.0, 0.0, 1.0, 10)
	var balance := 1.0
	var progress := 0.0
	var tenth: Array = []
	for i in 10:
		var result := advance(balance, progress, 0.1, 1)
		balance = result.balance
		progress = result.progress
		tenth.append({"tick":i+1,"result":result})
	var after_tenths := advance(balance, progress, 1.0, 1)
	print(JSON.stringify({"kind":"exploratory_research","half":half,"one_half":one_half,"second":second,"ten_input":ten_input,"dt_point_one_bits":bits(0.1),"balance_after_tenth_bits":bits(balance),"ten_tenths":tenth,"after_tenths_microclear":after_tenths}))
	quit()
