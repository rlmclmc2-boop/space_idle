from pathlib import Path
import os, subprocess, json, hashlib, shutil, sys
ROOT=Path(__file__).resolve().parents[3];E=Path(__file__).resolve().parent
AREA=ROOT/'test/work/missile-legends-validation';GAME=AREA/'space-battleship'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL=Path('D:/CodexBuild/space_idle/native-stable/bin/space_native.dll')
AREA.mkdir(parents=True,exist_ok=True)
if not GAME.exists():
 shutil.copytree(ROOT/'space-battleship',GAME,ignore=shutil.ignore_patterns('.git','.godot','engine','.runtime','__pycache__'))
 (GAME/'bin').mkdir(exist_ok=True)
 shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',GAME/'addons/native_battle/space_native.gdextension')
shutil.copy2(DLL,GAME/'bin/space_native.dll')
for name in ['game.gd','native_execution_compiler.gd','native_execution_session.gd','native_execution_handoff.gd']:shutil.copy2(ROOT/'space-battleship/scripts'/name,GAME/'scripts'/name)
for name in (sys.argv[1:] or ['test_native_missile_legends']):shutil.copy2(ROOT/'test'/(name+'.gd'),GAME/(name+'.gd'))
env=os.environ.copy()
for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
 env[key]=str(AREA/'user'/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
env['PYTHONPYCACHEPREFIX']=str(AREA/'pycache')
receipt={'dll_sha256':hashlib.sha256(DLL.read_bytes()).hexdigest(),'source_base':'3ed91ce9','kind':'isolated headless correctness, not real-time performance','cap':0,'vsync':0,'runs':[]}
if (E/'validation-receipt.json').exists():receipt['runs']=json.loads((E/'validation-receipt.json').read_text(encoding='utf-8'))['runs']
def run(label,args):
 cmd=[str(ENGINE),'--path',str(GAME),'--headless','--max-fps','0','--disable-vsync']+args
 log=E/(label+'.log')
 with log.open('w',encoding='utf-8') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=180)
 text=log.read_text(encoding='utf-8',errors='replace');receipt['runs'].append({'label':label,'command':cmd,'exit':r.returncode})
 (E/'validation-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
 print(label,r.returncode,text[-3500:],flush=True)
 if r.returncode or 'SCRIPT ERROR' in text or 'FAIL:' in text:sys.exit(1)
if len(sys.argv)==1:run('import',['--editor','--import','--quit'])
for name in (sys.argv[1:] or ['test_native_missile_legends']):run(name,['--script','res://'+name+'.gd'])
