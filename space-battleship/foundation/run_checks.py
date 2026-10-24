"""Build shipping sources, compile the fixture, and load that DLL in Godot.

Portable engine, editor data and test saves stay inside the explicit work root.
No dependency on the removed game project or any personal save directory.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--bindings', type=Path, required=True)
    p.add_argument('--compiler', type=Path, required=True)
    p.add_argument('--godot', type=Path, required=True)
    p.add_argument('--work', type=Path, required=True)
    a = p.parse_args()
    binding, work = a.bindings.resolve(), a.work.resolve()
    if subprocess.check_output(['git', '-c', 'safe.directory=*', '-C', str(binding), 'rev-parse', 'HEAD'], text=True).strip() != '507ed9d840c01a3c5b2a39af8bb4000bfac30bf5':
        raise RuntimeError('Unsupported godot-cpp revision')
    project = work / 'project'; project.mkdir(parents=True, exist_ok=True)
    engine = work / 'engine'; engine.mkdir(exist_ok=True)
    command = [str(a.compiler), '-std=c++17', '-shared', '-O1', '-fexceptions', '-fno-fast-math', '-ffp-contract=off', '-DGDEXTENSION', '-DNDEBUG', '-DWINDOWS_ENABLED']
    for name in ('include', 'gen/include', 'gdextension'): command += ['-I', str(binding / name)]
    command += [str(ROOT / 'addons/native_battle/src/space_native.cpp'), str(binding / 'bin/libgodot-cpp.windows.template_release.x86_64.a'), '-static-libstdc++', '-static-libgcc', '-o', str(project / 'space_native.dll')]
    subprocess.run(command, check=True)
    shutil.copytree(ROOT / 'foundation/host', project / 'host', dirs_exist_ok=True)
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Foundation Check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (project / 'space_native.gdextension').write_text('[configuration]\nentry_symbol="space_native_init"\ncompatibility_minimum="4.7"\n[libraries]\nwindows.debug.x86_64="res://space_native.dll"\nwindows.release.x86_64="res://space_native.dll"\n')
    source_engine = a.godot.resolve()
    if source_engine.name.endswith('_console.exe'): source_engine = source_engine.with_name(source_engine.name.replace('_console.exe', '.exe'))
    portable = engine / 'godot.exe'; shutil.copy2(source_engine, portable)
    (engine / '_sc_').touch()
    bundle = work / 'fixture'
    subprocess.run([sys.executable, str(ROOT / 'foundation/compile_config.py'), '--manifest', str(ROOT / 'foundation/tests/fixture.json'), '--output', str(bundle)], check=True)
    # A new save directory per invocation prevents a passing previous run from
    # satisfying this run's assertions or being overwritten as player data.
    import tempfile
    saves = Path(tempfile.mkdtemp(prefix='saves-', dir=work))
    result = work / 'result.json'
    if result.exists(): result.unlink()
    log = work / 'godot.log'
    subprocess.run([str(portable), '--headless', '--path', str(project), '--log-file', str(log), '--script', 'host/check_foundation.gd', '--', '--bundle', str(bundle), '--saves', str(saves), '--result', str(result)], check=True, timeout=60)
    report = json.loads(result.read_text(encoding='utf-8'))
    output = log.read_text(encoding='utf-8', errors='replace')
    errors = [line for line in output.splitlines() if line.startswith(('SCRIPT ERROR:', 'ERROR:')) and 'Failed to read the root certificate store.' not in line]
    if errors or not report['ok']: raise RuntimeError(str(errors or report))
    print(json.dumps(report))


if __name__ == '__main__': main()
