"""Build the same shipping native sources into an isolated, minimal Godot project.
No edits to the live game project, shipping DLL, or player data.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--bindings',type=Path,required=True)
    parser.add_argument('--compiler',type=Path,required=True)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--work',type=Path,required=True)
    parser.add_argument('--case')
    parser.add_argument('--manifest',type=Path,default=ROOT/'tests/excel/core_rules.json')
    parser.add_argument('--session',action='store_true')
    parser.add_argument('--duration',type=float,default=20)
    args=parser.parse_args()
    work=args.work.resolve();work.mkdir(parents=True,exist_ok=True)
    project=work/'project';project.mkdir(exist_ok=True)
    (project/'runtime').mkdir(exist_ok=True)
    (project/'scripts').mkdir(exist_ok=True)
    shutil.copy2(ROOT/'scripts/enemy_formation.gd',project/'scripts/enemy_formation.gd')
    lib=project/'space_native.dll'
    binding=args.bindings.resolve()
    pin=subprocess.check_output(['git','-c','safe.directory=*','-C',str(binding),'rev-parse','HEAD'],text=True).strip()
    if pin!='507ed9d840c01a3c5b2a39af8bb4000bfac30bf5': raise RuntimeError('Wrong godot-cpp pin')
    command=[str(args.compiler),'-std=c++17','-shared','-O1','-fexceptions','-fno-fast-math','-ffp-contract=off','-DGDEXTENSION','-DNDEBUG','-DWINDOWS_ENABLED']
    for p in ('include','gen/include','gdextension'):command+=['-I',str(binding/p)]
    command += [str(ROOT/'addons/native_battle/src/space_native.cpp'),str(binding/'bin/libgodot-cpp.windows.template_release.x86_64.a'),'-static-libstdc++','-static-libgcc','-o',str(lib)]
    subprocess.run(command,check=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Rewrite Foundation Tests"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (project/'space_native.gdextension').write_text('[configuration]\nentry_symbol="space_native_init"\ncompatibility_minimum="4.7"\n[libraries]\nwindows.debug.x86_64="res://space_native.dll"\nwindows.release.x86_64="res://space_native.dll"\n')
    shutil.copy2(ROOT/'tests/run_cases.gd',project/'run_cases.gd')
    for source in (ROOT/'runtime').glob('*.gd'):shutil.copy2(source,project/'runtime'/source.name)
    # Portable engine copy confines even engine user:// and editor metadata to
    # this run. No editor import is needed: runner explicitly loads the DLL.
    engine=work/'engine';engine.mkdir(exist_ok=True)
    original=args.godot.resolve()
    if original.name.endswith('_console.exe'):
        original=original.with_name(original.name.replace('_console.exe','.exe'))
    local_engine=engine/'godot.exe'
    shutil.copy2(original,local_engine)
    (engine/'_sc_').touch()
    godot=str(local_engine)
    entry='runtime/run_session.gd' if args.session else 'run_cases.gd'
    run=[godot,'--headless','--log-file',str(work/'godot.log'),'--path',str(project),'--script',entry,'--',
         '--fixture',str(args.manifest.resolve()),'--compiler',str(ROOT/'config_tools/compile.py'),
         '--python',sys.executable,'--output',str(work/'bundle')]
    if args.case: run+=['--case',args.case]
    if args.session:run+=['--duration',str(args.duration),'--skip-guides','true']
    result=work/'bundle/result.json'
    if result.exists():result.unlink()
    subprocess.run(run,check=True,timeout=60)
    log=(work/'godot.log').read_text(encoding='utf-8',errors='replace')
    if 'SCRIPT ERROR:' in log or 'Failed to load script' in log:
        raise RuntimeError('Godot script error; inspect '+str(work/'godot.log'))
    if any(line.startswith('ERROR:') and 'Failed to read the root certificate store.' not in line for line in log.splitlines()):
        raise RuntimeError('Unexpected Godot/native error; inspect '+str(work/'godot.log'))
    if not result.exists():
        raise RuntimeError('Runner produced no result; inspect '+str(work/'godot.log'))
    report=json.loads(result.read_text(encoding='utf-8'))
    print(json.dumps(report))
    if not report['ok']:raise RuntimeError('Headless assertions failed')


if __name__=='__main__':main()
