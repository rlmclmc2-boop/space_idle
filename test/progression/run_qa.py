"""Run one isolated QA package and reject engine errors or missing final evidence."""
from pathlib import Path
import argparse,json,os,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);p.add_argument('--godot',default='godot');p.add_argument('--label',required=True);p.add_argument('--duration',type=int,default=10800);p.add_argument('--engine',choices=['formal','basic'],default='formal');p.add_argument('--scene',action='store_true');p.add_argument('--stop-clear',type=int,default=10);p.add_argument('--stop-reach',type=int,default=0);p.add_argument('--visit-seconds',type=int,default=120);p.add_argument('--teaching-seconds',type=int,default=10);p.add_argument('--seed',type=int,default=20261002);p.add_argument('--thematic',action='store_true');p.add_argument('--no-reforge',action='store_true');p.add_argument('--bulk',action='store_true');p.add_argument('--stop-galaxy',action='store_true');p.add_argument('--resume',type=Path);p.add_argument('--allow-version-change',action='store_true');p.add_argument('--timeout',type=int,default=3600);a=p.parse_args()
project=a.project.resolve();result=project/'results'/a.label
if result.exists():raise SystemExit('Result label already exists; preserve evidence and choose a new label')
if not (project/'qa-manifest.json').exists():raise SystemExit('Build a package first')
if a.scene and not json.loads((project/'qa-manifest.json').read_text()).get('scene_dependencies'):raise SystemExit('Build with --scene first')
env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','roaming'),('LOCALAPPDATA','local')]:
 path=project/'userdata'/a.label/folder;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
options={'label':a.label,'engine':a.engine,'scene':a.scene,'duration':a.duration,'stop_clear':a.stop_clear,'stop_reach':a.stop_reach,'visit_seconds':a.visit_seconds,'teaching_seconds':a.teaching_seconds,'seed':a.seed,'thematic':a.thematic,'allow_reforge':not a.no_reforge,'bulk':a.bulk,'stop_galaxy':a.stop_galaxy,'resume':str(a.resume.resolve()) if a.resume else '', 'allow_version_change':a.allow_version_change}
env['PROGRESSION_OPTIONS']=json.dumps(options)
logs=project/'logs';logs.mkdir(exist_ok=True)
for label,command in [('import',[a.godot,'--headless','--editor','--path',str(project),'--import','--quit']),('run',[a.godot,'--headless','--path',str(project),'--script','qa/progression_probe.gd'])]:
 log=logs/(a.label+'-'+label+'.log')
 with log.open('w') as f:
  try:r=subprocess.run(command,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=a.timeout)
  except subprocess.TimeoutExpired:raise SystemExit('Wall timeout; partial evidence preserved at '+str(result))
 text=log.read_text(errors='replace')
 if r.returncode or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:raise SystemExit('QA failed; inspect '+str(log))
summary=result/'summary.json'
if not summary.exists():raise SystemExit('No final summary; inspect logs')
s=json.loads(summary.read_text());print(json.dumps({k:s[k] for k in ['x1_seconds','clears','highest','deaths','action_sessions','action_events','wall_seconds']},indent=2));print('Evidence: '+str(result))
