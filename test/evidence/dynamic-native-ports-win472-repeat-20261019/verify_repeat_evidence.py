"""Verify this delivery's raw bytes, immutable inputs and exact isolated QA edits."""
from pathlib import Path
import argparse,gzip,hashlib,json,struct,subprocess,sys
sys.dont_write_bytecode=True
from profile_ports import instrument_session,instrument_driver

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--write-checksums',action='store_true')
    a=p.parse_args();out=Path(__file__).resolve().parent;repo=out.parents[2]
    prior=out.parent/'dynamic-native-ports-win472-20261019';m=read(prior/'builds/manifest.json')
    analysis=read(out/'analysis.json');checked=[];invalid=[]
    def git_source(ref,path):
        return subprocess.check_output(['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo),'show',ref+':'+path])
    driver=git_source(m['candidate'],'test/evidence/ai-tech-final-matched-five-weapon/perf_driver.gd')
    expected_profile_driver=instrument_driver(driver.decode('utf-8')).encode('utf-8')
    for phase,expected_pairs in [('repeats',8),('profile',2)]:
        value=analysis['phases'][phase];assert value['all_runs_completed'] and len(value['pairs'])==expected_pairs
        assert value['formal_performance_eligible']==(phase=='repeats')
        for pair in value['pairs']:
            case=pair['case'];assert case in ['laser','missile']
            assert all(pair['matching'].values()) and all(pair['seed_only_projection_equal'].values())
            assert not any(pair['raw_full_state_equal'].values())
            folder=out/pair['output']
            for label in ['before','after']:
                name=case+'-'+label;receipt=read(folder/(name+'.receipt.json'));gates=pair['run_gates'][label]
                ref=m['baseline' if label=='before' else 'candidate']
                assert receipt['source_commit']==ref and receipt['library_sha256']==m['dll_sha256'][label]
                if phase=='repeats':
                    assert receipt['driver_sha256']==sha(driver)
                    assert receipt['script_sha256']==m['runtime_changed_scripts'][label]
                    if not gates['valid']:invalid.append(pair['output']+'/'+name)
                else:
                    assert gates['valid'] and receipt['driver_sha256']==sha(expected_profile_driver)
                    for path,expected in m['runtime_changed_scripts'][label].items():
                        if path=='scripts/native_execution_session.gd':
                            original=git_source(ref,'space-battleship/'+path).decode('utf-8').replace('\r\n','\n')
                            modified=instrument_session(original,label)
                            assert receipt['script_sha256'][path] in [sha(modified.encode('utf-8')),sha(modified.replace('\n','\r\n').encode('utf-8'))]
                        else:assert receipt['script_sha256'][path]==expected
                with gzip.open(folder/(name+'.json.gz'),'rt',encoding='utf-8') as f:d=json.load(f)
                assert (d['warm_steps'],d['sample_steps'])==(240,480)
                assert d['native_admitted'] and d['actual_1x_pass'] and d['gpu_beams_enabled']
                assert tuple(d['engine_version'][k] for k in ['major','minor','patch'])==(4,7,2)
                assert d['sampling_config']['window']=='(1373, 883)'
                assert not d['sampling_config']['old_pipeline_class'] and d['sampling_config']['retained']
                assert gates['phases']['pass'] and all(gates['fixture'].values()) and not gates['errors']
                png=(folder/(name+'.png')).read_bytes();assert struct.unpack('>II',png[16:24])==(1372,883)
                if phase=='profile':
                    for key in ['prepare_total','advance_total','kernel_advance','feedback_total']:
                        assert d['qa_profile'][key]['calls']==480
                    if label=='after':assert d['qa_profile']['ports_total']['calls']==480 and d['qa_profile']['ports_compute']['calls']==480
                else:assert 'qa_profile' not in d
                for suffix in ['.process.json.gz','.gpu.csv','.log','.engine.log']:assert (folder/(name+suffix)).is_file()
                checked.append(phase+'/'+name+'/'+str(pair['index']))
    assert invalid==['repeats/01-b1-laser-AB/laser-after']
    assert analysis['phases']['repeats']['summary']['laser']['valid_pairs']==3
    assert analysis['phases']['repeats']['summary']['missile']['valid_pairs']==4
    audit={'runs_checked':len(checked),'formal_repeats':16,'valid_formal_runs':15,
           'qa_runs':4,'qa_scope_reconstructed_and_hash_verified':True,
           'invalid_formal_run_retained':invalid,'raw_seed_only_mismatches_preserved':True,
           'new_projectile_pipeline_in_both':True,'formal_function_or_art_changes':False}
    (out/'evidence-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    sums={str(f.relative_to(out)).replace('\\','/'):sha(f.read_bytes()) for f in sorted(out.rglob('*'))
          if f.is_file() and '__pycache__' not in f.parts and f.name!='SHA256SUMS.json'}
    checksum=out/'SHA256SUMS.json'
    if checksum.exists() and not a.write_checksums:assert read(checksum)==sums,'Evidence checksum mismatch'
    else:checksum.write_text(json.dumps(sums,indent=2),encoding='utf-8')
    print('VERIFIED',len(checked),'runs;',len(sums),'files hashed; failed focus retained; exact QA scope verified.')

if __name__=='__main__':main()
