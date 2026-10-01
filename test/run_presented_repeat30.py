"""Save-isolated, bounded formal player-missile comparison, with frozen provenance."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument('--commit',default='ef848c50042a0ee326f8a823721204bac7d2eedc')
parser.add_argument('--timeout',type=int,default=240)
parser.add_argument('--seeds',choices=['initial','extra'],default='initial')
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent
source=root/'space-battleship'
subprocess.run(['git','diff','--exit-code',args.commit,'--','space-battleship/scripts','space-battleship/data'],cwd=root,check=True,stdout=subprocess.DEVNULL)
area=root/'test/work/presented-repeat30';area.mkdir(parents=True,exist_ok=True)
project=area/'runtime-project';project.mkdir(exist_ok=True)
for name in ['scripts','data']:shutil.copytree(source/name,project/name,dirs_exist_ok=True)
(project/'project.godot').write_text('[application]\nconfig/name="presented repeat30 isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
env=os.environ.copy()
for key,folder in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
    dest=area/'user'/folder;dest.mkdir(parents=True,exist_ok=True);env[key]=str(dest)
result=area/('presented-'+args.seeds+'.json')
env.update(ENHANCEMENT_TESTED_COMMIT=args.commit,ENHANCEMENT_BENCH_OUTPUT=str(result),PRESENTED_SEEDS=args.seeds)
harness=root/'test/benchmark_presented_repeat30.gd'
metadata={'runtime_commit':args.commit,'harness_sha256':hashlib.sha256(harness.read_bytes()).hexdigest(),'data_sha256':hashlib.sha256((source/'data/game_data.json').read_bytes()).hexdigest(),'projection_sha256':hashlib.sha256((source/'scripts/presented_battle_game.gd').read_bytes()).hexdigest(),'engine':subprocess.check_output(['/usr/local/bin/godot','--version'],env=env,text=True).strip(),'no_production_mutation':True,'seed_set':args.seeds}
(area/('presented-'+args.seeds+'-metadata.json')).write_text(json.dumps(metadata,indent=2)+'\n')
for label,command in [('import',['--editor','--import','--quit']),('presented-'+args.seeds,['--script',str(harness)])]:
    log=area/(label+'.log');begun=time.monotonic()
    with log.open('w') as output:
        code=subprocess.run(['/usr/local/bin/godot','--headless','--path',str(project),*command],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=args.timeout).returncode
    content=log.read_text();print(content[-2500:]);print(label,'exit',code,'wall_seconds',time.monotonic()-begun)
    if code or any(x in content for x in ['SCRIPT ERROR','Parse Error','Assertion failed']):raise SystemExit(code or 1)
print('Output:',result)
