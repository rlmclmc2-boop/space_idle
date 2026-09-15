"""Phase 8 characterization: isolated inputs, exact errors and file side effects.

Run only through test/run.py. No production defaults or validators are patched.
Fault injection records existing behavior, including unsafe historical outcomes.
"""
from contextlib import ExitStack
import io
import json
from pathlib import Path
import shutil
import sys
from types import SimpleNamespace
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
assert ROOT.parent.parent.name == 'work', 'Use test/run.py; never run on formal inputs'
sys.path.insert(0, str(ROOT / 'tools'))
import config_workbooks as cw
import level_editor_store as le
import import_workbook as full

AREA = ROOT.parent / 'phase8-matrix'
AREA.mkdir(exist_ok=True)
originals = {str(p.relative_to(ROOT)): p.read_bytes()
             for p in (ROOT / 'config_excel').iterdir() if p.is_file() and not p.name.startswith('~$')}
originals['data/game_data.json'] = (ROOT / 'data/game_data.json').read_bytes()
checks = 0


def check(condition, label):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(label)


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(full.encode(data))


def fresh(name):
    root = AREA / name
    assert root.resolve().is_relative_to(AREA.resolve()) and root != AREA
    if root.exists():
        shutil.rmtree(root)
    for name, raw in originals.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    return root


def snapshot(root):
    return {str(p.relative_to(root)).replace('\\', '/'): cw.sha(p.read_bytes())
            for p in sorted(root.rglob('*')) if p.is_file()}


def delta(before, after):
    return {key: ('created' if key not in before else 'deleted' if key not in after else 'modified')
            for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)}


def xml_cell(root, sheet, field, value=None, missing_cache=False):
    path = root / 'config_excel' / (sheet + '.xlsx')
    table = le.Store(root).load()['tables'][sheet]
    address = le.get_column_letter(table['headers'].index(field) + 1) + '4'
    with zipfile.ZipFile(path) as book:
        part = dict(cw.sheet_parts(book))[sheet]
        tree = cw.ET.fromstring(book.read(part))
        cell = next(c for c in tree.iter(cw.Q + 'c') if c.get('r') == address)
        if missing_cache:
            cell = next(c for c in tree.iter(cw.Q + 'c') if c.find(cw.Q + 'f') is not None)
            check(cell.find(cw.Q + 'v') is not None, 'remove an existing real formula cache')
            cached = cell.find(cw.Q + 'v')
            if cached is not None:
                cell.remove(cached)
        else:
            for child in list(cell):
                cell.remove(child)
            cell.attrib.pop('t', None)
            if isinstance(value, str):
                cell.set('t', 'inlineStr')
                cw.ET.SubElement(cw.ET.SubElement(cell, cw.Q + 'is'), cw.Q + 't').text = value
            else:
                cw.ET.SubElement(cell, cw.Q + 'v').text = str(value)
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w') as dest:
            for info in book.infolist():
                dest.writestr(info, cw.ET.tostring(tree) if info.filename == part else book.read(info.filename))
    path.write_bytes(output.getvalue())


def setup(root, case):
    manifest = root / 'config_excel' / cw.MANIFEST
    target = root / 'data/game_data.json'
    mapping = json.loads(manifest.read_text(encoding='utf-8'))
    if case == 'manifest_missing': manifest.unlink()
    elif case == 'manifest_broken': manifest.write_text('{', encoding='utf-8')
    elif case.startswith('manifest_value_'):
        values = {'empty': {}, 'list': [], 'sheets_missing': {'version': 1},
                  'sheets_null': {'sheets': None}, 'sheets_list': {'sheets': []}}
        write_json(manifest, values[case.removeprefix('manifest_value_')])
    elif case.startswith('path_'):
        values = {'empty': '', 'null': None, 'number': 42, 'parent': '../mon.xlsx',
                  'backslash': '..\\mon.xlsx', 'absolute': str(root / 'mon.xlsx'),
                  'missing_file': 'absent.xlsx', 'wrong_sheet': 'level.xlsx'}
        mapping['sheets']['mon'] = values[case.removeprefix('path_')]
        write_json(manifest, mapping)
    elif case == 'required_mapping_missing':
        del mapping['sheets']['mon']; write_json(manifest, mapping)
    elif case.startswith('optional_'):
        _, name, variant = case.split('_', 2)
        mapping['sheets'].pop(name, None)
        if variant == 'null': mapping['sheets'][name] = None
        if variant == 'empty': mapping['sheets'][name] = ''
        write_json(manifest, mapping)
        if variant.startswith('absent'):
            (root / 'config_excel' / (name + '.xlsx')).unlink()
            if variant == 'absent_no_projection':
                data = json.loads(target.read_text(encoding='utf-8'))
                data.pop(full.SECTIONS[name], None); write_json(target, data)
    elif case == 'target_missing': target.unlink()
    elif case == 'target_broken': target.write_text('{', encoding='utf-8')
    elif case == 'cache_broken': target.with_name('.import_state.json').write_text('{', encoding='utf-8')
    elif case in ('cache_valid', 'cache_old', 'cache_wrong_target'):
        cw.incremental_import(root / 'config_excel', target)
        state = target.with_name('.import_state.json')
        data = json.loads(state.read_text(encoding='utf-8'))
        if case == 'cache_old': data['version'] = -1
        if case == 'cache_wrong_target': data['target_hash'] = 'bad'
        write_json(state, data)
    elif case.startswith('invalid_'):
        values = {'health': ('mon', 'health', -1), 'size': ('mon', 'size', 1.5),
                  'armour': ('mon', 'armourType', 9), 'weapon': ('mon', 'equipment', '{missing|1}'),
                  'drop': ('mon', 'res', '{999,1,1}'), 'id': ('mon', 'id', 2),
                  'reference': ('monGroup', 'mon', '{999,null,null,null,null,null,null,null,null,null}')}
        xml_cell(root, *values[case.removeprefix('invalid_')])
    elif case == 'missing_formula_cache': xml_cell(root, 'level', 'atkRatio', missing_cache=True)
    elif case == 'corrupt_xlsx': (root / 'config_excel/mon.xlsx').write_bytes(b'not a workbook')
    elif case == 'extra_json':
        data = json.loads(target.read_text(encoding='utf-8'))
        data['phase8_sentinel'] = {'unchanged': [1, 'x', None]}
        data['defaults']['autoCollectDelay'] = 12
        write_json(target, data)


CASES = ['valid', 'manifest_missing', 'manifest_broken',
         *['manifest_value_' + x for x in ('empty', 'list', 'sheets_missing', 'sheets_null', 'sheets_list')],
         'required_mapping_missing',
         *['path_' + x for x in ('empty', 'null', 'number', 'parent', 'backslash', 'absolute', 'missing_file', 'wrong_sheet')],
         *['optional_' + n + '_' + v for n in ('charge', 'ship') for v in
           ('fallback', 'null', 'empty', 'absent_existing_projection', 'absent_no_projection')],
         'target_missing', 'target_broken', 'cache_broken', 'cache_valid', 'cache_old', 'cache_wrong_target',
         *['invalid_' + x for x in ('health', 'size', 'armour', 'weapon', 'drop', 'id', 'reference')],
         'missing_formula_cache', 'corrupt_xlsx', 'extra_json']


def run_case(case, entry):
    root = fresh(case + '-' + entry)
    setup(root, case)
    before = snapshot(root)
    before_times = {str(p.relative_to(root)): p.stat().st_mtime_ns for p in root.rglob('*') if p.is_file()}
    stage = 'import' if entry == 'incremental' else 'construct'
    parsed = []
    real_reader = cw.read_changed_file
    def reader(path, name, raw):
        parsed.append(name)
        return real_reader(path, name, raw)
    with patch.object(cw, 'read_changed_file', reader), patch.object(le, 'read_changed_file', reader), \
         patch.object(cw.uuid, 'uuid4', return_value=SimpleNamespace(hex='matrix')):
        try:
            if entry == 'incremental':
                result = cw.incremental_import(root / 'config_excel', root / 'data/game_data.json')
            else:
                store = le.Store(root)
                stage = 'load'; request = store.load()
                if entry == 'store_load': result = request
                else:
                    stage = 'save' if entry == 'store_save' else 'validate'
                    result = store.execute(request, entry == 'store_save')
            outcome = {'accepted': True, 'stage': stage, 'returned': result}
        except Exception as error:
            outcome = {'accepted': False, 'stage': stage, 'error_type': type(error).__name__, 'error': str(error)}
    after = snapshot(root)
    outcome.update(case=case, entry=entry, files=delta(before, after), unchanged=sorted(k for k in before if after.get(k)==before[k]),
                   parsed=parsed, file_hashes=after)
    if not outcome['accepted'] or entry in ('store_load', 'store_validate'):
        check(after == before, case + '/' + entry + ': read/rejection must not write')
    if case == 'cache_valid' and entry == 'incremental':
        check(after == before and not parsed, 'unchanged import is a no-op')
        check(before_times == {str(p.relative_to(root)):p.stat().st_mtime_ns for p in root.rglob('*') if p.is_file()}, 'no-op preserves mtimes')
    # Retain complete return data, errors and effects; normalize only the sandbox prefix.
    return json.loads(json.dumps(outcome, ensure_ascii=False).replace(str(root).replace('\\','\\\\'), '<CASE>'))


def transaction_case(entry, fault):
    root = fresh('fault-' + entry + '-' + fault)
    target = root / 'data/game_data.json'
    store = le.Store(root)
    request = store.load()
    request['tables']['mon']['rows'][0]['health'] += 1
    before = snapshot(root)
    calls, external, external_hashes = [], [], {}
    real_replace, real_write = cw.os.replace, Path.write_bytes
    real_reader = cw.read_changed_file
    fired = False
    def reader(path, name, raw):
        nonlocal fired
        result = real_reader(path, name, raw)
        if not fired and fault.startswith('concurrent_'):
            fired = True
            changed = {'source': store.paths['mon'], 'manifest': store.manifest, 'target': target}[fault.removeprefix('concurrent_')]
            if fault == 'concurrent_target':
                data = json.loads(changed.read_text(encoding='utf-8'))
                data['external_writer_sentinel'] = True
                write_json(changed, data)
            else:
                changed.write_bytes(changed.read_bytes() + b'\n')
            key = str(changed.relative_to(root)).replace('\\','/')
            external.append(key)
            external_hashes[key] = cw.sha(changed.read_bytes())
        return result
    def replace(src, dst):
        nonlocal fired
        dst = Path(dst); calls.append(str(dst.relative_to(root)).replace('\\','/'))
        if fault in ('replace_failure', 'rollback_failure') and dst.name == '.import_state.json':
            fired = True; raise OSError('injected commit failure')
        if fault == 'rollback_failure' and fired and dst == target:
            raise OSError('injected rollback failure')
        return real_replace(src, dst)
    def write(path, raw):
        if fault == 'stage_failure' and path.suffix == '.tmp':
            raise OSError('injected staging failure')
        return real_write(path, raw)
    with ExitStack() as stack:
        for mod in (cw, le): stack.enter_context(patch.object(mod, 'read_changed_file', reader))
        stack.enter_context(patch.object(cw.os, 'replace', replace))
        stack.enter_context(patch.object(Path, 'write_bytes', write))
        stack.enter_context(patch.object(cw.uuid, 'uuid4', return_value=SimpleNamespace(hex='matrix')))
        try:
            result = cw.incremental_import(store.directory,target) if entry == 'incremental' else store.execute(request,entry=='store_save')
            outcome = {'accepted':True,'message':result.get('message')}
        except Exception as error:
            outcome = {'accepted':False,'error_type':type(error).__name__,'error':str(error)}
    after = snapshot(root)
    outcome.update(case=fault,entry=entry,files=delta(before,after),external_mutations=external,replace_order=calls,
                   external_bytes_preserved={k:after.get(k)==v for k,v in external_hashes.items()},
                   temporary_files=sorted(str(p.relative_to(root)) for p in root.rglob('*.tmp')))
    check(not outcome['temporary_files'], 'temporary cleanup: '+entry+'/'+fault)
    if fault in ('stage_failure','replace_failure') and entry != 'store_validate':
        check(not outcome['accepted'] and before==after,'successful rollback restores every file')
    if fault == 'rollback_failure' and entry != 'store_validate':
        check(outcome.get('error_type')=='RuntimeError' and before!=after,'characterize existing rollback failure; NOT atomicity certification')
    return json.loads(json.dumps(outcome,ensure_ascii=False).replace(str(root).replace('\\','\\\\'),'<CASE>'))


def projection_and_excel():
    root = fresh('projection')
    target = root/'data/game_data.json'
    data = json.loads(target.read_text(encoding='utf-8'))
    data['phase8_sentinel']={'unknown':[1,2]}; write_json(target,data)
    cw.incremental_import(root/'config_excel',target)
    before = json.loads(target.read_text(encoding='utf-8'))
    xml_cell(root,'mon','health',321)
    result = cw.incremental_import(root/'config_excel',target)
    after = json.loads(target.read_text(encoding='utf-8'))
    check(result['parsed']==['mon'],'single-table parses only mon')
    check({k:v for k,v in before.items() if k!='enemies'}=={k:v for k,v in after.items() if k!='enemies'},'other JSON fields unchanged')
    state = json.loads(target.with_name('.import_state.json').read_text(encoding='utf-8'))
    check(state['version']==cw.CACHE_VERSION==4 and state['target_hash']==cw.sha(target.read_bytes()),'cache and target hash')
    store=le.Store(root)
    check(state['hashes']=={n:cw.sha(p.read_bytes()) for n,p in store.paths.items()},'source hashes')
    request=store.load(); old={p:p.read_bytes() for p in [*store.paths.values(),target,target.with_name('.import_state.json')]}
    table=request['tables']['level']; table['rows'][0]['atkRatio']='=ROUND(1.005,2)'; table['rows'][0]['lifeRatio']='=D4/3'
    result=store.execute(request,True)
    projected=json.loads(target.read_text(encoding='utf-8'))
    check(projected['levels'][0]['atkRatio']==1.01 and projected['levels'][0]['lifeRatio']==1.01/3,'ROUND and Decimal/float reference boundary')
    backup=Path(result['backup'])
    for p in (store.paths['level'],target,target.with_name('.import_state.json')):
        check((backup/p.relative_to(root)).read_bytes()==old[p],'backup original bytes')
    for name,p in store.paths.items():
        if name!='level': check(p.read_bytes()==old[p],'unmodified workbook bytes '+name)
    with zipfile.ZipFile(io.BytesIO(old[store.paths['level']])) as a, zipfile.ZipFile(store.paths['level']) as b:
        part=dict(cw.sheet_parts(a))['level']
        check(a.namelist()==b.namelist(),'ZIP members/order')
        for name in a.namelist():
            if name!=part: check(a.read(name)==b.read(name),'unchanged ZIP part '+name)
        tree=cw.ET.fromstring(b.read(part)); cell=next(c for c in tree.iter(cw.Q+'c') if c.get('r')=='D4')
        check(cell.find(cw.Q+'f').text=='ROUND(1.005,2)' and float(cell.find(cw.Q+'v').text)==1.01,'formula and XML cache')
    check(cw.incremental_import(store.directory,target)['parsed']==[],'Store fingerprint accepted by incremental')
    before=snapshot(root)
    try: full.full_import(ROOT.parent/'太空战舰.xlsx',target)
    except ValueError as error:
        check('techPointGet' in str(error),'historical aggregate rejection')
    else: raise AssertionError('Historical aggregate unexpectedly accepted')
    check(snapshot(root)==before and not target.with_suffix('.json.tmp').exists(),'full-import failure preserves output')


def main():
    matrix=[]
    for case in CASES:
        for entry in ('incremental','store_load','store_validate','store_save'):
            matrix.append(run_case(case,entry))
        print('Recorded',case,flush=True)
    faults=[transaction_case(entry,fault) for entry in ('incremental','store_validate','store_save')
            for fault in ('stage_failure','replace_failure','rollback_failure','concurrent_source','concurrent_manifest','concurrent_target')]
    projection_and_excel()
    report={'code_sha256':{n:cw.sha((ROOT/'tools'/n).read_bytes()) for n in ('config_workbooks.py','level_editor_store.py','import_workbook.py')},
            'matrix':matrix,'faults':faults,'assertions':checks}
    (AREA/'INPUT_MATRIX.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    rows=['# INPUT_MATRIX','', '| Case | Entry | Result / stage | Error | Changed files |','|---|---|---|---|---|']
    for r in matrix+faults:
        error=(r.get('error_type','')+': '+r.get('error','')).replace('|','\\|').replace('\n',' ')
        rows.append('| '+r['case']+' | '+r['entry']+' | '+('ACCEPT' if r['accepted'] else 'REJECT')+' / '+r.get('stage','fault')+' | '+error+' | '+', '.join(r['files'])+' |')
    (AREA/'INPUT_MATRIX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    print(f'Phase 8: {len(matrix)} input outcomes, {len(faults)} fault outcomes, {checks} assertions passed. Evidence: {AREA}',flush=True)


if __name__=='__main__': main()
