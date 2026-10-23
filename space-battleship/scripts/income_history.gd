extends RefCounted
## One rolling receipt owner. Coordinates and qualification retain current rules.
const N=preload("res://scripts/growth_number.gd")
var _samples:Array[Dictionary]=[]

func clear()->void:_samples.clear()
func size()->int:return _samples.size()
func records()->Array[Dictionary]:return _samples.duplicate(true)
func record(sample:Dictionary)->void:_samples.append(sample.duplicate(true))
func replace_records(samples:Array)->void:
	clear()
	for sample in samples:record(sample)

func retained(sample:Dictionary,wall_now:float,production_now:float)->bool:
	return float(sample.time)>wall_now-60.0 or (sample.has("production_time") and float(sample.production_time)>production_now-60.0)

func prune(wall_now:float,production_now:float)->void:
	_samples=_samples.filter(func(sample):return retained(sample,wall_now,production_now))

func snapshot(wall_now:float,production_now:float)->Array[Dictionary]:
	return _samples.filter(func(sample):return retained(sample,wall_now,production_now)).duplicate(true)

func nonnegative(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0

func restore(raw:Array,saved_at:float,production_now:float)->void:
	clear()
	for sample in raw:
		if not sample is Dictionary or not nonnegative(sample.get("time")) or not N.valid(sample.get("amount")) or str(sample.get("id","")) not in ["1","2","jewel"]:continue
		if float(sample.time)>saved_at:continue
		var valid_production:=nonnegative(sample.get("production_time")) and float(sample.production_time)<=production_now
		if float(sample.time)<=saved_at-60.0 and not (valid_production and float(sample.production_time)>production_now-60.0):continue
		var restored:Dictionary={"time":float(sample.time),"amount":sample.amount,"production_base":sample.get("production_base",sample.amount),"id":str(sample.id),"origin":str(sample.get("origin","unknown"))}
		if valid_production:restored.production_time=float(sample.production_time)
		record(restored)

func display_total(id:String,at:float)->Variant:
	var total:Variant=0.0
	for sample in _samples:
		if sample.id==id and float(sample.time)>at-60.0 and float(sample.time)<=at:total=N.add(total,sample.amount)
	return total

# Derived receipts (furnace/Galaxy) cannot feed the production income peak.
# Keep the peak's existing wall clock and credited-amount basis.
func peak_eligible(source:String)->bool:return source=="drop"

func peak_total(id:String,wall_now:float)->Variant:
	var total:Variant=0.0
	for sample in _samples:
		if not peak_eligible(str(sample.get("origin","unknown"))) or str(sample.id)!=id:continue
		if float(sample.time)>wall_now-60.0 and float(sample.time)<=wall_now:total=N.add(total,sample.amount)
	return total

func research_total(id:String,at:float)->Variant:
	var total:Variant=0.0
	for sample in _samples:
		if str(sample.id)!=id or not sample.has("production_time"):continue
		var stamp:=float(sample.production_time)
		if stamp>at-60.0 and stamp<=at:total=N.add(total,sample.amount)
	return total

func production_total(id:String,at:float,wall_now:float,production_now:float)->Variant:
	var total:Variant=0.0
	for sample in _samples:
		if sample.get("origin","drop")!="drop" or str(sample.id)!=id:continue
		var stamp:=float(sample.get("production_time",production_now-(wall_now-float(sample.time))))
		if stamp>at-60.0 and stamp<=at:total=N.add(total,sample.get("production_base",sample.amount))
	return total

func wall_production_total(id:String,at:float)->Variant:
	var total:Variant=0.0
	for sample in _samples:
		if sample.get("origin","drop")!="drop" or sample.id!=id:continue
		if float(sample.time)>at-60.0 and float(sample.time)<=at:total=N.add(total,sample.get("production_base",sample.amount))
	return total
