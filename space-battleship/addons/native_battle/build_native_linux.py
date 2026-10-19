"""Build a local Linux validation library against the selected Godot API.
The shipping Windows4.7.2 build remains build_native.ps1.
Requires a checkout of the repository-pinned godot-cpp commit and Python SCons.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, sys
p=argparse.ArgumentParser()
p.add_argument('--bindings',type=Path,required=True)
p.add_argument('--build-root',type=Path,required=True)
p.add_argument('--godot',default='godot')
p.add_argument('--jobs',type=int,default=4)
a=p.parse_args()
source=Path(__file__).resolve().parent
binding=a.bindings.resolve();build=a.build_root.resolve()
pin='507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'
assert subprocess.check_output(['git','-C',str(binding),'rev-parse','HEAD'],text=True).strip()==pin,'Wrong godot-cpp revision'
assert build!=source and not build.is_relative_to(source),'Use an isolated build directory'
build.mkdir(parents=True,exist_ok=True)
shutil.copytree(source/'src',build/'src',dirs_exist_ok=True)
shutil.copy2(source/'SConstruct',build/'SConstruct')
profile={'enabled_classes':['RefCounted','RenderingServer','Geometry2D','ArrayMesh','MultiMesh','ShaderMaterial','Font','RandomNumberGenerator','OS']}
(build/'profile.json').write_text(json.dumps(profile))
subprocess.run([a.godot,'--headless','--dump-extension-api'],cwd=build,check=True)
api=build/'extension_api.json'
subprocess.run([sys.executable,'-m','SCons','bindings='+str(binding),'platform=linux','arch=x86_64','custom_api_file='+str(api),'build_profile='+str(build/'profile.json'),'target=template_release','lto=none','-j'+str(a.jobs)],cwd=build,check=True)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
lib=build/'bin/libspace_native.so'
report={'platform':'linux.x86_64','shipping_windows_build':False,'godot':subprocess.check_output([a.godot,'--version'],text=True).strip(),'godot_cpp_commit':pin,'api_sha256':sha(api),'library_sha256':sha(lib),'source_sha256':{p.name:sha(p) for p in sorted((build/'src').iterdir()) if p.is_file()}}
(build/'build-manifest.json').write_text(json.dumps(report,indent=2))
print(lib)
