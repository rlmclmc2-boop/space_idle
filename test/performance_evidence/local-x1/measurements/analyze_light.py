import json
import pathlib
import sys
from collections import Counter

for filename in sys.argv[1:]:
    path=pathlib.Path(filename)
    data=json.loads(path.read_text(encoding="utf-8"))
    rows=data["rows"]
    def distribution(key):
        values=sorted(row[key]/1000 for row in rows)
        return {"p50":values[len(values)//2],"p95":values[int((len(values)-1)*.95)],"p99":values[int((len(values)-1)*.99)],"max":values[-1],"over16.7":sum(x>16.7 for x in values)}
    events=Counter()
    for row in rows:events.update(row["events"])
    print(path.name,"frames",len(rows),"duration",round(rows[-1]["elapsed_us"]/1e6,3),"metadata",data["metadata"])
    print("frame_ms",distribution("frame_us"))
    print("main_ms",distribution("main_us"))
    print("events",dict(events))
    print("stage",rows[0]["stage"],rows[-1]["stage"],"enhancement_level",rows[0]["upgrade_level"],rows[-1]["upgrade_level"])
    for row in sorted(rows,key=lambda r:r["frame_us"],reverse=True)[:8]:
        print("top",round(row["elapsed_us"]/1e6,3),round(row["frame_us"]/1000,3),round(row["main_us"]/1000,3),row["events"],"enemies",row["enemies"],"projectiles",row["projectiles"])
