"""Summarize raw saved-game frame traces without changing the measured game."""
import argparse
import json
from collections import defaultdict
from pathlib import Path
from statistics import mean, median

def pct(values, q):
    values = sorted(values)
    return values[min(len(values)-1, int(len(values)*q))]

def stats(rows, field):
    values = [float(r[field]) for r in rows]
    return {"mean": round(mean(values), 3), "p50": round(median(values), 3), "p95": round(pct(values, .95), 3), "p99": round(pct(values, .99), 3), "max": round(max(values), 3)}

def modules(rows):
    totals = defaultdict(lambda: [0, 0, 0])
    for row in rows:
        for name, (_, calls, total_us, max_us) in row.get("modules", {}).items():
            value = totals[name]
            value[0] += calls
            value[1] += total_us
            value[2] = max(value[2], max_us)
    result = []
    for name, (calls, total_us, max_us) in totals.items():
        result.append({"name": name, "calls_per_frame": round(calls/len(rows), 3), "total_ms_per_frame": round(total_us/len(rows)/1000, 3), "max_call_ms": round(max_us/1000, 3)})
    return sorted(result, key=lambda r: r["total_ms_per_frame"], reverse=True)

def tail(rows, selector):
    picked = [r for r in rows if selector(r)]
    if not picked:
        return {"count": 0}
    result = {"count": len(picked)}
    for field in ("frame_ms", "cpu_ms", "gpu_ms", "render_ms", "process_ms", "physics_ms", "draw_calls", "render_objects", "primitives", "objects", "nodes", "memory_bytes", "projectiles", "enemies", "particles", "layout_events", "draw_events", "redraw_requests", "nodes_added", "nodes_removed"):
        result[field] = round(mean(float(r[field]) for r in picked), 3)
    result["modules"] = modules(picked)[:18]
    result["text_writes"] = sum(r.get("ui_writes", {}).get("text", 0) for r in picked)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("area", type=Path)
    args = parser.parse_args()
    area = args.area
    files = {}
    for path in area.glob("*-*.json"):
        candidate = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(candidate, dict) and "pages" in candidate:
            files[path.stem] = candidate
    baseline = files["baseline-1-plain"]
    detail = files["baseline-1-detail"]
    result = {"run_names": sorted(files), "save_sha256": baseline["save_sha256"], "baseline": [], "detail": [], "profiles": {}, "ab": [], "long_run": []}
    for page in baseline["pages"]:
        rows = page["frames"]
        entry = {"page": page["page"]}
        for field in ("frame_ms", "cpu_ms", "gpu_ms", "render_ms", "process_ms", "physics_ms", "draw_calls", "render_objects", "primitives", "objects", "nodes", "memory_bytes", "projectiles"):
            entry[field] = stats(rows, field)
        result["baseline"].append(entry)
    for profile_name, profile in files.items():
        if not profile_name.endswith("-detail"):
            continue
        summary = []
        for page in profile["pages"]:
            rows = page["frames"]
            p95 = pct([r["frame_ms"] for r in rows], .95)
            p99 = pct([r["frame_ms"] for r in rows], .99)
            entry = {"page": page["page"], "top_modules": modules(rows)[:25], "tail_p95": tail(rows, lambda r:r["frame_ms"]>=p95), "tail_p99": tail(rows, lambda r:r["frame_ms"]>=p99), "gt20": tail(rows, lambda r:r["frame_ms"]>20), "gt33": tail(rows, lambda r:r["frame_ms"]>33), "gt50": tail(rows, lambda r:r["frame_ms"]>50), "slowest": sorted(rows,key=lambda r:r["frame_ms"], reverse=True)[:5]}
            summary.append(entry)
        result["profiles"][profile_name] = summary
    result["detail"] = result["profiles"]["baseline-1-detail"]
    for name, report in files.items():
        if name.startswith("baseline-") or name.startswith("longrun-") or name.startswith("validation-"):
            continue
        if not name.endswith("-plain"):
            continue
        comparison = files["validation-1-plain"] if name.startswith("shader_off-") else baseline
        deltas = []
        for base_page, variant_page in zip(comparison["pages"], report["pages"]):
            assert base_page["page"] == variant_page["page"]
            deltas.append({"page": base_page["page"], "mean_delta_ms": round(variant_page["frame_stats"]["mean"]-base_page["frame_stats"]["mean"],3), "p95_delta_ms": round(variant_page["frame_stats"]["p95"]-base_page["frame_stats"]["p95"],3), "cpu_delta_ms": round(variant_page["cpu_stats"]["mean"]-base_page["cpu_stats"]["mean"],3), "gpu_delta_ms": round(variant_page["gpu_stats"]["mean"]-base_page["gpu_stats"]["mean"],3), "variant_mean_ms": round(variant_page["frame_stats"]["mean"],3)})
        result["ab"].append({"name": name, "deltas": deltas})
    if "longrun-1-fps60-detail" in files:
        result["long_run"] = files["longrun-1-fps60-detail"].get("long_run", [])
        result["long_run_traces"] = files["longrun-1-fps60-detail"].get("long_run_traces", [])
    path = area / "diagnosis-summary.json"
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path)
    for row in result["baseline"]:
        print("PAGE",row["page"],"frame",row["frame_ms"],"cpu",row["cpu_ms"],"gpu",row["gpu_ms"],"render",row["render_ms"])
    for row in result["ab"]:
        print("AB", row["name"], [(x["page"],x["mean_delta_ms"],x["cpu_delta_ms"]) for x in row["deltas"]])

if __name__ == "__main__":
    main()
