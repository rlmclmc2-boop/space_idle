"""Pair the narrow geometry-corrected repeat30 probes and flag inherited bad geometry."""
import argparse, collections, csv, json, pathlib, statistics

parser = argparse.ArgumentParser()
parser.add_argument('repeat30', type=pathlib.Path)
parser.add_argument('corrected_cited', type=pathlib.Path)
parser.add_argument('--extra-seeds', type=pathlib.Path)
parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path(__file__).parent / 'enhancement_balance_report' / 'repeat30_supplement')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
data = json.loads(args.repeat30.read_text())
corrections = json.loads(args.corrected_cited.read_text())
assert len(data['rows']) == 256 and len(corrections['rows']) == 40, 'Incomplete bounded supplement'
assert data['commit'] == corrections['commit'] == 'ef848c50042a0ee326f8a823721204bac7d2eedc'
extra = json.loads(args.extra_seeds.read_text()) if args.extra_seeds else None
if extra:
    assert len(extra['rows']) == 128 and extra['commit'] == data['commit']
    assert all(row['scenario_inputs']['enemies'] == 3 for row in extra['rows'])
rows = []
datasets = [(data, 'repeat30'), (corrections, 'corrected_cited')] + ([(extra, 'repeat30')] if extra else [])
for dataset, label in datasets:
    for record in dataset['rows']:
        row = dict(record, stage=label, runtime_commit=dataset['commit'])
        counts = row['event_counts']
        row.update(secondary_events=counts.get('event_enhancement_secondary', 0), extra_repeat_events=counts.get('canonical_extra_repeat', 0), primary_events=counts.get('canonical_primary', 0))
        rows.append(row)

def write_csv(path, records):
    keys = list(dict.fromkeys(key for row in records for key in row))
    with path.open('w', newline='', encoding='utf-8-sig') as stream:
        writer = csv.DictWriter(stream, fieldnames=keys, lineterminator="\n")
        writer.writeheader()
        for row in records:
            writer.writerow({key: json.dumps(value, ensure_ascii=False, separators=(',', ':')) if isinstance(value, (dict, list)) else value for key, value in row.items()})

write_csv(args.output / 'corrected_rows.csv', rows)
groups = collections.defaultdict(dict)
for row in rows:
    groups[row['stage'], row['scenario']][row['tag'], row['seed']] = row
paired = []
for (stage, scenario), records in groups.items():
    patterns = [('repeat:--A', 'repeat:--B'), ('repeat:AAA', 'repeat:AAB')] if stage == 'repeat30' else [(tag, tag[:-1] + 'B') for tag, seed in records if tag.endswith('A')]
    for atag, btag in dict.fromkeys(patterns):
        seeds = sorted(seed for tag, seed in records if tag == atag)
        pairs = [(records[atag, seed], records[btag, seed]) for seed in seeds]
        amean = statistics.mean(a['dps'] for a, b in pairs)
        bmean = statistics.mean(b['dps'] for a, b in pairs)
        delta = [b['dps'] - a['dps'] for a, b in pairs]
        cleared = [(a, b) for a, b in pairs if a.get('wave_cleared') and b.get('wave_cleared')]
        paired.append(dict(stage=stage, scenario=scenario, A=atag, B=btag, paired_seeds=len(pairs), A_dps=amean, B_dps=bmean, B_over_A_mean_dps=bmean / amean if amean else None, B_dps_wins=sum(d > 0 for d in delta), dps_ties=sum(d == 0 for d in delta), paired_dps_difference_mean=statistics.mean(delta), paired_difference_sd=statistics.stdev(delta) if len(delta) > 1 else None, A_secondary=sum(a['secondary_events'] for a, b in pairs), B_secondary=sum(b['secondary_events'] for a, b in pairs), A_extra_repeats=sum(a['extra_repeat_events'] for a, b in pairs), B_extra_repeats=sum(b['extra_repeat_events'] for a, b in pairs), A_primary=sum(a['primary_events'] for a, b in pairs), B_primary=sum(b['primary_events'] for a, b in pairs), both_clear_pairs=len(cleared) if scenario.endswith('_ttk') else None, A_wave_ttk=statistics.mean(a['wave_clear_ttk'] for a, b in cleared) if scenario.endswith('_ttk') and cleared else None, B_wave_ttk=statistics.mean(b['wave_clear_ttk'] for a, b in cleared) if scenario.endswith('_ttk') and cleared else None, B_ttk_wins=sum(b['wave_clear_ttk'] < a['wave_clear_ttk'] for a, b in cleared) if scenario.endswith('_ttk') else None))
write_csv(args.output / 'paired_summary.csv', paired)
original = args.output.parent / 'completed_rows.csv'
invalid_scenarios = {'swap1', 'missile_multi', 'production_missile', 'joint_focus_many_sources', 'joint_swap'}
invalid = []
for csv_line, row in enumerate(csv.DictReader(original.open(encoding='utf-8-sig')), 2):
    if row['scenario'] in invalid_scenarios:
        invalid.append(dict(original_csv_line=csv_line, stage=row['stage'], runtime_commit=row['runtime_commit'], level=row['level'], scenario=row['scenario'], tag=row['tag'], seed=row['seed'], invalid_for_offensive_balance=True, invalid_for_whole_wave_ttk=True, reason='Inherited target geometry x=500,580,660 (and740 for four targets) exceeds actual battlefield width572; projectile losses and target availability confound DPS/TTK/secondary benefit', replacement='See corrected_rows.csv; joint multi-target interpretations retracted without broad rerun'))
write_csv(args.output / 'invalid_inherited_rows.csv', invalid)
manifest = dict(runtime_commit=data['commit'], engine=data['engine'], completed_rows=len(rows), repeat30_rows=len(data['rows']) + (len(extra['rows']) if extra else 0), corrected_cited_rows=len(corrections['rows']), invalid_inherited_rows=len(invalid), original_evidence_preserved=True, tuning_changed=False, valid_target_geometry=dict(x=[200,280,360], y=[230,228,226], battlefield=[572,696]), seeds=data['paired_seeds'] + (extra['paired_seeds'] if extra else []), excluded_trials='Initial exploratory copies used inherited out-of-field geometry; none included here', caveats=['Paired seeds do not guarantee identical random draws', 'TTK only reports full wave clears; window-censored cases are not successful kills', 'Small controlled sample, not population balance assurance'])
(args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
for row in paired:
    print(row['scenario'], row['A'], row['B'], 'ratio', round(row['B_over_A_mean_dps'], 4), 'B wins', row['B_dps_wins'], '/', row['paired_seeds'], 'TTK', row['A_wave_ttk'], row['B_wave_ttk'])
print('Invalid inherited offensive rows:', len(invalid))
