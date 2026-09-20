"""Run the real BAT from an unrelated cwd and a temporary non-source drive alias.

All files stay under test/work; the unused drive alias is always removed.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'space-battleship'


def main():
    area = Path(tempfile.mkdtemp(prefix='release-portability-', dir=ROOT / 'test/work'))
    subprocess.run(['icacls', str(area), '/inheritance:e'], check=True, stdout=subprocess.DEVNULL)
    workspace = area / 'Moved workspace 中文'
    project = workspace / 'Renamed game 中文'
    project.mkdir(parents=True)
    for folder in ('scripts', 'assets', 'data'):
        shutil.copytree(SOURCE / folder, project / folder,
                        ignore=shutil.ignore_patterns('__pycache__', '.import_state.json'))
    for name in ('project.godot', 'main.tscn', 'export_presets.cfg'):
        shutil.copy2(SOURCE / name, project / name)
    (project / 'tools').mkdir()
    shutil.copy2(SOURCE / 'tools/build_release.ps1', project / 'tools/build_release.ps1')
    (workspace / 'test').mkdir()
    shutil.copy2(ROOT / 'test/verify_release.gd', workspace / 'test/verify_release.gd')
    shutil.copy2(ROOT / 'build_release.bat', workspace / 'build_release.bat')
    for relative in ('Godot_v4.7.2-stable_win64.exe', 'templates/4.7.2.stable/windows_release_x86_64.exe'):
        destination = project / 'engine' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.link(SOURCE / 'engine' / relative, destination)
    preset_path = project / 'export_presets.cfg'
    stale_path = 'Z:/old-machine/deleted-project/windows_release_x86_64.exe'
    original_preset = preset_path.read_text(encoding='utf-8').replace(
        'engine/templates/4.7.2.stable/windows_release_x86_64.exe', stale_path)
    assert stale_path in original_preset
    preset_path.write_text(original_preset, encoding='utf-8')
    # Windows GetLogicalDrives includes network/subst drives; never replace an existing one.
    import ctypes
    occupied = ctypes.windll.kernel32.GetLogicalDrives()
    letter = next(c for c in 'RSTUVWXYZ' if not occupied & (1 << (ord(c) - ord('A'))))
    drive = letter + ':'
    subprocess.run(['subst', drive, str(area)], check=True)
    try:
        mapped_workspace = Path(drive + '\\') / workspace.name
        env = dict(os.environ)
        env['PORTABLE_BUILD_BAT'] = str(mapped_workspace / 'build_release.bat')
        print(f'Build via {mapped_workspace}; evidence: {area}', flush=True)
        with (area / 'launcher.log').open('w', encoding='utf-8') as log:
            result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                                     '-Command', '& $env:PORTABLE_BUILD_BAT --no-pause; exit $LASTEXITCODE'],
                                    cwd=os.environ['SystemRoot'], env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=600)
        assert result.returncode == 0, f'Build failed ({result.returncode}); see {area / "launcher.log"}'
        files = list((workspace / 'release').iterdir())
        assert len(files) == 1 and files[0].name == 'SpaceBattleship.exe'
        log_text = (workspace / 'build.log').read_text(encoding='utf-8')
        assert f'Detected project: {mapped_workspace / project.name}' in log_text
        assert f'SUCCESS: {mapped_workspace / "release/SpaceBattleship.exe"}' in log_text
        assert str(SOURCE) not in log_text, 'Build referenced original checkout'
        assert stale_path not in log_text, 'Build used stale template path'
        assert preset_path.read_text(encoding='utf-8') == original_preset, 'Source preset was changed'
        (area / 'results.txt').write_text(
            'PASS: non-source drive alias, renamed project, Chinese/spaces, unrelated cwd, '
            'stale absolute template rebound without changing source preset, full release '
            'build/runtime verification, exactly one EXE.\n', encoding='utf-8')
        print((area / 'results.txt').read_text(encoding='utf-8'), flush=True)
    finally:
        subprocess.run(['subst', drive, '/d'], check=True)


if __name__ == '__main__':
    main()
