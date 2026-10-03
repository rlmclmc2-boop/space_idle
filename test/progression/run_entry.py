"""Run a controlled Godot diagnostic with isolated state and immutable logs."""
from pathlib import Path
import argparse,json,os,subprocess
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--entry',required=True)
p.add_argument('--label',required=True)
p.add_argument('--godot',default='godot')
p.add_argument('--options',type=Path,help='Enemy-probe options JSON; output is isolated automatically')
p.add_argument('--timeout',type=int,default=1800)
p.add_argument('--skip-import',action='store_true',help='Use an already imported immutable package; avoids concurrent editor imports')
a=p.parse_args();project=a.project.resolve()
if not (project/'qa-manifest.json').exists():raise SystemExit('Build a fingerprinted package first')
if a.skip_import:
 marker=project/'.qa-import-complete.json'
 if not marker.exists():raise SystemExit('Cannot skip import before this package successfully completed its own editor import')
 saved=json.loads(marker.read_text());manifest=json.loads((project/'qa-manifest.json').read_text())
 if saved.get('project')!=str(project) or saved.get('manifest_fingerprint')!=manifest['fingerprint']:raise SystemExit('Import marker belongs to a different package')
result=project/'diagnostics'/a.label
if result.exists():raise SystemExit('Label exists; preserve evidence and choose another')
result.mkdir(parents=True);env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','roaming'),('LOCALAPPDATA','local')]:
 path=project/'userdata'/a.label/folder;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
if a.options:
 options=json.loads(a.options.read_text());options['output']=str(result/'enemy-results.json')
 (result/'options.json').write_text(json.dumps(options,indent=2));env['ENEMY_DESIGN_OPTIONS']=json.dumps(options)
(result/'run.json').write_text(json.dumps({'entry':a.entry,'manifest':json.loads((project/'qa-manifest.json').read_text()),'options':str(a.options) if a.options else None,'import_skipped':a.skip_import},indent=2))
commands=[('import',[a.godot,'--headless','--editor','--path',str(project),'--import','--quit']),('run',[a.godot,'--headless','--path',str(project),'--script',a.entry])]
for label,cmd in commands[1:] if a.skip_import else commands:
 log=result/(label+'.log')
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=a.timeout)
 text=log.read_text(errors='replace')
 if r.returncode or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:raise SystemExit('Diagnostic failed; inspect '+str(log))
 if label=='import':(project/'.qa-import-complete.json').write_text(json.dumps({'project':str(project),'manifest_fingerprint':json.loads((project/'qa-manifest.json').read_text())['fingerprint']}))
print('Diagnostic completed: '+str(result))
