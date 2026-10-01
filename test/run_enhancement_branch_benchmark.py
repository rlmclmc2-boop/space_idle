"""Run a bounded exact-runtime enhancement experiment in a save-isolated snapshot."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, time
p=argparse.ArgumentParser();p.add_argument('--stage',choices=['smoke','focus','risks','full','production','phase','crossover','combos','joint','critical_probe','buffer_probe','critical_cadence','delayed_fix','repeat30','corrected_cited'],default='focus');p.add_argument('--commit',required=True);p.add_argument('--godot',default='/usr/local/bin/godot');p.add_argument('--timeout',type=int,default=180);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent; src=root/'space-battleship'
area=root/'test/work/enhancement-balance-evidence'; area.mkdir(parents=True,exist_ok=True)
project=area/'runtime-project'; project.mkdir(exist_ok=True)
for name in ['scripts','data']:
    shutil.copytree(src/name,project/name,dirs_exist_ok=True)
(project/'project.godot').write_text('[application]\nconfig/name="enhancement benchmark isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
user=area/'user'; env=os.environ.copy();env['HOME']=str(user)
for key,folder in [('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config')]:
    dest=user/folder;dest.mkdir(parents=True,exist_ok=True);env[key]=str(dest)
result=area/(a.stage+'.json');env.update(ENHANCEMENT_BENCH_STAGE=a.stage,ENHANCEMENT_TESTED_COMMIT=a.commit,ENHANCEMENT_BENCH_OUTPUT=str(result))
harness=area/(a.stage+'-harness.gd');shutil.copy2(root/'test/benchmark_enhancement_branches.gd',harness)
metadata={'harness_sha256':hashlib.sha256(harness.read_bytes()).hexdigest(),'tested_runtime_commit':a.commit,'stage':a.stage,'data_sha256':hashlib.sha256((src/'data/game_data.json').read_bytes()).hexdigest(),'game_sha256':hashlib.sha256((src/'scripts/game.gd').read_bytes()).hexdigest(),'fixture_mutation': 'private in-memory weapon damage/CD and defense100HP; actual enhancement config retained; no player save','stationary_geometry': {'x': [200,280,360], 'y': [230,228,226], 'battlefield': [572,696]}, 'private_overrides': {key: os.environ.get(key) for key in ['REPEAT30_PROBABILITY','REPEAT30_ENEMIES','REPEAT30_MEASUREMENT','REPEAT30_SEED_SET']}, 'engine':subprocess.check_output([a.godot,'--version'],env=env,text=True).strip()}
(area/(a.stage+'-metadata.json')).write_text(json.dumps(metadata,indent=2))
commands=[([a.godot,'--headless','--editor','--import','--quit','--path',str(project)],'runtime-import.log'),([a.godot,'--headless','--path',str(project),'--script',str(harness)],a.stage+'.log')]
for cmd,logname in commands:
    begun=time.monotonic()
    with (area/logname).open('w') as log:
        code=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=a.timeout).returncode
    logtext=(area/logname).read_text(); print(logtext[-4000:]);print(f'{logname}: exit {code}, {time.monotonic()-begun:.2f}s')
    if code or 'SCRIPT ERROR' in logtext or 'Parse Error' in logtext:raise SystemExit(code or 1)
subprocess.run(['python',str(root/'test/summarize_enhancement_branches.py'),str(result)],check=True)
