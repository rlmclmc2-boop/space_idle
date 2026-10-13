from pathlib import Path
import subprocess,json,os,time,hashlib
root=Path('D:/CodexBuild/space_idle/stable-integration');area=root/'test/work/battle-fix-20261013';iso=area/'space-battleship'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def blob(ref,n):return subprocess.check_output(['git','show',ref+':'+n],cwd=root)
refs={'A':'52d8e727','B':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()}
receipt={'scope':'One identical-DLL A/B/A for fixed enemy model size and formation boundaries; prior accepted optimizations retained','driver_sha256':sha(iso/'qa_astra_fixed_layout.gd'),'refs':refs,'runs':[],'build_flags_reference':'../muzzle-demand-20261014/astra-matched-build-receipt.json','candidate_sources':{n:sha(root/'space-battleship/addons/native_battle/src'/n) for n in ['space_native.cpp','combat_presentation.h','combat_execution_kernel.h']}}
for label in ['A1','B','A2']:
 for n in ['battle_slice_runtime.gd','native_execution_session.gd','simulation_geometry_authority.gd','battlefield.gd','main.gd','battle_read_model.gd','equipment_tab.gd','equipment_card.gd']:(iso/'scripts'/n).write_bytes(blob(refs[label[0]],'space-battleship/scripts/'+n))
 dll=area/'space_native_text_candidate.dll';(iso/'bin/space_native.dll').write_bytes(dll.read_bytes())
 env=os.environ.copy();env.update(APPDATA=str(area/'roaming'),LOCALAPPDATA=str(area/'local'),PERF_NATIVE='1',PERF_SIDE='fixed-layout-'+label)
 cmd=['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_astra_fixed_layout.gd','--log-file',str(area/f'astra-fixed-layout-{label}.log')]
 start=time.time();subprocess.run(cmd,env=env,check=True,timeout=180)
 output=iso/'.runtime'/f'astra-direct-fixed-layout-{label}.json'
 receipt['runs'].append({'label':label,'started_unix':start,'completed_unix':time.time(),'dll_sha256':sha(dll),'sample_sha256':sha(output),'project_sha256':sha(iso/'project.godot')})
 (area/'astra-fixed-layout-build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 if label=='B':(area/'fixed-layout-hit-check.json').write_bytes((iso/'.runtime/clean-sample-acceptance.json').read_bytes())
 print('FINISHED',label,flush=True)
for n in ['main.gd','battle_slice_runtime.gd','native_execution_session.gd','simulation_geometry_authority.gd','battle_read_model.gd','equipment_tab.gd','equipment_card.gd']:(iso/'scripts'/n).write_bytes(blob(refs['B'],'space-battleship/scripts/'+n))
(iso/'bin/space_native.dll').write_bytes((area/'space_native_text_candidate.dll').read_bytes())
