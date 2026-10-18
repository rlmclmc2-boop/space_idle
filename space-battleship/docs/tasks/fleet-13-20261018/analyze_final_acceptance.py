"""Offline assertions for the final five paired full-picture measurements."""
from pathlib import Path
import copy
import gzip
import hashlib
import json
import statistics
import struct

task=Path(__file__).resolve().parent
root=task/"evidence/final-acceptance"
summary=json.loads((root/"summary.json").read_text(encoding="utf-8"))
cases=("mixed","laser","cannon","missile","longLaser")
assert set(summary["cases"])==set(cases)


def state_projection(state):
    value=copy.deepcopy(state)
    value.pop("kernel_hash",None)  # Derived from the unnormalized export.
    value["canonical_kernel"]["rng"].pop("seed",None)
    return value


def audit_pair(folder,case,entry):
    pair=[]
    for label in ("before","after"):
        stem=folder/(case+"-"+label)
        with gzip.open(str(stem)+".json.gz","rt",encoding="utf-8") as stream:
            row=json.load(stream)
        assert row["native_admitted"] and row["actual_1x_pass"] and row["performance_sample_valid"]
        assert row["sampling_focus"] and row["window_focused"] and not row["background_unfocused"]
        assert row["warm_steps"]==240 and row["sample_steps"]==480
        cfg=row["sampling_config"]
        assert cfg["stat_cache_enabled"] and not cfg["save_enabled"] and cfg["native_active"]
        assert cfg["engine_max_fps"]==0 and cfg["vsync"]==0 and cfg["speed"]==1 and cfg["time_scale"]==1
        assert len(row["frames_us_raw"])==len(row["phases"])==len(row["frame_trace"])
        assert all(f["window_focused"] and not f["unfocused"] for f in row["frame_trace"])
        log=Path(str(stem)+".log").read_text(encoding="utf-8")
        assert "PORT_PERF_DONE" in log and "SCRIPT ERROR" not in log
        png=Path(str(stem)+".png").read_bytes()
        assert png[:8]==b"\x89PNG\r\n\x1a\n" and struct.unpack(">II",png[16:24])==(1372,883)
        values=sorted(row["frames_us_raw"])
        assert abs(statistics.mean(values)/1000-entry[label]["mean_ms"])<1e-12
        assert values[int((len(values)-1)*.95)]/1000==entry[label]["p95_ms"]
        pair.append(row)
    a,b=pair
    assert a["events"]==b["events"] and a["stress"]["counts"]==b["stress"]["counts"]
    assert a["legendary_counts"]==b["legendary_counts"]
    for boundary in ("state_before","state_after"):
        assert state_projection(a[boundary])==state_projection(b[boundary])
    return {"all_events_equal":True,"equipment_stats":[a["events"].get("equipment_stats",0),b["events"].get("equipment_stats",0)],
            "full_start_and_final_state_equal":True,"stress_and_legendary_counts_equal":True,
            "valid_full_picture_samples":True,"adapter":a["video_adapter"],"engine":a["engine_version"],
            "reported_window":a["sampling_config"]["window"],"captured_framebuffer":[1372,883],
            "mean_ms":[entry["before"]["mean_ms"],entry["after"]["mean_ms"]],
            "p95_ms":[entry["before"]["p95_ms"],entry["after"]["p95_ms"]]}


audit={"baseline":summary["baseline"],"candidate":summary["candidate"],"cases":{},
       "state_equality_exception":"Historical canonical_kernel.rng.seed differs; transferred rng.state matches. Derived kernel_hash is excluded. No gameplay field is excluded.",
       "dll_sha256":"B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA"}
for case in cases:
    audit["cases"][case]=audit_pair(root,case,summary["cases"][case])
confirmation=root/"mixed-confirmation"
if (confirmation/"summary.json").exists():
    extra=json.loads((confirmation/"summary.json").read_text(encoding="utf-8"))
    assert extra["first_pair_reversed"]
    audit["mixed_reverse_order_confirmation"]=audit_pair(confirmation,"mixed",extra["cases"]["mixed"])
audit["raw_sha256"]={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted(root.rglob("*")) if p.is_file() and (p.name.endswith(".json.gz") or p.suffix in (".png",".log"))}
(root/"audit.json").write_text(json.dumps(audit,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("FINAL_ACCEPTANCE_PASS cases=5 all_events=true full_states=true focused_full_picture=true")
