from pathlib import Path
import subprocess,os,json,shutil
repo=Path('/workspace/planet-art');area=repo/'test/work/test_planet_dialog_layout-syvm2_lb';qa=area/'space-battleship';out=Path('/workspace/planet-delivery/protection-precision')
files=['scripts/game.gd','scripts/enhancement_branches.gd','scripts/main.gd']
env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[key]=str(area/'userdata'/folder)
shutil.copy2(repo/'test/test_protection_hit_feedback.gd',area/'test/test_protection_hit_feedback.gd')
def populate(ref=None):
 for name in files:
  data=subprocess.check_output(['git','show',ref+':space-battleship/'+name],cwd=repo) if ref else (repo/'space-battleship'/name).read_bytes()
  (qa/name).write_bytes(data)
def run(label,script='test_protection_hit_feedback.gd',baseline=False,expected=0):
 local=env.copy();local['PROTECTION_FEEDBACK_BASELINE']='1' if baseline else '0'
 with (out/(label+'.log')).open('w') as log:
  r=subprocess.run(['godot','--headless','--audio-driver','Dummy','--path',str(qa),'--script',str(area/'test'/script)],env=local,stdout=log,stderr=subprocess.STDOUT,timeout=30)
 print(label,'exit',r.returncode,flush=True)
 assert r.returncode==expected,(label,(out/(label+'.log')).read_text())
 if script=='test_protection_hit_feedback.gd':shutil.copy2(qa/'feedback-results.json',out/(label+'.json'))
try:
 populate('31933e2da98cf648f6aa1f89800813d1f7ffdf52');run('reviewed-candidate-boundaries',expected=1)
 populate('e16abb40f12ca25a547d381b4ac643b979124cb0');run('original-main-business',baseline=True)
 populate();run('fixed-feedback')
 before=json.loads((out/'original-main-business.json').read_text());after=json.loads((out/'fixed-feedback.json').read_text())
 assert len(before)==len(after)==24
 keys=['body','shield','armour','buffers','cover','hits','rng','debt','module_damage','state','since_hit']
 for a,b in zip(before,after):
  assert a['case']==b['case']
  for k in keys:assert a[k]==b[k],(a['case'],k,a[k],b[k])
 print('BUSINESS EQUALITY:',len(after),'cases x',len(keys),'fields; includes nonempty debt buckets',flush=True)
 run('neutral-memory','test_neutral_memory_protection.gd')
 run('deferred-regression','test_deferred_enhancements.gd')
finally:populate()
