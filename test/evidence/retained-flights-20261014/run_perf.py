from pathlib import Path
import subprocess,os,sys,json,ctypes,time,threading,hashlib
from ctypes import wintypes
r=Path('D:/CodexBuild/space_idle/stable-integration');work=r/'test/work';iso=work/'battle-fix-20261013/space-battleship';runtime=iso/'.runtime';python='D:/CodexTools/venv/godot-native/Scripts/python.exe'
api=ctypes.WinDLL('kernel32',use_last_error=True);api.GetProcessTimes.argtypes=[wintypes.HANDLE]+[ctypes.POINTER(wintypes.FILETIME)]*4;api.GetProcessTimes.restype=wintypes.BOOL

api.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];api.OpenProcess.restype=wintypes.HANDLE
api.CreateToolhelp32Snapshot.argtypes=[wintypes.DWORD,wintypes.DWORD];api.CreateToolhelp32Snapshot.restype=wintypes.HANDLE
api.CloseHandle.argtypes=[wintypes.HANDLE]
class Entry(ctypes.Structure):
 _fields_=[('size',wintypes.DWORD),('usage',wintypes.DWORD),('pid',wintypes.DWORD),('heap',ctypes.c_size_t),('module',wintypes.DWORD),('threads',wintypes.DWORD),('parent',wintypes.DWORD),('priority',wintypes.LONG),('flags',wintypes.DWORD),('exe',wintypes.WCHAR*260)]
api.Process32FirstW.argtypes=[wintypes.HANDLE,ctypes.POINTER(Entry)];api.Process32NextW.argtypes=[wintypes.HANDLE,ctypes.POINTER(Entry)]
def actual_game(proc):
 snapshot=api.CreateToolhelp32Snapshot(2,0);e=Entry();e.size=ctypes.sizeof(e);found=[]
 ok=api.Process32FirstW(snapshot,ctypes.byref(e))
 while ok:
  if e.parent==proc.pid and e.exe.startswith('Godot') and 'console' not in e.exe:found.append((e.pid,e.exe))
  ok=api.Process32NextW(snapshot,ctypes.byref(e))
 api.CloseHandle(snapshot)
 assert len(found)==1,('expected sole owned Godot child',proc.pid,found)
 proc.game_pid,proc.game_exe=found[0];proc.game_handle=api.OpenProcess(0x1000,False,proc.game_pid)
 if not proc.game_handle:raise ctypes.WinError(ctypes.get_last_error())
def cpu(proc):
 if not hasattr(proc,'game_handle'):actual_game(proc)
 values=[wintypes.FILETIME() for _ in range(4)]
 if not api.GetProcessTimes(proc.game_handle,*(ctypes.byref(v) for v in values)):raise ctypes.WinError(ctypes.get_last_error())
 us=lambda v:((v.dwHighDateTime<<32)|v.dwLowDateTime)/10
 return {'user_us':us(values[3]),'kernel_us':us(values[2]),'perf_counter_ns':time.perf_counter_ns()}

env=os.environ.copy();env.update(APPDATA=str(work/'battle-fix-20261013/roaming'),LOCALAPPDATA=str(work/'battle-fix-20261013/local'),PERF_NATIVE='1')
sequence=[('RF2A1',0,False),('RF2B',0,False),('RF2A2',0,False)]
previous_profile=None
for label,mode,profile in sequence:
 if previous_profile!=profile:
  subprocess.run([python,str(work/'prepare_strip.py')]+(['--profile'] if profile else []),check=True)
  previous_profile=profile
 for phase in ['begin','end']:
  ack=runtime/('cpu-ack-'+label+'-'+phase)
  if ack.exists():ack.unlink()
 env.update(STRIP_CASE=label,STRIP_MODE=str(mode),STRIP_PROFILE='1' if profile else '0',GPU_CONTACT_CASE='GPU',RETAINED_CASE='GPU' if label=='RF2B' else 'CPU')
 log=work/('strip-'+label+'.txt');receipt={};command=['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_retained_perf.gd']
 with log.open('w',encoding='utf-8') as out:
  proc=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
  watchdog=threading.Timer(90,proc.kill);watchdog.start()
  try:
   for line in proc.stdout:
    out.write(line);out.flush()
    if line.startswith('CPU_MARK '):
     parts=line.strip().split();assert parts[1]==label
     receipt[parts[2]]=cpu(proc)
     (runtime/('cpu-ack-'+label+'-'+parts[2])).write_text('ack',encoding='ascii')
    if 'STRIP_RESULT' in line:print(line.strip(),flush=True)
   code=proc.wait()
  finally:watchdog.cancel()
 text=log.read_text(encoding='utf-8')
 if code or 'SCRIPT ERROR' in text or 'STRIP_RESULT' not in text or not all(k in receipt for k in ['begin','end']):raise RuntimeError(label+' '+text[-1800:])
 api.CloseHandle(proc.game_handle)
 receipt.update(label=label,launcher_pid=proc.pid,pid=proc.game_pid,exe=proc.game_exe,method='Windows GetProcessTimes user+kernel CPU for the verified sole Godot game child of the owned console launcher, summed across its threads. File ACK surrounds the sample; CPU begins just before start ACK and ends before end ACK. Export/JSON/image saving happens only after end ACK; no unrelated process sampled.',dll_sha256=hashlib.sha256((iso/'bin/space_native.dll').read_bytes()).hexdigest())
 receipt['cpu_us']=sum(receipt['end'][k]-receipt['begin'][k] for k in ['user_us','kernel_us'])
 assert receipt['cpu_us']>0,('zero CPU counter',label)
 receipt['cpu_window_seconds']=(receipt['end']['perf_counter_ns']-receipt['begin']['perf_counter_ns'])/1e9
 (runtime/('cpu-'+label+'.json')).write_text(json.dumps(receipt,indent=2),encoding='utf-8')
 print('CPU',label,round(receipt['cpu_us']/1000,3),'ms',flush=True)
