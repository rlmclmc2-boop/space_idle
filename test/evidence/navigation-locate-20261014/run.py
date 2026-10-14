from pathlib import Path
import subprocess,json,shutil,re,sys,os,hashlib,gzip
ROOT=Path.cwd();E=ROOT/'test/evidence/navigation-locate-20261014';WORK=ROOT/'test/work/battle-fix-20261013';ISO=WORK/'space-battleship';RUNTIME=ISO/'.runtime'
BASE='63b93069';DLL=WORK/'native-ray/contact-candidate.dll';EXPECTED='45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e';GODOT='D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLL)==EXPECTED
protocol={'source':BASE,'dll_sha256':EXPECTED,'runs':1,'warmup_steps':180,'sample_steps':240,'gpu_beams':False,'damage_cache':False,'purchase_candidate':False,'native_probe':False,'OS_counters':False,'purpose':'Nested GDScript navigation attribution only, not acceptance; require normal process exit; stop on abnormal exit.'}
(E/'protocol.json').write_text(json.dumps(protocol,indent=2),encoding='utf8')
shutil.copy2(DLL,ISO/'bin/space_native.dll')
selected=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','space-battleship/scripts','space-battleship/shaders'],text=True).splitlines()
selected=[n for n in selected if n.endswith(('.gd','.gdshader'))]
sys.argv.append('--profile')
source=(ROOT/'test/evidence/presentation-strip-20261014/prepare_strip.py').read_text(encoding='utf8');marker='gate='+chr(39)*3+'extends RefCounted'
overlay="import subprocess\nfor name in selected:\n data=subprocess.check_output(['git','show',BASE+':'+name],cwd=r)\n (iso/Path(name).relative_to('space-battleship')).write_bytes(data)\n"
exec(source.replace(marker,overlay+marker,1),{'selected':selected,'BASE':BASE})
G='preload("res://strip_gate.gd")'
for name,funcs in {'main.gd':['refresh_hyperspace_badge','refresh_unlock_content'],'unlock_tutorial.gd':['refresh'],'game.gd':['tutorial_unlocks','unread_tutorial_unlocks','unlock_available','unlock_condition_available']}.items():
 path=ISO/'scripts'/name;s=path.read_text(encoding='utf8')
 for f in funcs:
  m=re.search(r'^func '+f+r'\(([^\n]*)\)(\s*->\s*[^:]+)?:\s*$',s,re.M);assert m,(name,f)
  args=m[1];ret=m[2] or '';names=[re.split(r'[:=]',x.strip())[0] for x in args.split(',') if x.strip()];void=ret.replace(' ','')=='->void';call='_nav_original_'+f+'('+','.join(names)+')'
  wrap='func '+f+'('+args+')'+ret+':\n\tvar stamp='+G+'.begin()\n\t'+('' if void else 'var result=')+call+'\n\t'+G+'.end(stamp,"nav.'+name[:-3]+'.'+f+'")\n'+('' if void else '\treturn result\n')+'\nfunc _nav_original_'+f+'('+args+')'+ret+':'
  s=s[:m.start()]+wrap+s[m.end():]
 path.write_text(s,encoding='utf8')
qa=(ROOT/'test/evidence/typed-events-20261014/qa_original.gd').read_text(encoding='utf8').replace('480','240').replace('"source":"346c67f8"','"source":"'+BASE+'"')
qa=qa.replace('scene.retained_contacts_enabled=true;','scene.retained_contacts_enabled=true;scene.retained_gpu_beams_enabled=false;scene.damage_display_cache_enabled=false;')
qa=qa.replace('var cpu_begin_wait:=cpu_handshake(label,"begin")','var cpu_begin_wait:=0').replace('var cpu_end_wait:=cpu_handshake(label,"end")','var cpu_end_wait:=0')
qa=qa.replace(' var row={',' var row={"gpu_beams_enabled":scene.retained_gpu_beams_enabled,"damage_cache_enabled":scene.damage_display_cache_enabled,"help_open":scene.help_open,"pending_unlocks":g.pending_unlocks.duplicate(),',1)
(ISO/'qa_current_frame.gd').write_text(qa,encoding='utf8')
for src,dest in [('test/evidence/galaxy-boundary-20261014/qa_galaxy_residence.gd','qa_galaxy_residence.gd'),('test/evidence/typed-events-20261014/fixture_original.gd','combat_stress_fixture.gd')]:shutil.copy2(ROOT/src,ISO/dest)
(E/'prepared-hashes.json').write_text(json.dumps({n:sha(ISO/n.removeprefix('space-battleship/')) for n in selected},indent=2),encoding='utf8')
env=os.environ.copy();env.update(APPDATA=str(WORK/'roaming'),LOCALAPPDATA=str(WORK/'local'),PERF_NATIVE='1',STRIP_CASE='navigation',STRIP_MODE='0',STRIP_PROFILE='1',GPU_CONTACT_CASE='GPU',RETAINED_CASE='GPU')
cmd=[GODOT,'--path',str(ISO),'--rendering-method','gl_compatibility','--script','res://qa_current_frame.gd']
with (E/'run.txt').open('w',encoding='utf8') as log:
 proc=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
(E/'exit.json').write_text(json.dumps({'exit_code':proc.returncode}),encoding='utf8')
text=(E/'run.txt').read_text(encoding='utf8');assert proc.returncode==0 and 'SCRIPT ERROR' not in text and 'STRIP_RESULT' in text,text[-2000:]
d=json.loads((RUNTIME/'strip-navigation.json').read_text(encoding='utf8'));assert d['dll_sha256']==EXPECTED and d['steps']==d['native_steps']==240 and not d['gpu_beams_enabled'] and not d['damage_cache_enabled']
with gzip.open(E/'raw.json.gz','wt',encoding='utf8') as f:json.dump(d,f)
print('normal exit; frames',len(d['frames_us']),'help_open',d['help_open'],'pending',d['pending_unlocks'])
