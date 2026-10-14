from pathlib import Path
import hashlib,io,json,os,shutil,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[4];E=Path(__file__).resolve().parent
AREA=ROOT/'test/work/five-environment-20261015-baseline'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
CASES=['on','off']
DLLS={key:ROOT/'test/work/endless-beam-main-20261014/test/artifacts/endless-beam-20261014/space_native.dll' for key in CASES}
REFS={key:'09b756a2a9cd0e1b389af2bdb8d54b9236aba433' for key in CASES}
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
assert sha(DLLS[CASES[0]])=='974e879a0d107f2c07c20b32e6f9cdd7939122cb4e7b3ed4618039b3012d0bab'
assert not any((E/(name+suffix)).exists() for name in CASES for suffix in ['.json','.json.gz']),'Never overwrite completed samples'
AREA.mkdir(parents=True,exist_ok=True)
receipt={'refs':REFS,'order':CASES,'warm_step_target':240,'sample_step_target':480,'runs':[],'imports':{},'dll_sha256':{key:sha(path) for key,path in DLLS.items()},'engine_sha256':sha(ENGINE),'driver_sha256':sha(E/'driver.gd'),'fixture_sha256':sha(E/'combat_stress_fixture.gd'),'probe_policy':{'whole_state_reads_per_run':2,'counter_reads_per_run':2,'per_step_exports':0,'per_step_scans':0,'counter_increment_cost_included':True},'scope':'Diagnostic shader isolation only in existing cannon environment, exact baseline54a9fa10. ON/OFF changes only visible shield mesh after production update; damage/logic/other visual workload unchanged. OFF is never production acceptance. Measures actual two shader-submit calls plus whole ship viewport CPU/GPU if driver supports them; includes instrument overhead.'}
def save(): (E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
projects={}
for label in CASES:
 target=AREA/'cannon';project=target/'space-battleship'
 assert project.exists()
 shutil.copy2(E/'driver.gd',project/'port_perf.gd')
 env=os.environ.copy()
 env.update(PERF_NATIVE='1',PERF_SIDE=label,WEAPON_CASE='cannon',MISSILE_CONTROL='legend',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 projects[label]=(project,env)
for label in CASES:
 project,base_env=projects[label]
 env=base_env.copy()
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(AREA/'users'/label/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env['PERF_SIDE']=label
 env['WEAPON_CASE']='cannon'
 env['SHIELD_COST_OFF']='1' if label=='off' else '0'
 env['MISSILE_CONTROL']='legend'
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
