"""Recompute frozen mixed GL render attribution without merging CPU/GPU clocks."""
from collections import Counter
from pathlib import Path
import gzip
import hashlib
import json
import math
import statistics

from instrument import sha

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
PROJECT = Path('D:/CodexBuild/space_idle/render-attribution-qa-20261015-live/space-battleship')
FROZEN = ROOT / 'test/evidence/five-environment-20261015/baseline'
DLL = Path('D:/CodexBuild/space_idle/compact-laser-20261015/bin/space_native.dll')
GODOT = Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def mean(values):
    return statistics.mean(values) if values else 0


def p95(values):
    return sorted(values)[math.ceil(len(values) * .95) - 1] if values else 0


def r(value):
    return round(value, 6)


receipt_path = E / ('receipt.json' if (E / 'receipt.json').exists() else 'progress.json')
receipt = json.loads(receipt_path.read_text())
assert sha(DLL) == sha(PROJECT / 'bin/space_native.dll') == receipt['dll_sha256']
assert sha(GODOT) == receipt['engine_sha256']
assert sha(FROZEN / 'mixed_fixture.gd') == sha(PROJECT / 'combat_stress_fixture.gd') == receipt['frozen_fixture_sha256']
assert sha(PROJECT / 'render_driver.gd') == sha(E / 'driver.gd') == receipt['driver_sha256']
assert sha(PROJECT / 'qa_draw_cost.gd') == sha(E / 'qa_draw_cost.gd') == receipt['ledger_sha256']
assert sha(E / 'instrument.py') == receipt['instrument_sha256']
assert sha(E / 'api_probe.gd') == receipt['api_probe_sha256']
assert sha(E / 'api_probe.log') == receipt['api_probe_log_sha256']
assert sha(E / 'import.log') == receipt['import_log_sha256']
with gzip.open(FROZEN / 'mixed.json.gz', 'rt', encoding='utf8') as source:
    manifest = json.load(source)['stress']['config']
assert hashlib.sha256(canonical(manifest)).hexdigest() == receipt['frozen_manifest_sha256']

for name, hashes in receipt['qa_patches'].items():
    assert sha(ROOT / 'space-battleship/scripts' / name) == hashes['source_sha256']
    assert sha(PROJECT / 'scripts' / name) == hashes['qa_sha256']
other_gd = 0
for path in (ROOT / 'space-battleship').rglob('*.gd'):
    if '.godot' in path.parts or path.name in receipt['qa_patches'] or path.name == 'combat_stress_fixture.gd':
        continue
    target = PROJECT / path.relative_to(ROOT / 'space-battleship')
    if target.exists():
        assert sha(path) == sha(target), path
        other_gd += 1
receipt['other_gd_files_identical'] = other_gd
receipt['failed_logs_sha256'] = {name: sha(E / name) for name in
                                 ('failed-off-a.log', 'failed-import.log', 'failed2-off-a.log',
                                  'failed2-on.log', 'failed2-import.log', 'failed2-off-a.json',
                                  'failed2-progress.json')}

data = {}
report = {'runs': {}, 'controls': {}, 'engine_read_alignment': {}, 'attestation': {
    'other_gd_files_identical': other_gd, 'qa_patches': receipt['qa_patches'],
    'dll_sha256': receipt['dll_sha256'], 'fixture_sha256': receipt['frozen_fixture_sha256']}}
for arm in ('off-a', 'on', 'off-b'):
    name = 'mixed-' + arm
    raw = E / (name + '.json')
    log = E / (name + '.log')
    x = json.loads(raw.read_text())
    assert sha(raw) == receipt['runs'][name]['raw_sha256']
    assert sha(log) == receipt['runs'][name]['log_sha256']
    assert x['run'] == name and x['case'] == 'mixed' and x['timer'] == ('on' if arm == 'on' else 'off')
    assert x['renderer'] == 'gl_compatibility' and x['native_active'] and x['focus_start']
    assert x['loadout_manifest'] == manifest and x['sample_target'] == 240 and x['warm_target'] == 120
    n = len(x['frames_us'])
    assert x['valid_frames'] == n == len(x['frame_steps']) == len(x['qa_frames']) == len(x['phases']) == len(x['render_pre']) == len(x['render_post'])
    assert x['before']['steps'] - x['initial']['steps'] >= 120
    assert x['after']['steps'] - x['before']['steps'] >= 240
    assert all(bool(q['durations_us']) == (arm == 'on') for q in x['qa_frames'] if q['calls'])
    assert x['viewport_inventory'] == x['viewport_inventory_end']
    assert [v['class'] for v in x['viewport_inventory']].count('Window') == 1
    assert [v['class'] for v in x['viewport_inventory']].count('AcceptDialog') == 3
    for p in x['phases']:
        assert p['previous_post_us'] <= p['main_begin_us'] <= p['main_end_us'] <= p['pre_draw_us'] <= p['post_draw_us']
    data[arm] = x
    buckets = {}
    for bucket in ('zero', 'one', 'multi', 'all'):
        ids = [i for i, steps in enumerate(x['frame_steps'])
               if bucket == 'all' or (steps == 0 if bucket == 'zero' else steps == 1 if bucket == 'one' else steps > 1)]
        vals = lambda fn: [fn(i) for i in ids]
        frame_ms = vals(lambda i: x['frames_us'][i] / 1000)
        phase_fns = {
            'post_to_main': lambda p: (p['main_begin_us'] - p['previous_post_us']) / 1000,
            'main': lambda p: (p['main_end_us'] - p['main_begin_us']) / 1000,
            'main_to_pre': lambda p: (p['pre_draw_us'] - p['main_end_us']) / 1000,
            'pre_to_post': lambda p: (p['post_draw_us'] - p['pre_draw_us']) / 1000,
        }
        calls = Counter()
        durations = Counter()
        for i in ids:
            calls.update(x['qa_frames'][i]['calls'])
            durations.update(x['qa_frames'][i]['durations_us'])
        row = {'frames': len(ids), 'frame_mean_ms': r(mean(frame_ms)), 'frame_p95_ms': r(p95(frame_ms)),
               'phase_mean_ms': {key: r(mean(vals(lambda i: f(x['phases'][i])))) for key, f in phase_fns.items()},
               'draw_calls': dict(sorted(calls.items())),
               'draw_scope_ms_per_frame': {key: r(value / 1000 / len(ids)) for key, value in sorted(durations.items())},
               'draw_scope_total_ms_per_frame': r(sum(durations.values()) / 1000 / len(ids))}
        if arm == 'on':
            active = [v['path'] for v in x['viewport_inventory'] if v['path'] == '/root' or v['path'].endswith('/ShipViewport')]
            row['render_reported_at_post'] = {}
            row['render_if_one_frame_delayed'] = {}
            for path in active:
                values = [(i, x['render_post'][i]['viewports'][path]) for i in ids]
                valid = [(i, value) for i, value in values if value[0] > 0 and value[1] > 0]
                row['render_reported_at_post'][path] = {
                    'nonzero': len(valid), 'cpu_mean_ms': r(mean([v[0] for _, v in valid])),
                    'gpu_mean_ms': r(mean([v[1] for _, v in valid]))}
                delayed_ids = [i + 1 for i in ids if i + 1 < n]
                delayed = [x['render_post'][i]['viewports'][path] for i in delayed_ids]
                delayed = [value for value in delayed if value[0] > 0 and value[1] > 0]
                row['render_if_one_frame_delayed'][path] = {
                    'nonzero': len(delayed), 'cpu_mean_ms': r(mean([v[0] for v in delayed])),
                    'gpu_mean_ms': r(mean([v[1] for v in delayed]))}
            row['setup_cpu_mean_ms'] = r(mean(vals(lambda i: x['render_post'][i]['setup_cpu'])))
            row['query_pre_post_mean_ms'] = r(mean(vals(lambda i: (x['render_pre'][i]['query_us'] + x['render_post'][i]['query_us']) / 1000)))
        buckets[bucket] = row
    report['runs'][name] = {'steps': dict(sorted(Counter(map(str, x['frame_steps'])).items())), 'buckets': buckets,
                            'viewport_inventory': x['viewport_inventory']}

for field in ('initial', 'before', 'after', 'loadout_manifest'):
    assert data['off-a'][field] == data['on'][field] == data['off-b'][field], field
on = data['on']
report['engine_read_alignment'] = {
    'viewport_pre_equals_post_same_iteration': sum(a['viewports'] == b['viewports'] for a, b in zip(on['render_pre'], on['render_post'])),
    'viewport_pre_equals_previous_post': sum(on['render_pre'][i]['viewports'] == on['render_post'][i - 1]['viewports'] for i in range(1, len(on['frames_us']))),
    'setup_pre_equals_previous_post': sum(on['render_pre'][i]['setup_cpu'] == on['render_post'][i - 1]['setup_cpu'] for i in range(1, len(on['frames_us']))),
    'first_nonzero_viewport_index': next(i for i, row in enumerate(on['render_post']) if row['viewports']['/root'][0] > 0),
}
for bucket in ('all', 'zero', 'one'):
    a, b, c = (report['runs']['mixed-' + arm]['buckets'][bucket] for arm in ('off-a', 'on', 'off-b'))
    report['controls'][bucket] = {'on_minus_off_midpoint_frame_ms': r(b['frame_mean_ms'] - (a['frame_mean_ms'] + c['frame_mean_ms']) / 2),
                                  'off_off_frame_drift_ms': r(abs(c['frame_mean_ms'] - a['frame_mean_ms']))}
    for phase in ('main', 'main_to_pre', 'pre_to_post'):
        report['controls'][bucket][phase + '_on_minus_off_midpoint_ms'] = r(b['phase_mean_ms'][phase] - (a['phase_mean_ms'][phase] + c['phase_mean_ms'][phase]) / 2)
        report['controls'][bucket][phase + '_off_off_drift_ms'] = r(abs(c['phase_mean_ms'][phase] - a['phase_mean_ms'][phase]))

(E / 'analysis.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
(E / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
print(json.dumps({'controls': report['controls'], 'alignment': report['engine_read_alignment'],
                  'busy_on': report['runs']['mixed-on']['buckets']['one'],
                  'other_gd_files_identical': other_gd}, indent=2))
