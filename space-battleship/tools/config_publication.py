"""Prepare existing configuration tools on captured inputs, then publish once."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

from config_snapshot import Store, digest, encoded, stable_external_bytes


def json_files(root):
    return {p.relative_to(root).as_posix(): p.read_bytes()
            for folder in ('data', 'config_excel') for p in (root/folder).rglob('*.json')}


def relocate_metadata(root, before, after):
    # Only provenance/cache paths change; never rewrite business strings.
    target=root/'data/game_data.json'
    data=json.loads(target.read_bytes())
    if 'source_files' in data:
        data['source_files']={k:str(after/'config_excel'/Path(v).name) for k,v in data['source_files'].items()}
        target.write_bytes((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    state=root/'data/.import_state.json'
    if state.exists():
        value=json.loads(state.read_bytes());value['directory']=str(after/'config_excel')
        value['target_hash']=digest(target.read_bytes())
        cache=value.get('entity_cache',{})
        if 'dependencies' in cache:
            cache['dependencies']={str(after/'data'/Path(name).name):sha for name,sha in cache['dependencies'].items()}
        state.write_bytes(encoded(value))


def validate_complete(root, project_sources=True):
    from import_workbook import validate_projection
    from hyperspace_entities import read_bundle, load_schema, validate_sources, validate_outputs, EARLY_FROZEN_SHA256
    files=json_files(root)
    for raw in files.values():json.loads(raw)
    mainline=json.loads(files['data/game_data.json'])
    validate_projection(mainline)
    if not project_sources:
        schema=load_schema();frozen={name:json.loads(files['data/'+name]) for name in schema['frozen_inputs']}
        for name,sha in schema['frozen_inputs'].items():
            if digest(files['data/'+name])!=sha:raise ValueError('Frozen source identity mismatch: '+name)
        early=files['data/space_enemy_reward_early_frozen.json']
        if digest(early)!=EARLY_FROZEN_SHA256:raise ValueError('Early source identity mismatch')
        validate_sources(frozen['space_enemy_reward_sources.json'],mainline,schema,json.loads(early))
        outputs={name:json.loads(files['data/'+name]) for name in schema['templates']}
        validate_outputs(outputs,mainline,frozen)
        return
    inputs={name:(root/'config_excel'/name).read_bytes()
            for name in ('hyperspace_config.xlsx','hyperspace_enemies.xlsx')}
    outputs,_=read_bundle(inputs,mainline,root/'data')
    for name,value in outputs.items():
        if json.loads(files['data/'+name])!=value:
            raise ValueError('Candidate disagrees with validated entity projection: '+name)


def worker(root,action,request):
    import config_workbooks as cw
    import level_editor_store as le
    if action=='initialize':
        result={'ok':True,'action':'initialize'}
    elif action=='import':
        result=cw._prepare_incremental_import(root/'config_excel',root/'data/game_data.json')
    elif action=='split':
        result=cw._prepare_sync_workbooks(root/'external.xlsx',root/'config_excel')
    elif action=='full':
        from import_workbook import _prepare_full_import
        mainline=_prepare_full_import(root/'external.xlsx',root/'data/game_data.json')
        from hyperspace_entities import read_bundle
        projected,_=read_bundle({name:(root/'config_excel'/name).read_bytes() for name in ('hyperspace_config.xlsx','hyperspace_enemies.xlsx')},mainline,root/'data')
        for name,value in projected.items():
            (root/'data'/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        result={'ok':True,'action':'full'}
    elif action=='load':
        result=le.PreparedStore(root).load()
    else:
        store=le.PreparedStore(root)
        request['snapshot']=store.snapshot() # outer capture identity was checked by the coordinator
        files,warnings=store.prepare(request)
        for path,raw in files.items():path.write_bytes(raw)
        result={'warnings':warnings}
    if action!='load':validate_complete(root,action!='split')
    return result


def execute(root,action,request=None,source=None):
    root=Path(root).resolve(strict=True)
    store=Store(root)
    # Import is the explicit initialization action; readers/editor never certify loose files.
    expected,original,inputs=store.capture_publication(initialize=action in ('import','initialize','full','split'))
    external=stable_external_bytes(source) if source is not None else None
    identity={'generation':expected.identity if expected else None,
              'sources':{name:digest(raw) for name,raw in inputs.items()}}
    if request is not None and request.get('snapshot')!=identity:
        raise ValueError('Configuration or workbook input changed; reload before editing')
    with tempfile.TemporaryDirectory(prefix='space-config-') as temporary:
        prepared=Path(temporary)/'space-battleship';prepared.mkdir()
        shutil.copytree(Path(__file__).parent,prepared/'tools',ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        for name,raw in {**original,**inputs}.items():
            path=prepared/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
        if action!='initialize':relocate_metadata(prepared,root,prepared)
        if external is not None:(prepared/'external.xlsx').write_bytes(external)
        control=Path(temporary)/'request.json';control.write_bytes(encoded({'action':action,'request':request}))
        result_path=Path(temporary)/'result.json'
        child=subprocess.run([sys.executable,'-X','utf8',str(prepared/'tools/config_publication.py'),str(control),str(result_path)],
                             cwd=prepared,capture_output=True,text=True,encoding='utf-8',timeout=180)
        if child.returncode:
            raise ValueError(child.stderr.strip() or child.stdout.strip() or 'Configuration preparation failed')
        result=json.loads(result_path.read_bytes())
        if action=='load':return {**result,'snapshot':identity}
        if action!='initialize':relocate_metadata(prepared,prepared,root)
        files={name:raw.replace(b"\r\n",b"\n") for name,raw in json_files(prepared).items()}
        if action=='split':
            path=prepared/'config_excel/.split_manifest.json';mapping=json.loads(path.read_bytes())
            mapping.update(source=str(Path(source).resolve()),source_sha256=digest(external))
            files['config_excel/.split_manifest.json']=encoded(mapping);result['directory']=str(root/'config_excel')
        updates={p.relative_to(prepared).as_posix():p.read_bytes() for p in (prepared/'config_excel').glob('*.xlsx')
                 if p.read_bytes()!=inputs.get(p.relative_to(prepared).as_posix())}
        # Built-in export templates and Lab enemies belong to the published snapshot;
        # the independently editable original workbooks remain separate source inputs.
        for name in ('level.xlsx','monGroup.xlsx','mon.xlsx'):
            key='config_excel/published/'+name
            files[key]=original[key] if action=='split' and key in original else (prepared/'config_excel'/name).read_bytes()
        if action=='validate':return result
        if action=='save':
            backup=root/'.runtime/level-editor-backups'/uuid.uuid4().hex
            backup.mkdir(parents=True)
            originals={name:raw for name,raw in {**original,**inputs}.items()
                       if name in updates or files.get(name,raw)!=raw}
            for name,raw in originals.items():
                path=backup/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
            (backup/'manifest.json').write_bytes(encoded({'version':1,'generation':expected.identity,
                'files':[{'target':str(root/name),'original':name,'sha256':digest(raw)} for name,raw in originals.items()]}))
            result['backup']=str(backup)
        published=store.publish(expected,files,lambda _:None,inputs=inputs,source_updates=updates,
                                initial_files=original if expected is None else None,
                                external_inputs=[{"path":str(Path(source).resolve()),"sha256":digest(external),"size":len(external),"model":"frozen_selection"}] if external is not None else None)
        result['generation']=published.identity
        if action=='save':return {**execute(root,'load'),**result}
        return result


if __name__=='__main__':
    control=json.loads(Path(sys.argv[1]).read_bytes())
    root=Path(__file__).resolve().parents[1]
    result=worker(root,control['action'],control['request'])
    Path(sys.argv[2]).write_bytes(encoded(result))
