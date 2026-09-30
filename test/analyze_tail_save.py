"""Summarize save pipeline traces without treating queued latency as CPU time."""
import argparse
import json
import math
from pathlib import Path
from statistics import mean


def distribution(values):
    values=sorted(values)
    if not values:return {"count":0}
    return {"count":len(values),"avg":mean(values),"p95":values[min(len(values)-1,int(len(values)*.95))],"p99":values[min(len(values)-1,int(len(values)*.99))],"max":values[-1]}


def summarize(report):
    requests=report["save_traces"]
    for i,row in enumerate(requests):row["save_id"]=i
    saves=[row for row in requests if row.get("written", True)]
    keys=sorted({key for row in saves for key in row["stages_us"]})
    result={"requests":len(requests),"writes":len(saves),"successes":sum(row["success"] for row in saves),"bytes":distribution([row["bytes"] for row in saves]),"total_ms":distribution([row["total_us"]/1000 for row in saves]),"stages_ms":{key:distribution([row["stages_us"].get(key,0)/1000 for row in saves]) for key in keys}}
    result["cpu_ms"]=distribution([sum(row["stages_us"].get(key,0) for key in ["build","copy_transform","serialize_stringify","encode"])/1000 for row in saves])
    result["io_ms"]=distribution([sum(row["stages_us"].get(key,0) for key in ["open","write","flush_close","verify_read","replace"])/1000 for row in saves])
    result["over10_saves"]=sum(row["total_us"]>10000 for row in saves)
    result["over20_saves"]=sum(row["total_us"]>20000 for row in saves)
    result["over30_saves"]=sum(row["total_us"]>30000 for row in saves)
    result["blocking_ms"]=distribution([row.get("main_thread_save_us",row["total_us"])/1000 for row in requests])
    result["blocking_by_mode"]={mode:distribution([row.get("main_thread_save_us",row["total_us"])/1000 for row in requests if row.get("mode","synchronous")==mode]) for mode in sorted({row.get("mode","synchronous") for row in requests})}
    if any("front_total_us" in row for row in requests):
        result["frontend_ms"]=distribution([row["front_total_us"]/1000 for row in requests])
        result["request_to_commit_ms"]=distribution([row["request_to_commit_us"]/1000 for row in saves])
    reasons={}
    for row in saves:
        reason="+".join(key for key in row["reason"] if key!="end_frame_save_batch") or "frame_flush"
        reasons.setdefault(reason,[]).append(row)
    result["reasons"]={}
    for reason, rows in sorted(reasons.items()):
        result["reasons"][reason]={"count":len(rows),"bytes":distribution([row["bytes"] for row in rows]),"total_ms":distribution([row["total_us"]/1000 for row in rows]),"stages_ms":{key:distribution([row["stages_us"].get(key,0)/1000 for row in rows]) for key in keys}}
    frames=[frame for page in report["pages"] for frame in page["frames"]]
    result["frames"]={"count":len(frames),"wall_ms":distribution([frame["frame_ms"] for frame in frames]),"cpu_ms":distribution([frame["cpu_ms"] for frame in frames]),"over20":sum(frame["frame_ms"]>20 for frame in frames),"over33":sum(frame["frame_ms"]>33 for frame in frames)}
    result["pages"]={str(page["page"]):{"frame":page["frame_stats"],"cpu":page["cpu_stats"],"over20":sum(frame["frame_ms"]>20 for frame in page["frames"]),"over33":sum(frame["frame_ms"]>33 for frame in page["frames"])} for page in report["pages"]}
    result["long_run"]={"count":report["long_frame_count"],"max_ms":report["long_frame_max"],"checkpoints":report["long_run"]}
    result["containers"]=report.get("container_counts",{})
    result["slow_saves"]=sorted([row for row in saves if row["total_us"]>10000],key=lambda row:row["total_us"],reverse=True)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report",type=Path)
    args=parser.parse_args()
    report=json.loads(args.report.read_text(encoding="utf-8"))
    summary=summarize(report)
    path=args.report.with_name(args.report.stem+"-summary.json")
    path.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({key:summary[key] for key in ["requests","writes","total_ms","cpu_ms","io_ms","over10_saves","over20_saves","over30_saves","frames","long_run"]},ensure_ascii=False,indent=2))


if __name__=="__main__":main()
