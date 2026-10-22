extends RefCounted
## Fixed resource value: nine significant digits plus one bounded residual.
const I=preload("res://scripts/currency_integer.gd")
const RADIX:=10000
static var _issuer:=RefCounted.new()

class Value extends RefCounted:
	var _main:Dictionary
	var _residual:Dictionary
	var _terms:Array
	var _owner:RefCounted
	func _init(main:Dictionary,residual:Dictionary,terms:Array,owner:RefCounted)->void:
		_main=main.duplicate(true);_main.make_read_only()
		_residual=residual.duplicate(true);_residual.make_read_only()
		_terms=terms.duplicate(true)
		for term in _terms:term.make_read_only()
		_terms.make_read_only()
		_owner=owner
class Outcome extends RefCounted:
	var status:String
	var value:Value
	func _init(state:String,result:Value=null)->void:status=state;value=result
class Comparison extends RefCounted:
	var status:String
	var order:int
	func _init(state:String,result:int=0)->void:status=state;order=result
class FiniteProjection extends RefCounted:
	var status:String
	var amount:float
	func _init(state:String,result:float=0.0)->void:status=state;amount=result

static func _zero()->Dictionary:return {"c":0,"e":"0"}
static func _component_valid(raw:Variant,positive:bool=false)->bool:
	if not raw is Dictionary or raw.size()!=2 or not raw.has("c") or not raw.get("e") is String or not _position_valid(raw.e):return false
	if not (raw.c is int or raw.c is float) or not is_finite(float(raw.c)) or raw.c!=floorf(float(raw.c)):return false
	if raw.c< -999999999 or raw.c>999999999:return false
	var c:int=int(raw.c)
	return raw.e=="0" if c==0 else absi(c)>=100000000 and absi(c)<=999999999 and (not positive or c>0)
static func _cells(component:Dictionary)->Array:
	if int(component.c)==0:return []
	var terms:Array=_from_digits(str(absi(int(component.c))),_signed_integer(component.e,"8",true))
	if int(component.c)<0:
		for term in terms:term.d=-int(term.d)
	return _normalized(terms)
static func _raw_compare(a:Array,b:Array)->int:
	var difference:Array=_signed_sum(a,b,true)
	return 0 if difference.is_empty() else 1 if _positive(difference) else -1
static func storage_valid(raw:Variant)->bool:
	if not raw is Dictionary or raw.size()!=3 or raw.get("currency_version")!=2 or not _component_valid(raw.get("main"),true) or not _component_valid(raw.get("residual")):return false
	if int(raw.main.c)==0:return int(raw.residual.c)==0
	var residual:Dictionary=raw.residual.duplicate();residual.c=absi(int(residual.c))
	var half:Dictionary={"c":500000000,"e":_signed_integer(raw.main.e,"9",true)}
	return _raw_compare(_cells(residual),_cells(half))<=0
static func _checked(value:Value)->bool:
	if value==null or not is_same(value._owner,_issuer) or value._terms.size()>12:return false
	return storage_valid({"currency_version":2,"main":value._main,"residual":value._residual}) and value._terms==_signed_sum(_cells(value._main),_cells(value._residual))
static func _term(c:int,shift:String)->Dictionary:
	if c==0:return _zero()
	while absi(c)<100000000:c*=10;shift=_signed_integer(shift,"1",true)
	while absi(c)>=1000000000:c/=10;shift=_signed_integer(shift,"1")
	return {"c":c,"e":_signed_integer(shift,"8")}
static func _quantize(source:Array,direction:int=0)->Dictionary:
	if source.is_empty():return _zero()
	var negative:bool=not _positive(source)
	var terms:Array=source
	if negative:
		terms=[]
		for term in source:terms.append({"p":term.p,"d":-int(term.d)})
		terms=_normalized(terms)
	var base:String=_signed_integer(str(terms[-1].p),"3",true)
	var coefficient:=0
	var tail:=0
	for term in terms:
		if _position_compare(term.p,base)<0:tail=1 if int(term.d)>0 else -1
		else:
			var offset:int=int(_signed_integer(term.p,base,true))
			coefficient+=int(term.d)*int(pow(10000.0,offset))
	var cut:int=str(coefficient).length()-9
	var unit:int=int(pow(10.0,cut))
	var c:int=coefficient/unit
	var remainder:int=coefficient%unit
	var mode:int=-direction if negative else direction
	if mode>0:
		if remainder>0 or (remainder==0 and tail>0):c+=1
	elif mode<0:
		if remainder==0 and tail<0:c-=1
	elif remainder*2>unit or (remainder*2==unit and (tail>0 or (tail==0 and c%2==1))):c+=1
	var shift:String=_signed_integer(_signed_integer(base,base),_signed_integer(base,base))
	shift=_signed_integer(shift,str(cut))
	return _term(-c if negative else c,shift)
static func _value(source:Array)->Value:
	var main:Dictionary=_quantize(source)
	var rest:Array=_signed_sum(source,_cells(main),true)
	var residual:Dictionary=_quantize(rest)
	var combined:Array=_signed_sum(_cells(main),_cells(residual))
	# Roundoff can put the represented residual exactly on a tie. Canonicalize
	# that tie once without retaining any additional source components.
	main=_quantize(combined)
	residual=_quantize(_signed_sum(combined,_cells(main),true))
	combined=_signed_sum(_cells(main),_cells(residual))
	return Value.new(main,residual,combined,_issuer)
static func _limited_digits(digits:String,shift:String)->Array:
	if digits.length()<=24:return _from_digits(digits,shift)
	var sticky:=false
	for index in range(24,digits.length()):
		if digits[index]!="0":sticky=true;break
	var head:String=digits.substr(0,24)+("1" if sticky else "0")
	return _from_digits(head,_signed_integer(shift,str(digits.length()-25)))
static func _decimal(text:String,extra_shift:String="0")->Array:
	var pieces:PackedStringArray=text.to_lower().split("e")
	var exponent:String=pieces[1] if pieces.size()==2 else "0"
	var negative:bool=exponent.begins_with("-")
	exponent=exponent.trim_prefix("+").trim_prefix("-").lstrip("0")
	if exponent.is_empty():exponent="0"
	if negative and exponent!="0":exponent="-"+exponent
	var dot:int=pieces[0].find(".")
	var places:int=pieces[0].length()-dot-1 if dot>=0 else 0
	var digits:String=pieces[0].replace(".","").lstrip("0")
	if digits.is_empty():return []
	return _limited_digits(digits,_signed_integer(_signed_integer(exponent,extra_shift),str(places),true))
static func _float_text(value:float)->String:
	if value==0:return "0"
	var exponent:int=int(floor(log(value)/log(10.0)))
	var mantissa:float=value/1e-308*pow(10.0,-(exponent+308)) if exponent< -308 else value/pow(10.0,exponent)
	while mantissa>=10.0:mantissa/=10.0;exponent+=1
	while mantissa<1.0:mantissa*=10.0;exponent-=1
	return String.num(mantissa,16)+"e"+str(exponent)
static func _legacy_valid(raw:Variant)->bool:
	if raw is int or raw is float:return is_finite(float(raw)) and raw>=0
	if raw is Dictionary and raw.has("i"):return I.valid(raw)
	return raw is Dictionary and raw.size()==2 and raw.has("m") and raw.has("e") and (raw.m is int or raw.m is float) and (raw.e is int or raw.e is float) and is_finite(float(raw.m)) and is_finite(float(raw.e)) and raw.m>=1 and raw.m<10 and float(raw.e)==floorf(float(raw.e))
static func decode(raw:Variant)->Outcome:
	if storage_valid(raw):
		var main:Dictionary={"c":int(raw.main.c),"e":raw.main.e}
		var residual:Dictionary={"c":int(raw.residual.c),"e":raw.residual.e}
		return Outcome.new("ok",Value.new(main,residual,_signed_sum(_cells(main),_cells(residual)),_issuer))
	var terms:Array
	if raw is Dictionary and raw.get("currency_version")==1 and raw.size()==2 and raw.get("blocks") is Array and (raw.blocks.is_empty() or _core_valid({"v":3,"blocks":raw.blocks})):
		terms=raw.blocks.duplicate(true) # optional WIP/internal conversion only
	elif raw is Dictionary and raw.has("currency_version"):return Outcome.new("invalid_storage")
	elif I.valid(raw):terms=_limited_digits(I.digits(raw),"0")
	elif raw is float and is_finite(raw) and raw>=0:
		terms=[] if raw==0 else _decimal(_float_text(raw))
	elif raw is Dictionary and raw.has("m") and _legacy_valid(raw):
		var exponent:float=float(raw.e)
		var shift:String=("-" if exponent<0 else "")+I.digits(I.float_floor(absf(exponent)))
		terms=_decimal(_float_text(float(raw.m)),shift)
	else:return Outcome.new("invalid_input")
	terms=_normalized(terms)
	return Outcome.new("ok",_value(terms)) if _positive(terms) else Outcome.new("negative_value")
static func from_generated_income(raw:Variant)->Outcome:
	return decode(raw) if _legacy_valid(raw) else Outcome.new("invalid_income")
static func from_price_integer(coefficient:Variant,decimal_shift:String,direction:int=0)->Outcome:
	if not I.valid(coefficient) or not _position_valid(decimal_shift):return Outcome.new("invalid_price")
	var source:Array=_normalized(_limited_digits(I.digits(coefficient),decimal_shift))
	if direction==0:return Outcome.new("ok",_value(source))
	var main:Dictionary=_quantize(source,direction)
	return Outcome.new("ok",Value.new(main,_zero(),_cells(main),_issuer))
static func encode(value:Value)->Dictionary:
	if not _checked(value):return {"error":"invalid_value"}
	return {"currency_version":2,"main":value._main.duplicate(),"residual":value._residual.duplicate()}
static func compare(a:Value,b:Value)->Comparison:
	if not _checked(a) or not _checked(b):return Comparison.new("invalid_value")
	return Comparison.new("ok",_raw_compare(a._terms,b._terms))
static func add(a:Value,b:Value)->Outcome:
	if not _checked(a) or not _checked(b):return Outcome.new("invalid_value")
	return Outcome.new("ok",_value(_signed_sum(a._terms,b._terms)))
static func add_directed(a:Value,b:Value,direction:int)->Outcome:
	if not _checked(a) or not _checked(b):return Outcome.new("invalid_value")
	var main:Dictionary=_quantize(_signed_sum(a._terms,b._terms),direction)
	return Outcome.new("ok",Value.new(main,_zero(),_cells(main),_issuer))
static func subtract(a:Value,b:Value)->Outcome:
	if not _checked(a) or not _checked(b):return Outcome.new("invalid_value")
	var difference:Array=_signed_sum(a._terms,b._terms,true)
	return Outcome.new("ok",_value(difference)) if _positive(difference) else Outcome.new("insufficient")
static func certifies_ratio(upper:Value,lower:Value)->bool:
	if not _checked(upper) or not _checked(lower):return false
	var left:Array=[];var right:Array=[]
	for term in upper._terms:left.append({"p":term.p,"d":int(term.d)*25})
	for term in lower._terms:right.append({"p":term.p,"d":int(term.d)*28})
	right.append({"p":"0","d":24})
	return _raw_compare(_normalized(left),_normalized(right))<=0
static func tail_within_budget(tail:Value,total:Value)->bool:
	if not _checked(tail) or not _checked(total):return false
	var scaled:Array=[]
	for term in tail._terms:scaled.append({"p":term.p,"d":int(term.d)*200000})
	return _raw_compare(_normalized(scaled),total._terms)<=0
static func _finite(value:Value)->FiniteProjection:
	if int(value._main.c)==0:return FiniteProjection.new("ok")
	if _position_compare(value._main.e,"308")>0 or _position_compare(value._main.e,"-318")<0:return FiniteProjection.new("out_of_domain")
	var amount:=0.0
	for part in [value._main,value._residual]:
		if int(part.c)==0 or _position_compare(part.e,"-324")<0:continue
		var exponent:int=int(part.e)
		var mantissa:float=float(part.c)/100000000.0
		amount+=mantissa*pow(10.0,exponent+308)*1e-308 if exponent< -308 else mantissa*pow(10.0,exponent)
	return FiniteProjection.new("ok",amount) if is_finite(amount) and amount>0 else FiniteProjection.new("out_of_domain")
static func finite_research_balance(value:Value,finite_upper:float)->FiniteProjection:
	if not _checked(value) or not is_finite(finite_upper) or finite_upper<0:return FiniteProjection.new("invalid_value")
	if compare(value,decode(finite_upper).value).order>0:return FiniteProjection.new("not_finite_shortage")
	var result:FiniteProjection=_finite(value)
	if result.status=="ok":result.amount=minf(result.amount,finite_upper);return result
	if _position_compare(value._main.e,"-318")<0:return FiniteProjection.new("ok")
	return FiniteProjection.new("ok",finite_upper) if _position_compare(value._main.e,"308")<=0 else result
static func analysis_value(raw:Variant)->FiniteProjection:
	var result:Outcome=decode(raw)
	return _finite(result.value) if result.status=="ok" else FiniteProjection.new(result.status)
static func text(value:Value)->String:
	if not _checked(value):return "invalid"
	if int(value._main.c)==0:return "0"
	return "%.2fe%s"%[float(value._main.c)/100000000.0,("" if value._main.e.begins_with("-") else "+")+value._main.e]
static func exact_text(value:Value)->String:
	if not _checked(value):return "invalid"
	if int(value._main.c)==0:return "0"
	var parts:=PackedStringArray()
	for part in [value._main,value._residual]:
		if int(part.c)==0:continue
		parts.append(("- " if int(part.c)<0 else "+ " if not parts.is_empty() else "")+str(absi(int(part.c)))+" × 10^("+_signed_integer(part.e,"8",true)+")")
	return " ".join(parts)

static func _position_valid(s:String)->bool:
	if s.is_empty() or s=="-0":return false
	var start:=1 if s.begins_with("-") else 0
	if start==s.length() or (s.length()-start>1 and s[start]=="0"):return false
	for index in range(start,s.length()):
		if s[index]<"0" or s[index]>"9":return false
	return true

static func _position_compare(a:String,b:String)->int:
	if a.length()<=17 and b.length()<=17:
		var x:int=int(a);var y:int=int(b)
		return 0 if x==y else 1 if x>y else -1
	if a==b:return 0
	var na:=a.begins_with("-");var nb:=b.begins_with("-")
	if na!=nb:return -1 if na else 1
	var x:=a.substr(1) if na else a
	var y:=b.substr(1) if nb else b
	var order:=I.compare(I.make(x),I.make(y))
	return -order if na else order

static func _signed_integer(a:String,b:String,negative_b:bool=false)->String:
	if a.length()<=17 and b.length()<=17:return str(int(a)+(-int(b) if negative_b else int(b)))
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
	if shift.length()<=17:
		var value:int=int(shift);var group:int=value/4;var remainder:int=value%4
		if remainder<0:group-=1;remainder+=4
		return [str(group),remainder]
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

