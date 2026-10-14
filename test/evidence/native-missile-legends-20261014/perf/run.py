from pathlib import Path
import hashlib,io,json,os,shutil,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[4];E=Path(__file__).resolve().parent
AREA=ROOT/'test/work/missile-legends-perf'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLLS={'A':ROOT.parent/'strange-matter-main-20261014/test/artifacts/strange-matter-20261014/space_native.dll','B':ROOT/'test/artifacts/missile-legends-20261014/space_native.dll'}
REFS={'A':'ce3ab502c17a9d00d598d8ff75aaa7a9b53b3ed8','B':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
import ctypes,threading
from ctypes import wintypes
class SystemLoad:
 def __init__(self):self.rows=[];self.done=threading.Event();self.thread=threading.Thread(target=self.collect,daemon=True)
 def collect(self):
  api=ctypes.WinDLL('kernel32',use_last_error=True)
  api.GetSystemTimes.argtypes=[ctypes.POINTER(wintypes.FILETIME)]*3
  previous=None
  while not self.done.is_set():
   stamps=[wintypes.FILETIME() for _ in range(3)]
   if api.GetSystemTimes(*[ctypes.byref(x) for x in stamps]):
    values=[(x.dwHighDateTime<<32)|x.dwLowDateTime for x in stamps]
    row={'unix':time.time(),'idle_100ns':values[0],'kernel_100ns':values[1],'user_100ns':values[2]}
    if previous:
     idle=values[0]-previous[0];total=values[1]+values[2]-previous[1]-previous[2]
     row['system_cpu_busy_percent']=100*(1-idle/total) if total else None
    self.rows.append(row);previous=values
   self.done.wait(0.5)
 def start(self):self.thread.start()
 def stop(self):self.done.set();self.thread.join()

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLLS['A'])=='ababa3df25330a0e4f12cc0b9fbb4757b9413f981d81930beec04b7b0510ecdf'
assert not any((E/(name+'.json')).exists() for name in ['Aordinary','Bordinary','Alegend','Blegend']),'Never overwrite completed samples'
AREA.mkdir(parents=True,exist_ok=True)
receipt={'refs':REFS,'order':['Aordinary','Bordinary','Alegend','Blegend'],'warm_step_target':240,'sample_step_target':480,'runs':[],'imports':{},'dll_sha256':{key:sha(path) for key,path in DLLS.items()},'engine_sha256':sha(ENGINE),'driver_sha256':sha(E/'driver.gd'),'fixture_sha256':sha(E/'combat_stress_fixture.gd'),'scope':'One full-legend missile AB pair plus separately labelled ordinary-missile control pair, current main versus corrected candidate. Preserve full legends, ordinary native admission/fallback, actual1x checks, uncapped/VSync off; overloaded sides remain diagnostics.'}
def save(): (E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
projects={}
for label,ref in REFS.items():
 DLL=DLLS[label]
 target=AREA/label;target.mkdir(exist_ok=True)
 archive=subprocess.check_output(['git','archive',ref,'space-battleship'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tf:tf.extractall(target,filter='data')
 project=target/'space-battleship';(project/'bin').mkdir(exist_ok=True)
 shutil.copy2(DLL,project/'bin/space_native.dll');shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',project/'space_native.gdextension')
 for a,z in [('driver.gd','port_perf.gd'),('combat_stress_fixture.gd','combat_stress_fixture.gd'),('missile_audit.gd','missile_audit.gd')]:shutil.copy2(E/a,project/z)
 (project/'.runtime').mkdir(exist_ok=True)
 shutil.copy2(E/'audit_smoke.gd',project/'audit_smoke.gd')
 from instrument import instrument
 shutil.copy2(E/'probe.gd',project/'probe.gd');instrument(project,E)
 from instrument_missile import instrument_missile
 instrument_missile(project)
 env=os.environ.copy()
 env['TEMP']=str(target/'tmp');env['TMP']=env['TEMP'];Path(env['TEMP']).mkdir(exist_ok=True)
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(target/'user'/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,WEAPON_CASE='missile',MISSILE_CONTROL='legend',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 with (target/'import.log').open('w',encoding='utf-8') as log:
  result=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 receipt['imports'][label]=result.returncode;save()
 assert result.returncode==0,'Import failed; stop'
 shutil.copy2(target/'import.log',E/(label+'-import.log'))
 assert 'SCRIPT ERROR' not in (target/'import.log').read_text(encoding='utf8',errors='replace'),'Import script error; no run'
 with (E/(label+'-audit-smoke.log')).open('w',encoding='utf8') as log:
  smoke=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--max-fps','0','--disable-vsync','--script','res://audit_smoke.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=60)
 if (project/'.runtime/audit-smoke.json').exists():shutil.copy2(project/'.runtime/audit-smoke.json',E/(label+'-audit-smoke.json'))
 assert smoke.returncode==0 and 'SCRIPT ERROR' not in (E/(label+'-audit-smoke.log')).read_text(encoding='utf8',errors='replace'),'Observer smoke failed before any full-frame sample'
 projects[label]=(project,env);print('Imported and audit-smoke passed',label,flush=True)
for label in ['Aordinary','Bordinary','Alegend','Blegend']:
 project,base_env=projects[label[0]]
 env=base_env.copy()
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(AREA/'users'/label/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env['PERF_SIDE']=label
 env['WEAPON_CASE']='missile'
 env['MISSILE_CONTROL']='ordinary' if label.endswith('ordinary') else 'legend'
 cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://port_perf.gd']
 run={'label':label,'cmd':cmd,'started_unix':time.time(),'project_sha256':sha(project/'project.godot'),'dll_sha256':sha(project/'bin/space_native.dll')}
 load=SystemLoad();load.start()
 try:
  with (E/(label+'.log')).open('w',encoding='utf-8') as log:result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
  run['exit']=result.returncode
 except subprocess.TimeoutExpired:run['exit']='timeout'
 load.stop()
 (E/(label+'-system-load.json')).write_text(json.dumps(load.rows,indent=2),encoding='utf8')
 run['completed_unix']=time.time()
 for ext in ['json','png']:
  source=project/'.runtime'/('uncapped-port.'+ext)
  if source.exists():shutil.copy2(source,E/(label+'.'+ext));run[ext+'_sha256']=sha(source)
 receipt['runs'].append(run);save()
 assert run['exit']==0 and 'json_sha256' in run,'Run failed; preserve output and stop'
 d=json.loads((E/(label+'.json')).read_text(encoding='utf-8'))
 assert 'SCRIPT ERROR' not in (E/(label+'.log')).read_text(encoding='utf8',errors='replace'),'Script errors; preserve and stop'
 invalid=[]
 for i,(f,dt) in enumerate(zip(d['phases'],d['frames_us_raw'])):
  t=[f[x] for x in ['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']]
  if t!=sorted(t) or t[-1]-t[0]!=dt:invalid.append(i)
 run['invalid_order_or_closure_frames']=invalid
 run['sample_count_equal']=len(d['phases'])==len(d['frames_us_raw'])==len(d['frame_trace'])
 save();print('Finished',label,'exit',run['exit'],'frames',len(d['phases']),'invalid',invalid,flush=True)
 assert not invalid and run['sample_count_equal'],'Invalid new timing boundary: preserve raw evidence and stop, do not change formula or rerun'
