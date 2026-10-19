from pathlib import Path
import argparse,gzip,hashlib,json,struct,subprocess,sys,zipfile
sys.dont_write_bytecode=True
import count_scope
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(data):return hashlib.sha256(data).hexdigest()
def raw(p):
    with gzip.open(p,'rt',encoding='utf-8') as f:return json.load(f)
def main():
    p=argparse.ArgumentParser();p.add_argument('--write-checksums',action='store_true');args=p.parse_args()
    out=Path(__file__).resolve().parent;repo=out.parents[2];m=read(out/'builds/manifest.json');a=read(out/'analysis.json')
    def git(*cmd):return subprocess.check_output(['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo),*cmd])
    c=read(out/'correctness.json');assert c['checks']==5717 and c['failures']==0 and c['native_sha256']==m['dll_sha256']
    assert a['all_4_pairs_valid'] and len(a['pairs'])==4
    for pair in a['pairs']:
        assert pair['sampling_event_valid'] and all(pair['matching'].values())
        assert all(x['seed_only_projection_equal'] for x in pair['states'].values())
        folder=out/pair['output'];case=pair['case']
        for label in ['before','after']:
            receipt=read(folder/(case+'-'+label+'.receipt.json'));d=raw(folder/(case+'-'+label+'.json.gz'))
            assert receipt['library_sha256']==m['dll_sha256'] and receipt['script_sha256']==m['runtime_scripts'][label]
            assert receipt['driver_sha256']==m['frozen_driver_sha256'] and receipt['fixture_sha256']==m['fixture_sha256']
            assert (d['warm_steps'],d['sample_steps'])==(240,480) and d['actual_1x_pass'] and d['performance_sample_valid'] and d['native_admitted']
            assert d['sampling_config']['window']=='(1373, 883)' and d['gpu_beams_enabled']
            assert struct.unpack('>II',(folder/(case+'-'+label+'.png')).read_bytes()[16:24])==(1372,883)
    assert len(a['counts'])==2
    driver=git('show',m['cache_commit']+':test/evidence/ai-tech-final-matched-five-weapon/perf_driver.gd').decode('utf-8')
    for case in ['laser','missile']:
        folder=out/'counts';receipt=read(folder/(case+'-after.receipt.json'));d=raw(folder/(case+'-after.json.gz'))
        assert receipt['qa_count_only'] and receipt['library_sha256']==m['dll_sha256']
        assert receipt['driver_sha256']==sha(count_scope.driver(driver).encode('utf-8'))
        for path,expected in m['runtime_scripts']['after'].items():
            original=git('show',m['cache_commit']+':space-battleship/'+path).decode('utf-8').replace('\r\n','\n')
            if path=='scripts/native_execution_session.gd':expected=sha(count_scope.session(original).encode('utf-8'))
            elif path=='scripts/logical_fleet_pose.gd':expected=sha(count_scope.pose(original).encode('utf-8'))
            assert receipt['script_sha256'][path]==expected
        assert d['qa_cache_counts']=={'queries':2400,'builds':40,'row_rebuilds':8}
        assert d['actual_1x_pass'] and d['performance_sample_valid'] and d['native_admitted']
        assert d['events']==raw(out/next(p['output'] for p in a['pairs'] if p['case']==case)/(case+'-after.json.gz'))['events']
    with zipfile.ZipFile(out/'builds/windows-native.zip') as z:
        assert sha(z.read('bin/space_native.dll'))==m['dll_sha256']
        assert sha(z.read('reference/space_native.gdextension.in'))==m['unchanged_extension_template_sha256']
    integration=read(out/'integration-audit.json');assert integration['main_deleted_path_count']==807 and not integration['resurrected_paths']
    final_paths=set(git('ls-tree','-rz','--name-only','HEAD').decode().split('\0'))
    assert not set(integration['deleted_paths'])&final_paths
    for ref in [m['main_target'],m['cache_commit']]:
        subprocess.run(['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo),'merge-base','--is-ancestor',ref,'HEAD'],check=True)
    assert not git('diff','--no-renames','--name-only',m['cache_commit'],'HEAD','--','space-battleship/scripts','space-battleship/addons','space-battleship/data','space-battleship/assets','test/test_dynamic_native_ports.gd').strip()
    audit={'checks':5717,'correctness_failures':0,'formal_runs':8,'formal_pairs_all_valid':True,'same_DLL':m['dll_sha256'],
           'QA_count_runs':2,'QA_source_scope_hash_verified':True,'projection_queries_each':2400,'projection_builds_each':40,
           'main_deletions_preserved':807,'main_updated':False,'runtime_identical_to_tested_cache':True}
    (out/'evidence-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    sums={str(f.relative_to(out)).replace('\\','/'):sha(f.read_bytes()) for f in sorted(out.rglob('*'))
          if f.is_file() and '__pycache__' not in f.parts and f.name!='SHA256SUMS.json'}
    checksum=out/'SHA256SUMS.json'
    if checksum.exists() and not args.write_checksums:assert read(checksum)==sums
    else:checksum.write_text(json.dumps(sums,indent=2),encoding='utf-8')
    print('VERIFIED: 5717 checks; 8 valid formal runs + 2 QA; 807 deletions preserved;',len(sums),'evidence file hashes.')
if __name__=='__main__':main()
