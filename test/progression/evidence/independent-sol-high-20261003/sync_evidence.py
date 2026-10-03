"""Persist this task's own raw checkpoints and compressed traces; never touch source."""
from pathlib import Path
import argparse, datetime, fcntl, gzip, hashlib, json, shutil, subprocess, time

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--project', type=Path, default=Path('/workspace/independent-sol-high-qa'))
parser.add_argument('--label', default='own-fresh-v23-fixed-zero-armour-max900-allmax')
parser.add_argument('--completion-marker', type=Path, default=EVIDENCE / 'fresh-exit.json')
args = parser.parse_args()
PROJECT = args.project
LABEL = args.label
RESULT = PROJECT / 'results' / LABEL
DEST = EVIDENCE / LABEL
DEST.mkdir(exist_ok=True)
LOCK = Path('/workspace/independent-sol-high-evidence.lock')

def persist():
    records = {}
    for src in sorted(RESULT.glob('*.json')):
        try:
            data = src.read_bytes()
            json.loads(data)
        except (OSError, ValueError):
            continue  # Heartbeat may be in its native write; retry next cycle.
        (DEST / src.name).write_bytes(data)
        records[src.name] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
    if args.completion_marker.exists():
        data = args.completion_marker.read_bytes()
        (DEST / 'process-exit.json').write_bytes(data)
        records['process-exit.json'] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
    errors = {}
    for src in [RESULT / 'actions.jsonl', *sorted((PROJECT / 'logs').glob(LABEL + '-*.log'))]:
        if not src.exists():
            continue
        data = src.read_bytes()
        if src.suffix == '.jsonl':
            data = data[:data.rfind(b'\n') + 1]  # Preserve whole flushed entries only.
        compressed = gzip.compress(data, mtime=0)
        (DEST / (src.name + '.gz')).write_bytes(compressed)
        records[src.name] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data), 'gzip_bytes': len(compressed)}
        if src.suffix == '.log':
            text = data.decode(errors='replace')
            errors[src.name] = {'script_errors': text.count('SCRIPT ERROR:'),
                                'parse_errors': text.count('Parse Error:'),
                                'engine_errors': text.count('ERROR:') - text.count('SCRIPT ERROR:')}
    if not records:
        return
    (DEST / 'archive.json').write_text(json.dumps({
        'captured_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'own_run': True, 'source_commit': json.loads((PROJECT / 'qa-manifest.json').read_text())['source_commit'],
        'scope': 'Own raw run evidence; use run.json initial_state to distinguish fresh from checkpoint diagnostics; partial until summary and exit recorded',
        'files': records, 'log_errors': errors,
    }, indent=2))
    with LOCK.open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(['git', 'add', str(DEST.relative_to(ROOT))], cwd=ROOT, check=True)
        if subprocess.run(['git', 'diff', '--cached', '--quiet'], cwd=ROOT).returncode:
            subprocess.run(['git', 'commit', '-m', 'qa: persist own frozen fresh checkpoints and raw trace'], cwd=ROOT, check=True)
            push = subprocess.run(['git', 'push', 'origin', 'qa/independent-sol-high-20261003'], cwd=ROOT)
            if push.returncode:
                print('REMOTE_PERSIST_FAILED', push.returncode, flush=True)

if __name__ == '__main__':
    previous = set()
    last = 0.0
    while True:
        milestones = set(RESULT.glob('save_*.json'))
        done = args.completion_marker.exists()
        if milestones != previous or time.monotonic() - last >= 180 or done:
            persist()
            last = time.monotonic()
            previous = milestones
        if done:
            break
        time.sleep(15)
