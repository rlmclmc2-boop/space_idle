"""One frozen mixed GL render attribution; QA draw wrappers, off/on/off."""
from pathlib import Path
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys

from instrument import patch, sha

ROOT = Path(__file__).resolve().parents[3]
E = Path(__file__).resolve().parent
FROZEN = ROOT / 'test/evidence/five-environment-20261015/baseline'
BASE = Path('D:/CodexBuild/space_idle/render-attribution-qa-20261015-live')
PROJECT = BASE / 'space-battleship'
DLL = Path('D:/CodexBuild/space_idle/compact-laser-20261015/bin/space_native.dll')
GODOT = Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA = '1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
FIXTURE_SHA = 'cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4'
assert len(sys.argv) == 1 and not PROJECT.exists(), 'One fresh three-arm series only'
assert sha(DLL) == DLL_SHA and sha(FROZEN / 'mixed_fixture.gd') == FIXTURE_SHA
assert sha(GODOT) == 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'
assert subprocess.check_output(['git', 'diff', '--name-only', 'b6ab391e', 'HEAD', '--', 'space-battleship'], cwd=ROOT) == b''
with gzip.open(FROZEN / 'mixed.json.gz', 'rt', encoding='utf8') as stream:
    manifest = json.load(stream)['stress']['config']


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf8')


def environment(arm):
    env = os.environ.copy()
    user = BASE / 'user'
    for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('TEMP', 'tmp'), ('TMP', 'tmp')]:
        env[key] = str(user / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(RENDER_CASE='mixed', RENDER_ARM='on' if arm == 'on' else 'off',
               RENDER_RUN='mixed-' + arm, WEAPON_CASE='mixed',
               SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
    return env


receipt = {'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
           'verified_production_ref': 'b6ab391e28ca55eb39827f95821bf94d95c8c8bb',
           'dll_sha256': DLL_SHA, 'engine_sha256': sha(GODOT), 'frozen_fixture_sha256': FIXTURE_SHA,
           'frozen_manifest_sha256': hashlib.sha256(canonical(manifest)).hexdigest(),
           'driver_sha256': sha(E / 'driver.gd'), 'ledger_sha256': sha(E / 'qa_draw_cost.gd'),
           'instrument_sha256': sha(E / 'instrument.py'), 'runs': {}}
PROJECT.mkdir(parents=True)
for name in ('scripts', 'shaders', 'tools', 'data', 'config_excel', 'assets', 'addons', 'dev'):
    source = ROOT / 'space-battleship' / name
    if source.exists():
        shutil.copytree(source, PROJECT / name, ignore=shutil.ignore_patterns('.godot', '*.dll'))
for name in ('project.godot', 'main.tscn', 'level_editor.tscn'):
    shutil.copy2(ROOT / 'space-battleship' / name, PROJECT / name)
shutil.copy2(FROZEN / 'mixed_fixture.gd', PROJECT / 'combat_stress_fixture.gd')
shutil.copy2(ROOT / 'space-battleship/addons/native_battle/space_native.gdextension.in', PROJECT / 'space_native.gdextension')
(PROJECT / 'bin').mkdir()
shutil.copy2(DLL, PROJECT / 'bin/space_native.dll')
(PROJECT / '.runtime').mkdir()
shutil.copy2(E / 'driver.gd', PROJECT / 'render_driver.gd')
shutil.copy2(E / 'qa_draw_cost.gd', PROJECT / 'qa_draw_cost.gd')
receipt['qa_patches'] = patch(PROJECT)
assert sha(PROJECT / 'bin/space_native.dll') == DLL_SHA
with (E / 'import.log').open('w', encoding='utf8') as out:
    result = subprocess.run([str(GODOT), '--path', str(PROJECT), '--headless', '--editor', '--import', '--quit'],
                            env=environment('off-a'), stdout=out, stderr=subprocess.STDOUT, timeout=240)
content = (E / 'import.log').read_text(encoding='utf8', errors='replace')
assert result.returncode == 0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content, content[-3000:]
receipt['import_log_sha256'] = sha(E / 'import.log')
print('IMPORTED', flush=True)
for arm in ('off-a', 'on', 'off-b'):
    name = 'mixed-' + arm
    raw = E / (name + '.json')
    log = E / (name + '.log')
    assert not raw.exists() and not log.exists()
    with log.open('w', encoding='utf8') as out:
        result = subprocess.run([str(GODOT), '--path', str(PROJECT), '--rendering-method', 'gl_compatibility',
                                 '--max-fps', '0', '--disable-vsync', '--script', 'res://render_driver.gd'],
                                env=environment(arm), stdout=out, stderr=subprocess.STDOUT, timeout=300)
    content = log.read_text(encoding='utf8', errors='replace')
    assert result.returncode == 0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content, (name, content[-3000:])
    shutil.copy2(PROJECT / '.runtime/perf.json', raw)
    data = json.loads(raw.read_text(encoding='utf8'))
    assert data['run'] == name and data['case'] == 'mixed' and data['timer'] == ('on' if arm == 'on' else 'off')
    assert data['loadout_manifest'] == manifest and data['renderer'] == 'gl_compatibility' and data['native_active']
    assert data['focus_start'] and data['valid_frames'] == len(data['frames_us']) == len(data['frame_steps']) == len(data['qa_frames']) == len(data['phases']) == len(data['render_pre']) == len(data['render_post'])
    assert data['before']['steps'] - data['initial']['steps'] >= 120
    assert data['after']['steps'] - data['before']['steps'] >= 240
    assert all(bool(x['durations_us']) == (arm == 'on') for x in data['qa_frames'] if x['calls'])
    receipt['runs'][name] = {'raw_sha256': sha(raw), 'log_sha256': sha(log), 'frames': len(data['frames_us']),
                             'zero_step_frames': data['frame_steps'].count(0)}
    (E / 'progress.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
    print('DONE', name, receipt['runs'][name], flush=True)

receipt['api_probe_sha256'] = sha(E / 'api_probe.gd')
receipt['api_probe_log_sha256'] = sha(E / 'api_probe.log')
(E / 'progress.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
