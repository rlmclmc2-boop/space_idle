class_name ReactorInteger
extends RefCounted
## Exact, nonnegative decimal integers for reactor capacity and allocation.
## Ordinary values remain Godot ints. The tagged form survives JSON unchanged.
const MAX_INT := "9223372036854775807"

static func valid(value: Variant) -> bool:
	if value is int:return value >= 0
	return value is Dictionary and value.size() == 2 and value.has("v") and (value.v is int or value.v is float) and value.v==1 and value.has("i") and value.i is String and _canonical(value.i) and _cmp_digits(value.i,"9007199254740991")>0

static func _canonical(s: String) -> bool:
	if s.is_empty() or (s.length()>1 and s[0]=="0"):return false
	for c in s:
		if c<"0" or c>"9":return false
	return true

static func digits(value: Variant) -> String:
	return value.i if value is Dictionary else str(value)

static func make(s: String) -> Variant:
	var n := s.lstrip("0")
	if n.is_empty():n="0"
	return int(n) if _cmp_digits(n,MAX_INT)<=0 else {"v":1,"i":n}

static func encode(value: Variant) -> Variant:
	return {"v":1,"i":digits(value)} if compare(value,9007199254740991)>0 else value

static func _cmp_digits(a: String,b: String) -> int:
	if a.length()!=b.length():return 1 if a.length()>b.length() else -1
	return 0 if a==b else 1 if a>b else -1

static func compare(a: Variant,b: Variant) -> int:
	return _cmp_digits(digits(a),digits(b))

static func minimum(a: Variant,b: Variant) -> Variant:
	return a if compare(a,b)<=0 else b

static func maximum(a: Variant,b: Variant) -> Variant:
	return a if compare(a,b)>=0 else b

static func command_floor(value: Variant) -> Variant:
	if valid(value):return {"v":1,"i":value.i} if value is Dictionary else value
	if not (value is int or value is float) or not is_finite(float(value)):return null
	if value<=0:return 0
	return float_floor(float(value))

static func float_floor(value: float) -> Variant:
	# Read the IEEE-754 payload so a finite command above 2^63 is rounded
	# according to its actual binary value, not its shortest printed decimal.
	if value<=0:return 0
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	var bits: int=bytes.decode_u64(0)
	var exponent: int=(bits>>52)&2047
	var mantissa: int=bits&4503599627370495
	var shift: int=-1074 if exponent==0 else exponent-1023-52
	if exponent!=0:mantissa+=4503599627370496
	var result: Variant=mantissa
	if shift>=0:
		var factor: Variant=2
		while shift>0:
			if shift%2==1:result=multiply(result,factor)
			shift/=2
			if shift>0:factor=multiply(factor,factor)
	else:
		for index in -shift:
			result=div_small(result,2)[0]
			if compare(result,0)==0:break
	return result

static func add(a: Variant,b: Variant) -> Variant:
	var x := digits(a);var y := digits(b);var carry := 0;var out := PackedStringArray()
	for k in range(maxi(x.length(),y.length())):
		var u := x.length()-1-k;var v := y.length()-1-k
		var sum := carry+(x.unicode_at(u)-48 if u>=0 else 0)+(y.unicode_at(v)-48 if v>=0 else 0)
		out.append(char(48+sum%10));carry=sum/10
	if carry>0:out.append("1")
	out.reverse()
	return make("".join(out))

static func subtract(a: Variant,b: Variant) -> Variant:
	assert(compare(a,b)>=0)
	var x := digits(a);var y := digits(b);var borrow := 0;var out := PackedStringArray()
	for k in x.length():
		var u := x.length()-1-k;var v := y.length()-1-k
		var d := x.unicode_at(u)-48-(y.unicode_at(v)-48 if v>=0 else 0)-borrow
		borrow=1 if d<0 else 0
		out.append(char(48+d+10*borrow))
	out.reverse()
	return make("".join(out))

static func multiply(a: Variant,b: Variant) -> Variant:
	var x := digits(a);var y := digits(b)
	if x=="0" or y=="0":return 0
	var slots := PackedInt32Array();slots.resize(x.length()+y.length())
	for i in range(x.length()-1,-1,-1):
		for j in range(y.length()-1,-1,-1):
			var at := i+j+1
			var n := slots[at]+(x.unicode_at(i)-48)*(y.unicode_at(j)-48)
			slots[at]=n%10;slots[at-1]+=n/10
	var out := PackedStringArray()
	for n in slots:out.append(str(n))
	return make("".join(out))

static func div_small(a: Variant,denominator: int) -> Array:
	assert(denominator>0)
	var carry := 0;var out := PackedStringArray()
	for c in digits(a):
		var n := carry*10+c.unicode_at(0)-48
		out.append(str(n/denominator));carry=n%denominator
	return [make("".join(out)),carry]

static func decimal_factor(value: float) -> Array:
	# String.num_scientific retains enough binary64 digits for the overflow
	# calculation; this is separate from the old ordinary-domain float path.
	assert(is_finite(value) and value>=0.0)
	var s := String.num_scientific(value).to_lower()
	var fields := s.split("e");var power := int(fields[1]) if fields.size()>1 else 0
	var coefficient := fields[0];var point := coefficient.find(".")
	var fractional := coefficient.length()-point-1 if point>=0 else 0
	var raw := coefficient.replace(".","")
	return [make(raw),fractional-power]

static func to_float(value: Variant) -> float:
	var s := digits(value)
	return float(s) if s.length()<300 else float(s.substr(0,17))*pow(10.0,s.length()-17)

static func _decimal_product(factors: Array, growth: float, exponent: int) -> Array:
	var mantissa: Variant=1;var scale := 0
	for factor in factors:
		var part := decimal_factor(float(factor))
		mantissa=multiply(mantissa,part[0]);scale+=int(part[1])
	var base := decimal_factor(growth)
	var count := exponent
	while count>0:
		if count%2==1:
			mantissa=multiply(mantissa,base[0]);scale+=int(base[1])
		count/=2
		if count>0:
			base=[multiply(base[0],base[0]),int(base[1])*2]
	return [mantissa,scale]

static func _integral(product: Array,up: bool) -> Variant:
	var s := digits(product[0]);var scale := int(product[1])
	if scale<=0:return make(s+"0".repeat(-scale))
	if scale>=s.length():return 1 if up and s!="0" else 0
	var cut := s.length()-scale
	var whole: Variant=make(s.substr(0,cut))
	return add(whole,1) if up and s.substr(cut).lstrip("0")!="" else whole

static func formula_floor(factors: Array,growth: float,exponent: int) -> Variant:
	return _integral(_decimal_product(factors,growth,exponent),false)
