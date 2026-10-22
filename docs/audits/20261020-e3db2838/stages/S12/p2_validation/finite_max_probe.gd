extends SceneTree
const Q=preload("res://scripts/equipment_max_query.gd")
const L=preload("res://scripts/currency_ledger.gd")
const B=preload("res://scripts/equipment_price_bounds.gd")
const I=preload("res://scripts/currency_integer.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	for start in [1,10000000000000000]:
		var query:=Q.new()
		var input:Dictionary={"start":start,"max_count":9223372036854775807-start,"material":9223372036854775807,"wallet":{"m":1.0,"e":3800.0 if start==1 else 1e308},"supported":true,"price_signature":{"fixed_family":true}}
		var result=query.request(input)
		while result.status=="pending":await process_frame;result=query.poll(result.request_id)
		if result.status!="complete":printerr("P2_FAIL ",result.status," ",result.reason);quit(1);return
		var cursor:Dictionary=query._cursors.values()[0]
		var interval:Array=B.new().rounded_fee_envelope(start+256,int(result.quote.count)-256)
		print("P2_MAX_FINITE_RESULT ",JSON.stringify({"start":start,"quote":result.quote,"original_upper_prefix":L.encode(cursor.prefix_high[256]),"original_upper_tail":{"coefficient":I.digits(interval[1][0]),"exponent":interval[1][1]}}))
		query.shutdown()
	print("P2_MAX_FINITE_COMPLETE")
	quit(0)
