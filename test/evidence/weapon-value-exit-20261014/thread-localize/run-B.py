from pathlib import Path
import json,shutil,gzip,subprocess,hashlib
ROOT=Path.cwd()
source=(ROOT/'test/evidence/weapon-value-exit-20261014/final/run.py').read_text(encoding='utf8').split('cases={}')[0]
source=source.replace('    assert code == 0 and "SCRIPT ERROR" not in output', '    (EVIDENCE / ("exit-"+label+".json")).write_text(json.dumps({"process_exit_code":code}), encoding="utf-8")\n    assert "SCRIPT ERROR" not in output')
exec(source,globals())
EVIDENCE=ROOT/'test/evidence/weapon-value-exit-20261014/thread-localize'
DIAG_DLL=WORK/'thread-probe-native/bin/space_native.dll'
EXPECTED_DLL=sha(DIAG_DLL)
base_prepare=prepare
G='preload("res://strip_gate.gd")'
def start(i,indent):return indent+'if '+G+'.sampled:'+G+'.probe.begin_span('+str(i)+')\n'
def end(i,indent):return indent+'if '+G+'.sampled:'+G+'.probe.end_span('+str(i)+')\n'
def prepare(profile):
 base_prepare(False)
 shutil.copy2(DIAG_DLL,ISO/'bin/space_native.dll')
 gate=ISO/'strip_gate.gd';s=gate.read_text(encoding='utf8');s+='\nstatic var probe:RefCounted=ClassDB.instantiate("SpaceThreadProbe")\nstatic var thread_signal:PackedInt64Array\nstatic var thread_predraw:PackedInt64Array\n';gate.write_text(s,encoding='utf8')
 # The diagnostic retains original nonprofile script paths; only five frame counters and tiny regions added.
 p=ISO/'scripts/game.gd';s=p.read_text(encoding='utf8')
 line='\tif kind in ["unlocks_changed","planet_changed","planet_reforged","progress_loaded","enhancement_changed","configuration_changed"]:combat_configuration_epoch+=1\n'
 if CASE_REF==CANDIDATE:
  assert line in s;s=s.replace(line,start(0,'\t')+line+end(0,'\t'),1)
 else:
  needle='func _compiled_configuration_event(kind:String,_info:Dictionary)->void:\n';assert needle in s;s=s.replace(needle,needle+start(0,'\t')+end(0,'\t'),1)
 p.write_text(s,encoding='utf8')
 p=ISO/'scripts/simulation_geometry_authority.gd';s=p.read_text(encoding='utf8')
 if CASE_REF==CANDIDATE:
  needle='\tif kind=="upgrade":\n';assert needle in s
  s=s.replace(needle,start(1,'\t')+'\tvar diag_upgrade:bool=kind=="upgrade"\n'+end(1,'\t')+'\tif diag_upgrade:\n',1)
  needle='\tturret_visuals[index].entry=entry\n';assert needle in s;s=s.replace(needle,start(2,'\t')+needle+end(2,'\t'),1)
 else:
  needle='func on_simulation_event(kind:String,info:Dictionary)->void:\n';assert needle in s;s=s.replace(needle,needle+start(1,'\t')+end(1,'\t'),1)
  needle='\treturn turret_visuals[index]\n';assert needle in s;s=s.replace(needle,start(2,'\t')+end(2,'\t')+needle,1)
 p.write_text(s,encoding='utf8')
 p=ISO/'scripts/enhancement_branches.gd';s=p.read_text(encoding='utf8')
 if CASE_REF==CANDIDATE:
  needle=' var data:=bind_weapon_entry(g,owner)\n if data.is_empty():return result\n'
  repl=start(3,' ')+' var data:=bind_weapon_entry(g,owner)\n if data.is_empty():\n'+end(3,'  ')+'  return result\n'+end(3,' ')
 else:
  needle=' var index: int=g.combat_weapon_entries().find_custom(func(candidate):return is_same(candidate,owner))\n if index<0:return result\n var data:=weapon(g,index)\n'
  repl=start(3,' ')+' var index: int=g.combat_weapon_entries().find_custom(func(candidate):return is_same(candidate,owner))\n if index<0:\n'+end(3,'  ')+'  return result\n var data:=weapon(g,index)\n'+end(3,' ')
 assert needle in s;s=s.replace(needle,repl,1);p.write_text(s,encoding='utf8')
 # Frozen parent driver: add main-loop/main/pre-draw native stamps, leaving its work intact.
 p=ISO/'qa_galaxy_residence.gd';s=(ROOT/'test/evidence/galaxy-boundary-20261014/qa_galaxy_residence.gd').read_text(encoding='utf8')
 s=s.replace(' var process_begin_us:=0',' var thread_main_start:PackedInt64Array\n var thread_main_end:PackedInt64Array\n var process_begin_us:=0',1)
 s=s.replace('  process_begin_us=Time.get_ticks_usec()','  thread_main_start='+G+'.probe.sample()\n  process_begin_us=Time.get_ticks_usec()',1)
 s=s.replace('  process_end_us=Time.get_ticks_usec()','  process_end_us=Time.get_ticks_usec()\n  thread_main_end='+G+'.probe.sample()',1)
 needle=' call_deferred("run")';assert needle in s
 s=s.replace(needle,' process_frame.connect(func():'+G+'.thread_signal='+G+'.probe.sample())\n RenderingServer.frame_pre_draw.connect(func():'+G+'.thread_predraw='+G+'.probe.sample())\n'+needle,1);p.write_text(s,encoding='utf8')
 p=ISO/'qa_current_frame.gd';s=p.read_text(encoding='utf8')
 needle=' g.event.connect(record_event);system_events.clear()';assert needle in s
 s=s.replace(needle,' var probe_info:Dictionary=Gate.probe.info()\n var calibration_start:PackedInt64Array=Gate.probe.sample()\n for unused in 2000:\n  Gate.probe.begin_span(4)\n  Gate.probe.end_span(4)\n var calibration_end:PackedInt64Array=Gate.probe.sample()\n var calibration:Array=Gate.probe.take()\n'+needle,1)
 s=s.replace(' var begin:=Time.get_ticks_usec();var previous:=begin',' Gate.probe.take()\n var thread_previous:PackedInt64Array=Gate.probe.sample()\n var begin:=Time.get_ticks_usec();var previous:=begin',1)
 s=s.replace('  var now:=Time.get_ticks_usec();var sample_start:=now;frames.append(now-previous)','  var thread_now:PackedInt64Array=Gate.probe.sample()\n  var now:=Time.get_ticks_usec();var sample_start:=now;frames.append(now-previous)',1)
 s=s.replace('"render":render_times(scene)})','"render":render_times(scene),"thread":{"previous":thread_previous,"signal":Gate.thread_signal,"main_start":scene.thread_main_start,"main_end":scene.thread_main_end,"pre_draw":Gate.thread_predraw,"post_draw":thread_now},"micro":Gate.probe.take()})',1)
 s=s.replace('  previous=now','  thread_previous=thread_now\n  previous=now',1)
 s=s.replace(' var row={',' var row={"probe_info":probe_info,"calibration_start":calibration_start,"calibration_end":calibration_end,"calibration":calibration,',1)
 p.write_text(s,encoding='utf8')
 names=list(CHANGED)+['space-battleship/qa_galaxy_residence.gd','space-battleship/qa_current_frame.gd','space-battleship/strip_gate.gd']
 hashes={n:sha(ISO/n.removeprefix('space-battleship/')) for n in names if (ISO/n.removeprefix('space-battleship/')).exists()}
 # Parse-only preflight is not a workload sample; retain output even on failure.
 env=os.environ.copy();env.update(APPDATA=str(WORK/'roaming'),LOCALAPPDATA=str(WORK/'local'))
 check=subprocess.run([str(GODOT),'--headless','--path',str(ISO),'--script','res://qa_current_frame.gd','--check-only'],env=env,capture_output=True,text=True,timeout=60)
 (EVIDENCE/('parse-'+('B' if CASE_REF==CANDIDATE else 'A')+'.txt')).write_text(check.stdout+check.stderr,encoding='utf8')
 assert check.returncode==0 and 'SCRIPT ERROR' not in check.stderr,check.stderr
 return hashes
if __name__=='__main__':
 for label,ref in [('diag-B',CANDIDATE)]:
  CASE_REF=ref
  raw,marks=run_case(label,True)
  with gzip.open(EVIDENCE/(label+'.json.gz'),'wt',encoding='utf8') as f:json.dump(raw,f)
  (EVIDENCE/('cpu-'+label+'.json')).write_text(json.dumps(marks,indent=2),encoding='utf8')
  shutil.copy2(RUNTIME/('current-ledger-'+label+'.txt'),EVIDENCE/(label+'.txt'))
