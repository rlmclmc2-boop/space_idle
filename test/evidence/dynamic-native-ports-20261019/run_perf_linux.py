"""Replay the existing five high-load fixtures on Linux; retain invalid gates too.
Requires an imported isolated project and before/after Linux libraries. No save IO.
"""
from pathlib import Path
import argparse, gzip, hashlib, json, os, shutil, statistics, subprocess
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--before-lib',type=Path,required=True)
p.add_argument('--after-lib',type=Path,required=True)
p.add_argument('--display',default=':91')
p.add_argument('--cases',nargs='+',default=['mixed','laser','cannon','missile','longLaser'])
a=p.parse_args()
base=Path(__file__).resolve().parent
repo=base.parents[2]
frozen=base.parent/'ai-tech-final-matched-five-weapon'
project=a.project.resolve()
files=['scripts/native_execution_session.gd','scripts/battle_slice_runtime.gd','scripts/logical_fleet_pose.gd']
after={n:(repo/'space-battleship'/n).read_bytes() for n in files}
before={n:subprocess.check_output(['git','show','c4a5e259:space-battleship/'+n],cwd=repo) for n in files}
driver=(frozen/'perf_driver.gd').read_text()
# Observation only; preserve fixture, warm/sample loop, wall spans and validity gates.
driver=driver.replace('var fire_count:=0','var fire_count:=0\n var visual_port_feedback:=0')
driver=driver.replace('fire_count+=1','fire_count+=1\n   if info.has("presentation_origin") or info.get("shot",{}).has("presentation_origin"):visual_port_feedback+=1')
driver=driver.replace('row.runtime_config_end=config(scene)','row.flight_metrics=g.combat_presentation.retained_metrics()\n row.visual_port_feedback=scene.visual_port_feedback\n row.runtime_config_end=config(scene)')
(project/'port_perf.gd').write_text(driver)
for n in ['probe.gd','counter_probe.gd']:shutil.copy2(base.parent/'compact-laser-20261015'/n,project/n)
output=base/'linux';output.mkdir(exist_ok=True)
results=json.loads((output/'summary.json').read_text())['rows'] if (output/'summary.json').exists() else []
try:
 for case in a.cases:
  for label,library,sources in [('before',a.before_lib,before),('after',a.after_lib,after)]:
   for n,data in sources.items():(project/n).write_bytes(data)
   shutil.copy2(library,project/'bin/libspace_native.so')
   fixture=frozen/('mixed_fixture.gd' if case=='mixed' else 'combat_stress_fixture.gd')
   shutil.copy2(fixture,project/'combat_stress_fixture.gd')
   env=os.environ.copy();env.update(DISPLAY=a.display,PERF_NATIVE='1',AI_TECH_PERF_STATE='closed',WEAPON_CASE=case,MISSILE_CONTROL='legend',XDG_DATA_HOME='/tmp/dynamic-port-perf-user/data',XDG_CONFIG_HOME='/tmp/dynamic-port-perf-user/config',XDG_CACHE_HOME='/tmp/dynamic-port-perf-user/cache')
   name=case+'-'+label
   (project/'.runtime/uncapped-port.json').unlink(missing_ok=True)
   with (output/(name+'.log')).open('w') as log:
    proc=subprocess.run(['godot','--path',str(project),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--max-fps','0','--disable-vsync','--script','res://port_perf.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
   if proc.returncode:raise RuntimeError(name+' process failed')
   source=project/'.runtime/uncapped-port.json'
   data=json.loads(source.read_text())
   with gzip.open(output/(name+'.json.gz'),'wt') as dst:json.dump(data,dst,separators=(',',':'))
   log=(output/(name+'.log')).read_text()
   phases=data['phases']
   spans={'wall':data['frames_us_raw'],
          'before_main':[r['main_begin_us']-r['previous_post_us'] for r in phases],
          'main':[r['main_end_us']-r['main_begin_us'] for r in phases],
          'submit':[r['pre_draw_us']-r['main_end_us'] for r in phases],
          'render_wait':[r['post_draw_us']-r['pre_draw_us'] for r in phases]}
   row={k:data.get(k) for k in ['warm_steps','sample_steps','actual_1x_pass','performance_sample_valid','native_admitted','logic_hz','render_hz','game_wall_ratio','enemies_alive','video_adapter','flight_metrics','visual_port_feedback','events']}
   row.update(case=case,label=label,exit=proc.returncode,script_errors=log.count('SCRIPT ERROR'),fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),library_sha256=hashlib.sha256(library.read_bytes()).hexdigest())
   row['spans_ms']={k:{'mean':statistics.mean(v)/1000,'p95':sorted(v)[int((len(v)-1)*.95)]/1000} for k,v in spans.items()}
   row['formal_valid']=bool(data['performance_sample_valid'] and data['actual_1x_pass'] and data['warm_steps']==240 and data['sample_steps']==480 and data['native_admitted'] and data['enemies_alive']==15 and proc.returncode==0 and 'SCRIPT ERROR' not in log)
   results=[r for r in results if (r['case'],r['label'])!=(case,label)]
   results.append(row)
   (output/'summary.json').write_text(json.dumps({'baseline':'c4a5e259','environment':'Godot4.6.3 Linux x86_64 / Xorg dummy / llvmpipe; diagnostic only','rows':results},indent=2))
   print(name,'valid=',row['formal_valid'],'wall_ms=',round(row['spans_ms']['wall']['mean'],2),'logic_hz=',round(row['logic_hz'],2),'native=',row['native_admitted'],'visual_feedback=',row['visual_port_feedback'],flush=True)
finally:
 for n,data in after.items():(project/n).write_bytes(data)
 shutil.copy2(a.after_lib,project/'bin/libspace_native.so')
