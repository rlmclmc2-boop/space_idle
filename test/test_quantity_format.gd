extends SceneTree
var checks := 0
var failures := 0
func check(value, expected: String) -> void:
	checks+=1
	var actual=NumberFormat.compact(value)
	if actual!=expected:
		failures+=1
		printerr(str(value)," expected ",expected," got ",actual)
func _initialize() -> void:
	for pair in [[0,"0"],[-65,"-65"],[65,"65"],[123,"123"],[12.345,"12.3"],[0.012345,"0.0123"],[999.49,"999"],[999.5,"1K"],[-999.5,"-1K"],[1234,"1.23K"],[1200,"1.2K"],[1e17,"100Qa"],[9.9e19,"99Qi"],[1e20,"100Qi"],[1e33,"1e+33"],[1.23456e100,"1.23e+100"]]:check(pair[0],pair[1])
	var suffixes=["K","M","B","T","Qa","Qi","Sx","Sp","Oc","No"]
	for i in suffixes.size():
		var scale=pow(10.0,(i+1)*3)
		check(scale,"1"+suffixes[i])
		check(999.49*scale,"999"+suffixes[i])
		check(999.5*scale,"1"+suffixes[i+1] if i+1<suffixes.size() else "1e+33")
	var large={"m":1.23456,"e":350}
	var original=large.duplicate(true)
	check(large,"1.23e+350")
	check({"m":9.9,"e":19},"99Qi")
	check({"m":9.99999,"e":350},"1e+351")
	assert(large==original,"Formatting must not mutate stored mantissa/exponent")
	assert(NumberFormat.damage(-9.9e19)=="99Qi")
	assert(NumberFormat.rate(large)=="1.23e+350")
	assert(NumberFormat.rate(0.5)=="0.50")
	print("QUANTITY_FORMAT ",checks," cases, ",failures," failures; dictionary preservation and damage/rate checks passed")
	quit(1 if failures else 0)
