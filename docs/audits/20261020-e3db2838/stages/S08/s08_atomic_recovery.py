import hashlib
import ast
import argparse
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import pathlib
import shutil
import subprocess
import sys
import tempfile
import uuid
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / 'tools/config_workbooks.py'
tree = ast.parse(source.read_text(encoding='utf-8'))
nodes = [node for node in tree.body if isinstance(node, (ast.FunctionDef, ast.ClassDef))
         and node.name in ('RecoveryRequired', 'atomic_batch')]
scope = {'os': os, 'pathlib': pathlib, 'shutil': shutil, 'uuid': uuid, 'json': json,
         'sha': lambda value: hashlib.sha256(value).hexdigest()}
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(source), 'exec'), scope)
RecoveryRequired = scope['RecoveryRequired']
atomic_batch = scope['atomic_batch']


def check(fail_calls, expected_recovery):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        a, b = root / 'A', root / 'B'
        a.write_bytes(b'A-old')
        b.write_bytes(b'B-old')
        real_replace = os.replace
        calls = []

        def injected(source, target):
            calls.append(str(target))
            if len(calls) in fail_calls:
                raise OSError('injected replace failure ' + str(len(calls)))
            return real_replace(source, target)

        with patch.object(os, 'replace', injected):
            try:
                atomic_batch({a: b'A-new', b: b'B-new'}, root / 'recovery')
            except RecoveryRequired as error:
                assert expected_recovery
                manifest = json.loads((Path(error.recovery_path) / 'manifest.json').read_text())
                assert len(manifest['entries']) == 2
                for entry in manifest['entries']:
                    raw = (Path(error.recovery_path) / entry['original']).read_bytes()
                    assert hashlib.sha256(raw).hexdigest() == entry['original_sha256']
                assert a.read_bytes() == b'A-new' and b.read_bytes() == b'B-old'
                assert error.rollback_failed == [str(a)]
                print(json.dumps({'case': 'secondary_failure', 'status': 'recovery_required',
                                  'calls': len(calls), 'disk': ['A-new', 'B-old'],
                                  'originals_verified': len(manifest['entries']),
                                  'recovery_path_exists': True}))
                real_replace(Path(error.recovery_path) / manifest['entries'][0]['original'], a)
                assert a.read_bytes() == b'A-old'
                print(json.dumps({'case': 'manual_restore', 'status': 'old_versions_restored'}))
            except OSError:
                assert not expected_recovery
                assert a.read_bytes() == b'A-old' and b.read_bytes() == b'B-old'
                assert not list((root / 'recovery').glob('*'))
                print(json.dumps({'case': 'single_failure', 'status': 'rolled_back', 'calls': len(calls)}))
            else:
                assert not fail_calls
                assert a.read_bytes() == b'A-new' and b.read_bytes() == b'B-new'
                assert not list((root / 'recovery').glob('*'))
                print(json.dumps({'case': 'success', 'status': 'cleaned', 'calls': len(calls)}))


check({2}, False)
check({2, 3}, True)
check(set(), False)

baseline = subprocess.check_output([
    'git', 'show', '19879285e68f0e1b7ad722d7e27dd402ad4ab6ec:space-battleship/tools/config_workbooks.py'
], cwd=source.parents[2], text=True, encoding='utf-8')
baseline_tree = ast.parse(baseline)
baseline_node = next(node for node in baseline_tree.body if isinstance(node, ast.FunctionDef)
                     and node.name == 'atomic_batch')
baseline_scope = {'os': os, 'uuid': uuid, 'ui_text': lambda key, **kwargs: key}
exec(compile(ast.Module(body=[baseline_node], type_ignores=[]), 'baseline', 'exec'), baseline_scope)
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    a, b = root / 'A', root / 'B'
    a.write_bytes(b'A-old')
    b.write_bytes(b'B-old')
    real_replace = os.replace
    calls = []

    def baseline_injected(source, target):
        calls.append(str(target))
        if len(calls) in {2, 3}:
            raise OSError('injected baseline replace failure ' + str(len(calls)))
        return real_replace(source, target)

    with patch.object(os, 'replace', baseline_injected):
        try:
            baseline_scope['atomic_batch']({a: b'A-new', b: b'B-new'})
            raise AssertionError('expected baseline failure')
        except RuntimeError:
            assert a.read_bytes() == b'A-new' and b.read_bytes() == b'B-old'
            assert not list(root.glob('*.tmp')) and not list(root.glob('.*.tmp'))
            print(json.dumps({'case': 'baseline_secondary_failure', 'status': 'materials_removed',
                              'disk': ['A-new', 'B-old'], 'calls': len(calls)}))

editor_source = Path(__file__).resolve().parents[1] / 'tools/level_editor_store.py'
editor_tree = ast.parse(editor_source.read_text(encoding='utf-8'))
editor_class = next(node for node in editor_tree.body if isinstance(node, ast.ClassDef) and node.name == 'Store')
execute = next(node for node in editor_class.body if isinstance(node, ast.FunctionDef) and node.name == 'execute')
test_class = ast.ClassDef(name='Editor', bases=[], keywords=[], body=[execute], decorator_list=[])
ast.fix_missing_locations(test_class)
editor_scope = {'json': json, 'uuid': uuid, 'sha': scope['sha'], 'atomic_batch': atomic_batch,
                'RecoveryRequired': RecoveryRequired, 'ui_text': lambda key: key}
exec(compile(ast.Module(body=[test_class], type_ignores=[]), str(editor_source), 'exec'), editor_scope)

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    a, b = root / 'A', root / 'B'
    a.write_bytes(b'A-old')
    b.write_bytes(b'B-old')
    editor = editor_scope['Editor']()
    editor.root = root
    editor.prepare = lambda request: ({a: b'A-new', b: b'B-new'}, [])
    editor.snapshot = lambda: 'snapshot'
    editor.load = lambda: {}
    real_replace = os.replace
    calls = []

    def editor_injected(source, target):
        calls.append(str(target))
        if len(calls) in {5, 6}:
            raise OSError('injected editor replace failure ' + str(len(calls)))
        return real_replace(source, target)

    with patch.object(os, 'replace', editor_injected):
        try:
            editor.execute({'snapshot': 'snapshot'}, save=True)
            raise AssertionError('expected editor recovery failure')
        except RecoveryRequired as error:
            backup_dirs = list((root / '.runtime/level-editor-backups').iterdir())
            assert len(backup_dirs) == 1
            backup = backup_dirs[0]
            manifest = json.loads((backup / 'manifest.json').read_text())
            assert len(manifest['files']) == 2
            assert (backup / 'A').read_bytes() == b'A-old'
            assert (backup / 'B').read_bytes() == b'B-old'
            assert a.read_bytes() == b'A-new' and b.read_bytes() == b'B-old'
            assert Path(error.recovery_path, 'manifest.json').is_file()
            print(json.dumps({'case': 'editor_secondary_failure', 'status': 'recovery_required',
                              'disk': ['A-new', 'B-old'], 'persistent_backup_files': 2,
                              'journal_exists': True, 'calls': len(calls)}))

for label, parsed, filename in (('config_cli', tree, source),
                                ('editor_cli', editor_tree, editor_source)):
    main_node = next(node for node in parsed.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
    failure = RecoveryRequired(Path('recovery-journal'), [Path('A')])

    def fail(*args, **kwargs):
        raise failure

    class FailingStore:
        def __init__(self):
            pass

        load = fail
        execute = fail

    cli_scope = {'argparse': argparse, 'pathlib': pathlib, 'Path': Path, 'ROOT': Path('.'),
                 'sys': sys, 'json': json, 'Store': FailingStore, 'RecoveryRequired': RecoveryRequired,
                 'sync_workbooks': fail, 'incremental_import': fail}
    exec(compile(ast.Module(body=[main_node], type_ignores=[]), str(filename), 'exec'), cli_scope)
    output = io.StringIO()
    old_argv = sys.argv
    request_path = Path(tempfile.gettempdir()) / ('s08-' + uuid.uuid4().hex + '.json')
    try:
        request_path.write_text('{}', encoding='utf-8')
        sys.argv = ([label, 'split'] if label == 'config_cli' else
                    [label, 'save', '--request', str(request_path)])
        with redirect_stdout(output):
            code = cli_scope['main']()
    finally:
        sys.argv = old_argv
        request_path.unlink(missing_ok=True)
    response = json.loads(output.getvalue())
    assert code == 1 and response['recovery_required'] is True
    assert response['recovery_path'] == 'recovery-journal'
    assert response['rollback_failed'] == ['A']
    print(json.dumps({'case': label, 'status': 'recovery_fields_returned', 'exit_code': code}))
