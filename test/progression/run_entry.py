"""Run a controlled Godot diagnostic with isolated state and immutable logs."""
from pathlib import Path
import argparse,json,os,subprocess,hashlib
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--entry',required=True)
p.add_argument('--label',required=True)
p.add_argument('--godot',default='godot')
p.add_argument('--options',type=Path,help='Enemy-probe options JSON; output is isolated automatically')
p.add_argument('--timeout',type=int,default=1800)
p.add_argument('--skip-import',action='store_true',help='Use an already imported immutable package; avoids concurrent editor imports')
p.add_argument('--resume',type=Path,help='Validated checkpoint.bin; falls back to its valid .previous file')
p.add_argument('--resume-legacy',type=Path,help='Old save_*.json: formal journey reload with explicitly incomplete QA state')
p.add_argument('--resume-manifest',type=Path,help='Original qa-manifest.json required for legacy continuity validation')
p.add_argument('--longrun-options',type=Path,help='HYPERSPACE_LONGRUN_OPTIONS JSON; duration is absolute campaign X1 time')
a=p.parse_args();project=a.project.resolve()
if not (project/'qa-manifest.json').exists():raise SystemExit('Build a fingerprinted package first')
if a.skip_import:
 marker=project/'.qa-import-complete.json'
 if not marker.exists():raise SystemExit('Cannot skip import before this package successfully completed its own editor import')
 saved=json.loads(marker.read_text());manifest=json.loads((project/'qa-manifest.json').read_text())
 if saved.get('project')!=str(project) or saved.get('manifest_fingerprint')!=manifest['fingerprint']:raise SystemExit('Import marker belongs to a different package')
if a.resume and a.resume_legacy:raise SystemExit('Choose one resume format')
if a.resume_legacy and not a.resume_manifest:raise SystemExit('Legacy recovery requires its original manifest')
manifest=json.loads((project/'qa-manifest.json').read_text())
continuity_qa={'early_page_route.gd','hyperspace_player_policy.gd','hyperspace_safe_farm.gd','player_input.gd','scene_driver.gd','presented_balance_game.gd'}
def continuity_rows(value):
 return {k:v for k,v in value['files'].items() if not k.startswith('qa/') or k.removeprefix('qa/') in continuity_qa}
if a.resume:
 failures=[]
 for candidate in [a.resume,a.resume.with_name(a.resume.name+'.previous')]:
  try:
   with candidate.open('rb') as f:header=json.loads(f.readline());payload=f.read()
   if header.get('format')!=1 or header.get('bytes')!=len(payload) or header.get('sha256')!=hashlib.sha256(payload).hexdigest():raise ValueError('format/checksum mismatch')
   if header.get('code_fingerprint')!=manifest['fingerprint']:raise ValueError('frozen package mismatch')
   break
  except (OSError,ValueError) as error:failures.append(str(candidate)+': '+str(error))
 else:raise SystemExit('No valid matching checkpoint: '+str(failures))
if a.resume_legacy:
 checkpoint=json.loads(a.resume_legacy.read_text());old_manifest=json.loads(a.resume_manifest.read_text())
 if not isinstance(checkpoint.get('save'),dict) or checkpoint.get('code_fingerprint')!=old_manifest['fingerprint'] or continuity_rows(old_manifest)!=continuity_rows(manifest):raise SystemExit('Legacy checkpoint/manifest gameplay or policy identity mismatch')
if a.resume or a.resume_legacy:
 for name,expected in manifest['files'].items():
  if (name.startswith(('scripts/','data/')) and name.endswith(('.gd','.json'))) or name.removeprefix('qa/') in continuity_qa:
   if hashlib.sha256((project/name).read_bytes()).hexdigest()!=expected:raise SystemExit('Frozen recovery package changed: '+name)
result=project/'diagnostics'/a.label
if result.exists():raise SystemExit('Label exists; preserve evidence and choose another')
result.mkdir(parents=True);env=os.environ.copy()
env['QA_DIAGNOSTIC_RESULT_DIR']=str(result)
if a.resume or a.resume_legacy:env['HYPERSPACE_RESUME_PATH']=str((a.resume or a.resume_legacy).resolve())
else:env.pop('HYPERSPACE_RESUME_PATH',None)
if a.resume_legacy:
 env['HYPERSPACE_RESUME_LEGACY']='1';env['HYPERSPACE_RESUME_MANIFEST']=str(a.resume_manifest.resolve())
else:
 env.pop('HYPERSPACE_RESUME_LEGACY',None);env.pop('HYPERSPACE_RESUME_MANIFEST',None)
if a.longrun_options:env['HYPERSPACE_LONGRUN_OPTIONS']=json.dumps(json.loads(a.longrun_options.read_text()))
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','roaming'),('LOCALAPPDATA','local')]:
 path=project/'userdata'/a.label/folder;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
if a.options:
 options=json.loads(a.options.read_text());options['output']=str(result/'enemy-results.json')
 (result/'options.json').write_text(json.dumps(options,indent=2));env['ENEMY_DESIGN_OPTIONS']=json.dumps(options)
(result/'run.json').write_text(json.dumps({'entry':a.entry,'manifest':json.loads((project/'qa-manifest.json').read_text()),'options':str(a.options) if a.options else None,'import_skipped':a.skip_import,'resume':str(a.resume or a.resume_legacy) if a.resume or a.resume_legacy else None,'legacy_resume':bool(a.resume_legacy),'longrun_options':env.get('HYPERSPACE_LONGRUN_OPTIONS')},indent=2))
commands=[('import',[a.godot,'--headless','--editor','--path',str(project),'--import','--quit']),('run',[a.godot,'--headless','--path',str(project),'--script',a.entry])]
for label,cmd in commands[1:] if a.skip_import else commands:
 log=result/(label+'.log')
 # Godot may remove obsolete importer options from tracked .import inputs.
 # Retain the frozen input bytes after importing into the isolated engine cache.
 import_inputs={name:(project/name).read_bytes() for name in manifest['files'] if name.endswith('.import')} if label=='import' else {}
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=a.timeout)
 restored=[]
 for name,original in import_inputs.items():
  if (project/name).read_bytes()!=original:
   (project/name).write_bytes(original);restored.append(name)
 if restored:(result/'import-metadata-restored.json').write_text(json.dumps(restored,indent=2))
 text=log.read_text(errors='replace')
 if r.returncode or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:raise SystemExit('Diagnostic failed; inspect '+str(log))
 if label=='import':(project/'.qa-import-complete.json').write_text(json.dumps({'project':str(project),'manifest_fingerprint':json.loads((project/'qa-manifest.json').read_text())['fingerprint']}))
print('Diagnostic completed: '+str(result))
