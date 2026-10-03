from pathlib import Path
import subprocess,json,datetime
ev=Path('/workspace/space-idle-independent-sol-high/test/progression/evidence/independent-sol-high-20261003')
r=subprocess.run(json.loads((ev/'own-supplied34-v23-beam-positive-defence-max300-noforge12h-command.json').read_text())["command"],cwd='/workspace/space-idle-independent-sol-high')
(ev/'own-supplied34-v23-beam-positive-defence-max300-noforge12h-exit.json').write_text(json.dumps({"exit_code":r.returncode,"ended_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2))
raise SystemExit(r.returncode)
