"""Recompute the single frozen mixed off/on/off zero-step publication probe."""
from collections import Counter
from pathlib import Path
import gzip
import hashlib
import json
import math

from instrument import sha

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
PROJECT = Path('D:/CodexBuild/space_idle/zero-step-publication-qa-20261015-repair/space-battleship')
FROZEN = ROOT / 'test/evidence/five-environment-20261015/baseline'
DLL = Path('D:/CodexBuild/space_idle/compact-laser-20261015/bin/space_native.dll')
GODOT = Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def mean(items):
    return sum(items) / len(items) if items else 0


def percentile(items, fraction):
    return sorted(items)[math.ceil(len(items) * fraction) - 1] if items else 0


def rounded(value):
    return round(value, 6)


receipt_path = E / ('receipt.json' if (E / 'receipt.json').exists() else 'progress.json')
receipt = json.loads(receipt_path.read_text())
assert sha(DLL) == sha(PROJECT / 'bin/space_native.dll') == receipt['dll_sha256']
assert sha(GODOT) == receipt['engine_sha256']
assert sha(FROZEN / 'mixed_fixture.gd') == sha(PROJECT / 'combat_stress_fixture.gd') == receipt['frozen_fixture_sha256']
assert sha(PROJECT / 'publication_driver.gd') == sha(E / 'driver.gd') == receipt['driver_sha256']
assert sha(PROJECT / 'qa_publication_cost.gd') == sha(E / 'qa_publication_cost.gd') == receipt['ledger_sha256']
assert sha(E / 'instrument.py') == receipt['instrument_sha256']
with gzip.open(FROZEN / 'mixed.json.gz', 'rt', encoding='utf8') as stream:
    manifest = json.load(stream)['stress']['config']
assert hashlib.sha256(canonical(manifest)).hexdigest() == receipt['frozen_manifest_sha256']
assert sha(E / 'import.log') == receipt['import_log_sha256']
receipt['failed_import_log_sha256'] = sha(E / 'import-failed.log')

patched = set(receipt['qa_patches'])
for name, hashes in receipt['qa_patches'].items():
    assert sha(ROOT / 'space-battleship/scripts' / name) == hashes['source_sha256']
    assert sha(PROJECT / 'scripts' / name) == hashes['qa_sha256']
other = 0
for path in (ROOT / 'space-battleship').rglob('*.gd'):
    if '.godot' in path.parts or path.name in patched or path.name == 'combat_stress_fixture.gd':
        continue
    target = PROJECT / path.relative_to(ROOT / 'space-battleship')
    if target.exists():
        assert sha(path) == sha(target), path
        other += 1
receipt['other_gd_files_identical'] = other
receipt['qa_project'] = str(PROJECT)

arms = {}
report = {'runs': {}, 'controls': {}, 'bounds': {}, 'source_attestation': {
    'other_gd_files_identical': other, 'qa_patches': receipt['qa_patches'],
    'dll_sha256': receipt['dll_sha256'], 'fixture_sha256': receipt['frozen_fixture_sha256']}}
for arm in ('off-a', 'on', 'off-b'):
    name = 'mixed-' + arm
    raw = E / (name + '.json')
    log = E / (name + '.log')
    data = json.loads(raw.read_text())
    assert sha(raw) == receipt['runs'][name]['raw_sha256']
    assert sha(log) == receipt['runs'][name]['log_sha256']
    assert data['run'] == name and data['case'] == 'mixed'
    assert data['timer'] == ('on' if arm == 'on' else 'off')
    assert data['loadout_manifest'] == manifest
    assert data['renderer'] == 'gl_compatibility' and data['native_active'] and data['focus_start']
    assert data['sample_target'] == 240 and data['warm_target'] == 120
    assert data['valid_frames'] == len(data['frames_us']) == len(data['frame_steps']) == len(data['qa_frames']) == len(data['wall_state'])
    assert data['after']['steps'] - data['before']['steps'] >= 240
    assert data['before']['steps'] - data['initial']['steps'] >= 120
    for qa in data['qa_frames']:
        assert bool(qa['durations_us']) == (arm == 'on')
    arms[arm] = data
    buckets = {}
    for bucket in ('zero', 'one', 'multi'):
        indexes = [i for i, steps in enumerate(data['frame_steps'])
                   if (steps == 0 if bucket == 'zero' else steps == 1 if bucket == 'one' else steps > 1)]
        frames = [data['frames_us'][i] / 1000 for i in indexes]
        calls = Counter()
        durations = Counter()
        for i in indexes:
            calls.update(data['qa_frames'][i]['calls'])
            durations.update(data['qa_frames'][i]['durations_us'])
        buckets[bucket] = {'frames': len(indexes), 'mean_ms': rounded(mean(frames)),
                           'p95_ms': rounded(percentile(frames, .95)),
                           'scope_calls': dict(sorted(calls.items())),
                           'scope_ms_per_frame': {key: rounded(value / 1000 / len(indexes))
                                                  for key, value in sorted(durations.items())}}
    zero_indexes = [i for i, steps in enumerate(data['frame_steps']) if steps == 0]
    prior = [i for i in zero_indexes if i > 0]
    wall_changes = {key: sum(data['wall_state'][i][index] != data['wall_state'][i - 1][index] for i in prior)
                    for index, key in enumerate(('fx_time', 'star_travel', 'shake', 'particle_count', 'float_count', 'scenery_time'))}
    report['runs'][name] = {'frames': len(data['frames_us']), 'steps': dict(sorted(Counter(map(str, data['frame_steps'])).items())),
                            'mean_ms': rounded(mean([v / 1000 for v in data['frames_us']])),
                            'p95_ms': rounded(percentile([v / 1000 for v in data['frames_us']], .95)),
                            'buckets': buckets, 'zero_frame_wall_state_changes_vs_prior': wall_changes,
                            'zero_frames_with_prior': len(prior)}

for key in ('initial', 'before', 'after', 'loadout_manifest'):
    assert arms['off-a'][key] == arms['on'][key] == arms['off-b'][key], key
assert all(report['runs']['mixed-' + arm]['buckets']['zero']['scope_calls'].get('static_part_draw', 0) == 0
           for arm in ('off-a', 'on', 'off-b'))
assert all(report['runs']['mixed-' + arm]['buckets']['zero']['scope_calls'].get('dynamic_part_draw', 0)
           == 2 * report['runs']['mixed-' + arm]['buckets']['zero']['frames'] for arm in ('off-a', 'on', 'off-b'))

off_a, on, off_b = (report['runs']['mixed-' + arm] for arm in ('off-a', 'on', 'off-b'))
for bucket in ('overall', 'zero', 'one'):
    values = [row['mean_ms'] if bucket == 'overall' else row['buckets'][bucket]['mean_ms']
              for row in (off_a, on, off_b)]
    report['controls'][bucket] = {'off_a_ms': values[0], 'timer_on_ms': values[1], 'off_b_ms': values[2],
                                  'on_minus_off_midpoint_ms': rounded(values[1] - (values[0] + values[2]) / 2),
                                  'off_off_drift_ms': rounded(abs(values[2] - values[0]))}

zero = on['buckets']['zero']
z = zero['scope_ms_per_frame']
share = zero['frames'] / on['frames']
strict = z['snapshot'] + z['apply_nodes']
generous = strict + z['retained_sync']
report['bounds'] = {'zero_step_fraction': rounded(share),
                    'snapshot_apply_gross_ms_per_zero_frame': rounded(strict),
                    'snapshot_apply_gross_ms_per_all_frame': rounded(strict * share),
                    'generous_plus_full_retained_sync_ms_per_zero_frame': rounded(generous),
                    'generous_plus_full_retained_sync_ms_per_all_frame': rounded(generous * share),
                    'generous_margin_above_0_5_ms_per_all_frame': rounded(generous * share - .5),
                    'required_gross_recovery_fraction_before_guard': rounded(.5 / (generous * share)),
                    'excluded_dynamic_foreground_ms_per_zero_frame': z['foreground_stage'],
                    'excluded_dynamic_part_draw_ms_per_zero_frame': z['dynamic_part_draw'],
                    'static_part_draw_calls_all_arms': 0}

(E / 'analysis.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
(E / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
print(json.dumps({'controls': report['controls'], 'bounds': report['bounds'],
                  'other_gd_files_identical': other}, indent=2))
