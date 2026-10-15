"""Recompute frozen feedback boundaries and control drift from raw JSON."""
from pathlib import Path
import gzip
import hashlib
import json
import math
import statistics

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
receipt = json.loads((E / 'receipt.json').read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf8')


def p95(values):
    return sorted(values)[math.ceil(len(values) * .95) - 1]


output = {'source_head': receipt['source_head'], 'dll_sha256': receipt['dll_sha256'], 'cases': {}, 'raw_sha256': {}}
for case in ('laser', 'mixed'):
    with gzip.open(ROOT / f'test/evidence/five-environment-20261015/baseline/{case}.json.gz', 'rt', encoding='utf8') as stream:
        frozen = json.load(stream)['stress']['config']
    assert hashlib.sha256(canonical(frozen)).hexdigest() == receipt['manifest_sha256'][case]
    rows = []
    summary = {}
    for arm in ('off-a', 'on', 'off-b'):
        name = f'{case}-{arm}'
        path = E / (name + '.json')
        log = E / (name + '.log')
        assert sha(path) == receipt['runs'][name]['raw_sha256']
        assert sha(log) == receipt['runs'][name]['log_sha256']
        output['raw_sha256'][path.name] = sha(path)
        output['raw_sha256'][log.name] = sha(log)
        row = json.loads(path.read_text(encoding='utf8'))
        assert row['loadout_manifest'] == frozen
        assert row['valid_frames'] == len(row['frames_us']) == len(row['frame_steps'])
        assert row['after']['steps'] - row['before']['steps'] == 240
        assert row['qa_cost']['calls']['consume_feedback'] == row['qa_cost']['calls']['take_feedback'] == 240
        assert sum(row['qa_cost']['calls'].get(key, 0) for key in ('fire_impact', 'hit', 'chain_secondary', 'other')) == receipt['runs'][name]['feedback_rows']
        assert row['qa_cost']['calls']['hit'] == row['qa_cost']['calls']['hit_label']
        assert bool(row['qa_cost']['durations_us']) == (arm == 'on')
        frames = [value / 1000 for value in row['frames_us']]
        busy = [value / 1000 for value, steps in zip(row['frames_us'], row['frame_steps']) if steps == 1]
        summary[arm] = {'frames': len(frames), 'one_step_frames': len(busy), 'full_mean_ms': statistics.mean(frames),
                        'full_p95_ms': p95(frames), 'one_step_mean_ms': statistics.mean(busy), 'one_step_p95_ms': p95(busy),
                        'feedback_rows': receipt['runs'][name]['feedback_rows'], 'calls': row['qa_cost']['calls']}
        if arm == 'on':
            summary[arm]['inclusive_ms_per_step'] = {key: value / 240000 for key, value in row['qa_cost']['durations_us'].items()}
            summary[arm]['inclusive_ms_per_displayed_frame'] = {key: value / (1000 * len(frames)) for key, value in row['qa_cost']['durations_us'].items()}
            summary[arm]['hit_without_label_ms_per_step'] = (row['qa_cost']['durations_us']['hit'] - row['qa_cost']['durations_us']['hit_label']) / 240000
        rows.append(row)
    assert rows[0]['initial'] == rows[1]['initial'] == rows[2]['initial']
    assert rows[0]['before'] == rows[1]['before'] == rows[2]['before']
    assert rows[0]['after'] == rows[1]['after'] == rows[2]['after']
    for metric in ('full_mean_ms', 'one_step_mean_ms'):
        summary[f'{metric}_on_minus_off_mid'] = summary['on'][metric] - (summary['off-a'][metric] + summary['off-b'][metric]) / 2
        summary[f'{metric}_off_drift'] = abs(summary['off-b'][metric] - summary['off-a'][metric])
    output['cases'][case] = summary
for name in ('import-laser.log', 'import-mixed.log'):
    assert sha(E / name) == receipt['qa_sources'][name.removeprefix('import-').removesuffix('.log')]['import_log_sha256']
    output['raw_sha256'][name] = sha(E / name)
(E / 'analysis.json').write_text(json.dumps(output, indent=2) + '\n', encoding='utf8')
print(json.dumps({case: {'timed': data['on']['inclusive_ms_per_step'],
                         'full_frame_timer_effect_ms': data['full_mean_ms_on_minus_off_mid'],
                         'full_frame_control_drift_ms': data['full_mean_ms_off_drift']}
                  for case, data in output['cases'].items()}, indent=2))
