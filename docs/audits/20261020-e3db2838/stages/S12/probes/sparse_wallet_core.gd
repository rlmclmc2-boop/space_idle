extends RefCounted
## Audit prototype: exact nonnegative decimal sums on widely separated positions.
const I=preload("res://scripts/reactor_integer.gd")
const C=preload("res://scripts/compact_wallet.gd")
const RADIX:=10000

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

static func valid(value:Variant)->bool:
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

static func blocks(value:Variant)->Variant:
	if valid(value):return value.blocks.duplicate(true)
	if value is Dictionary and value.get("v")==3:return null
	if C.is_compact(value):
		if not C.valid(value):return null
		var base=blocks(value.base)
		# JSON reads a small v2 integer coefficient back as a float. Convert its
		# exact integer payload before splitting decimal digits into radix blocks.
		var coefficient=I.command_floor(value.delta)
		if coefficient==null:return null
		var adjustment=_from_digits(I.digits(coefficient),str(-int(value.places)))
		var result=_signed_sum(base,adjustment,int(value.sign)<0)
		return result if _positive(result) else null
	if C.legacy_valid(value):
		var exponent:float=float(value.e)
		var e_digits:String=I.digits(_float_integer(absf(exponent)))
		var e:String=("-" if exponent<0.0 else "")+e_digits
		var part:Array=I.decimal_factor(float(value.m))
		return _from_digits(I.digits(part[0]),_signed_integer(e,str(int(part[1])),true))
	if I.valid(value):return _from_digits(I.digits(value),"0")
	if value is float and is_finite(value) and value>=0.0:return _float_decimal(value)
	return null

static func compare(a:Variant,b:Variant)->Variant:
	var x=blocks(a);var y=blocks(b)
	if x==null or y==null:return null
	var difference:=_signed_sum(x,y,true)
	return 0 if difference.is_empty() else (1 if _positive(difference) else -1)

static func add(a:Variant,b:Variant)->Variant:
	var x=blocks(a);var y=blocks(b)
	if x==null or y==null:return null
	var result:=_signed_sum(x,y)
	return _encode(result) if _positive(result) else null

static func subtract(a:Variant,b:Variant)->Variant:
	var x=blocks(a);var y=blocks(b)
	if x==null or y==null:return null
	var result:=_signed_sum(x,y,true)
	return _encode(result) if _positive(result) else null
