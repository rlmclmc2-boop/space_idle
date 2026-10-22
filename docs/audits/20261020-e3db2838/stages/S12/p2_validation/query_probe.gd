extends SceneTree
const Q=preload("res://scripts/equipment_max_query.gd")
const L=preload("res://scripts/currency_ledger.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		printerr("P2_FAIL ",label)
		quit(1)
		assert(false,label)
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")
func _run()->void:
	var query:=Q.new()
	var budget:Dictionary={"v":1,"i":"55916713612491779479035"}
	var input:Dictionary={"start":1,"max_count":9223372036854775806,"material":9007199254740991,"wallet":budget,"supported":true,"price_signature":{"base":50,"multiplier":0.2,"interval":20,"per_tier":10}}
	var out:Q.Outcome=query.request(input)
	budget.i="9007199254740992"
	var started:int=Time.get_ticks_usec()
	while out.status=="pending":
		await process_frame
		out=query.poll(out.request_id)
	check(out.status=="complete" and out.quote.count==256 and out.quote.mode=="exact","exact frozen original-price budget")
	var fee:L.Outcome=L.decode(out.quote.resource_debit["1"])
	var expected:L.Outcome=L.decode({"v":1,"i":"55916713612491779479035"})
	check(L.compare(fee.value,expected.value).order==0,"exact fee from original main prices")
	var altered:Dictionary=out.quote
	altered.count=1
	check(query.confirmed_content(out.request_id,out.fingerprint).count==256,"public result alias isolated")
	query.forget(out.request_id)
	input.wallet={"m":1.0,"e":3800.0}
	out=query.request(input)
	started=Time.get_ticks_usec()
	var max_work:=0
	var heartbeat:=0
	var previous:int=started
	while out.status=="pending":
		await process_frame
		var now:int=Time.get_ticks_usec()
		heartbeat=maxi(heartbeat,now-previous)
		previous=now
		var work:int=Time.get_ticks_usec()
		out=query.poll(out.request_id)
		max_work=maxi(max_work,Time.get_ticks_usec()-work)
	check(out.status=="complete" and out.quote.count==47959,"middle frozen count")
	check(max_work<=4000 and heartbeat<=50000,"middle host scheduling")
	query.forget(out.request_id)
	input.wallet={"m":1.0,"e":1000000000.0}
	out=query.request(input)
	var requested:=0
	while out.status=="pending":
		await process_frame
		out=query.poll(out.request_id)
		if requested==0 and out.metrics.phase=="bound" and out.metrics.candidate>=32768:
			requested=Time.get_ticks_usec()
			query.cancel(out.request_id)
	check(out.status=="cancelled" and requested>0,"cancel during active bounds")
	check(int(out.metrics.stopped_us)-requested<=100000,"actual worker stop latency")
	query.forget(out.request_id)
	print("P2_QUERY_COMPLETE checks=",checks," main_poll_max_us=",max_work," heartbeat_max_us=",heartbeat)
	quit(0)

