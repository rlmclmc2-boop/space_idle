"""Run the real release pipeline in a disposable workspace, never replace release/."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'space-battleship'
area = Path(tempfile.mkdtemp(prefix='ui-text-release-', dir=ROOT/'test/work'))
if os.name == 'nt':
    subprocess.run(['icacls',str(area),'/inheritance:e'],check=True,stdout=subprocess.DEVNULL)
project = area/'space-battleship'
project.mkdir()
for folder in ['scripts','assets','data']:
    shutil.copytree(SOURCE/folder, project/folder, ignore=shutil.ignore_patterns('__pycache__','.import_state.json'))
for name in ['project.godot','main.tscn','export_presets.cfg']:
    shutil.copy2(SOURCE/name, project/name)
(project/'tools').mkdir()
shutil.copy2(SOURCE/'tools/build_release.ps1',project/'tools/build_release.ps1')
(area/'test').mkdir()
shutil.copy2(ROOT/'test/verify_release.gd',area/'test/verify_release.gd')
for relative in ['Godot_v4.7.2-stable_win64.exe','templates/4.7.2.stable/windows_release_x86_64.exe']:
    destination = project/'engine'/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    os.link(SOURCE/'engine'/relative,destination)
print('Isolated release validation: '+str(area),flush=True)
# Python normalizes Windows environment-key case before the PS 5.1 child reads it.
raise SystemExit(subprocess.call(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(project/'tools/build_release.ps1')],cwd=area,env=dict(os.environ)))
