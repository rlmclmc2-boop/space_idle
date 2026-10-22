extends RefCounted
## One read-only worker per game. Requests keep a fixed budget while income continues.
const Ledger=preload("res://scripts/currency_ledger.gd")
const Price=preload("res://scripts/equipment_price.gd")
const Bounds=preload("res://scripts/equipment_price_bounds.gd")
const I=preload("res://scripts/currency_integer.gd")
const RULE="MAX-APPROX-v1"
var _next_id:=1
var _jobs:Dictionary={}
var _queue:Array=[]
var _thread:Thread
var _active:=0
var _cancelled_id:=0
var _mutex:=Mutex.new()
var _phase:="idle"
var _candidate:=0
# Only the single worker accesses cursors; wallet mutations never clear prices.
var _cursors:Dictionary={}

class Outcome extends RefCounted:
	var status:String
	var request_id:int
	var quote:Dictionary={}
	var fingerprint:String=""
	var reason:String=""
	var metrics:Dictionary={}
	func _init(state:String,id:int)->void:
		status=state
		request_id=id

func request(inputs:Dictionary)->Outcome:
	var id:int=_next_id
	_next_id+=1
	_jobs[id]={"inputs":inputs.duplicate(true),"status":"pending","result":{}}
	_queue.append(id)
	pump()
	return poll(id)

func cancel(id:int)->void:
	if not _jobs.has(id):return
	if id==_active:
		_mutex.lock()
		_cancelled_id=id
		_mutex.unlock()
	else:
		_queue.erase(id)
		_jobs[id].status="cancelled"
		_jobs[id].result={"reason":"cancelled"}
		
func _cancelled(id:int)->bool:
	_mutex.lock()
	var stopped:bool=_cancelled_id==id
	_mutex.unlock()
	return stopped

func pump()->void:
	if _thread!=null and not _thread.is_alive():
		var result:Dictionary=_thread.wait_to_finish()
		_jobs[_active].result=result
		_jobs[_active].status=str(result.status)
		_thread=null
		_active=0
	if _thread==null and not _queue.is_empty():
		_active=int(_queue.pop_front())
		_mutex.lock()
		_cancelled_id=0
		_mutex.unlock()
		_thread=Thread.new()
		var error:Error=_thread.start(Callable(self,"_solve").bind(_active,_jobs[_active].inputs))
		if error!=OK:
			_jobs[_active].status="error"
			_jobs[_active].result={"reason":"thread_start"}
			_thread=null
			_active=0

func poll(id:int)->Outcome:
	pump()
	if not _jobs.has(id):return Outcome.new("error",id)
	var job:Dictionary=_jobs[id]
	var out:=Outcome.new(str(job.status),id)
	var result:Dictionary=job.result
	out.reason=str(result.get("reason",""))
	_mutex.lock()
	out.metrics={"phase":_phase,"candidate":_candidate,"stopped_us":result.get("stopped_us",0)}
	_mutex.unlock()
	if result.has("quote"):
		out.quote=result.quote.duplicate(true)
		out.fingerprint=str(result.fingerprint)
	return out

func confirmed_content(id:int,fingerprint:String)->Dictionary:
	var out:Outcome=poll(id)
	if out.status!="complete" or out.fingerprint!=fingerprint:return {}
	return out.quote.duplicate(true)

func forget(id:int)->void:
	cancel(id)
	if id!=_active:_jobs.erase(id)

func _notification(what:int)->void:
	if what==NOTIFICATION_PREDELETE and _thread!=null:
		cancel(_active)
		_thread.wait_to_finish()

func _material(start:int,count:int)->Variant:
	var last:int=(start+count)/20
	var first:int=start/20
	var upper:Variant=I.div_small(I.multiply(last,last+1),2)[0]
	var lower:Variant=I.div_small(I.multiply(first,first+1),2)[0]
	return I.multiply(I.subtract(upper,lower),10)

func _scale(value:Ledger.Value,times:int,id:int)->Ledger.Value:
	var result:Ledger.Value=Ledger.decode(0).value
	for unused in times:
		if _cancelled(id):return null
		var sum:Ledger.Outcome=Ledger.add(result,value)
		if sum.status!="ok":return null
		result=sum.value
	return result

func _fee(start:int,count:int,cursor:Dictionary,id:int)->Dictionary:
	if _cancelled(id):return {"status":"cancelled"}
	if cursor.fees.has(count):return cursor.fees[count]
	_mutex.lock()
	_phase="bound"
	_candidate=count
	_mutex.unlock()
	var material:Variant=_material(start,count)
	var low:Ledger.Value
	var high:Ledger.Value
	if count<=256:
		low=cursor.prefix[count]
		high=low
	else:
		var engine:=Bounds.new()
		var interval:Array=engine.rounded_fee_envelope(start+256,count-256)
		if _cancelled(id):return {"status":"cancelled"}
		var lower:Ledger.Outcome=Ledger.decode(engine.encoded_integer(interval[0],false))
		var upper:Ledger.Outcome=Ledger.decode(engine.encoded_integer(interval[1],true))
		if lower.status!="ok" or upper.status!="ok":return {"status":"error","reason":"bound_encoding"}
		var lower_total:Ledger.Outcome=Ledger.add(cursor.prefix[256],lower.value)
		var upper_total:Ledger.Outcome=Ledger.add(cursor.prefix[256],upper.value)
		if lower_total.status!="ok" or upper_total.status!="ok":return {"status":"error","reason":"bound_sum"}
		low=lower_total.value
		high=upper_total.value
		var left:Ledger.Value=_scale(high,25,id)
		var right:Ledger.Value=_scale(low,28,id)
		if left==null or right==null:return {"status":"cancelled" if _cancelled(id) else "error","reason":"certificate_arithmetic"}
		right=Ledger.add(right,Ledger.decode(24).value).value
		if Ledger.compare(left,right).order>0:return {"status":"error","reason":"fee_certificate"}
	var result:Dictionary={"status":"ready","lower":low,"upper":high,"material":material}
	cursor.fees[count]=result
	return result

func _fits(fee:Dictionary,wallet:Ledger.Value,material:Variant)->bool:
	return fee.status=="ready" and I.compare(fee.material,material)<=0 and Ledger.compare(wallet,fee.upper).order>=0

func _complete(start:int,count:int,mode:String,fee:Dictionary,boundary:String)->Dictionary:
	var quote:Dictionary={"rule_version":RULE,"mode":mode,"start_level":start,"count":count,"resource_debit":{"1":Ledger.encode(fee.upper)},"material_debit":int(I.digits(fee.material)),"bound_certificate":{"lower":Ledger.encode(fee.lower),"upper":Ledger.encode(fee.upper),"precision":Bounds.PRECISION},"boundary":boundary}
	var fingerprint:String=JSON.stringify(quote).sha256_text()
	return {"status":"complete","quote":quote,"fingerprint":fingerprint,"stopped_us":Time.get_ticks_usec()}

func _solve(id:int,inputs:Dictionary)->Dictionary:
	var result:Dictionary=_search(id,inputs)
	result.stopped_us=Time.get_ticks_usec()
	return result

func _search(id:int,inputs:Dictionary)->Dictionary:
	var start:Variant=inputs.get("start")
	var limit:Variant=inputs.get("max_count")
	var material:Variant=inputs.get("material")
	if not start is int or not limit is int or start<1 or limit<0 or limit>9223372036854775807-start:
		return {"status":"error","reason":"level_transport"}
	if not material is int or material<0:return {"status":"error","reason":"material_transport"}
	if not bool(inputs.get("supported",false)):return {"status":"error","reason":"unsupported_configuration"}
	var decoded:Ledger.Outcome=Ledger.decode(inputs.get("wallet"))
	if decoded.status!="ok":return {"status":"error","reason":decoded.status}
	var wallet:Ledger.Value=decoded.value
	var key:String=JSON.stringify([inputs.get("price_signature"),start,RULE])
	if not _cursors.has(key):
		if _cursors.size()>=32:_cursors.erase(_cursors.keys()[0])
		_cursors[key]={"prefix":[Ledger.decode(0).value],"fees":{}}
	var cursor:Dictionary=_cursors[key]
	var prices:=Price.new()
	var count:=0
	while count<mini(257,limit):
		_mutex.lock()
		_phase="prefix"
		_candidate=count
		_mutex.unlock()
		if _cancelled(id):return {"status":"cancelled","stopped_us":Time.get_ticks_usec()}
		var next:int=count+1
		if cursor.prefix.size()<=next:
			var quoted:Ledger.Outcome=prices.quote(50.0,0.2,start+next)
			if quoted.status!="ok":return {"status":"error","reason":quoted.status}
			var sum:Ledger.Outcome=Ledger.add(cursor.prefix[-1],quoted.value)
			if sum.status!="ok":return {"status":"error","reason":sum.status}
			cursor.prefix.append(sum.value)
		var fee:Dictionary={"status":"ready","lower":cursor.prefix[next],"upper":cursor.prefix[next],"material":_material(start,next)}
		if not _fits(fee,wallet,material):
			var exact:Dictionary=_fee(start,count,cursor,id)
			return _complete(start,count,"exact",exact,"insufficient")
		count=next
	if count<=256:
		var exact:Dictionary=_fee(start,count,cursor,id)
		return _complete(start,count,"exact",exact,"integer_transport" if count==limit else "insufficient")
	var fee257:Dictionary=_fee(start,257,cursor,id)
	if fee257.status!="ready":return {"status":fee257.status,"reason":fee257.get("reason","")}
	if not _fits(fee257,wallet,material):
		return _complete(start,256,"approx_exact_fallback",_fee(start,256,cursor,id),"upper_bound")
	var low:=257
	var high:int=mini(limit,514)
	var best:Dictionary=fee257
	while high>low:
		var fee:Dictionary=_fee(start,high,cursor,id)
		if fee.status!="ready":return {"status":fee.status,"reason":fee.get("reason","")}
		if not _fits(fee,wallet,material):break
		low=high
		best=fee
		if low==limit:break
		high=limit if low>limit/2 else low*2
	while high-low>1:
		var middle:int=low+(high-low)/2
		var fee:Dictionary=_fee(start,middle,cursor,id)
		if fee.status!="ready":return {"status":fee.status,"reason":fee.get("reason","")}
		if _fits(fee,wallet,material):
			low=middle
			best=fee
		else:high=middle
	if _cancelled(id):return {"status":"cancelled","stopped_us":Time.get_ticks_usec()}
	return _complete(start,low,"approx",best,"integer_transport" if low==limit else "upper_bound")

