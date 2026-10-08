extends RefCounted
## Preserve module and idle shares exactly across an integer capacity increase.
## Quotient/remainder multiplication avoids float rounding and int64 products.
static func product_share(amount: int, weight: int, total: int) -> Array[int]:
	var quotient := 0
	var remainder := 0
	var part_quotient: int = weight / total
	var part_remainder: int = weight % total
	var bits := amount
	while bits > 0:
		if bits & 1:
			quotient += part_quotient
			if remainder >= total-part_remainder:
				remainder -= total-part_remainder
				quotient += 1
			else:remainder += part_remainder
		bits >>= 1
		if bits == 0:break
		part_quotient *= 2
		if part_remainder >= total-part_remainder:
			part_remainder -= total-part_remainder
			part_quotient += 1
		else:part_remainder *= 2
	return [quotient,remainder]

static func expand(modules: Array, allocation: Dictionary, old_capacity: int, new_capacity: int) -> Dictionary:
	var next := allocation.duplicate()
	if old_capacity <= 0 or new_capacity <= old_capacity:return next
	var weights: Array[int] = []
	var assigned := 0
	for key in modules:
		var value := int(allocation.get(key,0))
		if value < 0 or value > old_capacity-assigned:return next
		weights.append(value)
		assigned += value
	weights.append(old_capacity-assigned) # Idle is a real share, never silently spent.
	var shares: Array[int] = []
	var remainders: Array[int] = []
	var order: Array[int] = []
	var left := new_capacity-old_capacity
	for index in weights.size():
		var quote := product_share(new_capacity-old_capacity,weights[index],old_capacity)
		shares.append(quote[0])
		remainders.append(quote[1])
		order.append(index)
		left -= quote[0]
	order.sort_custom(func(a,b):return remainders[a]>remainders[b] if remainders[a]!=remainders[b] else a<b)
	for index in left:shares[order[index]] += 1
	for index in modules.size():next[modules[index]] = weights[index]+shares[index]
	return next
