from pathlib import Path
import re,json,gzip,sys,shutil
ROOT=Path.cwd()
source=(ROOT/'test/evidence/numeric-batch-incremental-20261014/run.py').read_text(encoding='utf8').split('cases={}')[0]
exec(source,globals())
EVIDENCE=ROOT/'test/evidence/numeric-update-20261014'
CASE_REF='b6a81045';base_prepare=prepare
sys.argv.append('--profile')
def prepare(profile):
 hashes=base_prepare(profile)
 targets={'game.gd':['upgrade_equipment_batch','upgrade_slot','invalidate_stat_cache'],'crew_system.gd':['advance','invalidate_resources'],'native_execution_session.gd':['prepare_numeric_batch','commit_numeric_batch'],'native_execution_compiler.gd':['compile','enemy_projection'],'compiled_combat_rules.gd':['compile']}
 for name,funcs in targets.items():
  p=ISO/'scripts'/name;s=p.read_text(encoding='utf8')
  if name=='compiled_combat_rules.gd':s=re.sub(r'^ +',lambda m:'\t'*len(m[0]),s,flags=re.M)
  for f in funcs:
   pat=r'^func '+re.escape(f)+r'\((.*)\)(\s*->\s*[^:]+)?:\s*$';m=re.search(pat,s,re.M);assert m,(name,f)
   args=m[1];ret=m[2] or '';names=[re.split(r'[:=]',x.strip())[0].strip() for x in args.split(',') if x.strip()]
   call='_economy_original_'+f+'('+','.join(names)+')';void=ret.replace(' ','')=='->void'
   wrapper='func '+f+'('+args+')'+ret+':\n\tvar stamp=preload("res://strip_gate.gd").begin()\n\t'+('' if void else 'var result=')+call+'\n\tpreload("res://strip_gate.gd").end(stamp,"economy.'+name[:-3]+'.'+f+'")\n'+('' if void else '\treturn result\n')+'\nfunc _economy_original_'+f+'('+args+')'+ret+':'
   s=s[:m.start()]+wrapper+s[m.end():]
  p.write_text(s,encoding='utf8')
 return hashes
raw,marks=run_case('economy-locate',True)
with gzip.open(EVIDENCE/'economy-locate.json.gz','wt',encoding='utf8') as f:json.dump(raw,f)
(EVIDENCE/'economy-ledger.json').write_text(json.dumps(ledger(raw),indent=2),encoding='utf8')
(EVIDENCE/'economy-cpu.json').write_text(json.dumps(marks,indent=2),encoding='utf8')
shutil.copy2(RUNTIME/'current-ledger-economy-locate.txt',EVIDENCE/'economy-locate.txt')
from collections import Counter
rows=[]
for phase,sample in zip(raw['phases'],raw['samples']):
 if any(x[2]=='economy.game.upgrade_equipment_batch' for x in phase['spans']):
  c=Counter()
  for a,b,k in phase['spans']:c[k]+=b-a
  rows.append({'step':sample['step'],'inclusive_ms':{k:v/1000 for k,v in c.items() if k.startswith('economy.') or k=='game.advance_shared_clock_and_economy'}})
(EVIDENCE/'economy-boundaries.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
print(json.dumps(rows,indent=2))
