"""Verified player entry. Never selects a test copy or changes player saves."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
# Reviewed source-tree anchor. The parent merge must retain its ancestry.
BASE = '24f0751d5acd698eeb06d8ec7f0eb02e34a09e94'
DLL_SHA = '137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78'
BUNDLED_DLL = Path('tools/player_runtime/space_native.dll')
NON_RUNTIME_CHANGES = frozenset({
    'space-battleship/AGENTS.md',
    'space-battleship/docs/READ_DEMOS.md',
    'space-battleship/docs/READ_PROTOCOL.md',
    'space-battleship/docs/READ_ROUTE.md',
    'space-battleship/docs/knowledge/INDEX.md',
    'space-battleship/docs/knowledge/TASKS.md',
    'space-battleship/docs/knowledge/archive/20261016-token-reading.md',
    'space-battleship/docs/knowledge/tasks/.gitkeep',
    'space-battleship/docs/roles/DOT.md',
    'space-battleship/docs/roles/EXECUTOR.md',
    'space-battleship/tools/read_budget.py',
    'space-battleship/tools/test_read_budget.py',
})
DESCRIPTOR = '''[configuration]
entry_symbol = "space_native_init"
compatibility_minimum = "4.7"

[libraries]
windows.debug.x86_64 = "res://bin/space_native.dll"
windows.release.x86_64 = "res://bin/space_native.dll"
'''

def run(args, cwd, env=None):
    return subprocess.run(args, cwd=cwd, env=env, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, encoding='utf-8', errors='replace').stdout.strip()

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda: f.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()

def checked_source(root):
    if root.resolve() != ROOT.resolve():
        raise RuntimeError('Player entry must run from its own checkout')
    project = root / 'space-battleship'
    head = run(['git', 'rev-parse', 'HEAD'], root)
    branch = run(['git', 'branch', '--show-current'], root)
    if branch != 'main':
        raise RuntimeError('当前分支不是 main：' + branch)
    run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], root)
    # Compare both committed and working-tree runtime against accepted source.
    changed = '\n'.join(path for path in run(
        ['git', 'diff', '--no-renames', '--name-only', BASE, '--', 'space-battleship'], root
    ).splitlines() if path not in NON_RUNTIME_CHANGES)
    if changed:
        raise RuntimeError('运行内容偏离已验收版本，停止启动：\n' + changed)
    # A reviewed commit does not authorize later uncommitted runtime edits.
    local_changes = '\n'.join(path for path in run(
        ['git', 'status', '--porcelain', '--untracked-files=no', '--', 'space-battleship'], root
    ).splitlines() if path[3:] not in NON_RUNTIME_CHANGES and not path[3:].endswith(('.uid', '.import')))
    # These are entry-managed files, not additional trusted source. The DLL
    # and descriptor are both checked separately before the engine starts.
    untracked_runtime = '\n'.join(path for path in run(
        ['git', 'ls-files', '--others', '--exclude-standard', '--', 'space-battleship'], root
    ).splitlines() if not path.endswith(('.uid', '.import'))
    and not (path.startswith('space-battleship/docs/tasks/playtest-ui-art/evidence/')
             and path.endswith('.translation'))
    and path not in {'space-battleship/space_native.gdextension',
                     'space-battleship/bin/space_native.dll'})
    if untracked_runtime:
        local_changes += '\n' + untracked_runtime
    if local_changes:
        raise RuntimeError('Unreviewed local runtime changes:\n' + local_changes)

    return project, head

def verified_bundle(root):
    bundle = root / BUNDLED_DLL
    if not bundle.is_file() or digest(bundle) != DLL_SHA:
        raise RuntimeError('Bundled native DLL is missing or has the wrong SHA256: ' + str(bundle))
    return bundle

def install_native(root):
    project, _ = checked_source(root)
    bundle = verified_bundle(root)
    dll = project / 'bin' / 'space_native.dll'
    if dll.is_file():
        previous = digest(dll)
        if previous == DLL_SHA:
            return dll
        backup = project / '.runtime' / 'native-backup' / ('space_native-' + previous + '.dll')
        backup.parent.mkdir(parents=True, exist_ok=True)
        if backup.exists() and digest(backup) != previous:
            raise RuntimeError('Native DLL backup path is occupied: ' + str(backup))
        if not backup.exists():
            shutil.copy2(dll, backup)
    dll.parent.mkdir(parents=True, exist_ok=True)
    temporary = dll.with_name('space_native.dll.tmp')
    shutil.copyfile(bundle, temporary)
    if digest(temporary) != DLL_SHA:
        temporary.unlink()
        raise RuntimeError('Native DLL copy failed SHA256 verification')
    temporary.replace(dll)
    return dll

def validate(root):
    project, head = checked_source(root)
    verified_bundle(root)

    engine = project / 'engine' / 'Godot_v4.7.2-stable_win64.exe'
    if not engine.is_file():
        raise RuntimeError('缺少引擎：' + str(engine))
    if engine.with_suffix('.pck').exists():
        raise RuntimeError('引擎旁存在自动加载的 PCK，请先确认其用途：' + str(engine.with_suffix('.pck')))
    dll = project / 'bin' / 'space_native.dll'
    if not dll.is_file():
        raise RuntimeError('缺少原生库：' + str(dll) + '\n请先安装与正式源码匹配的原生库。')
    actual_dll_sha = digest(dll)
    if actual_dll_sha != DLL_SHA:
        raise RuntimeError('原生库与正式源码不匹配：' + str(dll) + '\n实际 SHA256：' + actual_dll_sha + '\n需要 SHA256：' + DLL_SHA)
    descriptor = project / 'space_native.gdextension'
    for other in project.rglob('*.gdextension'):
        if '.godot' in other.parts or other == descriptor:
            continue
        if 'space_native_init' in other.read_text(encoding='utf-8-sig', errors='replace'):
            raise RuntimeError('发现重复原生库入口，请确认后移除：' + str(other))
    if descriptor.exists() and not descriptor.is_file():
        raise RuntimeError('原生库入口不是文件：' + str(descriptor))
    if descriptor.is_file() and descriptor.read_text(encoding='utf-8-sig').replace('\r\n','\n').strip() != DESCRIPTOR.strip():
        raise RuntimeError('原生库入口不匹配：' + str(descriptor))
    version = run([str(engine), '--version'], project)
    if not version.startswith('4.7.2.stable.'):
        raise RuntimeError('引擎版本不匹配：' + version)
    if not descriptor.exists():
        descriptor.write_text(DESCRIPTOR, encoding='utf-8')
    return project, engine, head, version

def main():
    if sys.argv[1:] == ['--install-native']:
        dll = install_native(ROOT)
        print('Installed matching native DLL:', dll, 'SHA256:', DLL_SHA)
        return 0
    if len(sys.argv) != 1:
        raise RuntimeError('Unknown player-entry argument')
    project, engine, head, version = validate(ROOT)
    env = os.environ.copy()
    window_check = env.get('SPACE_BATTLESHIP_VERIFY_WINDOW') == '1'
    runtime = (ROOT / 'test' / 'work' / 'player-window-check'
               if window_check else project / '.runtime')
    user_data = runtime / 'userdata' if window_check else project / '.userdata'
    env['APPDATA'] = str(user_data / 'roaming')
    env['LOCALAPPDATA'] = str(user_data / 'local')
    for p in [Path(env['APPDATA']), Path(env['LOCALAPPDATA']), runtime]:
        p.mkdir(parents=True, exist_ok=True)
    print('项目：', project, '\nGit：', head, '\n引擎：', version,
          '\n原生库 SHA256：', DLL_SHA, '\n数据 SHA256：', digest(project/'data/game_data.json'),
          '\n存档：', env['APPDATA'], flush=True)
    receipt = {'project': str(project), 'head': head, 'accepted_runtime': BASE,
               'engine': str(engine), 'engine_version': version,
               'dll_sha256': DLL_SHA, 'game_data_sha256': digest(project/'data/game_data.json')}
    (runtime/'player-launch.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding='utf-8')
    # Import in-place, reusing Godot's cache. No project or asset copies.
    print('检查资源导入……', flush=True)
    with (runtime/'player-import.log').open('w', encoding='utf-8') as log:
        subprocess.run([str(engine), '--headless', '--editor', '--import', '--quit', '--path', str(project)],
                       cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    print('启动正式游戏。', flush=True)
    game_args = [str(engine), '--path', str(project), 'res://main.tscn',
                 '--log-file', str(runtime/'player-game.log')]
    if window_check and env.get('SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES'):
        try:
            frames = int(env['SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES'])
        except ValueError as exc:
            raise RuntimeError('Verification frame count must be an integer') from exc
        if not 1 <= frames <= 3600:
            raise RuntimeError('Verification frame count must be between 1 and 3600')
        game_args += ['--quit-after', str(frames)]
    return subprocess.call(game_args, cwd=project, env=env)

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print('启动已停止：', exc, file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr, file=sys.stderr)
        sys.exit(1)
