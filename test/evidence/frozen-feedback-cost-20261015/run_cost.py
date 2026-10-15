"""One frozen laser/mixed feedback attribution, timer off/on/off per fixture."""
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
BASE = Path('D:/CodexBuild/space_idle/frozen-feedback-cost-qa-20261015')
DLL = Path('D:/CodexBuild/space_idle/compact-laser-20261015/bin/space_native.dll')
GODOT = Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA = '1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
FIXTURE_SHA = {
    'laser': '227f9cc6bba709ba29a41041c01eab3d4064e58cdc1fc23b0f4fb92e31cb9dfe',
    'mixed': 'cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4',
}
assert sha(DLL) == DLL_SHA
assert sha(GODOT) == 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'
assert subprocess.check_output(['git', 'diff', '--name-only', 'b6ab391e', 'HEAD', '--', 'space-battleship'], cwd=ROOT) == b''
for case, name in [('laser', 'combat_stress_fixture.gd'), ('mixed', 'mixed_fixture.gd')]:
    assert sha(FROZEN / name) == FIXTURE_SHA[case]
manifests = {}
for case in FIXTURE_SHA:
    with gzip.open(FROZEN / (case + '.json.gz'), 'rt', encoding='utf8') as stream:
        manifests[case] = json.load(stream)['stress']['config']


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf8')


def environment(case, arm):
    env = os.environ.copy()
    user = BASE / case / 'user'
    for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('TEMP', 'tmp'), ('TMP', 'tmp')]:
        env[key] = str(user / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(COST_CASE=case, COST_TIMER='on' if arm == 'on' else 'off', COST_RUN=f'{case}-{arm}',
               WEAPON_CASE=case, SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
    return env


assert len(sys.argv) == 1, 'One planned six-run series only'
BASE.mkdir(parents=True, exist_ok=True)
receipt = {
    'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'verified_production_ref': 'b6ab391e28ca55eb39827f95821bf94d95c8c8bb',
    'dll_sha256': DLL_SHA, 'engine_sha256': sha(GODOT),
    'driver_sha256': sha(E / 'cost_driver.gd'), 'counter_sha256': sha(E / 'qa_cost.gd'),
    'instrument_sha256': sha(E / 'instrument.py'), 'fixture_sha256': FIXTURE_SHA,
    'manifest_sha256': {case: hashlib.sha256(canonical(value)).hexdigest() for case, value in manifests.items()},
    'runs': {}, 'qa_sources': {},
}
for case, fixture_name in [('laser', 'combat_stress_fixture.gd'), ('mixed', 'mixed_fixture.gd')]:
    project = BASE / case / 'space-battleship'
    assert not project.exists(), 'Never overwrite earlier isolated project'
    project.mkdir(parents=True)
    for name in ('scripts', 'shaders', 'tools', 'data', 'config_excel', 'assets', 'addons', 'dev'):
        source = ROOT / 'space-battleship' / name
        if source.exists():
            shutil.copytree(source, project / name, ignore=shutil.ignore_patterns('.godot', '*.dll'))
    for name in ('project.godot', 'main.tscn', 'level_editor.tscn'):
        shutil.copy2(ROOT / 'space-battleship' / name, project / name)
    shutil.copy2(FROZEN / fixture_name, project / 'combat_stress_fixture.gd')
    shutil.copy2(ROOT / 'space-battleship/addons/native_battle/space_native.gdextension.in', project / 'space_native.gdextension')
    (project / 'bin').mkdir()
    shutil.copy2(DLL, project / 'bin/space_native.dll')
    (project / '.runtime').mkdir()
    shutil.copy2(E / 'cost_driver.gd', project / 'cost_driver.gd')
    shutil.copy2(E / 'qa_cost.gd', project / 'qa_cost.gd')
    patched = patch(project)
    assert sha(project / 'bin/space_native.dll') == DLL_SHA
    receipt['qa_sources'][case] = {'patched': patched, 'fixture_sha256': sha(project / 'combat_stress_fixture.gd'),
                                    'driver_sha256': sha(project / 'cost_driver.gd'), 'counter_sha256': sha(project / 'qa_cost.gd'),
                                    'dll_sha256': sha(project / 'bin/space_native.dll')}
    log = E / f'import-{case}.log'
    with log.open('w', encoding='utf8') as out:
        result = subprocess.run([str(GODOT), '--path', str(project), '--headless', '--editor', '--import', '--quit'],
                                env=environment(case, 'off'), stdout=out, stderr=subprocess.STDOUT, timeout=240)
    content = log.read_text(encoding='utf8', errors='replace')
    assert result.returncode == 0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content, (case, content[-3000:])
    receipt['qa_sources'][case]['import_log_sha256'] = sha(log)
    print('IMPORTED', case, flush=True)

for case in ('laser', 'mixed'):
    project = BASE / case / 'space-battleship'
    for arm in ('off-a', 'on', 'off-b'):
        name = f'{case}-{arm}'
        raw = E / (name + '.json')
        log = E / (name + '.log')
        assert not raw.exists() and not log.exists(), name + ' exists'
        with log.open('w', encoding='utf8') as out:
            result = subprocess.run([str(GODOT), '--path', str(project), '--rendering-method', 'gl_compatibility',
                                     '--max-fps', '0', '--disable-vsync', '--script', 'res://cost_driver.gd'],
                                    env=environment(case, arm), stdout=out, stderr=subprocess.STDOUT, timeout=300)
        content = log.read_text(encoding='utf8', errors='replace')
        assert result.returncode == 0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content, (name, content[-3000:])
        shutil.copy2(project / '.runtime/perf.json', raw)
        data = json.loads(raw.read_text(encoding='utf8'))
        assert data['run'] == name and data['case'] == case and data['timer'] == ('on' if arm == 'on' else 'off')
        assert data['loadout_manifest'] == manifests[case], name + ' frozen manifest mismatch'
        assert data['renderer'] == 'gl_compatibility' and data['native_active']
        assert data['focus_start'] and data['valid_frames'] == len(data['frames_us']) == len(data['frame_steps']), name
        assert data['before']['steps'] - data['initial']['steps'] >= 120
        assert data['after']['steps'] - data['before']['steps'] >= 240
        assert bool(data['qa_cost']['durations_us']) == (arm == 'on')
        receipt['runs'][name] = {'raw_sha256': sha(raw), 'log_sha256': sha(log), 'frames': len(data['frames_us']),
                                 'feedback_rows': data['after']['feedback_rows'] - data['before']['feedback_rows'],
                                 'qa_calls': data['qa_cost']['calls']}
        (E / 'progress.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
        print('DONE', name, receipt['runs'][name]['feedback_rows'], data['qa_cost']['calls'], flush=True)
