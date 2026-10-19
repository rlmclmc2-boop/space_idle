"""Serial replay of the existing five full-window fixtures on shipping Windows4.7.2.

The frozen GDS driver/fixtures are copied byte-for-byte. CPU sampling is external
GetProcessTimes (50ms); GPU sampling is whole-device nvidia-smi (100ms), never a
claim of per-process GPU time. Raw failed gates are retained without retries.
"""
from pathlib import Path
import argparse, ctypes, ctypes.wintypes as wt, datetime, gzip, hashlib, json
import os, shutil, statistics, subprocess, time

BASE = 'c4a5e25968e757adc3a0ceb5bc741a615600f5bd'
HEAD = '6e8d2ed992f4239219a1348a7929ee04c59abf6a'
SCRIPTS = ['scripts/native_execution_session.gd', 'scripts/battle_slice_runtime.gd',
           'scripts/logical_fleet_pose.gd']
CASES = ['mixed', 'laser', 'cannon', 'missile', 'longLaser']

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

def compressed(path, data):
    with gzip.open(path, 'wt', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

def source(repo, ref, path):
    return subprocess.check_output(['git', 'show', ref + ':' + path], cwd=repo)

def environment(project):
    env = os.environ.copy()
    user = project.parent / 'user'
    for key, part in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'),
                      ('TEMP', 'temp'), ('TMP', 'temp')]:
        folder = user / part
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update(PERF_NATIVE='1', AI_TECH_PERF_STATE='closed', MISSILE_CONTROL='legend')
    return env

kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
kernel32.GetProcessTimes.argtypes = [wt.HANDLE] + [ctypes.POINTER(wt.FILETIME)] * 4
kernel32.GetProcessTimes.restype = wt.BOOL

def cpu_sample(proc):
    values = [wt.FILETIME() for _ in range(4)]
    t0 = time.time()
    ok = kernel32.GetProcessTimes(int(proc._handle), *(ctypes.byref(v) for v in values))
    t1 = time.time()
    if not ok:
        raise ctypes.WinError(ctypes.get_last_error())
    seconds = [(v.dwHighDateTime * 2**32 + v.dwLowDateTime) / 1e7 for v in values]
    return {'unix': (t0+t1)/2, 'read_wall_seconds': t1-t0,
            'kernel_seconds': seconds[2], 'user_seconds': seconds[3]}

def cpu_summary(rows, start, end):
    def point(t):
        for left, right in zip(rows, rows[1:]):
            if left['unix'] <= t <= right['unix']:
                width = right['unix']-left['unix']
                alpha = (t-left['unix'])/width
                total = lambda r: r['kernel_seconds']+r['user_seconds']
                return total(left)+(total(right)-total(left))*alpha, width
        return None
    a, b = point(start), point(end)
    if a is None or b is None:
        return {'available': False, 'reason': 'sample boundary not bracketed'}
    seconds = b[0]-a[0]
    return {'available': True, 'cpu_seconds': seconds,
            'one_core_percent': 100*seconds/(end-start),
            'max_boundary_bracket_seconds': max(a[1], b[1]),
            'method': 'GetProcessTimes external 50ms timeline; linear boundary interpolation'}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--before-lib', type=Path, required=True)
    p.add_argument('--after-lib', type=Path, required=True)
    p.add_argument('--godot', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--prepare-only', action='store_true')
    p.add_argument('--cases', nargs='+', choices=CASES, default=CASES)
    a = p.parse_args()
    repo, project, output = a.repo.resolve(), a.project.resolve(), a.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    frozen = repo/'test/evidence/ai-tech-final-matched-five-weapon'
    support = repo/'test/evidence/compact-laser-20261015'
    frozen_ref = 'test/evidence/ai-tech-final-matched-five-weapon/'
    support_ref = 'test/evidence/compact-laser-20261015/'
    env = environment(project)
    if a.prepare_only:
        if project.exists():
            raise RuntimeError('Refuse to overwrite existing isolated project')
        shutil.copytree(repo/'space-battleship', project,
                        ignore=shutil.ignore_patterns('.godot', '.git', '.runtime', '__pycache__'))
        (project/'.runtime').mkdir(exist_ok=True)
        (project/'bin').mkdir(exist_ok=True)
        shutil.copy2(a.after_lib, project/'bin/space_native.dll')
        (project/'space_native.gdextension').write_bytes(source(repo, HEAD,
            'space-battleship/addons/native_battle/space_native.gdextension.in'))
        (project/'port_perf.gd').write_bytes(source(repo, HEAD, frozen_ref+'perf_driver.gd'))
        for name in ['probe.gd', 'counter_probe.gd']:
            (project/name).write_bytes(source(repo, HEAD, support_ref+name))
        (project/'combat_stress_fixture.gd').write_bytes(source(repo, HEAD, frozen_ref+'mixed_fixture.gd'))
        with (output/'import.log').open('w', encoding='utf-8') as log:
            done = subprocess.run([str(a.godot), '--headless', '--editor', '--path',
                                   str(project), '--import', '--quit', '--log-file', str(output/'import.engine.log')],
                                  env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        if done.returncode:
            raise RuntimeError('Import failed: '+str(done.returncode))
        print('IMPORTED', project, flush=True)
        return
    if not project.exists():
        raise RuntimeError('Prepare isolated imported project first')
    if (project/'port_perf.gd').read_bytes() != source(repo, HEAD, frozen_ref+'perf_driver.gd'):
        raise RuntimeError('Frozen driver changed')
    results = []
    for case in a.cases:
        for label, ref, library in [('before', BASE, a.before_lib), ('after', HEAD, a.after_lib)]:
            name = case+'-'+label
            if (output/(name+'.json.gz')).exists():
                raise RuntimeError('Refuse to overwrite existing raw run: '+name)
            for path in SCRIPTS:
                (project/path).write_bytes(source(repo, ref, 'space-battleship/'+path))
            shutil.copy2(library, project/'bin/space_native.dll')
            fixture = frozen/('mixed_fixture.gd' if case=='mixed' else 'combat_stress_fixture.gd')
            (project/'combat_stress_fixture.gd').write_bytes(source(repo, HEAD, frozen_ref+fixture.name))
            env['WEAPON_CASE'] = case
            raw_path = project/'.runtime/uncapped-port.json'
            raw_path.unlink(missing_ok=True)
            (project/'.runtime/uncapped-port.png').unlink(missing_ok=True)
            process_rows = []
            args = [str(a.godot), '--path', str(project), '--rendering-method', 'gl_compatibility',
                    '--audio-driver', 'Dummy', '--max-fps', '0', '--disable-vsync',
                    '--log-file', str(output/(name+'.engine.log')), '--script', 'res://port_perf.gd']
            receipt = {'case': case, 'label': label, 'source_commit': ref, 'command': args,
                       'driver_sha256': sha(project/'port_perf.gd'), 'fixture_sha256': sha(project/'combat_stress_fixture.gd'),
                       'library_sha256': sha(project/'bin/space_native.dll'),
                       'script_sha256': {f: sha(project/f) for f in SCRIPTS},
                       'environment': {k: env[k] for k in ['PERF_NATIVE', 'AI_TECH_PERF_STATE',
                           'MISSILE_CONTROL', 'WEAPON_CASE', 'APPDATA', 'LOCALAPPDATA', 'TEMP']}}
            write_json(output/(name+'.receipt.json'), receipt)
            with (output/(name+'.gpu.csv')).open('w', encoding='utf-8') as gpu_log:
                gpu = subprocess.Popen(['C:/Windows/System32/nvidia-smi.exe',
                    '--query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used,power.draw',
                    '--format=csv,noheader,nounits', '--loop-ms=100'],
                    stdout=gpu_log, stderr=subprocess.STDOUT)
                try:
                    with (output/(name+'.log')).open('w', encoding='utf-8') as log:
                        proc = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT)
                        began = time.monotonic()
                        try:
                            while proc.poll() is None:
                                process_rows.append(cpu_sample(proc))
                                if time.monotonic()-began > 180:
                                    proc.kill()
                                    raise TimeoutError(name+' exceeded 180 seconds')
                                time.sleep(.05)
                            process_rows.append(cpu_sample(proc))
                        finally:
                            if proc.poll() is None:
                                proc.kill()
                            proc.wait()
                finally:
                    gpu.terminate()
                    gpu.wait(timeout=10)
            compressed(output/(name+'.process.json.gz'), process_rows)
            receipt['exit_code'] = proc.returncode
            write_json(output/(name+'.receipt.json'), receipt)
            if not raw_path.exists():
                raise RuntimeError(name+' produced no raw JSON; preserve logs and stop')
            raw = raw_path.read_bytes()
            with gzip.open(output/(name+'.json.gz'), 'wb') as f:
                f.write(raw)
            screen = project/'.runtime/uncapped-port.png'
            if screen.exists():
                shutil.copy2(screen, output/(name+'.png'))
            data = json.loads(raw)
            phases = data['phases']
            spans = {'wall': data['frames_us_raw'],
                     'before_main': [r['main_begin_us']-r['previous_post_us'] for r in phases],
                     'main': [r['main_end_us']-r['main_begin_us'] for r in phases],
                     'submit': [r['pre_draw_us']-r['main_end_us'] for r in phases],
                     'render_wait': [r['post_draw_us']-r['pre_draw_us'] for r in phases]}
            log_files = [output/(name+'.log'), output/(name+'.engine.log')]
            logs = [p.read_text(encoding='utf-8', errors='replace') for p in log_files if p.exists()]
            log = '\n'.join(logs)
            row = {k: data.get(k) for k in ['warm_steps','sample_steps','actual_1x_pass',
                'performance_sample_valid','native_admitted','logic_hz','render_hz',
                'game_wall_ratio','enemies_alive','video_adapter','events','warm_fires',
                'fires','warm_hits','hits','rng_state','engine_version','stress']}
            row.update(case=case, label=label, exit_code=proc.returncode,
                       script_errors=max((s.count('SCRIPT ERROR') for s in logs), default=0),
                       spans_ms={k: {'mean': statistics.mean(v)/1000,
                                     'p95': sorted(v)[int((len(v)-1)*.95)]/1000,
                                     'min': min(v)/1000, 'max': max(v)/1000}
                                 for k, v in spans.items()},
                       process_cpu=cpu_summary(process_rows, data['sample_start_unix'], data['sample_end_unix']))
            row['process_cpu']['interval_scope'] = 'Frozen driver UNIX envelope; includes cold endpoint export. Not an exact GPU or wall-frame interval.'
            row['process_cpu']['envelope_seconds'] = data['sample_end_unix']-data['sample_start_unix']
            row['process_cpu']['wall_sample_seconds'] = data['wall_seconds']
            row['formal_run_valid'] = bool(data['performance_sample_valid'] and data['actual_1x_pass']
                and data['warm_steps']==240 and data['sample_steps']==480 and data['native_admitted']
                and data['enemies_alive']==15 and proc.returncode==0 and 'SCRIPT ERROR' not in log)
            results.append(row)
            write_json(output/'summary-runs.json', {'baseline': BASE, 'candidate': HEAD, 'rows': results})
            print(name, 'valid=', row['formal_run_valid'], 'steps=', data['warm_steps'], data['sample_steps'],
                  'wall_ms=', round(row['spans_ms']['wall']['mean'], 3), 'events=', data['events'], flush=True)
    for path in SCRIPTS:
        (project/path).write_bytes(source(repo, HEAD, 'space-battleship/'+path))
    shutil.copy2(a.after_lib, project/'bin/space_native.dll')

if __name__ == '__main__':
    main()
