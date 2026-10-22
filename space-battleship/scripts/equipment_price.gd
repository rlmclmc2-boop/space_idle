extends RefCounted

class Costs extends RefCounted:
	var status: String
	var amounts: Dictionary
	func _init(state: String, costs: Dictionary = {}) -> void:
		status = state
		amounts = costs

func costs_for_level(database: RefCounted, key: String, level: int) -> Costs:
	if level < 1:
		return Costs.new("invalid_level")
	for row in database.equipment.get(key, []):
		if int(row.get("level", 0)) != 1:
			continue
		var amounts := {}
		for field in row:
			if not str(field).begins_with("res_") or row[field] == null:
				continue
			var suffix: String = str(field).trim_prefix("res_")
			var base: Variant = row.get("cost_" + suffix)
			if base == null:
				continue
			if not (base is int or base is float) or not is_finite(float(base)) or base < 0:
				return Costs.new("invalid_price")
			var multiplier: Variant = row.get("cost_multi_" + suffix, row.get("costMulti_" + suffix))
			var result: Ledger.Outcome = Ledger.decode(I.float_floor(ceilf(float(base)))) if multiplier == null else quote(float(base), float(multiplier), level)
			if result.status != "ok":
				return Costs.new(result.status)
			amounts[str(int(row[field]))] = Ledger.encode(result.value)
		var interval: int = int(database.data.equipment_evolution.interval)
		if interval <= 0:
			return Costs.new("invalid_material_config")
		if level >= interval and level % interval == 0:
			var due: Variant = I.multiply(int(database.data.equipment_evolution.material_cost_per_tier), level / interval)
			if I.compare(due, I.make(I.MAX_INT)) > 0:
				return Costs.new("material_transport")
			amounts[database.evolution_material_id()] = int(I.digits(due))
		return Costs.new("ok", amounts)
	return Costs.new("missing_cost_row")

func sum_costs(database: RefCounted, key: String, current: int, count: int) -> Costs:
	if current < 1 or count < 1 or count > 9223372036854775807-current:
		return Costs.new("invalid_level_range")
	if count>256 and _bounded_family(database,key):return _bounded_sum(database,key,current,count)
	var amounts := {}
	var material_id: String = database.evolution_material_id()
	for offset in count:
		var quoted: Costs = costs_for_level(database, key, current + offset + 1)
		if quoted.status != "ok":
			return quoted
		for id in quoted.amounts:
			if id == material_id:
				var total: Variant = I.add(amounts.get(id, 0), quoted.amounts[id])
				if I.compare(total, I.make(I.MAX_INT)) > 0:
					return Costs.new("material_transport")
				amounts[id] = int(I.digits(total))
			else:
				var before: Ledger.Outcome = Ledger.decode(amounts.get(id, 0))
				var price: Ledger.Outcome = Ledger.decode(quoted.amounts[id])
				var total: Ledger.Outcome = Ledger.add(before.value, price.value)
				if total.status != "ok":
					return Costs.new(total.status)
				amounts[id] = Ledger.encode(total.value)
	return Costs.new("ok", amounts)

func _bounded_family(database:RefCounted,key:String)->bool:
	var rows:Array=database.equipment.get(key,[])
	if rows.size()!=1:return false
	var row:Dictionary=rows[0]
	return row.get("cost_1")==50 and row.get("cost_multi_1",row.get("costMulti_1"))==0.2 and row.get("res_1")==1 and row.get("cost_2")==null and row.get("res_2")==null and database.data.equipment_evolution.interval==20 and database.data.equipment_evolution.material_cost_per_tier==10

func _bounded_sum(database:RefCounted,_key:String,current:int,count:int)->Costs:
	var last:int=current+count
	var upper:int=last/20;var lower:int=current/20
	var a:Variant=I.div_small(I.multiply(upper,upper+1),2)[0]
	var b:Variant=I.div_small(I.multiply(lower,lower+1),2)[0]
	var material:Variant=I.multiply(I.subtract(a,b),10)
	if I.compare(material,I.make(I.MAX_INT))>0:return Costs.new("material_transport")
	var window:=72
	var omitted:int=count-window
	var engine=preload("res://scripts/equipment_price_bounds.gd").new(24)
	var power:Dictionary=engine.power_and_series(last-window)
	var running:Array=engine._interval_mul(power.power,engine._point([50,0]))
	var omitted_upper:Array=engine._mul(running[1],[525,-2],true)
	var factor:Array=engine._point(engine.growth)
	var total_units:=0
	var unit_shift:=0
	for offset in window:
		var level:int=last-window+offset+1
		var amount:Ledger.Outcome
		if is_finite(50.0*pow(1.2,level-1)):amount=quote(50.0,0.2,level)
		else:
			var low:Array=rounded_bound(running[0]);var high:Array=rounded_bound(running[1])
			amount=Ledger.from_price_integer(low[0],str(low[1])) if low==high else quote(50.0,0.2,level)
		if amount.status!="ok":return Costs.new(amount.status)
		# The last72 fixed-family rounded prices span at most seven decades.
		# Fold their nine-digit main coefficients in int64; each discarded
		# residual is at most 5e-9 relative, well inside the reserved budget.
		var component:Dictionary=Ledger.encode(amount.value).main
		var coefficient:int=int(component.c)
		var shift:int=int(component.e)-8
		while coefficient%10==0:coefficient/=10;shift+=1
		if offset==0:unit_shift=shift
		if shift<unit_shift:
			var delta:int=unit_shift-shift
			if delta>8:return Costs.new("sum_error_budget")
			total_units*=int(pow(10.0,delta));unit_shift=shift
		var difference:int=shift-unit_shift
		if difference>8:return Costs.new("sum_error_budget")
		total_units+=coefficient*int(pow(10.0,difference))
		running=engine._interval_mul(running,factor)
	var total:Ledger.Value=Ledger.from_price_integer(total_units,str(unit_shift)).value
	# Omitted original-rule prices are bounded separately; MAX U is never a
	# refund oracle. Reserve five parts per million for this discarded tail.
	var tail:Ledger.Value=Ledger.decode(engine.encoded_integer(omitted_upper,true)).value
	var low_branch:Ledger.Value=Ledger.from_price_integer(I.multiply(omitted,10),"0",1).value
	tail=Ledger.add_directed(tail,low_branch,1).value
	if not Ledger.tail_within_budget(tail,total):return Costs.new("sum_error_budget")
	var amounts:Dictionary={"1":Ledger.encode(total)}
	if I.compare(material,0)>0:amounts[database.evolution_material_id()]=int(I.digits(material))
	return Costs.new("ok",amounts)

## Single-level prices retain the main ordinary branches and P1 bounded overflow rule.
const Ledger = preload("res://scripts/currency_ledger.gd")

const I = preload("res://scripts/currency_integer.gd")

func trim_bound(coefficient: Variant, exponent: int, precision: int, up: bool) -> Array:
	var digits: String = I.digits(coefficient)
	if digits.length() <= precision:
		return [coefficient, exponent]
	var cut := digits.length() - precision
	var kept = I.make(digits.substr(0, precision))
	if up and digits.substr(precision).lstrip("0") != "":
		kept = I.add(kept, 1)
	return [kept, exponent + cut]

func multiply_bound(a: Array, b: Array, precision: int, up: bool) -> Array:
	return trim_bound(I.multiply(a[0], b[0]), int(a[1]) + int(b[1]), precision, up)

func rounded_bound(bound: Array) -> Array:
	var digits: String = I.digits(bound[0])
	var magnitude := digits.length() + int(bound[1]) - 1
	if magnitude < 2:
		return [int(digits.substr(0,1)) * 10 + 5 if magnitude == 1 else 5, 0]
	var step_power := magnitude - 1
	var shift := int(bound[1]) - step_power
	var shifted: String = digits + "0".repeat(shift) if shift >= 0 else digits
	var whole_length := shifted.length() + mini(shift, 0)
	var leading := int(shifted.substr(0, maxi(0, whole_length)))
	if shift < 0 and whole_length >= 0 and whole_length < shifted.length() and shifted[whole_length] >= "5":
		leading += 1
	return [leading, step_power]

func bounded_large(base: float, growth: float, level: int, direction:int=0) -> Variant:
	var base_part: Array = I.decimal_factor(base)
	var growth_part: Array = I.decimal_factor(growth)
	for precision in [16,24,32,48,96,192,384]:
		var lower: Array = [1,0]
		var upper: Array = [1,0]
		var low_power: Array = [growth_part[0], -int(growth_part[1])]
		var high_power: Array = low_power.duplicate()
		var count := level - 1
		while count > 0:
			if count % 2 == 1:
				lower = multiply_bound(lower, low_power, precision, false)
				upper = multiply_bound(upper, high_power, precision, true)
			count /= 2
			if count > 0:
				low_power = multiply_bound(low_power, low_power, precision, false)
				high_power = multiply_bound(high_power, high_power, precision, true)
		lower = multiply_bound(lower, [base_part[0], -int(base_part[1])], precision, false)
		upper = multiply_bound(upper, [base_part[0], -int(base_part[1])], precision, true)
		var low_rounded := rounded_bound(lower)
		var high_rounded := rounded_bound(upper)
		if low_rounded == high_rounded:
			return Ledger.from_price_integer(low_rounded[0], str(low_rounded[1]),direction)
	return null

# This audit-only prototype takes the immutable main decimal-factor primitive
# as input. It applies S09's low/zero/high branch before the final integer.
func quote(base: float, multiplier: float, level: int, direction:int=0) -> Ledger.Outcome:
	if level < 1 or base < 0.0 or not is_finite(base) or multiplier <= -1.0 or not is_finite(multiplier):
		return Ledger.Outcome.new("invalid_price")
	if base == 0.0:
		return Ledger.decode(0)
	if level == 1:
		return Ledger.from_price_integer(I.float_floor(ceilf(base)),"0",direction)
	var growth := 1.0 + multiplier
	var ordinary := base * pow(growth, level - 1)
	if is_finite(ordinary):
		if ordinary <= 0.0:
			return Ledger.decode(0)
		if ordinary < 100.0:
			return Ledger.from_price_integer(I.float_floor(ceilf(floorf(ordinary / 10.0) * 10.0 + 5.0)),"0",direction)
		var step := pow(10.0, floorf(log(ordinary) / log(10.0) + 1e-12) - 1.0)
		return Ledger.from_price_integer(I.float_floor(ceilf(floorf(ordinary / step + 0.5) * step)),"0",direction)
	var bounded = bounded_large(base, growth, level,direction)
	if bounded != null:
		return bounded
	var cursor: Array = I.cost_cursor(base, growth, level - 1)
	var digits: String = I.digits(cursor[0])
	var magnitude: int = digits.length() - int(cursor[1]) - 1
	if magnitude < 2:
		# floor(value/10)*10+5, even when pow overflowed before the
		# subnormal base brought the final mathematical price below 100.
		var tens = I._integral([cursor[0], int(cursor[1]) + 1], false)
		return Ledger.from_price_integer(I.add(I.multiply(tens, 10), 5),"0",direction)
	var step_power := magnitude - 1
	var leading := int(digits.substr(0, 2))
	if digits.length() > 2 and digits[2] >= "5":
		leading += 1
	return Ledger.from_price_integer(leading, str(step_power),direction)


