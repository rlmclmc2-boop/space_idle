class_name GrowthNumber
extends RefCounted
const ReactorInt := preload("res://scripts/reactor_integer.gd")
## Ordinary values stay floats. Large values use a JSON-safe mantissa/exponent.
## Binary64 precision; exponent arithmetic avoids expanding a resource into digits.
## Reactor allocation integers enter only through the explicit from_integer projection.
static func valid(value) -> bool:
	if value is int or value is float:return is_finite(float(value)) and value>=0
	return value is Dictionary and value.size()==2 and value.has("m") and value.has("e") and (value.m is float or value.m is int) and (value.e is float or value.e is int) and is_finite(float(value.m)) and is_finite(float(value.e)) and float(value.m)>=1 and float(value.m)<10 and float(value.e)==floorf(float(value.e))

static func parts(value) -> Array:
	if value is Dictionary:return [float(value.m),float(value.e)]
	var n := float(value)
	if n==0:return [0.0,0.0]
	var exponent := floorf(log(absf(n))/log(10.0))
	var m := (n*1e300)/pow(10,exponent+300.0) if exponent < -300.0 else n/pow(10,exponent)
	if m>=10.0:m/=10.0;exponent+=1.0
	elif m<1.0:m*=10.0;exponent-=1.0
	return [m,exponent]

static func normalize(value: Variant) -> Variant:
	return make(float(value.m),float(value.e)) if value is Dictionary else float(value)

static func from_integer(value: Variant) -> Variant:
	# Allocation/capacity retain their integer owner and exact save contract.
	# Combat ratios and displayed growth consume only a bounded projection.
	if not value is Dictionary:return float(value)
	assert(ReactorInt.valid(value))
	var digits: String=value.i
	var count:=mini(16,digits.length())
	return make(float(digits.substr(0,count))/pow(10.0,count-1),float(digits.length()-1))

static func make(m: float, e: float):
	if m==0:return 0.0
	var shift := floorf(log(absf(m))/log(10.0))
	m /= pow(10,shift)
	e += shift
	if m>=10.0:m/=10.0;e+=1.0
	elif m<1.0:m*=10.0;e-=1.0
	if e<300 and e> -300:return m*pow(10,e)
	return {"m":m,"e":e}

static func add(a,b):
	if compare(a,0)==0:return normalize(b)
	if compare(b,0)==0:return normalize(a)
	if not a is Dictionary and not b is Dictionary:
		var sum := float(a)+float(b)
		if is_finite(sum):return sum
	var x := parts(a)
	var y := parts(b)
	var e := maxf(x[1],y[1])
	return make(x[0]*pow(10,x[1]-e)+y[0]*pow(10,y[1]-e),e)

static func subtract(a,b):
	if compare(a,b)<=0:return 0.0
	if not a is Dictionary and not b is Dictionary:return float(a)-float(b)
	var x := parts(a)
	var y := parts(b)
	return make(x[0]-y[0]*pow(10,y[1]-x[1]),x[1])

static func multiply(a,b):
	if not a is Dictionary and not b is Dictionary:
		var product := float(a)*float(b)
		if is_finite(product):return product
	var x := parts(a)
	var y := parts(b)
	return make(x[0]*y[0],x[1]+y[1])

static func divide(a,b):
	if compare(b,0)==0:return 0.0
	if not a is Dictionary and not b is Dictionary:
		var quotient := float(a)/float(b)
		if is_finite(quotient):return quotient
	var x := parts(a)
	var y := parts(b)
	return make(x[0]/y[0],x[1]-y[1])

static func power(a, exponent: float):
	if exponent==0:return 1.0
	if compare(a,0)==0:return 0.0
	if not a is Dictionary:
		var result := pow(float(a),exponent)
		if is_finite(result):return result
	var p := parts(a)
	var logarithm: float = (log(p[0])/log(10.0)+p[1])*exponent
	return make(pow(10,logarithm-floorf(logarithm)),floorf(logarithm))

static func compare(a,b) -> int:
	if not a is Dictionary and not b is Dictionary:return 0 if float(a)==float(b) else (1 if float(a)>float(b) else -1)
	var x := parts(a)
	var y := parts(b)
	if x[0]==0:return 0 if y[0]==0 else -1
	if y[0]==0:return 1
	if x[1]!=y[1]:return 1 if x[1]>y[1] else -1
	return 0 if x[0]==y[0] else (1 if x[0]>y[0] else -1)

static func minimum(a,b):return a if compare(a,b)<=0 else b
static func maximum(a,b):return a if compare(a,b)>=0 else b
static func ceiling(a):return (1.0 if a.e<0 else a) if a is Dictionary else ceilf(float(a))
static func ratio(a,b) -> float:
	var value = divide(a,b)
	return float(value) if not value is Dictionary else (0.0 if value.e<0 else 1.0)
static func text(a) -> String:
	return "%.2fe+%.0f" % [a.m,a.e] if a is Dictionary else NumberFormat.plain(float(a))

static func logarithm(a) -> float:
	if compare(a,0)<=0:return 0.0
	var p := parts(a)
	return log(p[0])/log(10.0)+p[1]

static func signed_difference(a,b) -> String:
	return ("+" if compare(a,b)>=0 else "-")+text(subtract(maximum(a,b),minimum(a,b)))
