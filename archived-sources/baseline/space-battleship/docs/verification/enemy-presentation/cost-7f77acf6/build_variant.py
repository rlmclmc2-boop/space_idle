from pathlib import Path
import subprocess,os,sys,hashlib,json

repo=Path(r'C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate')
build=Path(r'C:/Users/Administrator/AppData/Local/Temp/space-idle-enemy-presentation-contract/native-stable')
out=build.parent/'cost-evidence'
out.mkdir(exist_ok=True)
variant=sys.argv[1]
if variant=='baseline':
    payload=subprocess.check_output(['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo),'show','b29e442ef8ce5bf3d93e3c4346dd898f2d694308:space-battleship/addons/native_battle/src/combat_execution_kernel.h'])
else:
    payload=(repo/'space-battleship/addons/native_battle/src/combat_execution_kernel.h').read_bytes()
target=build/'src/combat_execution_kernel.h'
target.write_bytes(payload)
compiler=r'D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64'
env=os.environ.copy();env['PATH']=compiler+'/bin;'+env['PATH']
args=[r'D:/CodexTools/venv/godot-native/Scripts/python.exe','-m','SCons',
      'bindings=D:/CodexBuild/space_idle/godot-cpp','platform=windows','arch=x86_64','use_mingw=yes','use_llvm=yes',
      'mingw_prefix='+compiler,'use_static_cpp=yes','custom_api_file=D:/CodexBuild/space_idle/api/extension_api.json',
      'target=template_release','lto=none','-j','4']
with (out/(variant+'-build.log')).open('wb') as log:
    result=subprocess.run(args,cwd=build,env=env,stdout=log,stderr=subprocess.STDOUT)
assert result.returncode==0,(out/(variant+'-build.log')).read_text(errors='replace')[-5000:]
dll=out/(variant+'.dll'); dll.write_bytes((build/'bin/space_native.dll').read_bytes())
manifest=out/(variant+'.gdextension')
template=(repo/'space-battleship/addons/native_battle/space_native.gdextension.in').read_text(encoding='utf-8')
manifest.write_text(template.replace('res://bin/space_native.dll',dll.as_posix()),encoding='utf-8')
metadata={'variant':variant,'kernel_sha256':hashlib.sha256(payload).hexdigest(),'dll_sha256':hashlib.sha256(dll.read_bytes()).hexdigest(),'args':args}
(out/(variant+'-build.json')).write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print(json.dumps(metadata))
