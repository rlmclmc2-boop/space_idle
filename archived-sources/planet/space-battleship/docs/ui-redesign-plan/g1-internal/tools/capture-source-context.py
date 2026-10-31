"""Docs browser evidence source attribution. HEAD and captured working-tree bytes differ.
Capture first; bind only after a fixed source commit contains exactly those bytes.
This utility does not execute the game, change Git state, or write outside its JSON output.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT)
def capture():
    files = [p for p in ROOT.iterdir() if p.suffix in ('.js', '.css') or p.name == 'index.html']
    return {'capture_head_commit': git('rev-parse', 'HEAD').decode().strip(),
            'source_commit': None,
            'captured_source_files_sha256': {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)},
            'source_note': 'capture_head_commit records then-current HEAD. Working-tree source identity is captured by file hashes; source_commit is unset until byte-verified binding.'}
def bind(context, source, base):
    source = git('rev-parse', source).decode().strip()
    base = git('rev-parse', base).decode().strip()
    prefix = git('rev-parse', '--show-prefix').decode().strip()
    for path, expected in context['captured_source_files_sha256'].items():
        actual = hashlib.sha256(git('show', source + ':' + prefix + path)).hexdigest()
        if actual != expected:
            raise ValueError('Fixed source does not contain captured bytes: ' + path)
    return {**context, 'base_commit': base, 'source_commit': source,
            'source_note': 'Captured working-tree file hashes byte-verified against source_commit after capture. capture_head_commit remains the original HEAD; no claim it was already the later source commit.'}
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--source')
    parser.add_argument('--base')
    args = parser.parse_args()
    if args.source:
        if not args.base:
            parser.error('--base is required with --source')
        context = bind(json.loads(args.output.read_text()), args.source, args.base)
    else:
        context = capture()
    args.output.write_text(json.dumps(context, ensure_ascii=False, indent=2) + '\n')
