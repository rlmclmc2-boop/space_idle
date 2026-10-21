extends RefCounted
## A legacy decimal base plus a signed, exact decimal adjustment. Large gaps
## between the base exponent and adjustment never allocate intervening zeros.
const I=preload("res://scripts/reactor_integer.gd")
const MAX_PLACES:=1074 # Every finite binary64 fraction has at most 1074 binary places.

static func is_compact(value:Variant)->bool:
	return value is Dictionary and value.get("v")==2

static func legacy_valid(value:Variant)->bool:
	return value is Dictionary and value.size()==2 and value.has("m") and value.has("e") and (value.m is float or value.m is int) and (value.e is float or value.e is int) and is_finite(float(value.m)) and is_finite(float(value.e)) and float(value.m)>=1.0 and float(value.m)<10.0 and float(value.e)==floorf(float(value.e))

static func _zero()->Dictionary:return {"sign":0,"coefficient":0,"places":0}

static func _term(sign:int,coefficient:Variant,places:int)->Dictionary:
	if coefficient is float:coefficient=I.command_floor(coefficient)
	if coefficient==null:return _zero()
	if I.compare(coefficient,0)==0:return _zero()
	var digits:String=I.digits(coefficient)
	while places>0 and digits.ends_with("0"):
		digits=digits.substr(0,digits.length()-1)
		places-=1
	return {"sign":sign,"coefficient":I.make(digits),"places":places}

static func _signed_add(a:Dictionary,b:Dictionary)->Dictionary:
	if a.sign==0:return b
	if b.sign==0:return a
	var places:int=maxi(int(a.places),int(b.places))
	var x=I.multiply(a.coefficient,I.make("1"+"0".repeat(places-int(a.places))))
	var y=I.multiply(b.coefficient,I.make("1"+"0".repeat(places-int(b.places))))
	if a.sign==b.sign:return _term(int(a.sign),I.add(x,y),places)
	var order:int=I.compare(x,y)
	if order==0:return _zero()
	return _term(int(a.sign) if order>0 else int(b.sign),I.subtract(x,y) if order>0 else I.subtract(y,x),places)

static func _float_term(value:float)->Dictionary:
	if value==0.0:return _zero()
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	var bits:int=bytes.decode_u64(0)
	var exponent:int=(bits>>52)&2047
	var mantissa:int=bits&4503599627370495
	var shift:int=-1074 if exponent==0 else exponent-1023-52
	if exponent!=0:mantissa+=4503599627370496
	var coefficient:Variant=mantissa
	if shift>=0:
		for index in shift:coefficient=I.multiply(coefficient,2)
		return _term(1,coefficient,0)
	for index in -shift:coefficient=I.multiply(coefficient,5)
	return _term(1,coefficient,-shift)

static func _value_term(value:Variant)->Dictionary:
	if is_compact(value):return _term(int(value.sign),value.delta,int(value.places))
	if legacy_valid(value):return _zero()
	if I.valid(value):return _term(1,value,0)
	if value is float and is_finite(value) and value>=0.0:return _float_term(value)
	return {}

static func _legacy_adjustment(value:Dictionary)->Dictionary:
	var exponent:float=float(value.e)
	if exponent>16000000.0 or exponent< -16000000.0:return {}
	var part:Array=I.decimal_factor(float(value.m))
	var shift:int=int(exponent)-int(part[1])
	if shift>=0:return _term(1,I.make(I.digits(part[0])+"0".repeat(shift)),0)
	if -shift>16000000:return {}
	return _term(1,part[0],-shift)

static func _base(value:Variant)->Variant:
	if is_compact(value):return value.base
	return value if legacy_valid(value) else null

static func _base_compare(a:Variant,b:Variant)->int:
	if a==null:return 0 if b==null else -1
	if b==null:return 1
	if float(a.e)!=float(b.e):return 1 if float(a.e)>float(b.e) else -1
	if float(a.m)==float(b.m):return 0
	return 1 if float(a.m)>float(b.m) else -1

static func _base_scaled(base:Variant,places:int)->Variant:
	if base==null:return 0
	var part:Array=I.decimal_factor(float(base.m))
	var shift:int=int(base.e)-int(part[1])+places
	if shift<0:return null
	return I.make(I.digits(part[0])+"0".repeat(shift))

static func _compare_core(a_base:Variant,b_base:Variant,adjustment:Dictionary)->int:
	var bases:int=_base_compare(a_base,b_base)
	if bases==0:return int(adjustment.sign)
	if adjustment.sign==0 or adjustment.sign==bases:return bases
	var magnitude:float=float(I.digits(adjustment.coefficient).length()-int(adjustment.places)-1)
	var high:float=maxf(float(a_base.e) if a_base!=null else -INF,float(b_base.e) if b_base!=null else -INF)
	# A binary64 mantissa has at most 17 printed decimal digits. If the
	# smaller term is over 20 orders away, even maximal borrowing cannot win.
	if high-20.0>magnitude:return bases
	if magnitude>high+2.0:return int(adjustment.sign)
	var places:int=int(adjustment.places)
	for base in [a_base,b_base]:
		if base==null:continue
		var part:Array=I.decimal_factor(float(base.m))
		places=maxi(places,int(part[1])-int(base.e))
	var lhs=_base_scaled(a_base,places)
	var rhs=_base_scaled(b_base,places)
	if lhs==null or rhs==null:return bases # Only unreachable after the proven magnitude bounds.
	var adjusted=I.multiply(adjustment.coefficient,I.make("1"+"0".repeat(places-int(adjustment.places))))
	var left:=_signed_add(_term(1,lhs,0),_term(-1,rhs,0))
	var result:=_signed_add(left,_term(int(adjustment.sign),adjusted,0))
	return int(result.sign)

static func compare(a:Variant,b:Variant)->int:
	var a_term:=_value_term(a)
	var b_term:=_value_term(b)
	if a_term.is_empty() or b_term.is_empty():return 0
	var negative_b:=_term(-int(b_term.sign),b_term.coefficient,int(b_term.places))
	return _compare_core(_base(a),_base(b),_signed_add(a_term,negative_b))

static func valid(value:Variant)->bool:
	if not is_compact(value) or value.size()!=5 or not value.has("base") or not value.has("sign") or not value.has("delta") or not value.has("places"):return false
	if not legacy_valid(value.base) or not (value.sign is int or value.sign is float) or not is_finite(float(value.sign)) or int(value.sign) not in [-1,1] or float(value.sign)!=float(int(value.sign)):return false
	if not (value.places is int or value.places is float) or not is_finite(float(value.places)) or value.places<0 or value.places>MAX_PLACES or float(value.places)!=float(int(value.places)):return false
	if (value.delta is float or value.delta is int) and value.delta>9007199254740991:return false
	var coefficient=I.command_floor(value.delta)
	if coefficient==null or I.compare(coefficient,0)==0:return false
	if value.places>0 and I.digits(coefficient).ends_with("0"):return false
	return _compare_core(value.base,null,_term(int(value.sign),coefficient,int(value.places)))>0

static func make(base:Dictionary,adjustment:Dictionary)->Variant:
	if adjustment.sign==0:return base.duplicate(true)
	var result:Dictionary={"v":2,"base":base.duplicate(true),"sign":int(adjustment.sign),"delta":I.encode(adjustment.coefficient),"places":int(adjustment.places)}
	if compare(result,0)==0:return 0
	return result if valid(result) else null

static func change(value:Variant,amount:Variant,sign:int)->Variant:
	var base=_base(value)
	if base==null:return null
	if is_compact(amount):
		push_error("unsupported_numeric_domain: combining two compact wallet bases")
		return null
	if legacy_valid(amount) and is_compact(value) and float(amount.e)==float(base.e) and sign==1:
		var combined:float=float(base.m)+float(amount.m)
		if combined<10.0 and is_finite(combined):
			var next_base:Dictionary={"m":combined,"e":base.e}
			var retained:=_value_term(value)
			return make(next_base,retained)
	var term:=_legacy_adjustment(amount) if legacy_valid(amount) else _value_term(amount)
	if term.is_empty():return null
	var old:=_value_term(value) if is_compact(value) else _zero()
	var next:=_signed_add(old,_term(sign,term.coefficient,int(term.places)))
	return make(base,next)

static func near_integer(value:Variant,max_digits:int)->Variant:
	if not is_compact(value):return null
	var base=I.legacy_integer(value.base,max_digits)
	if base==null or int(value.places)!=0:return null
	return I.add(base,value.delta) if int(value.sign)>0 else I.subtract(base,value.delta) if I.compare(base,value.delta)>=0 else null

static func difference(a:Variant,b:Variant)->Variant:
	if _base(a)!=_base(b):return null
	var x:=_value_term(a)
	var y:=_value_term(b)
	var result:=_signed_add(x,_term(-int(y.sign),y.coefficient,int(y.places)))
	if result.sign<=0:return 0.0
	if result.places==0:return result.coefficient
	var size:int=I.digits(result.coefficient).length()-int(result.places)
	if size>300 or size< -300:return null
	var digits:String=I.digits(result.coefficient)
	var prefix:String=digits.substr(0,mini(17,digits.length()))
	return float(prefix)/pow(10.0,prefix.length()-1)*pow(10.0,size-1)

static func text(value:Dictionary)->String:
	var base:Dictionary=value.base
	var coefficient:String=I.digits(value.delta)
	var adjustment:String=coefficient if value.places==0 else coefficient+"e-"+str(value.places)
	if coefficient.length()>18:adjustment=coefficient.substr(0,3)+"e+"+str(coefficient.length()-3-int(value.places))
	return "%.2fe+%.0f (%s%s)" % [float(base.m),float(base.e),"+" if value.sign>0 else "-",adjustment]
