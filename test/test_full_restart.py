"""Real process restart test; run via test/run.py in an isolated workspace."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
game = root / 'space-battleship'
# test/run.py copies scripts/data but intentionally does not duplicate engines.
engine = Path(os.environ['SPACE_BATTLESHIP_TEST_GODOT'])
for args in [ ['--headless', '--editor', '--import', '--quit'],
              ['--script', str(root / 'test/test_full_restart_driver.gd')] ]:
    result = subprocess.run([str(engine), '--path', str(game), *args], capture_output=True, timeout=60)
    if result.returncode:
        raise AssertionError(result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace'))
deadline = time.monotonic() + 60
marker = root / 'restart-result.json'
while not marker.exists() and time.monotonic() < deadline:
    time.sleep(0.2)
assert marker.exists(), 'New process did not execute updated code; inspect .runtime/full-restart*.log'
time.sleep(0.2)
before = json.loads((root / 'restart-before.json').read_text(encoding="utf-8"))
after = json.loads(marker.read_text(encoding="utf-8"))
assert before['pid'] != after['pid'], 'PID must change'
assert before['user'] == after['user'], 'Same isolated save directory'
assert after['code'] == 'fresh', 'Updated code must execute'
assert after['save']['resources']['1'] == 432123, 'Progress must survive'
for field in ('stage', 'groupIndex', 'distance'):
    assert after[field] == before[field], f'Current node must survive: {field}'
assert 'speed=5' in (Path(after['user']) / 'qa_settings.cfg').read_text(encoding="utf-8"), 'QA settings must survive'
while time.monotonic() < deadline:
    acknowledgements = [json.loads(p.read_text(encoding='utf-8')) for p in Path(after['user']).glob('restart-*.json')]
    if any(a.get('pid') == after['pid'] and a.get('state') == 'ready' and a.get('owns_progress') for a in acknowledgements): break
    time.sleep(0.2)
else: raise AssertionError('New process must acknowledge fully bound writer ownership')
host_log = game / '.runtime/full-restart.log'
while time.monotonic() < deadline and 'RESTART_READY ' not in host_log.read_text(encoding='utf-8', errors='replace'):
    time.sleep(0.2)
assert 'RESTART_READY ' in host_log.read_text(encoding='utf-8', errors='replace'), 'Restart host must verify acknowledgement, not only process creation'
print('PASS: busy guard, real new PID, updated source, same user directory, saved progress, current node, QA settings')
