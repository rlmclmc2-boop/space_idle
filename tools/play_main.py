"""Verified player entry. Never selects a test copy or changes player saves."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BUNDLED_DLL = Path('tools/player_runtime/space_native.dll')
ENTRY_CMD = '\u73a9\u6e38\u620f.cmd'
NATIVE_INVENTORY = Path('space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json')
ENGINE_NAME = 'Godot_v4.7.2-stable_win64.exe'
ENGINE_URL = ('https://downloads.godotengine.org/?flavor=stable&platform=windows.64'
              '&slug=win64.exe.zip&version=4.7.2')
ENGINE_ARCHIVE_SHA256 = '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
ENGINE_EXE_SHA256 = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
APPROVED_ORIGIN_URLS = frozenset({
    'https://github.com/rlmclmc2-boop/space_idle.git',
    'https://github.com/rlmclmc2-boop/space_idle',
    'git@github.com:rlmclmc2-boop/space_idle.git',
    'ssh://git@github.com/rlmclmc2-boop/space_idle.git',
})
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
    if args[0] == 'git':
        args = ['git', '-c', 'core.longpaths=true', '-c', 'safe.directory=' + str(cwd), *args[1:]]
    return subprocess.run(args, cwd=cwd, env=env, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, encoding='utf-8', errors='replace').stdout.strip()

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda: f.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()


class LocalRuntimeChanges(RuntimeError):
    pass

def generated_evidence_translation(path, tracked_csv):
    if not path.endswith('.translation') or '/evidence/' not in path:
        return False
    for csv in tracked_csv:
        prefix = csv[:-4] + '.'
        if path.startswith(prefix):
            variant = path[len(prefix):-len('.translation')]
            if variant and '/' not in variant:
                return True
    return False

def checked_source(root):
    if root.resolve() != ROOT.resolve():
        raise RuntimeError('Player entry must run from its own checkout')
    project = root / 'space-battleship'
    head = run(['git', 'rev-parse', 'HEAD'], root)
    branch = run(['git', 'branch', '--show-current'], root)
    if branch != 'main':
        raise RuntimeError('Player entry requires main; current branch: ' + branch)
    origin = run(['git', 'remote', 'get-url', 'origin'], root)
    if origin not in APPROVED_ORIGIN_URLS:
        raise RuntimeError('The origin remote is not rlmclmc2-boop/space_idle on GitHub: ' + origin)
    try:
        accepted = run(['git', 'rev-parse', '--verify', 'refs/remotes/origin/main^{commit}'], root)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError('Missing origin/main; fetch it manually before starting the player') from exc
    if head != accepted:
        raise RuntimeError('Local main differs from fetched origin/main; update or review it manually. '
                           'HEAD=' + head + ' origin/main=' + accepted)
    # Local edits to accepted runtime and entry files are never silently launched.
    local_changes = '\n'.join(path for path in run(
        ['git', 'status', '--porcelain', '--untracked-files=no', '--',
         'space-battleship', ENTRY_CMD, 'tools/play_main.py', BUNDLED_DLL.as_posix()], root
    ).splitlines() if path[3:] not in NON_RUNTIME_CHANGES and not path[3:].endswith(('.uid', '.import')))
    # These are entry-managed files, not additional trusted source. The DLL
    # and descriptor are both checked separately before the engine starts.
    tracked_csv = {path for path in run(
        ['git', 'ls-files', '--', '*.csv'], root
    ).splitlines() if path.startswith('space-battleship/') and '/evidence/' in path}
    untracked_runtime = '\n'.join(path for path in run(
        ['git', 'ls-files', '--others', '--exclude-standard', '--', 'space-battleship'], root
    ).splitlines() if not path.endswith(('.uid', '.import'))
    and not generated_evidence_translation(path, tracked_csv)
    and path not in {'space-battleship/space_native.gdextension',
                     'space-battleship/bin/space_native.dll'})
    if untracked_runtime:
        local_changes += '\n' + untracked_runtime
    if local_changes:
        raise LocalRuntimeChanges('Unreviewed local runtime changes:\n' + local_changes)
    return project, head

def verified_bundle(root):
    inventory = json.loads((root / NATIVE_INVENTORY).read_text(encoding='utf-8'))
    native = inventory['dll']
    if (native['bundled_path'] != BUNDLED_DLL.as_posix()
            or native['runtime_path'] != 'space-battleship/bin/space_native.dll'
            or native['bundled_sha256'] != native['runtime_sha256']):
        raise RuntimeError('Native acceptance inventory has inconsistent runtime paths or hashes')
    tracked_sources = set(run(
        ['git', 'ls-files', '--', 'space-battleship/addons/native_battle/src'], root
    ).splitlines())
    inventoried_sources = {source['repository_path'] for source in inventory['sources']}
    if tracked_sources != inventoried_sources:
        raise RuntimeError('Native source inventory does not cover the accepted main source set')
    for source in inventory['sources']:
        actual_blob = run(['git', 'rev-parse', 'HEAD:' + source['repository_path']], root)
        if actual_blob != source['repository_git_blob']:
            raise RuntimeError('Native source changed without an accepted DLL rebuild: '
                               + source['repository_path'])
    bundle = root / BUNDLED_DLL
    expected_sha = native['bundled_sha256']
    if not bundle.is_file() or digest(bundle) != expected_sha:
        raise RuntimeError('Bundled native DLL is missing or has the wrong SHA256: ' + str(bundle))
    return bundle, expected_sha, inventory['acceptance']['engine']


def prepare_engine(root):
    external = os.environ.get('SPACE_BATTLESHIP_ENGINE_PATH')
    engine = (Path(external) if external else root / 'space-battleship' / 'engine' / ENGINE_NAME)
    if engine.exists():
        if not engine.is_file() or digest(engine) != ENGINE_EXE_SHA256:
            raise RuntimeError('Godot executable does not match the approved Windows 4.7.2 build: ' + str(engine))
        return engine
    if external:
        raise RuntimeError('Approved Godot executable is missing: ' + str(engine))
    engine.parent.mkdir(parents=True, exist_ok=True)
    archive = engine.parent / 'downloads' / (ENGINE_NAME + '.zip')
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        partial = archive.with_name(archive.name + '.' + str(os.getpid()) + '.partial')
        try:
            request = urllib.request.Request(ENGINE_URL, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(request, timeout=60) as response, partial.open('xb') as output:
                shutil.copyfileobj(response, output)
            if digest(partial) != ENGINE_ARCHIVE_SHA256:
                raise RuntimeError('Official Godot archive failed SHA256 verification: ' + str(partial))
            partial.replace(archive)
        finally:
            if partial.exists():
                partial.unlink()
    if digest(archive) != ENGINE_ARCHIVE_SHA256:
        raise RuntimeError('Cached Godot archive failed SHA256 verification: ' + str(archive))
    temporary = engine.with_name(engine.name + '.' + str(os.getpid()) + '.partial')
    try:
        with zipfile.ZipFile(archive) as bundle:
            if sorted(bundle.namelist()) != [ENGINE_NAME, ENGINE_NAME.replace('.exe', '_console.exe')]:
                raise RuntimeError('Official Godot archive has unexpected contents: ' + str(archive))
            with bundle.open(ENGINE_NAME) as source, temporary.open('xb') as output:
                shutil.copyfileobj(source, output)
        if digest(temporary) != ENGINE_EXE_SHA256:
            raise RuntimeError('Godot executable failed SHA256 verification: ' + str(temporary))
        temporary.replace(engine)
    finally:
        if temporary.exists():
            temporary.unlink()
    return engine


def prepare_clean_mirror(root, head):
    mirror = root / 'space-battleship' / '.runtime' / 'player-main' / 'checkout'
    marker = mirror / '.player-managed.json'
    if not mirror.exists():
        mirror.parent.mkdir(parents=True, exist_ok=True)
        temporary = mirror.with_name('checkout.' + str(os.getpid()) + '.partial')
        try:
            subprocess.run(['git', '-c', 'core.longpaths=true', '-c', 'safe.directory=' + str(root),
                            'clone', '--shared', '--branch', 'main', '--single-branch',
                            str(root), str(temporary)], cwd=root, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as exc:
            detail = exc.stderr.decode('utf-8', errors='replace').splitlines()[-5:]
            raise RuntimeError('Unable to create clean player mirror:\n' + '\n'.join(detail)) from exc
        origin = run(['git', 'remote', 'get-url', 'origin'], root)
        run(['git', 'remote', 'set-url', 'origin', origin], temporary)
        if run(['git', 'rev-parse', 'HEAD'], temporary) != head:
            raise RuntimeError('Player mirror did not checkout the accepted main commit')
        run(['git', 'update-ref', 'refs/remotes/origin/main', head], temporary)
        (temporary / '.player-managed.json').write_text(
            json.dumps({'source': str(root.resolve())}), encoding='utf-8')
        temporary.rename(mirror)
    if not marker.is_file() or json.loads(marker.read_text(encoding='utf-8')).get('source') != str(root.resolve()):
        raise RuntimeError('Existing player mirror is not owned by this checkout: ' + str(mirror))
    if run(['git', 'remote', 'get-url', 'origin'], mirror) != run(['git', 'remote', 'get-url', 'origin'], root):
        raise RuntimeError('Existing player mirror has a different GitHub origin: ' + str(mirror))
    if run(['git', 'rev-parse', 'HEAD'], mirror) != head:
        tracked = run(['git', 'status', '--porcelain', '--untracked-files=no'], mirror).splitlines()
        if any(not item[3:].endswith(('.uid', '.import')) for item in tracked):
            raise RuntimeError('Managed player mirror has non-generated local edits; update stopped: ' + str(mirror))
        run(['git', 'reset', '--hard', head], mirror)
        run(['git', 'update-ref', 'refs/remotes/origin/main', head], mirror)
    return mirror


def launch_clean_mirror(root, changes):
    if os.environ.get('SPACE_BATTLESHIP_MANAGED_MIRROR') == '1':
        raise changes
    head = run(['git', 'rev-parse', 'HEAD'], root)
    engine = prepare_engine(root)
    mirror = prepare_clean_mirror(root, head)
    print('Local runtime edits remain untouched; playing accepted main from:', mirror, flush=True)
    env = os.environ.copy()
    env['SPACE_BATTLESHIP_MANAGED_MIRROR'] = '1'
    env['SPACE_BATTLESHIP_PLAYER_SOURCE_ROOT'] = str(root)
    env['SPACE_BATTLESHIP_ENGINE_PATH'] = str(engine)
    return subprocess.call([sys.executable, str(mirror / 'tools' / 'play_main.py')], cwd=mirror, env=env)

def install_native(root):
    project, _ = checked_source(root)
    bundle, dll_sha, _ = verified_bundle(root)
    dll = project / 'bin' / 'space_native.dll'
    if dll.is_file():
        previous = digest(dll)
        if previous == dll_sha:
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
    if digest(temporary) != dll_sha:
        temporary.unlink()
        raise RuntimeError('Native DLL copy failed SHA256 verification')
    temporary.replace(dll)
    return dll

def validate(root, engine=None):
    project, head = checked_source(root)
    _, dll_sha, accepted_engine = verified_bundle(root)

    engine = engine or project / 'engine' / ENGINE_NAME
    if not engine.is_file():
        raise RuntimeError('缺少引擎：' + str(engine))
    if engine.with_suffix('.pck').exists():
        raise RuntimeError('引擎旁存在自动加载的 PCK，请先确认其用途：' + str(engine.with_suffix('.pck')))
    dll = project / 'bin' / 'space_native.dll'
    if not dll.is_file():
        raise RuntimeError('缺少原生库：' + str(dll) + '\n请先安装与正式源码匹配的原生库。')
    actual_dll_sha = digest(dll)
    if actual_dll_sha != dll_sha:
        raise RuntimeError('原生库与正式源码不匹配：' + str(dll) + '\n实际 SHA256：' + actual_dll_sha + '\n需要 SHA256：' + dll_sha)
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
    if version != accepted_engine:
        raise RuntimeError('引擎版本不匹配：' + version)
    if not descriptor.exists():
        descriptor.write_text(DESCRIPTOR, encoding='utf-8')
    return project, engine, head, version

def main():
    if sys.argv[1:] == ['--install-native']:
        dll = install_native(ROOT)
        print('Installed matching native DLL:', dll, 'SHA256:', digest(dll))
        return 0
    if len(sys.argv) != 1:
        raise RuntimeError('Unknown player-entry argument')
    try:
        checked_source(ROOT)
    except LocalRuntimeChanges as changes:
        return launch_clean_mirror(ROOT, changes)
    engine = prepare_engine(ROOT)
    install_native(ROOT)
    project, engine, head, version = validate(ROOT, engine)
    dll_sha = digest(project / 'bin' / 'space_native.dll')
    env = os.environ.copy()
    window_check = env.get('SPACE_BATTLESHIP_VERIFY_WINDOW') == '1'
    player_root = Path(env.get('SPACE_BATTLESHIP_PLAYER_SOURCE_ROOT', ROOT))
    runtime = (player_root / 'test' / 'work' / 'player-window-check'
               if window_check else player_root / 'space-battleship' / '.runtime')
    user_data = runtime / 'userdata' if window_check else player_root / 'space-battleship' / '.userdata'
    env['APPDATA'] = str(user_data / 'roaming')
    env['LOCALAPPDATA'] = str(user_data / 'local')
    for p in [Path(env['APPDATA']), Path(env['LOCALAPPDATA']), runtime]:
        p.mkdir(parents=True, exist_ok=True)
    print('项目：', project, '\nGit：', head, '\n引擎：', version,
          '\n原生库 SHA256：', dll_sha, '\n数据 SHA256：', digest(project/'data/game_data.json'),
          '\n存档：', env['APPDATA'], flush=True)
    receipt = {'project': str(project), 'head': head, 'accepted_runtime': head,
               'engine': str(engine), 'engine_version': version,
               'dll_sha256': dll_sha, 'game_data_sha256': digest(project/'data/game_data.json')}
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
