from pathlib import Path
import os, subprocess, json, hashlib, shutil, sys
ROOT=Path(__file__).resolve().parents[3]; E=Path(__file__).resolve().parent
AREA=ROOT/'test/work/endless-validation'; GAME=AREA/'space-battleship'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL=Path('D:/CodexBuild/space_idle/native-stable/bin/space_native.dll')
AREA.mkdir(parents=True,exist_ok=True)
fresh=not GAME.exists()
if fresh: shutil.copytree(ROOT/'space-battleship',GAME,ignore=shutil.ignore_patterns('.git','.godot','engine','.runtime','__pycache__'))
(GAME/'bin').mkdir(exist_ok=True)
shutil.copy2(DLL,GAME/'bin/space_native.dll')
shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',GAME/'addons/native_battle/space_native.gdextension')
for name in ['game.gd','native_execution_compiler.gd','native_execution_session.gd','native_execution_handoff.gd']:shutil.copy2(ROOT/'space-battleship/scripts'/name,GAME/'scripts'/name)
names=sys.argv[1:] or ['test_native_endless_beam','test_native_execution_handoff','test_native_numeric_upgrade','test_native_numeric_range','test_legacy_beam_shield_timing']
for name in names:shutil.copy2(ROOT/'test'/(name+'.gd'),GAME/(name+'.gd'))
env=os.environ.copy()
for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
 env[key]=str(AREA/'user'/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
env['QA_NATIVE_SHA256']=hashlib.sha256(DLL.read_bytes()).hexdigest()
receipt={'dll_sha256':env['QA_NATIVE_SHA256'],'kind':'isolated headless correctness, not performance','runs':[]}
if (E/'receipt.json').exists():receipt['runs']=json.loads((E/'receipt.json').read_text())['runs']
def run(label,args):
 cmd=[str(ENGINE),'--path',str(GAME),'--headless','--max-fps','0','--disable-vsync']+args
 log=E/(label+'-'+str(len(receipt['runs']))+'.log')
 with log.open('w',encoding='utf-8') as f:
  try:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  except subprocess.TimeoutExpired:
   receipt['runs'].append({'label':label,'command':cmd,'exit':'timeout_120s','log':log.name,'dll_sha256':env['QA_NATIVE_SHA256']});(E/'receipt.json').write_text(json.dumps(receipt,indent=2));raise
 text=log.read_text(encoding='utf-8',errors='replace');receipt['runs'].append({'label':label,'command':cmd,'exit':r.returncode,'log':log.name,'dll_sha256':env['QA_NATIVE_SHA256']})
 (E/'receipt.json').write_text(json.dumps(receipt,indent=2))
 print(label,r.returncode,text[-4500:],flush=True)
 if r.returncode or 'SCRIPT ERROR' in text or 'FAIL:' in text:sys.exit(1)
if fresh:run('import',['--editor','--import','--quit'])
for name in names:run(name,['--script','res://'+name+'.gd'])
