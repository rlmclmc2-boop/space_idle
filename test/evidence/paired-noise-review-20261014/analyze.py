from pathlib import Path
import gzip,json,statistics,collections,hashlib
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
SETS={"gpu_final":ROOT/"test/evidence/foreground-gpu-20261014/final-validation","damage_lifecycle":ROOT/"test/evidence/damage-lifecycle-20261014"}
ORDER=["A1","B1","B2","A2","A3","B3"]
def stats(a):
 s=sorted(a);return {"n":len(a),"mean_ms":statistics.mean(a),"median_ms":statistics.median(a),"p95_ms":s[min(len(a)-1,int(len(a)*.95))],"max_ms":max(a)}
def canonical(v):
 if isinstance(v,dict):return {k:canonical(x) for k,x in v.items() if k!="kernel_hash" and not(k=="seed" and v.get("class")=="RandomNumberGenerator")}
 if isinstance(v,list):return [canonical(x) for x in v]
 return v
output={"method":"Existing12 samples only. No executions, exclusions, reordered pairs or changed acceptance. p95 uses sorted[floor(0.95*N)]; slow threshold33.333333ms is two60Hz steps. Half-by-frame and half-by-logic-step shown separately. CPU is whole Godot process aggregated across threads.","sets":{}}
slow_total=0;aligned=0
for group,path in SETS.items():
 rows={};raw={}
 for name in ORDER:
  file=path/(name+".json.gz");r=json.load(gzip.open(file,"rt",encoding="utf-8"));raw[name]=r
  c=json.loads((path/("cpu-"+name+".json")).read_text());f=[x/1000 for x in r["frames_us"]];n=len(f);wall=sum(f)/1000
  assert n==len(r["samples"])
  elapsed=0;slow=[];step_prev=0;deltas=collections.Counter();step_cost=collections.defaultdict(list)
  for i,(duration,sample) in enumerate(zip(f,r["samples"])):
   elapsed+=duration;delta=sample["step"]-step_prev;step_prev=sample["step"];deltas[delta]+=1;step_cost[delta].append(duration)
   if duration>1000/30:
    slow.append({"frame_0based":i,"ms":duration,"step":sample["step"],"step_delta":delta,"wall_fraction":elapsed/(wall*1000),"game":sample["game"],"render":sample["render"]})
    slow_total+=1
    if sample["step"] in [60,61,120,180,240]:aligned+=1
  logic_halves=[[f[i] for i,s in enumerate(r["samples"]) if (s["step"]<=120)==first] for first in [True,False]]
  quarters=[[f[i] for i,s in enumerate(r["samples"]) if min(3,max(0,s["step"]-1)//60)==q] for q in range(4)]
  top_window=max(range(n-29),key=lambda i:sum(f[i:i+30]))
  rows[name]={"all":stats(f),"frame_halves":[stats(f[:n//2]),stats(f[n//2:])],"logic_halves":[stats(x) for x in logic_halves],"logic_quarters":[stats(x) for x in quarters],"slow_frames":slow,"worst30frame_window":{"start":top_window,"end":top_window+29,"mean_ms":statistics.mean(f[top_window:top_window+30])},"step_delta_counts":dict(deltas),"step_delta_means_ms":{str(k):statistics.mean(v) for k,v in step_cost.items()},"cpu_seconds":c["cpu_us"]/1e6,"cpu_window_seconds":c["cpu_window_seconds"],"frame_wall_seconds":wall,"cpu_per_wall":c["cpu_us"]/1e6/c["cpu_window_seconds"],"cpu_before_measurement_seconds":(c["begin"]["user_us"]+c["begin"]["kernel_us"])/1e6,"cpu_begin_handshake_us":r["cpu_begin_handshake_us"],"cpu_end_handshake_us":r["cpu_end_handshake_us"],"sampling_us":r["sampling_us"],"warmup_snapshot":r["before"],"beam_metrics_before":r.get("beam_metrics_before"),"damage_cache_before":r.get("damage_before"),"dll":r["dll_sha256"],"source":r["source"],"raw_sha256":hashlib.sha256(file.read_bytes()).hexdigest(),"startup_compile_import_messages":any(s in (path/(name+".txt")).read_text().lower() for s in ["compiling","importing","shader cache"])}
 for name in ORDER:
  for key in ["before","state_before","state_after","events"]:assert canonical(raw[name][key])==canonical(raw["A1"][key]),(group,name,key)
 pairs=[]
 for i in range(1,4):
  a,b=rows["A"+str(i)],rows["B"+str(i)]
  pairs.append({"pair":i,"A_minus_B_ms":{k:a["all"][k]-b["all"][k] for k in ["mean_ms","median_ms","p95_ms"]},"frame_half_A_minus_B_ms":[a["frame_halves"][j]["mean_ms"]-b["frame_halves"][j]["mean_ms"] for j in [0,1]],"logic_half_A_minus_B_ms":[a["logic_halves"][j]["mean_ms"]-b["logic_halves"][j]["mean_ms"] for j in [0,1]]})
 output["sets"][group]={"rows":rows,"pairs":pairs,"warmup_and_state_equal":True,"protocol":json.loads((path/"protocol.json").read_text())}
output["findings"]={"slow_frames_total":slow_total,"aligned_with_60_61_120_180_240":aligned,"remaining":"3 slow frames at183/184 immediately follow the180-step boundary. Association with simulation phase is proven; its producer is not identifiable in clean runs with empty phases.","warmup":"All12 before snapshots equal:180 steps,1178 fires,2925 hits,1836 purchases, game clock3.12; each final sample240 steps. GPU B1/B2/B3 all66 live quad builds before sampling. Damage B1/B2/B3 metric caches already built1054/1058/1052 rows. This proves workload warmup and prior use, not equivalent driver/font/OS caches.","cold_start":"No uniform first-candidate warm-up signature: GPU B1 slows in first half, damage B1 slows in second half; GPU B3 also has a slow first half. First-pair medians are negative too. Normal logs contain no compilation/import messages, but no compile/cache-hit telemetry was recorded; absence of such logs does not prove absence of lazy compilation.","cpu":"All process CPU windows aggregate all Godot threads. They cannot reveal main-thread preemption or distinguish GPU waits, engine contention and other processes. CPU values quantize to15.625ms. Wall-clock frame timestamps include any scheduling delays inside the interval. No scheduler trace, external process load or per-frame/thread CPU data exists.","measurement_limits":"Shared isolated project/cache across sequential fresh processes; no cache reset/precompiled-cache manifest or warmup wall/render-frame history. Fixed3s simulation warmup does not establish equal rendered warmup count. Deterministic A1 B1 B2 A2 A3 B3 order and one run/cell do not identify time/order effects independently from treatment. This is a design limitation, not proof of a particular bias direction.","acceptance":"Preserve original all-sample decisions and signed differences. No samples removed and no new test requested/performed. Neither first negative pair can be assigned to external user work or startup compilation from these records."}
(OUT/"analysis.json").write_text(json.dumps(output,indent=2),encoding="utf-8")
print(json.dumps({"pairs":{k:v["pairs"] for k,v in output["sets"].items()},"findings":output["findings"]},indent=2))
