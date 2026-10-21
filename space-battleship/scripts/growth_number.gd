class_name GrowthNumber
extends RefCounted
const ReactorInt := preload("res://scripts/reactor_integer.gd")
## Ordinary values stay floats. Large values use a JSON-safe mantissa/exponent.
## No gameplay cap: exponent arithmetic replaces overflowing float products.
static func valid(value) -> bool:
	if value is int or value is float:return is_finite(float(value)) and value>=0
	if value is Dictionary and value.has("i"):return ReactorInt.valid(value)
	return value is Dictionary and value.size()==2 and value.has("m") and value.has("e") and (value.m is float or value.m is int) and (value.e is float or value.e is int) and is_finite(float(value.m)) and is_finite(float(value.e)) and float(value.m)>=1 and float(value.m)<10 and float(value.e)==floorf(float(value.e))

static func parts(value) -> Array:
	if value is Dictionary and value.has("i"):
		var s: String=value.i
		return [float(s.substr(0,mini(16,s.length())))/pow(10.0,mini(16,s.length())-1),float(s.length()-1)]
	if value is Dictionary:return [float(value.m),float(value.e)]
	var n := float(value)
	if n==0:return [0.0,0.0]
	var exponent := floorf(log(absf(n))/log(10.0))
	return [n/pow(10,exponent),exponent]

static func make(m: float, e: float):
	if m==0:return 0.0
	var shift := floorf(log(absf(m))/log(10.0))
	m /= pow(10,shift)
	e += shift
	if e<300 and e> -300:return m*pow(10,e)
	return {"m":m,"e":e}

static func add(a,b):
	if a is Dictionary or b is Dictionary:
		var ai=ReactorInt.from_growth(a);var bi=ReactorInt.from_growth(b)
		if ai!=null and bi!=null:return ReactorInt.add(ai,bi)
	if compare(a,0)==0:return b
	if compare(b,0)==0:return a
	if not a is Dictionary and not b is Dictionary:
		var sum := float(a)+float(b)
		if is_finite(sum):return sum
	var x := parts(a)
	var y := parts(b)
	var e := maxf(x[1],y[1])
	return make(x[0]*pow(10,x[1]-e)+y[0]*pow(10,y[1]-e),e)

static func subtract(a,b):
	if a is Dictionary or b is Dictionary:
		var ai=ReactorInt.from_growth(a);var bi=ReactorInt.from_growth(b)
		if ai!=null and bi!=null:return ReactorInt.subtract(ai,bi) if ReactorInt.compare(ai,bi)>0 else 0
	if compare(a,b)<=0:return 0.0
	if not a is Dictionary and not b is Dictionary:return float(a)-float(b)
	var x := parts(a)
	var y := parts(b)
	return make(x[0]-y[0]*pow(10,y[1]-x[1]),x[1])

static func multiply(a,b):
	if a is Dictionary or b is Dictionary:
		var ai=ReactorInt.from_growth(a);var bi=ReactorInt.from_growth(b)
		if ai!=null and bi!=null:return ReactorInt.multiply(ai,bi)
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
	if a is Dictionary or b is Dictionary:
		var ai=ReactorInt.from_growth(a);var bi=ReactorInt.from_growth(b)
		if ai!=null and bi!=null:return ReactorInt.compare(ai,bi)
	if not a is Dictionary and not b is Dictionary:return 0 if a==b else (1 if a>b else -1)
	var x := parts(a)
	var y := parts(b)
	if x[0]==0:return 0 if y[0]==0 else -1
	if y[0]==0:return 1
	if x[1]!=y[1]:return 1 if x[1]>y[1] else -1
	return 0 if x[0]==y[0] else (1 if x[0]>y[0] else -1)

static func minimum(a,b):return a if compare(a,b)<=0 else b
static func maximum(a,b):return a if compare(a,b)>=0 else b
static func ceiling(a):return a if a is Dictionary and a.has("i") else (1.0 if a.e<0 else a) if a is Dictionary else ceilf(float(a))
static func ratio(a,b) -> float:
	var value = divide(a,b)
	return float(value) if not value is Dictionary else (0.0 if value.e<0 else 1.0)
static func text(a) -> String:
	if a is Dictionary and a.has("i"):
		var s: String=a.i
		return s if s.length()<=18 else "%.2fe+%d" % [parts(a)[0],s.length()-1]
	return "%.2fe+%.0f" % [a.m,a.e] if a is Dictionary else NumberFormat.plain(float(a))

static func logarithm(a) -> float:
	if compare(a,0)<=0:return 0.0
	var p := parts(a)
	return log(p[0])/log(10.0)+p[1]

static func signed_difference(a,b) -> String:
	return ("+" if compare(a,b)>=0 else "-")+text(subtract(maximum(a,b),minimum(a,b)))
