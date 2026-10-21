extends SceneTree
const S=preload("res://test/sparse_wallet_core.gd")
const C=preload("res://scripts/compact_wallet.gd")
const I=preload("res://scripts/reactor_integer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var low={"m":1.0,"e":1000000000.0}
	var high={"m":1.0,"e":1000000100.0}
	var low_minus_one=C.change(low,1,-1)
	var v2_cases:Array=[
		{"label":"small coefficient","amount":1234},
		{"label":"large v1 coefficient","amount":I.make("9007199254740993")},
		{"label":"fractional places","amount":0.125},
		{"label":"fractional with whole part","amount":2.5}
	]
	for row in v2_cases:
		var original=C.change(low,row.amount,-1)
		var parsed=JSON.parse_string(JSON.stringify(original))
		var from_original=S.add(original,0)
		var from_json=S.add(parsed,0)
		check(C.valid(original) and C.valid(parsed),"v2 input valid "+row.label)
		check(S.valid(from_original) and S.valid(from_json) and S.compare(from_original,from_json)==0,"v2 JSON to v3 exact "+row.label)
		check(S.compare(S.add(from_json,row.amount),low)==0,"v2 parsed refund exact "+row.label)
		check(S.valid(JSON.parse_string(JSON.stringify(from_json))),"v3 JSON round trip "+row.label)
	check(not C.valid({"v":2,"base":low,"sign":-1,"delta":1.5,"places":0}),"malformed fractional v2 coefficient rejected")
	var order_a=S.add(low_minus_one,high)
	var order_b=S.add(high,low_minus_one)
	check(S.valid(order_a) and S.valid(order_b) and S.compare(order_a,order_b)==0,"distant income both orders")
	check(order_a.blocks.size()<20 and JSON.stringify(order_a).length()<1000,"large gap stays sparse")
	check(S.compare(S.subtract(order_a,high),low_minus_one)==0,"distant income reversible")
	check(S.compare(S.subtract(order_b,low_minus_one),high)==0,"swapped distant income reversible")
	check(S.compare(S.subtract(low,1),low_minus_one)==0,"long borrow exact")
	check(S.compare(S.add(low_minus_one,1),low)==0,"refund restores base")
	check(S.compare(S.subtract(low,low),0)==0,"cancellation to zero")
	check(S.compare(S.subtract(low,low_minus_one),1)==0,"difference exactly one")
	check(S.subtract(low_minus_one,low)==null,"negative balance rejected")
	check(S.compare(S.add(S.subtract(low,1),1),low)==0,"large-gap algebra identity")
	var fractional=S.add(low_minus_one,0.1)
	check(S.compare(S.subtract(fractional,0.1),low_minus_one)==0,"fractional income exactly reverses")
	check(S.compare(S.add(0.1,0.2),0.3)>0,"binary64 fractional sum is exact, not rounded to displayed 0.3")
	check(S.compare(S.subtract(S.add(0.1,0.2),0.1),0.2)==0,"fractional cancellation")
	var roundtrip=JSON.parse_string(JSON.stringify(order_a))
	check(S.valid(roundtrip) and S.compare(roundtrip,order_a)==0,"JSON round trip")
	check(not S.valid({"v":3,"blocks":[{"p":"0","d":1},{"p":"0","d":2}]}),"duplicate position rejected")
	check(not S.valid({"v":3,"blocks":[{"p":"1","d":1},{"p":"0","d":1}]}),"out-of-order position rejected")
	check(not S.valid({"v":3,"blocks":[{"p":"00","d":1}]}),"noncanonical position rejected")
	check(not S.valid({"v":3,"blocks":[{"p":"0","d":5000}]}),"uncarried digit rejected")
	check(not S.valid({"v":3,"blocks":[{"p":"0","d":-1}]}),"negative wallet rejected")
	check(not S.valid({"v":3,"blocks":[{"p":"0","d":1.5}]}),"fractional digit rejected")
	check(S.blocks({"m":1.0,"e":1e20})!=null,"legacy exponent beyond int64 converts")
	var giant=S.add({"m":1.0,"e":1e20},1)
	check(S.valid(giant) and S.compare(S.subtract(giant,1),{"m":1.0,"e":1e20})==0,"beyond int64 exponent position exact")
	var rng:=RandomNumberGenerator.new();rng.seed=129819
	for index in 1000:
		var a:=rng.randi_range(0,1000000000)
		var b:=rng.randi_range(0,1000000000)
		check(S.compare(S.add(a,b),a+b)==0,"random add "+str(index))
		check(S.compare(a,b)==(0 if a==b else (1 if a>b else -1)),"random compare "+str(index))
		check(S.subtract(a,b)==null if a<b else S.compare(S.subtract(a,b),a-b)==0,"random nonnegative subtract "+str(index))
	var vectors=JSON.parse_string(FileAccess.get_file_as_string("res://test/sparse_decimal_oracle.json"))
	check(vectors is Array and vectors.size()==250,"independent Decimal vector fixture loaded")
	if vectors is Array:
		for index in vectors.size():
			var row:Dictionary=vectors[index]
			var actual=S.add(float(row.a),float(row.b))
			var got:Array=actual.blocks if actual is Dictionary else []
			var expected:Array=row.blocks
			var same:=got.size()==expected.size()
			if same:
				for part in got.size():
					if got[part].p!=expected[part].p or int(got[part].d)!=int(expected[part].d):same=false;break
			check(same,"independent Decimal.from_float sum "+str(index))
	print("S12_SPARSE_CORE checks=",checks," failures=",failures," distant_blocks=",order_a.blocks.size())
	quit(1 if failures else 0)
