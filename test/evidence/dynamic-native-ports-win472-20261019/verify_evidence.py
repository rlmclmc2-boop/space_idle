"""Verify delivered evidence consistency; does not run or alter the game."""
from pathlib import Path
import argparse,gzip,hashlib,json,struct,zipfile

def main():
    p=argparse.ArgumentParser();p.add_argument('output',nargs='?',type=Path,default=Path(__file__).resolve().parent)
    p.add_argument('--write-checksums',action='store_true')
    args=p.parse_args();out=args.output
    m=json.loads((out/'builds/manifest.json').read_text(encoding='utf-8'))
    v=json.loads((out/'validity.json').read_text(encoding='utf-8'))
    summary=json.loads((out/'summary-runs.json').read_text(encoding='utf-8'))
    assert len(summary['rows'])==10
    assert v['all_five_sampling_event_pairs_valid'] is True
    assert v['all_five_pairs_valid'] is False
    with zipfile.ZipFile(out/'builds/windows-validation.zip') as archive:
        for label in ['before','after']:
            assert hashlib.sha256(archive.read(label+'/space_native.dll')).hexdigest()==m['dll_sha256'][label]
    runs=[]
    for pair in v['pairs']:
        assert pair['sampling_event_pair_valid'] and not pair['paired_valid']
        assert all(pair['seed_only_projection_diagnostic']['endpoint_equal'].values())
        for label in ['before','after']:
            name=pair['case']+'-'+label
            receipt=json.loads((out/(name+'.receipt.json')).read_text(encoding='utf-8'))
            assert receipt['exit_code']==0
            assert receipt['source_commit']==m['baseline' if label=='before' else 'candidate']
            assert receipt['driver_sha256']==m['frozen_inputs']['perf_driver.gd']['sha256']
            key='mixed_fixture.gd' if pair['case']=='mixed' else 'combat_stress_fixture.gd'
            assert receipt['fixture_sha256']==m['frozen_inputs'][key]['sha256']
            assert receipt['library_sha256']==m['dll_sha256'][label]
            assert receipt['script_sha256']==m['runtime_changed_scripts'][label]
            with gzip.open(out/(name+'.json.gz'),'rt',encoding='utf-8') as f:d=json.load(f)
            assert (d['warm_steps'],d['sample_steps'])==(240,480)
            assert d['performance_sample_valid'] and d['actual_1x_pass'] and d['native_admitted']
            assert d['sampling_config']['window']=='(1373, 883)'
            assert d['gpu_beams_enabled']
            png=(out/(name+'.png')).read_bytes()
            assert png[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',png[16:24])==(1372,883)
            assert pair['runs'][label]['valid'] and not pair['runs'][label]['errors']
            assert pair['runs'][label]['gpu']['samples']>0
            assert (out/(name+'.process.json.gz')).is_file()
            runs.append(name)
    audit={'scope':'Evidence consistency only; no game execution',
        'runs_checked':runs,'frozen_driver_and_fixtures_verified':True,
        'exact_commit_scripts_and_built_DLL_hashes_verified':True,
        'DLL_archive_matches_manifest':True,
        'ten_runtime_gates_pass':True,'five_sampling_event_pairs_pass':True,
        'five_raw_full_state_pairs_pass':False,
        'raw_seed_and_derived_hash_mismatches_preserved':True,
        'ten_complete_root_images_same_dimensions':[1372,883],
        'source_window_dimensions':[1373,883]}
    (out/'evidence-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    sums={str(path.relative_to(out)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest()
          for path in sorted(out.rglob('*')) if path.is_file() and path.name!='SHA256SUMS.json'}
    checksum_file=out/'SHA256SUMS.json'
    if checksum_file.exists() and not args.write_checksums:
        assert json.loads(checksum_file.read_text(encoding='utf-8'))==sums,'Delivered SHA256 checksums differ'
    else:checksum_file.write_text(json.dumps(sums,indent=2),encoding='utf-8')
    print('Evidence audit passed:',len(runs),'runs;',len(sums),'files hashed; raw full-state mismatch retained.')

if __name__=='__main__':main()
