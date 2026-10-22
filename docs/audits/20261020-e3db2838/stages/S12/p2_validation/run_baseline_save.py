from pathlib import Path
import hashlib,io,json,os,subprocess,tarfile,time
root=Path(__file__).resolve().parent;repo=root.parent/'p2-runtime';project=root/'game-project'
baseline='31e79337741bf9860d69fff21dae6be994dacd00';restore='5174bf1079f7442f67655cd5ff1b098179284e7d'
def materialize(ref):
    hashes={}
    data=subprocess.check_output(['git','archive',ref,'space-battleship/scripts'],cwd=repo)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for entry in archive.getmembers():
            if not entry.isfile():continue
            destination=project/Path(entry.name).relative_to('space-battleship')
            assert destination.resolve().is_relative_to(project.resolve())
            content=archive.extractfile(entry).read();destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(content)
            hashes[entry.name]=hashlib.sha256(content).hexdigest()
    return hashes
hashes=materialize(baseline)
probe=(root/'baseline_save_probe.gd').read_bytes();(project/'baseline_save_probe.gd').write_bytes(probe)
run=root/'evidence'/('baseline-save-'+str(time.time_ns()));run.mkdir()
env=os.environ.copy()
for key,name in (('APPDATA','Roaming'),('LOCALAPPDATA','Local')):
    env[key]=str(run/name);Path(env[key]).mkdir()
engine=r'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
cmd=[engine,'--headless','--path',str(project),'--script','baseline_save_probe.gd']
freeze={'runtime_sha':baseline,'source_sha256':hashes,'probe_sha256':hashlib.sha256(probe).hexdigest(),'engine_sha256':hashlib.sha256(Path(engine).read_bytes()).hexdigest(),'command':cmd,'appdata':env['APPDATA'],'localappdata':env['LOCALAPPDATA'],'scope':'three ordinary saves of a fresh actual main Game, old m/e iron1e3800, material1000; diagnostic only, no added pressure class. Unreferenced P2 modules remain in stage, no baseline script imports them.'}
(run/'freeze.json').write_text(json.dumps(freeze,indent=2),encoding='utf-8')
try:
    p=subprocess.run(cmd,env=env,capture_output=True,timeout=30);out,err,code=p.stdout,p.stderr,p.returncode
except subprocess.TimeoutExpired as exc:out,err,code=exc.stdout or b'',exc.stderr or b'',124
finally:materialize(restore)
(run/'stdout.log').write_bytes(out);(run/'stderr.log').write_bytes(err)
passed=code==0 and b'P2_BASELINE_SAVE_COMPLETE' in out and not any(x in out+err for x in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:',b'P2_FAIL'))
receipt={'status':'PASS' if passed else 'FAIL','exit_code':code,'stdout_sha256':hashlib.sha256(out).hexdigest(),'stderr_sha256':hashlib.sha256(err).hexdigest()}
(run/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({'evidence':str(run),**receipt}));print(out.decode('utf-8',errors='replace'));print(err.decode('utf-8',errors='replace')[-3000:])
raise SystemExit(0 if passed else 1)
