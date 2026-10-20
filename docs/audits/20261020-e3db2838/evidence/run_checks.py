import os,subprocess,pathlib,json,time
root=pathlib.Path('/tmp/space-idle-audit'); logs=pathlib.Path('/tmp/space-audit-evidence')
tests=['/tmp/space-audit-evidence/probe_integrity.gd','test_save_transfer.gd','test_save_policy.gd','test_large_numbers.gd','test_state_ownership.gd','test_stat_cache.gd','test_ai_tech_tree.gd','test_hyperspace_state.gd']
results=[]
for name in tests:
 p=pathlib.Path(name); p=p if p.is_absolute() else root/'test'/p
 env=os.environ.copy()
 for var,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  q=logs/'userdata'/p.stem/folder;q.mkdir(parents=True,exist_ok=True);env[var]=str(q)
 start=time.monotonic()
 with (logs/(p.stem+'.log')).open('w') as out:
  try:r=subprocess.run(['godot','--headless','--path',str(root/'space-battleship'),'--script',str(p)],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=90);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 text=(logs/(p.stem+'.log')).read_text(errors='replace')
 results.append({'test':name,'code':code,'seconds':round(time.monotonic()-start,2),'script_errors':text.count('SCRIPT ERROR'),'fail_lines':[l for l in text.splitlines() if 'FAIL' in l or 'checks' in l or 'PASS' in l]})
 print(json.dumps(results[-1]),flush=True)
 (logs/'results.json').write_text(json.dumps(results,indent=2))
