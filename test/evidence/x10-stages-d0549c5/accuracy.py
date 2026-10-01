from pathlib import Path
import os,subprocess,shutil
r=Path('/workspace/space_idle');w=r/'test/work/x10-hotspot';p=w/'project';out=w/'accuracy';out.mkdir(exist_ok=True)
env=os.environ.copy()
for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:env[k]=str(w/'accuracy-user'/k)
for mode,frames in [('x1',6000),('x10',600),('exact10',600)]:
 with (out/(mode+'.log')).open('w') as f:
  z=subprocess.run(['godot','--headless','--path',str(p),'--script','res://probe.gd','--',mode,str(frames)],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/(mode+'.log')).read_text();print(mode,z.returncode,text[-500:],flush=True)
 assert z.returncode==0 and 'SCRIPT ERROR' not in text
 shutil.copy2(w/(mode+'.json'),out/(mode+'.json'))
