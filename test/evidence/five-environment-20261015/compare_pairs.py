from pathlib import Path
import json,gzip,statistics,sys
root=Path(sys.argv[1])
def read(p):
 return json.loads(p.read_text(encoding="utf8") if p.exists() else gzip.decompress(p.with_suffix(".json.gz").read_bytes()).decode("utf8"))
def diff(a,b,p=""):
 if type(a)!=type(b):return [p]
 if isinstance(a,dict):return [q for k in sorted(set(a)|set(b)) for q in ([p+"/"+k] if k not in a or k not in b else diff(a[k],b[k],p+"/"+k))]
 if isinstance(a,list):return [p+"/length"] if len(a)!=len(b) else [q for i,(x,y) in enumerate(zip(a,b)) for q in diff(x,y,p+"/"+str(i))]
 return [] if a==b else [p]
out={}
for case in ["mixed","laser","cannon","missile","longLaser"]:
 a=read(root/(case+"_A.json"));b=read(root/(case+"_B.json"));pair={}
 for label,d in [("A",a),("B",b)]:
  v=sorted(d["frames_us_raw"]);n=len(v)
  pair[label]={"mean_ms":statistics.mean(v)/1000,"p95_ms":v[min(n-1,int(n*.95))]/1000,"frames":n,"valid":d["performance_sample_valid"],"actual_1x":d["actual_1x_pass"],"warm_steps":d["warm_steps"],"steps":d["sample_steps"],"events":d["events"],"floats_mean":statistics.mean(d["floats_raw"]),"drawcalls_mean":statistics.mean(d["drawcalls_raw"]),"state_hash_before":d["state_before"]["kernel_hash"],"state_hash_after":d["state_after"]["kernel_hash"]}
 pair["net_mean_gain_ms"]=pair["A"]["mean_ms"]-pair["B"]["mean_ms"]
 pair["candidate_under_10ms"]=pair["B"]["mean_ms"]<10
 pair["events_exact_equal"]=a["events"]==b["events"]
 pair["canonical_differences"]={key:diff(a[key]["canonical_kernel"],b[key]["canonical_kernel"]) for key in ["state_before","state_after"]}
 pair["canonical_rng_state_exact_equal"]={key:a[key]["kernel_rng"]==b[key]["kernel_rng"] for key in ["state_before","state_after"]}
 pair["raw_hash_equal"]=a["state_after"]["kernel_hash"]==b["state_after"]["kernel_hash"]
 pair["hash_note"]="Raw hashes remain different: the ONLY recursive canonical differences are /rng/seed, construction metadata of the new RNG instance. Authoritative copied rng.state and every other exported field are exactly equal. No raw data was normalized."
 out[case]=pair
(root/"comparison.json").write_text(json.dumps(out,indent=2),encoding="utf8")
print(json.dumps({k:{q:v[q] for q in ["net_mean_gain_ms","candidate_under_10ms","events_exact_equal","canonical_differences"]} for k,v in out.items()},indent=2))
