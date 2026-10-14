from pathlib import Path
import re,json,gzip,sys,shutil
ROOT=Path.cwd()
source=(ROOT/'test/evidence/numeric-batch-incremental-20261014/run.py').read_text(encoding='utf8').split('cases={}')[0]
exec(source,globals())
EVIDENCE=ROOT/'test/evidence/weapon-value-exit-20261014'
CASE_REF='b6292852';base_prepare=prepare
CHANGED=subprocess.check_output(['git','diff','--name-only','85ada8bc',CASE_REF,'--','space-battleship/scripts','space-battleship/shaders'],cwd=ROOT,text=True).splitlines()
EXPECTED_DLL='052b231e64bae9efb9e2601fc221f26390ee5346758bed5f5da278b2235caf4e'
sys.argv.append('--profile')
def prepare(profile):
 hashes=base_prepare(profile)
 shutil.copy2(WORK/"numeric-update/candidate.dll",ISO/"bin/space_native.dll")
 targets={'game.gd':['upgrade_equipment_batch','upgrade_slot','invalidate_stat_cache','can_upgrade_slot','slot_upgrade_cost','resources_changed'],'crew_system.gd':['advance','invalidate_resources'],'native_execution_session.gd':['prepare_numeric_batch','commit_numeric_batch'],'native_execution_compiler.gd':['compile','compile_numeric_update','bind_numeric_context','configuration_template'],'compiled_combat_rules.gd':['compile','refresh_equipment_rows']}
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
 p=ISO/'scripts/game.gd';s=p.read_text(encoding='utf8')
 a=s.index('func _economy_original_upgrade_slot(');b=s.index('\nfunc ',a+5);part=s[a:b]
 G='preload("res://strip_gate.gd")'
 part=part.replace('\tfor id in costs:', '\tvar slot_stamp='+G+'.begin()\n\tfor id in costs:',1)
 for needle,label in [('\tvar before = upgrade_capacity_value(entry,key)','slot.debit'),('\tprofile.loadout[category][index].level','slot.before_value'),('\tresources_changed(costs.keys())','slot.level_write'),('\tinvalidate_stat_cache(native_updated)','slot.resources_changed'),('\tvar after = upgrade_capacity_value(entry,key)','slot.invalidate'),('\t# Preserve existing damage','slot.after_value'),('\tnative_numeric_update=false','slot.defence_delta'),('\tevent.emit("upgrade",','slot.bookkeeping')]:
  assert needle in part,needle
  part=part.replace(needle,'\t'+G+'.end(slot_stamp,"'+label+'")\n\tslot_stamp='+G+'.begin()\n'+needle,1)
 part=part.replace('\treturn true','\t'+G+'.end(slot_stamp,"slot.upgrade_event")\n\treturn true',1)
 p.write_text(s[:a]+part+s[b:],encoding='utf8')
 return hashes
raw,marks=run_case('slot-locate',True)
with gzip.open(EVIDENCE/'slot-locate.json.gz','wt',encoding='utf8') as f:json.dump(raw,f)
(EVIDENCE/'slot-ledger.json').write_text(json.dumps(ledger(raw),indent=2),encoding='utf8')
(EVIDENCE/'slot-cpu.json').write_text(json.dumps(marks,indent=2),encoding='utf8')
shutil.copy2(RUNTIME/'current-ledger-slot-locate.txt',EVIDENCE/'slot-locate.txt')
from collections import Counter
rows=[]
for phase,sample in zip(raw['phases'],raw['samples']):
 if any(x[2]=='economy.game.upgrade_equipment_batch' for x in phase['spans']):
  c=Counter()
  for a,b,k in phase['spans']:c[k]+=b-a
  rows.append({'step':sample['step'],'inclusive_ms':{k:v/1000 for k,v in c.items() if k.startswith('economy.') or k.startswith('slot.') or k=='game.advance_shared_clock_and_economy'}})
(EVIDENCE/'slot-boundaries.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
print(json.dumps(rows,indent=2))
