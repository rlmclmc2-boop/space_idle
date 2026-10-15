"""QA-only pulse fixture: one clock per entire event-pattern batch, no gameplay mutation."""
from pathlib import Path
import hashlib, json, os, subprocess
from prepare_cost import ROOT,E,sha,exact

ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
PROJECT=Path('D:/CodexBuild/space_idle/compact-laser-perf-20261015/laser/space-battleship')
OUT=E/'internal-listener'
OUT.mkdir(exist_ok=True)
assert not (OUT/'receipt.json').exists()
assert sha(PROJECT/'bin/space_native.dll')=='1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
source=ROOT/'test/evidence/compact-laser-20261015/perf_driver.gd'
s=source.read_text(encoding='utf8')
s=exact(s,'class UI extends "res://scripts/battlefield.gd":',
'''class DummyEmitter extends RefCounted:
 signal event(kind:String,payload:Dictionary)
class UI extends "res://scripts/battlefield.gd":''','emitter')
probe='''
 var emitter=DummyEmitter.new()
 var selected:Array=[];var observed:Array=[]
 for connection in g.event.get_connections():
  var cb:Callable=connection.callable
  var owner=cb.get_object()
  var script=owner.get_script() if owner!=null else null
  var path=str(script.resource_path) if script!=null else ""
  observed.append({"path":path,"method":str(cb.get_method())})
  if str(cb.get_method())=="_compiled_configuration_event" or path in ["res://scripts/crew_system.gd","res://scripts/hightech_workshop.gd","res://scripts/hyperspace_panel.gd","res://scripts/planet_panel.gd","res://scripts/reactor_panel.gd"]:
   selected.append(cb)
 print("CALLBACKS ",JSON.stringify(observed)," selected=",selected.size())
 assert(selected.size()>=1,"No production listener connected")
 var patterns:Array=[["fire",7906],["projectile_impact",18436],["hit",18436],["enhancement_chain",10527],["enhancement_secondary",90]]
 var payload:Dictionary={}
 var times:Array=[]
 for enabled in [false,true,false,true,false]:
  if enabled:
   for cb in selected:emitter.event.connect(cb)
  else:
   for cb in selected:
    if emitter.event.is_connected(cb):emitter.event.disconnect(cb)
  var began=Time.get_ticks_usec()
  for pair in patterns:
   for i in int(pair[1]):emitter.event.emit(pair[0],payload)
  times.append({"internal_listeners":enabled,"duration_us":Time.get_ticks_usec()-began})
 var report={"listeners":observed,"selected":selected.size(),"patterns":patterns,"times":times,"source_sha256":''' + '"'+sha(source)+'"' + '''}
 FileAccess.open("res://.runtime/internal-listener.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("LISTENER_PROBE ",JSON.stringify(report))
 g.begin_retreat();scene.queue_free();await process_frame;quit();return
'''
s=exact(s,' g.event.connect(count_event)\n',' g.event.connect(count_event)\n'+probe,'probe insertion')
driver=PROJECT/'internal_listener_driver.gd'
assert not driver.exists()
driver.write_text(s,encoding='utf8')
env=os.environ.copy();u=Path('D:/CodexBuild/space_idle/compact-laser-cost-20261015/users/laser')
for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
 env[key]=str(u/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
env.update(PERF_NATIVE='1',PERF_SIDE='laser',WEAPON_CASE='laser',MISSILE_CONTROL='legend',COMPACT_LASER_MODE='on',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
try:
 with (OUT/'import.log').open('w',encoding='utf8') as f:
  imp=subprocess.run([str(ENGINE),'--path',str(PROJECT),'--headless','--editor','--import','--quit'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=150)
 assert imp.returncode==0 and 'SCRIPT ERROR' not in (OUT/'import.log').read_text(encoding='utf8',errors='replace'),'import failed'
 with (OUT/'run.log').open('w',encoding='utf8') as f:
  run=subprocess.run([str(ENGINE),'--path',str(PROJECT),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://internal_listener_driver.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=150)
 assert run.returncode==0 and 'SCRIPT ERROR' not in (OUT/'run.log').read_text(encoding='utf8',errors='replace'),'run failed'
 raw=(PROJECT/'.runtime/internal-listener.json').read_bytes()
 (OUT/'raw.json').write_bytes(raw)
 receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          'dll_sha256':sha(PROJECT/'bin/space_native.dll'),'driver_sha256':sha(driver),'raw_sha256':hashlib.sha256(raw).hexdigest(),
          'method':'Signal with actual production no-business hot listener Callables (eight registrations of six classes in this fixture); same event pattern on empty vs connected signal. One clock pair per whole batch; no gameplay event emitted.',
          'run_log_sha256':sha(OUT/'run.log'),'import_log_sha256':sha(OUT/'import.log')}
 (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
 print(json.dumps(json.loads(raw),indent=2))
finally:
 if driver.exists():driver.unlink()
