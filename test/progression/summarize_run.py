"""Derive segment-scoped facts without changing immutable run evidence."""
import argparse, collections, json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('result', type=Path)
a = p.parse_args()
s = json.loads((a.result / 'summary.json').read_text())
start = json.loads((a.result / 'save_0.json').read_text())['x1_seconds']
end = s['x1_seconds']
elapsed = end - start
waves = collections.defaultdict(list)
visit_times = []
for line in (a.result / 'actions.jsonl').open():
    row = json.loads(line)
    if row.get('kind') == 'wave_result':
        w = row['wave']
        waves[(w['stage'], w['node'], w['status'])].append(w['seconds'])
    elif row.get('kind') == 'visit' and row.get('actions', 0) > 0:
        visit_times.append(row['x1_seconds'])
gaps = [b - a for a, b in zip(visit_times, visit_times[1:])]
facts = {
    'scope': 'Derived segment facts only; original summary and traces unchanged. '
             'Some legacy metrics use absolute journey time as denominator/initial '
             'gap on resume; do not interpret those as segment waiting or rates.',
    'start_x1_seconds': start, 'end_x1_seconds': end,
    'elapsed_x1_seconds': elapsed, 'highest': s['highest'],
    'deaths': s['deaths'], 'action_sessions': s['action_sessions'],
    'domain_events_not_literal_clicks': s['action_events'],
    'meaningful_visit_gap_seconds': {'count': len(gaps),
        'minimum': min(gaps) if gaps else None,
        'maximum': max(gaps) if gaps else None,
        'mean': sum(gaps) / len(gaps) if gaps else None},
    'segment_income_per_minute': {k: v * 60 / elapsed
        for k, v in s['metrics']['resources']['income'].items()} if elapsed else {},
    'clears_after_start': {k: {'absolute_x1_seconds': v, 'segment_hours': (v-start)/3600}
        for k, v in s['clears'].items() if v > start + 0.001},
    'waves': [{'stage': key[0], 'node': key[1], 'status': key[2],
        'count': len(values), 'minimum_seconds': min(values),
        'maximum_seconds': max(values), 'mean_seconds': sum(values)/len(values)}
        for key, values in sorted(waves.items())],
}
print(json.dumps(facts, indent=2))
