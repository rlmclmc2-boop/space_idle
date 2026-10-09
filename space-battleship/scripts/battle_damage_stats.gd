extends RefCounted
## Optional bounded combat-time buckets. No history, profile write or per-hit display.
const N=preload("res://scripts/growth_number.gd")
const WIDTH:=0.5
const COUNT:=16
const SOURCE_LIMIT:=32
var enabled:=false
var elapsed:=0.0
var bucket_index:=0
var buckets:Array[Dictionary]=[]
var totals:Dictionary={}
var total=0.0
func clear() -> void:
 elapsed=0.0;bucket_index=0;buckets.clear();totals.clear();total=0.0
 if enabled:
  for i in COUNT:buckets.append({})
func set_enabled(value:bool) -> void:
 if enabled==value:return
 enabled=value;clear()
func advance(dt:float) -> void:
 if not enabled or dt<=0:return
 elapsed+=dt
 var next:=int(floor(elapsed/WIDTH))
 if next-bucket_index>=COUNT:
  for bucket in buckets:bucket.clear()
  totals.clear();total=0.0
 else:
  for index in range(bucket_index+1,next+1):
   var bucket:Dictionary=buckets[index%COUNT]
   for source in bucket:
    totals[source]=N.subtract(totals.get(source,0),bucket[source]);total=N.subtract(total,bucket[source])
    if N.compare(totals[source],0)<=0:totals.erase(source)
   bucket.clear()
 bucket_index=next
func record(source:String,amount) -> void:
 if not enabled or N.compare(amount,0)<=0:return
 if not source.begins_with("module:") and not source.begins_with("drone:") and not source.begins_with("legendary:"):source="other"
 if not totals.has(source) and totals.size()>=SOURCE_LIMIT-1:source="other"
 var bucket:Dictionary=buckets[bucket_index%COUNT]
 bucket[source]=N.add(bucket.get(source,0),amount);totals[source]=N.add(totals.get(source,0),amount);total=N.add(total,amount)
func snapshot() -> Dictionary:
 # The oldest retained bucket starts here; denominator follows its actual range.
 var seconds:=elapsed-maxf(0.0,float(bucket_index-COUNT+1)*WIDTH)
 var rows:Array=[]
 for source in totals:rows.append({"source":source,"damage":totals[source],"dps":N.divide(totals[source],seconds) if seconds>0 else 0.0})
 return {"seconds":seconds,"damage":total,"dps":N.divide(total,seconds) if seconds>0 else 0.0,"rows":rows}
