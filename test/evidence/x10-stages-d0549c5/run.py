from pathlib import Path
import os,subprocess,time,sys
r=Path('/workspace/space_idle');w=r/'test/work/x10-hotspot';env=os.environ.copy();env['DISPLAY']=':96'
for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:env[k]=str(w/'userdata'/k)
assert not Path('/tmp/.X11-unix/X96').exists(), 'Display96 already in use'
x=subprocess.Popen(['Xorg',':96','-config',str(r/'test/work/first-draw/xorg.conf'),'-noreset','-nolisten','tcp','-logfile',str(w/'xorg.log')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 for i in range(30):
  if x.poll() is not None:raise RuntimeError('Xorg startup failed')
  if Path('/tmp/.X11-unix/X96').exists():break
  time.sleep(.1)
 for mode in sys.argv[1:] or ['x1','x10','exact10']:
  with (w/(mode+'.log')).open('w') as f:
   z=subprocess.run(['godot','--path',str(w/'project'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1373x883','--script','res://probe.gd','--',mode,env.get('X10_FRAMES','600')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  s=(w/(mode+'.log')).read_text();print(mode,z.returncode,s[-900:],flush=True)
  if z.returncode or 'SCRIPT ERROR' in s:raise SystemExit(1)
finally:
 x.terminate();x.wait(timeout=10)
