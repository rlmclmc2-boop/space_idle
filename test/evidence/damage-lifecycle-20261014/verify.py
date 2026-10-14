from pathlib import Path
import gzip,json,statistics,subprocess,hashlib
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
def scrub(v):
 if isinstance(v,dict):return {k:scrub(x) for k,x in v.items() if k!="kernel_hash" and not(k=="seed" and v.get("class")=="RandomNumberGenerator")}
 if isinstance(v,list):return [scrub(x) for x in v]
 return v
raw={n:json.load(gzip.open(P/(n+".json.gz"),"rt",encoding="utf-8")) for n in ["A1","B1","B2","A2","A3","B3"]}
ref=raw["A1"]
for n,r in raw.items():
 for key in ["state_before","state_after","events"]:assert scrub(r[key])==scrub(ref[key]),(n,key)
 assert r["steps"]==r["native_steps"]==240 and r["physics_ticks_per_second"]==60 and r["config"]["speed"]==1
 assert not r["gpu_beams_enabled"] and r["damage_cache_enabled"]==n.startswith("B")
 assert r["extension_open"] and r["dll_sha256"]=="45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e"
 if n.startswith("B"):assert r["beam_metrics_before"]["live_quad_builds"]==r["beam_metrics_after"]["live_quad_builds"]==0
summary=json.loads((P/"comparison.json").read_text())
summary["equivalence"]="All six before/after canonical states and event counts equal, excluding RNG seed metadata and its derived kernel_hash only. RNG state retained."
summary["workload"]={n:{"frames":len(r["frames_us"]),"steps":r["steps"],"game_seconds":r["game_seconds"],"mean_projectiles":statistics.mean(x["projectiles"] for x in r["samples"]),"mean_floats":statistics.mean(x["floats"] for x in r["samples"]),"events":r["events"],"kernel_metrics_before":r["kernel_metrics_before"],"kernel_metrics_after":r["kernel_metrics_after"],"loaded_dll_path":r["loaded_dll_path"],"config":r["config"]} for n,r in raw.items()}
summary["percentiles_ms"]={n:{str(q):sorted(r["frames_us"])[min(len(r["frames_us"])-1,int(len(r["frames_us"])*q))]/1000 for q in [.5,.95,.99]} for n,r in raw.items()}
summary["production_tree_hashes"]={ref:subprocess.check_output(["git","rev-parse",ref+":space-battleship"],cwd=ROOT,text=True).strip() for ref in [summary["baseline"],summary["candidate"]]}
summary["scope"]="Exactly three predeclared short interleaved pairs, both sides GPU beams disabled; all prior accepted GPU contacts/projectiles retained. Same held-health15-enemy scene, AI factory/research/exploration, true1x60Hz, uncapped VSync0, sameDLL. 688 lifecycle differential checks and262 display/death/history checks pass. No result-dependent extra rounds."
summary["limitations"]="Concurrent user work uncontrolled and not stopped. Report all signs and drift. GPU beam candidate gains are not included. This evidence measures damage lifecycle only. No claim of under10ms or long-run/natural-save performance."
summary["decision"]="Report all pairs to parent; no GPU candidate gain credited. Retain only on evidence of complete frame benefit; no selective repeats or main changes."
summary["damage_cache_counts"]={n:{"before":r.get("damage_before"),"after":r.get("damage_after")} for n,r in raw.items() if n.startswith("B")}
(P/"decision.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in summary.items() if k not in ["cases","workload","percentiles_ms"]},indent=2))
