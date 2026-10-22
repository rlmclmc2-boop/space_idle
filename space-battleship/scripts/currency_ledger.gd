extends RefCounted
## Resource-only immutable-value boundary. Internal arrays never enter profile/JSON.
## Arithmetic helpers extracted from the reviewed P1 arbitrary-position core.
const I = preload("res://scripts/currency_integer.gd")
const RADIX := 10000
static var _issuer := RefCounted.new()

class Value extends RefCounted:
	var _terms: Array
	var _owner: RefCounted
	func _init(terms: Array, owner: RefCounted) -> void:
		_terms = terms.duplicate(true)
		_owner = owner

class Outcome extends RefCounted:
	var status: String
	var value: Value
	func _init(state: String, result: Value = null) -> void:
		status = state
		value = result

class Comparison extends RefCounted:
	var status: String
	var order: int
	func _init(state: String, result: int = 0) -> void:
		status = state
		order = result

class FiniteProjection extends RefCounted:
	var status: String
	var amount: float
	func _init(state: String, result: float = 0.0) -> void:
		status = state
		amount = result

static func _value(terms: Array) -> Value:
	return Value.new(terms, _issuer)

static func _checked(value: Value) -> bool:
	if value == null or not is_same(value._owner, _issuer):
		return false
	return value._terms.is_empty() or _core_valid({"v":3,"blocks":value._terms})

static func _legacy_valid(raw: Variant) -> bool:
	if raw is int or raw is float:
		return is_finite(float(raw)) and raw >= 0
	if raw is Dictionary and raw.has("i"):
		return I.valid(raw)
	return raw is Dictionary and raw.size() == 2 and raw.has("m") and raw.has("e") and (raw.m is int or raw.m is float) and (raw.e is int or raw.e is float) and is_finite(float(raw.m)) and is_finite(float(raw.e)) and raw.m >= 1 and raw.m < 10 and float(raw.e) == floorf(float(raw.e))

static func storage_valid(raw: Variant) -> bool:
	if not (raw is Dictionary and raw.size() == 2 and raw.has("currency_version") and raw.has("blocks")):
		return false
	if not (raw.currency_version is int or raw.currency_version is float) or raw.currency_version != 1 or not raw.blocks is Array:
		return false
	return raw.blocks.is_empty() or _core_valid({"v":3,"blocks":raw.blocks})

static func decode(raw: Variant) -> Outcome:
	var terms: Variant
	if storage_valid(raw):
		terms = raw.blocks.duplicate(true)
	elif raw is Dictionary and raw.has("currency_version"):
		return Outcome.new("invalid_storage")
	elif I.valid(raw):
		terms = _from_digits(I.digits(raw), "0")
	elif raw is float and is_finite(raw) and raw >= 0.0:
		terms = _float_decimal(raw)
	elif raw is Dictionary and raw.has("m") and _legacy_valid(raw):
		var exponent: float = float(raw.e)
		var e: String = ("-" if exponent < 0.0 else "") + I.digits(I.float_floor(absf(exponent)))
		var part: Array = I.decimal_factor(float(raw.m))
		terms = _from_digits(I.digits(part[0]), _signed_integer(e, str(int(part[1])), true))
	else:
		return Outcome.new("invalid_input")
	terms = _normalized(terms)
	return Outcome.new("ok", _value(terms)) if _positive(terms) else Outcome.new("negative_value")

static func from_generated_income(raw: Variant) -> Outcome:
	# Generated source values keep their existing domain; no display projection.
	if not _legacy_valid(raw):
		return Outcome.new("invalid_income")
	return decode(raw)

static func from_price_integer(coefficient: Variant, decimal_shift: String) -> Outcome:
	if not I.valid(coefficient) or not _position_valid(decimal_shift):
		return Outcome.new("invalid_price")
	return Outcome.new("ok", _value(_normalized(_from_digits(I.digits(coefficient), decimal_shift))))

static func encode(value: Value) -> Dictionary:
	if not _checked(value):
		return {"error":"invalid_value"}
	return {"currency_version":1,"blocks":value._terms.duplicate(true)}

static func compare(a: Value, b: Value) -> Comparison:
	if not _checked(a) or not _checked(b):
		return Comparison.new("invalid_value")
	var difference: Array = _signed_sum(a._terms, b._terms, true)
	return Comparison.new("ok", 0 if difference.is_empty() else (1 if _positive(difference) else -1))

static func add(a: Value, b: Value) -> Outcome:
	if not _checked(a) or not _checked(b):
		return Outcome.new("invalid_value")
	return Outcome.new("ok", _value(_signed_sum(a._terms, b._terms)))

static func subtract(a: Value, b: Value) -> Outcome:
	if not _checked(a) or not _checked(b):
		return Outcome.new("invalid_value")
	var difference: Array = _signed_sum(a._terms, b._terms, true)
	return Outcome.new("ok", _value(difference)) if _positive(difference) else Outcome.new("insufficient")

static func finite_research_balance(value: Value, finite_upper: float) -> FiniteProjection:
	if not _checked(value) or not is_finite(finite_upper) or finite_upper < 0.0:
		return FiniteProjection.new("invalid_value")
	var limit: Outcome = decode(finite_upper)
	var relation: Comparison = compare(value, limit.value)
	if relation.status != "ok" or relation.order > 0:
		return FiniteProjection.new("not_finite_shortage")
	# All binary64 rounding midpoints have a terminating decimal expansion
	# shorter than this projection window. A signed sticky unit distinguishes
	# a distant tail at a midpoint without expanding its exponent gap.
	var scaled := "0"
	var tail_sign := 0
	for term in value._terms:
		if _position_compare(term.p, "-300") < 0:
			tail_sign = 1 if int(term.d) > 0 else -1
			continue
		if _position_compare(term.p, "77") > 0:
			return FiniteProjection.new("out_of_domain")
		var shift: int = int(term.p) * 4 + 1200
		var digits: String = str(absi(int(term.d))) + "0".repeat(shift)
		scaled = _signed_integer(scaled, ("-" if int(term.d) < 0 else "") + digits)
	if tail_sign != 0:
		scaled = _signed_integer(scaled, str(tail_sign))
	if scaled.begins_with("-"):
		return FiniteProjection.new("ok") # Positive value below the projection window.
	var padded: String = "0".repeat(maxi(0, 1201-scaled.length())) + scaled
	var decimal: String = padded.substr(0, padded.length()-1200) + "." + padded.substr(padded.length()-1200)
	var amount: float = float(decimal)
	return FiniteProjection.new("ok", amount) if is_finite(amount) and amount >= 0.0 else FiniteProjection.new("out_of_domain")

static func text(value: Value) -> String:
	if not _checked(value):
		return "invalid"
	if value._terms.is_empty():
		return "0"
	var front: Array = _front(value._terms)
	var highest: String = value._terms[-1].p
	var magnitude = I.multiply(I.make(highest.substr(1) if highest.begins_with("-") else highest), 4)
	var exponent: String = _signed_integer(("-" if highest.begins_with("-") else "") + I.digits(magnitude), str(int(front[1])))
	return "%.2fe%s" % [front[0], exponent if exponent.begins_with("-") else "+" + exponent]

static func exact_text(value: Value) -> String:
	if not _checked(value):return "invalid"
	if value._terms.is_empty():return "0"
	var terms:=PackedStringArray()
	for index in range(value._terms.size()-1,-1,-1):
		var term:Dictionary=value._terms[index]
		var exponent:String=_signed_integer(str(term.p),str(term.p))
		exponent=_signed_integer(exponent,exponent)
		var body:String=str(absi(int(term.d)))
		if exponent!="0":body+=" × 10^("+exponent+")"
		terms.append(("- " if int(term.d)<0 else ("+ " if not terms.is_empty() else ""))+body)
	return " ".join(terms)

static func analysis_value(raw: Variant) -> FiniteProjection:
	var decoded: Outcome = decode(raw)
	if decoded.status!="ok":return FiniteProjection.new(decoded.status)
	var projected: FiniteProjection = finite_research_balance(decoded.value,1.7976931348623157e308)
	if projected.status=="ok" and projected.amount==0.0 and compare(decoded.value,decode(0).value).order>0:
		return FiniteProjection.new("out_of_domain")
	return projected if projected.status=="ok" else FiniteProjection.new("out_of_domain")

static func _position_valid(s:String)->bool:
	if s.is_empty() or s=="-0":return false
	var start:=1 if s.begins_with("-") else 0
	if start==s.length() or (s.length()-start>1 and s[start]=="0"):return false
	for index in range(start,s.length()):
		if s[index]<"0" or s[index]>"9":return false
	return true

static func _position_compare(a:String,b:String)->int:
	if a==b:return 0
	var na:=a.begins_with("-");var nb:=b.begins_with("-")
	if na!=nb:return -1 if na else 1
	var x:=a.substr(1) if na else a
	var y:=b.substr(1) if nb else b
	var order:=I.compare(I.make(x),I.make(y))
	return -order if na else order

static func _signed_integer(a:String,b:String,negative_b:bool=false)->String:
	var a_neg:=a.begins_with("-");var b_neg:=b.begins_with("-")!=negative_b
	var x:Variant=I.make(a.substr(1) if a_neg else a)
	var y:Variant=I.make(b.substr(1) if b.begins_with("-") else b)
	if a_neg==b_neg:
		var sum=I.add(x,y)
		return ("-" if a_neg and I.compare(sum,0)>0 else "")+I.digits(sum)
	var order:=I.compare(x,y)
	if order==0:return "0"
	var result=I.subtract(x,y) if order>0 else I.subtract(y,x)
	return ("-" if (a_neg if order>0 else b_neg) else "")+I.digits(result)

static func _shift_group(shift:String)->Array:
	var negative:=shift.begins_with("-")
	var divided:=I.div_small(I.make(shift.substr(1) if negative else shift),4)
	var quotient:String=I.digits(divided[0])
	var remainder:int=int(divided[1])
	if not negative:return [quotient,remainder]
	if remainder==0:return ["-"+quotient if quotient!="0" else "0",0]
	return ["-"+I.digits(I.add(divided[0],1)),4-remainder]

static func _from_digits(digits:String,shift:String)->Array:
	var group:=_shift_group(shift)
	var padded:=digits+"0".repeat(int(group[1]))
	var blocks:Array=[]
	var position:String=group[0]
	for index in range(padded.length(),0,-4):
		var start:=maxi(0,index-4)
		var digit:=int(padded.substr(start,index-start))
		if digit!=0:blocks.append({"p":position,"d":digit})
		position=_signed_integer(position,"1")
	return blocks

static func _normalized(terms:Array)->Array:
	var by_position:Dictionary={}
	for term in terms:
		var position:String=term.p
		by_position[position]=int(by_position.get(position,0))+int(term.d)
	var positions:Array=by_position.keys()
	positions.sort_custom(func(a,b):return _position_compare(a,b)<0)
	var index:=0
	while index<positions.size():
		var position:String=positions[index]
		var digit:int=int(by_position[position])
		var carry:int=floori(float(digit+5000)/float(RADIX))
		digit-=carry*RADIX
		by_position[position]=digit
		if carry!=0:
			var next:String=_signed_integer(position,"1")
			if not by_position.has(next):
				positions.insert(index+1,next)
				by_position[next]=0
			by_position[next]=int(by_position[next])+carry
		index+=1
	var result:Array=[]
	for position in positions:
		if int(by_position[position])!=0:result.append({"p":position,"d":int(by_position[position])})
	return result

static func _signed_sum(a:Array,b:Array,negative_b:bool=false)->Array:
	var terms:=a.duplicate(true)
	for block in b:terms.append({"p":block.p,"d":-int(block.d) if negative_b else int(block.d)})
	return _normalized(terms)

static func _positive(blocks:Array)->bool:return blocks.is_empty() or int(blocks[-1].d)>0
static func _encode(blocks:Array)->Variant:return 0 if blocks.is_empty() else {"v":3,"blocks":blocks}

static func _core_valid(value:Variant)->bool:
	if not (value is Dictionary and value.size()==2 and value.has("v") and value.v==3 and value.has("blocks") and value.blocks is Array):return false
	var blocks:Array=value.blocks
	if blocks.is_empty():return false
	var previous:String=""
	for block in blocks:
		if not (block is Dictionary and block.size()==2 and block.has("p") and block.p is String and _position_valid(block.p) and block.has("d") and (block.d is int or block.d is float)):return false
		if not is_finite(float(block.d)) or float(block.d)!=floorf(float(block.d)) or block.d< -5000 or block.d>4999 or block.d==0:return false
		if previous!="" and _position_compare(previous,block.p)>=0:return false
		previous=block.p
	return int(blocks[-1].d)>0

static func _float_integer(value:float)->Variant:
	return I.float_floor(value)

static func _float_decimal(value:float)->Array:
	if value==0.0:return []
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	var bits:int=bytes.decode_u64(0)
	var exponent:int=(bits>>52)&2047
	var mantissa:int=bits&4503599627370495
	var shift:int=-1074 if exponent==0 else exponent-1023-52
	if exponent!=0:mantissa+=4503599627370496
	var coefficient:Variant=mantissa
	if shift>=0:
		for unused in shift:coefficient=I.multiply(coefficient,2)
		return _from_digits(I.digits(coefficient),"0")
	for unused in -shift:coefficient=I.multiply(coefficient,5)
	return _from_digits(I.digits(coefficient),str(shift))


static func _front(source:Array)->Array:
	var highest:Dictionary=source[-1]
	var prefix:=float(highest.d)
	for index in range(source.size()-2,-1,-1):
		var gap:String=_signed_integer(str(highest.p),str(source[index].p),true)
		if gap.length()>1 or int(gap)>6:break
		prefix+=float(source[index].d)*pow(10000.0,-int(gap))
	var local:int=int(floor(log(prefix)/log(10.0)))
	return [prefix/pow(10.0,float(local)),local]


