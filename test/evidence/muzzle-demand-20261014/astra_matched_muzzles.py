from pathlib import Path
import subprocess,hashlib,json,os,time
root=Path('D:/CodexBuild/space_idle/stable-integration');area=root/'test/work/battle-fix-20261013';iso=area/'space-battleship';build=Path('D:/CodexBuild/space_idle/native-stable/src')
compiler=Path('D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64/bin/x86_64-w64-mingw32-clang++.exe');cpp=Path('D:/CodexBuild/space_idle/godot-cpp');godot=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
flags=['-c','-std=c++17','-fno-exceptions','-Wwrite-strings','-fvisibility=hidden','-O3','-fno-fast-math','-ffp-contract=off','-fPIC','-DWINDOWS_ENABLED','-DTHREADS_ENABLED','-DNDEBUG','-DGDEXTENSION']+[f'-I{cpp/x}' for x in ['include','gen/include','gdextension']]
linkflags=['-shared','-Wl,--no-undefined','-static','-static-libgcc','-static-libstdc++']
def blob(ref,path):return subprocess.check_output(['git','show',f'{ref}:{path}'],cwd=root)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
revs={'A':'9f9c762dd6985bbd3b6c6552e9adb1a06441d5ac','B':'44bd2d38'}
receipt={'compiler':str(compiler),'compiler_sha256':sha(compiler),'compile_flags':flags,'link_flags':linkflags,'godot_cpp_library_sha256':sha(cpp/'bin/libgodot-cpp.windows.template_release.x86_64.a'),'driver_sha256':sha(iso/'qa_astra_direct.gd'),'engine_sha256':sha(godot.with_name('Godot_v4.7.2-stable_win64.exe')),'builds':{},'runs':[]}
for label,ref in revs.items():
 for name in ['space_native.cpp','combat_presentation.h','combat_execution_kernel.h']:(build/name).write_bytes(blob(ref,'space-battleship/addons/native_battle/src/'+name))
 obj=build/'space_native.os';dll=area/f'space_native_matched_{label}.dll'
 subprocess.run([str(compiler),'-o',str(obj)]+flags+[str(build/'space_native.cpp')],check=True)
 subprocess.run([str(compiler)]+linkflags+['-o',str(dll),str(obj),str(cpp/'bin/libgodot-cpp.windows.template_release.x86_64.a')],check=True)
 receipt['builds'][label]={'ref':ref,'dll_sha256':sha(dll),'dll_bytes':dll.stat().st_size,'source_sha256':{n:sha(build/n) for n in ['space_native.cpp','combat_presentation.h','combat_execution_kernel.h']}}
 print('BUILT',label,receipt['builds'][label],flush=True)
for label in ['A1','B','A2']:
 ref=revs[label[0]]
 for name in ['battle_slice_runtime.gd','native_execution_session.gd','simulation_geometry_authority.gd','battlefield.gd','main.gd','battle_read_model.gd','equipment_tab.gd','equipment_card.gd']:(iso/'scripts'/name).write_bytes(blob(ref,'space-battleship/scripts/'+name))
 (iso/'project.godot').write_bytes(blob('44bd2d38','space-battleship/project.godot'))
 (iso/'bin/space_native.dll').write_bytes((area/f'space_native_matched_{label[0]}.dll').read_bytes())
 env=os.environ.copy();env.update(APPDATA=str(area/'roaming'),LOCALAPPDATA=str(area/'local'),PERF_NATIVE='1',PERF_SIDE='matched-'+label)
 cmd=[str(godot),'--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_astra_direct.gd','--log-file',str(area/f'astra-matched-{label}.log')]
 start=time.time();subprocess.run(cmd,env=env,check=True,timeout=180)
 output=iso/'.runtime'/f'astra-direct-matched-{label}.json'
 receipt['runs'].append({'label':label,'started_unix':start,'completed_unix':time.time(),'command':cmd,'sample_sha256':sha(output),'dll_sha256':sha(iso/'bin/space_native.dll'),'project_sha256':sha(iso/'project.godot')})
 (area/'astra-matched-build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print('FINISHED',label,flush=True)
# Leave the verified cannon/muzzle candidate as the isolated owner.
for name in ['battle_slice_runtime.gd','native_execution_session.gd','simulation_geometry_authority.gd']:(iso/'scripts'/name).write_bytes(blob('44bd2d38','space-battleship/scripts/'+name))
(iso/'bin/space_native.dll').write_bytes((area/'space_native_matched_B.dll').read_bytes())
