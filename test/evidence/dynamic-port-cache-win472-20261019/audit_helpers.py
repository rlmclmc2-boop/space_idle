# Reused audit functions from Windows evidence 42ee955; no game execution.
def differences(a, b, path='', out=None):
    if out is None:
        out = []
    if a == b:
        return out
    if isinstance(a, dict) and isinstance(b, dict):
        for key in sorted(set(a) | set(b)):
            if key not in a or key not in b:
                out.append({'path': path + '/' + key, 'before': a.get(key), 'after': b.get(key)})
            else:
                differences(a[key], b[key], path + '/' + key, out)
    elif isinstance(a, list) and isinstance(b, list) and (len(a) == len(b)):
        for i, (x, y) in enumerate(zip(a, b)):
            differences(x, y, path + '/' + str(i), out)
    elif len(out) < 500:
        out.append({'path': path, 'before': a, 'after': b})
    return out

def phase_gates(d):
    phases = d['phases']
    frames = d['frames_us_raw']
    lengths = {k: len(d[k]) for k in ['phases', 'frames_us_raw', 'projectiles_raw', 'floats_raw', 'pending_raw', 'primitives_raw', 'drawcalls_raw', 'frame_trace']}
    negative = []
    partitions = []
    for i, (r, wall) in enumerate(zip(phases, frames)):
        v = [r['main_begin_us'] - r['previous_post_us'], r['main_end_us'] - r['main_begin_us'], r['pre_draw_us'] - r['main_end_us'], r['post_draw_us'] - r['pre_draw_us']]
        if min(v) < 0:
            negative.append(i)
        if sum(v) != wall:
            partitions.append(i)
    return {'array_lengths': lengths, 'lengths_equal': len(set(lengths.values())) == 1, 'negative_phase_frames': negative, 'partition_fail_frames': partitions, 'phase_steps_sum': sum((r['logic_steps'] for r in phases)), 'pass': len(set(lengths.values())) == 1 and (not negative) and (not partitions) and (sum((r['logic_steps'] for r in phases)) == d['sample_steps'])}

def fixture_gates(d):
    c = d['stress']['config']
    return {'layer2': c['layer'] == 2, 'enemies15': c['alive_enemies'] == 15 and d['enemies_alive'] == 15, 'enhancement40': c['enhancement_effective_level'] == 40, 'five_drones': len(c['equipped']) == 5, 'ordinary140': len(c['ordinary']) > 0 and all((int(w['level']) == 140 for w in c['ordinary']))}
