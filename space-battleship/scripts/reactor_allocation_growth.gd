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

const I=preload("res://scripts/reactor_integer.gd")
static func share(amount,weight,total)->Array:
	if amount is int and weight is int and total is int:return product_share(amount,weight,total)
	return I.share(amount,weight,total)

static func distribute(amount,weights:Array,total)->Array:
	var shares:Array=[];var remainders:Array=[];var order:Array[int]=[]
	var left=amount
	for index in weights.size():
		var part:=share(amount,weights[index],total)
		shares.append(part[0]);remainders.append(part[1]);order.append(index)
		left=I.subtract(left,part[0])
	order.sort_custom(func(a,b):return I.compare(remainders[a],remainders[b])>0 if I.compare(remainders[a],remainders[b])!=0 else a<b)
	# Largest-remainder deficit is strictly less than the number of shares.
	for index in int(left):shares[order[index]]=I.add(shares[order[index]],1)
	return shares

static func available(modules: Array, allocation: Dictionary, capacity) -> Dictionary:
	var next:=allocation.duplicate();var total=0;var weights:Array=[]
	for key in modules:
		var amount=I.normalize(allocation.get(key,0))
		next[key]=amount;weights.append(amount);total=I.add(total,amount)
	if I.compare(total,capacity)<=0:return next
	var shares:=distribute(capacity,weights,total)
	for index in modules.size():next[modules[index]]=shares[index]
	return next

static func expand(modules: Array, allocation: Dictionary, old_capacity, new_capacity) -> Dictionary:
	var next := allocation.duplicate()
	if old_capacity==null or new_capacity==null or I.compare(old_capacity,0)<=0 or I.compare(new_capacity,old_capacity)<=0:return next
	var weights:Array=[];var assigned=0
	for key in modules:
		var amount=I.normalize(allocation.get(key,0))
		if I.compare(amount,I.subtract(old_capacity,assigned))>0:return next
		weights.append(amount);assigned=I.add(assigned,amount)
	weights.append(I.subtract(old_capacity,assigned)) # Idle is a real share.
	var shares:=distribute(I.subtract(new_capacity,old_capacity),weights,old_capacity)
	for index in modules.size():next[modules[index]]=I.add(weights[index],shares[index])
	return next
