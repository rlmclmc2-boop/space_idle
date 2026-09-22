"""Summarize completed FAST Accuracy Benchmark pairs; never estimate missing runs."""
import argparse
import json
from pathlib import Path
from statistics import mean


def metrics(run):
    result = {key: run[key] for key in ('final_stage', 'dps', 'normal_ttk', 'boss_ttk', 'upgrades')}
    result['total_damage'] = sum(run['damage'].values())
    result['first_death_seconds'] = (run['defence']['first_death'] or {}).get('time')
    result['deaths'] = run['defence']['deaths']
    for section in ('income', 'spending', 'balance'):
        result.update({f'{section}/{key}': value for key, value in run['resources'][section].items()})
    result.update({f'weapon_share/{key}': value*100 for key, value in run['weapon_damage_share'].items()})
    result.update({f'uses/{key}': value for key, value in run['system_uses'].items()})
    return result


def summarize(directory):
    groups = {}
    for path in directory.glob('accuracy_*.json'):
        run = json.loads(path.read_text(encoding='utf-8'))
        key = (run['config']['duration'], run['seed'])
        groups.setdefault(key, {})[run['simulation_mode']] = run
    results = {}
    for duration in sorted({key[0] for key in groups}):
        pairs = [(seed, modes['exact'], modes['fast']) for (seconds, seed), modes in groups.items()
                 if seconds == duration and set(modes) == {'exact', 'fast'}]
        if not pairs:
            continue
        rows = []
        for key in metrics(pairs[0][1]):
            exact_values, fast_values, errors, missing = [], [], [], []
            absolute = key == 'final_stage' or key.startswith('weapon_share/')
            for seed, exact, fast in pairs:
                assert exact['config']['data_sha256'] == fast['config']['data_sha256']
                assert exact.get('strategy') == fast.get('strategy')
                for setting in ('policy', 'step_seconds', 'initial_state', 'sample_interval', 'max_samples'):
                    assert exact['config'].get(setting) == fast['config'].get(setting)
                a, b = metrics(exact)[key], metrics(fast)[key]
                if a is not None: exact_values.append(a)
                if b is not None: fast_values.append(b)
                if a is None or b is None:
                    if a != b: missing.append(seed)
                    continue
                if absolute: error = abs(b-a)
                elif a != 0: error = abs(b-a)/abs(a)*100
                elif b == 0: error = 0
                else:
                    missing.append(seed)  # Undefined relative error is never reported as zero.
                    continue
                errors.append((error, seed))
            worst = max(errors, default=(None, None))
            rows.append(dict(metric=key, exact=mean(exact_values) if exact_values else None,
                             fast=mean(fast_values) if fast_values else None,
                             avg_error=mean(e for e, _ in errors) if errors else None,
                             max_error=worst[0], worst_seed=worst[1],
                             unit='stage' if key == 'final_stage' else 'pp' if absolute else '%',
                             valid_pairs=len(errors), undefined_or_presence_mismatch_seeds=missing))
        exact_time = sum(a['wall_seconds'] for _, a, _ in pairs)
        fast_time = sum(b['wall_seconds'] for _, _, b in pairs)
        limits = {'dps': 2, 'normal_ttk': 3, 'boss_ttk': 5, 'first_death_seconds': 5}
        for row in rows:
            key = row['metric']
            limit = limits.get(key, 1 if key.startswith(('income/', 'spending/', 'balance/')) else 3 if key.startswith('weapon_share/') else None)
            row['reference_limit'] = limit
            row['within_reference'] = (not row['undefined_or_presence_mismatch_seeds'] and row['max_error'] <= limit
                                       if limit is not None and row['max_error'] is not None else None)
        results[str(duration)] = dict(pairs=len(pairs), rows=rows,
            performance=dict(exact_seconds=exact_time, fast_seconds=fast_time, speedup=exact_time/fast_time),
            identical_core_seeds=[seed for seed, a, b in pairs if a['core_hash'] == b['core_hash']],
            stage_within_one=sum(abs(a['final_stage']-b['final_stage']) <= 1 for _, a, b in pairs),
            projectile_processing={str(seed): b['projectile_processing'] for seed, _, b in pairs})
    return dict(results=results, incomplete_pairs=[list(key) for key, modes in groups.items() if len(modes) != 2])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--performance', type=Path, help='Optional late-fixture fast_performance.json')
    args = parser.parse_args()
    report = summarize(args.directory)
    if args.performance:
        measurements = json.loads(args.performance.read_text(encoding='utf-8'))
        performance = []
        for scale in sorted({r['scale'] for r in measurements}, reverse=True):
            exact = {r['repeat']: r for r in measurements if r['scale'] == scale and r['simulation_mode'] == 'exact'}
            fast = {r['repeat']: r for r in measurements if r['scale'] == scale and r['simulation_mode'] == 'fast'}
            paired = sorted(exact.keys() & fast.keys())
            if not paired: continue
            a = mean(exact[i]['seconds'] for i in paired)
            b = mean(fast[i]['seconds'] for i in paired)
            performance.append(dict(speed_scale=scale, pairs=len(paired), exact_seconds=a, fast_seconds=b,
                speedup=a/b, exact_average_projectiles=mean(exact[i]['average'] for i in paired),
                exact_peak_projectiles=max(exact[i]['peak'] for i in paired),
                identical_core_pairs=sum(exact[i]['core_hash'] == fast[i]['core_hash'] for i in paired)))
        report['late_performance'] = performance
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    lines = ['# FAST Accuracy Benchmark', '', 'Errors use paired absolute relative error; stage uses absolute difference, shares use percentage points.',
             'Null means unavailable, never zero. Presence mismatch and zero-reference/nonzero-FAST are reported separately. Times include final reporting.', '']
    def display(value):
        return 'N/A' if value is None else f'{value:.6g}'
    for duration, group in report['results'].items():
        lines += [f'## {duration}s ({group["pairs"]} pairs)', '', 'Metric | Exact | Fast | Avg Error | Max Error', '--- | ---: | ---: | ---: | ---:']
        for row in group['rows']:
            lines.append(' | '.join([row['metric'], display(row['exact']), display(row['fast']),
                display(row['avg_error'])+' '+row['unit'], display(row['max_error'])+' '+row['unit']]))
        p = group['performance']
        lines += ['', 'Test | Exact Time | Fast Time | Speedup', '--- | ---: | ---: | ---:',
                  f'{duration}s × {group["pairs"]} | {p["exact_seconds"]:.3f}s | {p["fast_seconds"]:.3f}s | {p["speedup"]:.3f}×', '',
                  'Outliers: '+json.dumps([r for r in group['rows'] if (r['max_error'] or 0)>0 or r['undefined_or_presence_mismatch_seeds']],ensure_ascii=False), '']
    if 'late_performance' in report:
        lines += ['## Late fixture performance', '', 'Test | Exact Time | Fast Time | Speedup', '--- | ---: | ---: | ---:']
        for row in report['late_performance']:
            lines.append(f'Projectile speed {row["speed_scale"]}×, P mean {row["exact_average_projectiles"]:.1f}, peak {row["exact_peak_projectiles"]} | {row["exact_seconds"]:.3f}s | {row["fast_seconds"]:.3f}s | {row["speedup"]:.3f}×')
        lines += ['', 'Each time is the mean of completed paired 60s fixed-build runs. The JSON records pair counts and core equality.']
    args.output.with_suffix('.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps({k:dict(pairs=v['pairs'],performance=v['performance'],identical_core_seeds=v['identical_core_seeds']) for k,v in report['results'].items()}))


if __name__ == '__main__':
    main()
