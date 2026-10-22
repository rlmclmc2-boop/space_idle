from pathlib import Path
import hashlib,json,os,subprocess,time,sys
root=Path(__file__).resolve().parent
repo=root.parent/'p2-runtime'
project=root/'game-project'
target='062168c31017a53686da53488cfeefef473b542b'
import io,tarfile
hashes={}
archive=subprocess.check_output(['git','archive',target,'space-battleship/scripts'],cwd=repo)
with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
    for entry in bundle.getmembers():
        if not entry.isfile():continue
        destination=project/Path(entry.name).relative_to('space-battleship')
        assert destination.resolve().is_relative_to(project.resolve())
        data=bundle.extractfile(entry).read();destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data)
        hashes[entry.name]=hashlib.sha256(data).hexdigest()
probe=(root/'cold_game_probe.gd').read_bytes()
(project/'cold_game_probe.gd').write_bytes(probe)
suite=root/'evidence'/('cold-'+str(time.time_ns()))
suite.mkdir(parents=True)
engine=r'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
freeze={'runtime_sha':target,'runtime_tree':'8fa63c6767a6f37befb23fc7b9e18e2b48ce55f4','source_sha256':hashes,'probe_sha256':hashlib.sha256(probe).hexdigest(),'engine_sha256':hashlib.sha256(Path(engine).read_bytes()).hexdigest(),'inputs':{'start':1,'material':9007199254740991,'exact256':{'v':1,'i':'55916713612491779479035'},'middle':{'m':1,'e':3800},'far':{'m':1,'e':1000000000},'cancel':'far; cancel during bound at candidate>=32768'},'rounds':10,'gates':{'query_frame_total_us':4000,'heartbeat_us':50000,'actual_cancel_us':100000,'total_time':'report only'},'overlay':'isolated APPDATA/LOCALAPPDATA; public CA project override; audit probe only'}
(suite/'freeze.json').write_text(json.dumps(freeze,indent=2),encoding='utf-8')
print(str(suite),flush=True)
rows=[]
for scenario in ('exact256','middle','far','cancel'):
    for iteration in range(10):
        run=suite/(scenario+'-%02d'%(iteration+1));run.mkdir()
        env=os.environ.copy()
        for key,name in (('APPDATA','Roaming'),('LOCALAPPDATA','Local')):
            env[key]=str(run/name);Path(env[key]).mkdir()
        cmd=[engine,'--headless','--path',str(project),'--script','cold_game_probe.gd','--',scenario]
        start=time.monotonic()
        try:
            p=subprocess.run(cmd,env=env,capture_output=True,timeout=120)
            out,err,code=p.stdout,p.stderr,p.returncode
        except subprocess.TimeoutExpired as exc:
            out,err,code=exc.stdout or b'',exc.stderr or b'',124
        (run/'stdout.log').write_bytes(out);(run/'stderr.log').write_bytes(err)
        marker=b'P2_COLD_RESULT '
        results=[json.loads(line[len(marker):]) for line in out.splitlines() if line.startswith(marker)]
        passed=code==0 and b'P2_COLD_COMPLETE' in out and len(results)==1 and results[0]['status']=='PASS' and not any(term in out+err for term in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:',b'P2_FAIL'))
        row={'scenario':scenario,'iteration':iteration+1,'status':'PASS' if passed else 'FAIL','exit_code':code,'seconds':time.monotonic()-start,'command':cmd,'appdata':env['APPDATA'],'localappdata':env['LOCALAPPDATA'],'measurement':results,'stdout_sha256':hashlib.sha256(out).hexdigest(),'stderr_sha256':hashlib.sha256(err).hexdigest()}
        (run/'receipt.json').write_text(json.dumps(row,indent=2),encoding='utf-8')
        rows.append(row)
        (suite/'result.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
        print(json.dumps(row),flush=True)
        if not passed:
            print(err.decode('utf-8',errors='replace')[-3000:],flush=True)
            sys.exit(1)
print('P2_COLD_SUITE_COMPLETE',flush=True)
