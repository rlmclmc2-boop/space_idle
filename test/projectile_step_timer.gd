extends RefCounted
# Narrow QA loop-boundary timing only. Callback time is included, not pure physics.
var enabled=false
var current={}
var rows=[]
var outside_calls=0
func begin_sample()->void:
 enabled=true;current={};rows.clear();outside_calls=0
func begin_step()->void:
 if not enabled:return
 if not current.is_empty():rows.append(current)
 current={"base_us":0,"presented_us":0,"base_calls":0,"presented_calls":0,"base_dt":0.}
func record(kind:String,elapsed:int,dt:float)->void:
 if not enabled:return
 if current.is_empty():outside_calls+=1;return
 current[kind+"_us"]+=elapsed;current[kind+"_calls"]+=1
 if kind=="base":current.base_dt+=dt
func report(tree:SceneTree,logical_ticks:int)->Dictionary:
 enabled=false
 if not current.is_empty():rows.append(current);current={}
 var base=[];var presented=[];var base_calls=0;var presented_calls=0;var dt=0.
 for row in rows:
  base.append(row.base_us);presented.append(row.presented_us)
  base_calls+=row.base_calls;presented_calls+=row.presented_calls;dt+=row.base_dt
 return {"logical_steps":logical_ticks,"measured_steps":rows.size(),"step_count_equal":rows.size()==logical_ticks,"base_calls":base_calls,"presented_calls":presented_calls,"base_dt_seconds":dt,"outside_step_calls":outside_calls,"base_us_per_logical_step":tree.stats(base),"presented_us_per_logical_step":tree.stats(presented),"rows":rows,"scope":"Per60Hz logical step, partial ejection segments summed within their actual parent step. Inclusive original loop/callback wall time; base and presented overlap and must not be added. Two time reads per boundary, RAM accumulation; no broad/function/native profiler. Separate from clean AB qualification."}
