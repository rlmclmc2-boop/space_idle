"""Verify the isolated QA project after the corrected uptake probe."""
from pathlib import Path
import hashlib
import json

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
PROJECT = Path('D:/CodexBuild/space_idle/pulse-fixture-correction-qa-20261015/on/space-battleship')
receipt = json.loads((E / 'receipt.json').read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


expected = receipt['qa_sources']['on']
actual = {
    'session_sha256': sha(PROJECT / 'scripts/native_execution_session.gd'),
    'driver_sha256': sha(PROJECT / 'perf_driver.gd'),
    'dll_sha256': sha(PROJECT / 'bin/space_native.dll'),
}
assert actual == expected, (actual, expected)
assert sha(ROOT / 'test/evidence/five-environment-20261015/baseline/laser.json.gz') == receipt['frozen_laser_raw_sha256']
for label, name in [('laser', 'combat_stress_fixture.gd'), ('mixed', 'mixed_fixture.gd')]:
    assert sha(PROJECT / name) == receipt['frozen_fixture_sha256'][label]
count = 0
for part in ('scripts', 'addons'):
    for source in (ROOT / 'space-battleship' / part).rglob('*.gd'):
        relative = source.relative_to(ROOT / 'space-battleship')
        if relative.as_posix() == 'scripts/native_execution_session.gd':
            continue
        assert (PROJECT / relative).read_bytes() == source.read_bytes(), relative
        count += 1
for name in ('project.godot', 'main.tscn', 'level_editor.tscn'):
    assert (PROJECT / name).read_bytes() == (ROOT / 'space-battleship' / name).read_bytes(), name
assert sha(E / 'laser-on-probe.json') == receipt['runs']['laser-on-probe']['raw_sha256']
assert sha(E / 'laser-on-probe.log') == receipt['runs']['laser-on-probe']['log_checkout_sha256']
actual['other_gd_files_identical'] = count
actual['raw_sha256'] = receipt['runs']['laser-on-probe']['raw_sha256']
actual['log_sha256'] = receipt['runs']['laser-on-probe']['log_checkout_sha256']
(E / 'source-after.json').write_text(json.dumps(actual, indent=2) + '\n', encoding='utf8')
print(json.dumps(actual, indent=2))
