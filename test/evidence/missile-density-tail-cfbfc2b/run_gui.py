from pathlib import Path
import subprocess,os,time,sys,json
r=Path('/workspace/space_idle');a=r/'test/work/density-tail';p=a/'run/space-battleship';label=sys.argv[1];env=os.environ.copy();env['DISPLAY']=':98';env['LD_PRELOAD']=str(a/'thread_clock.so')
for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:env[k]=str(a/'run/userdata'/k)
if len(sys.argv)>2:env['LP_NUM_THREADS']=sys.argv[2]
meta={'cgroup_before':Path('/sys/fs/cgroup/cpu.stat').read_text(),'lp_threads':env.get('LP_NUM_THREADS','default')}
x=subprocess.Popen(['Xorg',':98','-config',str(r/'test/work/first-draw/xorg.conf'),'-noreset','-nolisten','tcp','-logfile',str(a/(label+'-xorg.log'))],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 for i in range(30):
  if Path('/tmp/.X11-unix/X98').exists():break
  time.sleep(.1)
 with (a/(label+'.log')).open('w') as f:
  z=subprocess.run(['godot','--path',str(p),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1373x883','--script','res://dynamic.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=150)
 log=(a/(label+'.log')).read_text();print('exit',z.returncode,log[-1000:]);assert z.returncode==0 and 'SCRIPT ERROR' not in log and 'Parse Error' not in log
 (a/(label+'.json')).write_bytes((p/'density.json').read_bytes())
finally:
 x.terminate();x.wait(timeout=10)
 meta['cgroup_after']=Path('/sys/fs/cgroup/cpu.stat').read_text();(a/(label+'-meta.json')).write_text(json.dumps(meta,indent=2))
