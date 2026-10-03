"""Replay the parent's controlled input against current rule code and original numeric data."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--godot',default='godot');p.add_argument('--parent-ref',default='4d81bed07d88c008a02bcbd42eff25eb217214e4');a=p.parse_args()
subprocess.run([sys.executable,str(Path(__file__).with_name('build_qa.py')),'--output',str(a.output),'--data-ref','04a5a307bcef9325efa9026e1ca94affa577e10d'],check=True)
project=a.output.resolve();(project/'.runtime/parent-direct-first-hour').mkdir(parents=True)
for remote,local in [('parent_chrono_probe.gd','qa/parent_chrono_probe.gd'),('first-hour-evidence.json','.runtime/parent-direct-first-hour/evidence.json')]:
 content=subprocess.check_output(['git','show',a.parent_ref+':test/evidence/parent-progression-20261002/'+remote],cwd=ROOT)
 (project/local).write_bytes(content)
manifest=json.loads((project/'qa-manifest.json').read_text());manifest['parent_input_ref']=a.parent_ref
for rel in ['qa/parent_chrono_probe.gd','.runtime/parent-direct-first-hour/evidence.json']:manifest['files'][rel]=hashlib.sha256((project/rel).read_bytes()).hexdigest()
manifest['fingerprint']=hashlib.sha256(json.dumps(manifest['files'],sort_keys=True).encode()).hexdigest();(project/'qa-manifest.json').write_text(json.dumps(manifest,indent=2))
env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
 path=project/'userdata'/folder;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
for label,command in [('import',[a.godot,'--headless','--editor','--path',str(project),'--import','--quit']),('run',[a.godot,'--headless','--path',str(project),'--script','qa/parent_chrono_probe.gd'])]:
 log=project/(label+'.log')
 with log.open('w') as f:r=subprocess.run(command,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=900)
 if r.returncode or 'SCRIPT ERROR:' in log.read_text(errors='replace'):raise SystemExit('Failed: '+str(log))
report=json.loads((project/'.runtime/parent-chrono-probe.json').read_text());x1,x10,coarse=report['runs']
fields=['final_resources','furnace_peak','events','rng_state','hightech','stage','wave','cleared']
checks={k:x1[k]==x10[k] for k in fields}
output={'source_manifest':manifest,'parent_probe_output':report,'fine_x1_x10_checks':checks,'coarse_is_control_not_formal_path':True}
(project/'replay-evidence.json').write_text(json.dumps(output,indent=2))
print(json.dumps({'checks':checks,'x1_iron':x1['final_resources']['1'],'x10_iron':x10['final_resources']['1'],'peak':x1['furnace_peak'],'coarse_iron':coarse['final_resources']['1'],'output':str(project/'replay-evidence.json')},indent=2))
if not all(checks.values()):raise SystemExit(1)
