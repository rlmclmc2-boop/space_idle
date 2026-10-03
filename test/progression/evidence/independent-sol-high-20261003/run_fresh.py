import json,subprocess,time,datetime
from pathlib import Path
ev=Path('/workspace/space-idle-independent-sol-high/test/progression/evidence/independent-sol-high-20261003')
cmd=json.loads((ev/"fresh-command.json").read_text())["command"]
r=subprocess.run(cmd,cwd='/workspace/space-idle-independent-sol-high')
(ev/"fresh-exit.json").write_text(json.dumps({"exit_code":r.returncode,"ended_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2))
raise SystemExit(r.returncode)
