@echo off
setlocal
set "CLEANUP_SELF=%~f0"
where py >nul 2>nul
if not errorlevel 1 goto usepy
if exist "D:\CodexTools\venv\Scripts\python.exe" goto usevenv
where python >nul 2>nul
if not errorlevel 1 goto usepython
echo Python 3 is required. Nothing was deleted.
pause
exit /b 1
:usepy
py -3 -c "import os; p=os.environ['CLEANUP_SELF']; exec(compile(open(p,encoding='utf-8').read().rsplit(chr(35)+'==PYTHON==',1)[1],p,'exec'))"
goto finish
:usevenv
"D:\CodexTools\venv\Scripts\python.exe" -c "import os; p=os.environ['CLEANUP_SELF']; exec(compile(open(p,encoding='utf-8').read().rsplit(chr(35)+'==PYTHON==',1)[1],p,'exec'))"
goto finish
:usepython
python -c "import os; p=os.environ['CLEANUP_SELF']; exec(compile(open(p,encoding='utf-8').read().rsplit(chr(35)+'==PYTHON==',1)[1],p,'exec'))"
:finish
echo.
echo Cleanup finished or stopped. Read the messages above.
pause
exit /b
#==PYTHON==
import os, sys, re, json, time, stat, shutil, subprocess, traceback
from pathlib import Path

MAIN = Path('D:/\u653e\u7f6e')
ROOTS = (MAIN / 'test/work', Path('D:/CodexBuild/space_idle'))
PATTERN = re.compile(r'^(?:release-\d{8}-\d{6}-[0-9a-f]{8}|release-failure-tests-[0-9a-f]{8}|release-portability-[a-z0-9_]+|ui-text-release-[a-z0-9_]+)$')
PRIVATE = {'.git', '.userdata', 'saves', 'savegames', '.aws', '.ssh', '.env'}
CACHES = {'.godot', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache'}
CUTOFF = 24 * 3600
LOG = None
last_progress = 0

def note(text):
    print(text, flush=True)
    if LOG:
        LOG.write(text + '\n'); LOG.flush()

def key(path): return os.path.normcase(os.path.abspath(str(path)))
def inside(path, parent):
    return key(path) == key(parent) or key(path).startswith(key(parent) + os.sep)
def link(path):
    s = os.lstat(path)
    return stat.S_ISLNK(s.st_mode) or bool(getattr(s, 'st_file_attributes', 0) & 0x400)
def safe_ancestors(path):
    for part in (path, *path.parents):
        if part.exists() and link(part): raise RuntimeError('Link/junction: ' + str(part))

def git(*args):
    r = subprocess.run(['git', '-c', 'safe.directory='+str(MAIN), '-c', 'core.quotepath=false', '-C', str(MAIN), *args], capture_output=True)
    if r.returncode: raise RuntimeError('Git safety check failed: '+r.stderr.decode('utf-8', 'replace'))
    return r.stdout.decode('utf-8', 'strict')

def busy():
    ps = "Get-CimInstance Win32_Process | Select-Object ProcessId,Name,ExecutablePath,CommandLine | ConvertTo-Json -Compress"
    r = subprocess.run(['powershell.exe','-NoProfile','-Command',ps], capture_output=True, timeout=30)
    if r.returncode: raise RuntimeError('Cannot verify running processes; cleanup stopped.')
    data = json.loads(r.stdout.decode('utf-8-sig', 'replace'))
    if isinstance(data, dict): data=[data]
    for p in data:
        if p['ProcessId']==os.getpid(): continue
        name=(p.get('Name') or '').lower()
        if name.startswith('godot') or name in ('spacebattleship.exe','verify.exe'):
            raise RuntimeError('Close the game/Godot, then rerun: '+name)
        if name.startswith(('python','scons','blender')):
            command=(p.get('CommandLine') or '')+' '+(p.get('ExecutablePath') or '')
            if any(key(root) in os.path.normcase(command.replace('/',os.sep)) for root in ROOTS):
                raise RuntimeError('A process is using a cleanup area: '+name)

def inspect(path, tracked, worktrees, cache=False):
    global last_progress
    safe_ancestors(path)
    if not any(inside(path,r) and key(path)!=key(r) for r in ROOTS): raise RuntimeError('Outside allowed roots')
    # Never remove a registered worktree or any part of it as a whole test run.
    if not cache and any(inside(path,w) or inside(w,path) for w in worktrees if key(w)!=key(MAIN)):
        raise RuntimeError('Registered Git worktree')
    if any(inside(p,path) for p in tracked): raise RuntimeError('Contains tracked source files')
    total=0; count=0; newest=0
    stack=[path]
    while stack:
        current=stack.pop()
        now=time.monotonic()
        if now-last_progress>2:
            note('Checking: '+str(current)); last_progress=now
        with os.scandir(current) as entries:
            for e in entries:
                p=Path(e.path)
                if link(p): raise RuntimeError('Contains link/junction: '+str(p))
                n=e.name.lower()
                if n in PRIVATE or n.endswith(('.pem','.key','.blend','.xlsx')) or n.startswith(('savegame','save_game','player_save')) or n in ('save.json','profile.json'):
                    raise RuntimeError('Protected/unknown content: '+str(p))
                if e.is_dir(follow_symlinks=False): stack.append(p)
                else:
                    s=e.stat(follow_symlinks=False)
                    total+=s.st_size; count+=1; newest=max(newest,s.st_mtime)
    if newest and time.time()-newest<CUTOFF: raise RuntimeError('Modified within the last 24 hours')
    return total,count,newest

def delete_verified(path):
    # Never follow links, alter read-only attributes, or modify shared hardlink bytes.
    for e in list(os.scandir(path)):
        p=Path(e.path)
        if link(p): raise RuntimeError('Link appeared during cleanup; stopped: '+str(p))
        if e.is_dir(follow_symlinks=False): delete_verified(p)
        else: os.unlink(p)
    os.rmdir(path)

def known_run(path):
    n=path.name
    if n.startswith(("ui-text-release-", "release-failure-tests-")):
        return (path/"space-battleship/tools/build_release.ps1").is_file() and (path/"space-battleship/project.godot").is_file()
    if n.startswith("release-portability-"):
        return any((x/"build_release.bat").is_file() for x in path.iterdir() if x.is_dir() and not link(x))
    return (path/"project/project.godot").is_file() or (path/"previous-release-not-current").is_dir() or (path/"failed-publish-not-current").is_dir()

def run():
    global LOG
    if os.name!='nt': raise RuntimeError('Windows only')
    if not shutil.which('git'): raise RuntimeError('Git not found; nothing deleted')
    desktop=Path(os.environ.get('TEMP',str(Path.home())))
    log_path=desktop/('space-idle-cleanup-'+time.strftime('%Y%m%d-%H%M%S')+'.log')
    LOG=open(log_path,'x',encoding='utf-8')
    note('PERMANENT cleanup of verified old test outputs. No Recycle Bin.')
    note('Protected: main source, Git worktrees, saves, tools, unknown folders, recent files.')
    note('Log: '+str(log_path))
    busy()
    tracked=[MAIN/Path(p) for p in git('ls-files','-z').split('\0') if p]
    worktrees=[Path(line[9:]) for line in git('worktree','list','--porcelain').splitlines() if line.startswith('worktree ')]
    pending=[]; skipped=0
    for root in ROOTS:
        if not root.exists(): note('Missing; skipped: '+str(root)); continue
        safe_ancestors(root)
        stack=[root]
        while stack:
            current=stack.pop()
            try:
                for e in os.scandir(current):
                    if not e.is_dir(follow_symlinks=False): continue
                    p=Path(e.path)
                    if link(p): note('KEEP link: '+str(p)); continue
                    if e.name.lower() in PRIVATE or e.name in ('node_modules','venv','.venv'): continue
                    is_cache=e.name in CACHES
                    known=bool(PATTERN.fullmatch(e.name)) and known_run(p)
                    if is_cache and e.name=='.godot' and not (p.parent/'project.godot').is_file(): is_cache=False
                    if is_cache or known:
                        try:
                            facts=inspect(p,tracked,worktrees,is_cache)
                            pending.append((p,facts,is_cache))
                            note('Eligible %.1f MiB: %s'%(facts[0]/2**20,p))
                        except (OSError,RuntimeError) as ex:
                            skipped+=1; note('KEEP '+str(p)+' | '+str(ex))
                        # Do not descend into a rejected run to evade protection.
                        continue
                    stack.append(p)
            except OSError as ex: skipped+=1; note('KEEP unreadable '+str(current)+' | '+str(ex))
    before=shutil.disk_usage('D:/').free; removed=0
    for p,facts,is_cache in pending:
        busy()
        # Recheck Git tracking, worktree registration and content immediately before deletion.
        tracked_now=[MAIN/Path(x) for x in git('ls-files','-z').split('\0') if x]
        trees_now=[Path(x[9:]) for x in git('worktree','list','--porcelain').splitlines() if x.startswith('worktree ')]
        try:
            if inspect(p,tracked_now,trees_now,is_cache)!=facts: raise RuntimeError('Contents changed after scan')
            note('Deleting: '+str(p)); delete_verified(p); removed+=1
        except (OSError,RuntimeError) as ex:
            skipped+=1; note('STOP/KEEP (may be partially removed): '+str(p)+' | '+str(ex)); break
    after=shutil.disk_usage('D:/').free
    note('Done. Removed directories: %d; skipped/problem entries: %d'%(removed,skipped))
    note('Observed D: free-space change: %.2f GiB. Hardlinks and other disk activity affect this value.'%((after-before)/2**30))
    clean_verified_copies()
    note('Log: '+str(log_path))


def clean_verified_copies():
    """Remove only historical Git-identical files in verified run.py sandboxes."""
    import hashlib
    allowed = ('space-battleship/scripts/', 'space-battleship/shaders/',
               'space-battleship/tools/', 'space-battleship/data/',
               'space-battleship/config_excel/', 'space-battleship/assets/',
               'space-battleship/addons/', 'space-battleship/dev/')
    single = {'space-battleship/project.godot', 'space-battleship/main.tscn',
              'space-battleship/level_editor.tscn', '\u592a\u7a7a\u6218\u8230.xlsx'}
    paths = list(allowed) + list(single) + ['test/']
    note('Checking historical Git-identical test copies; modified/unknown files and saves stay.')
    historical = {}
    for line in git('rev-list', '--objects', '--all', '--', *paths).splitlines():
        oid, sep, rel = line.partition(' ')
        if sep: historical.setdefault(rel, set()).add(oid)
    names = {Path(p).stem for p in git('ls-files','-z','--','test').split('\0')
             if p and Path(p).parent.as_posix() == 'test' and Path(p).suffix in ('.py','.gd')}
    trees = [Path(x[9:]) for x in git('worktree','list','--porcelain').splitlines() if x.startswith('worktree ')]
    owners = [MAIN] + [x for x in trees if inside(x, ROOTS[1]) and key(x)!=key(MAIN)]
    removed = 0; kept = 0; logical = 0
    before = shutil.disk_usage('D:/').free
    def digest(p):
        s = p.stat(); h = hashlib.sha1(('blob '+str(s.st_size)+'\0').encode())
        with open(p,'rb') as f:
            for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
        return h.hexdigest(), s.st_size, s.st_mtime_ns
    for owner in owners:
        work = owner/'test/work'
        if not work.is_dir(): continue
        safe_ancestors(work)
        # Read each real worktree's own index, including uncommitted staged files.
        r = subprocess.run(['git','-c','safe.directory='+str(owner),'-C',str(owner),'ls-files','-z'],capture_output=True)
        if r.returncode: note('KEEP cannot read worktree index: '+str(owner)); continue
        tracked = {key(owner/Path(x)) for x in r.stdout.decode('utf-8','strict').split('\0') if x}
        for area in work.iterdir():
            if link(area) or not area.is_dir(): continue
            stem, sep, suffix = area.name.rpartition('-')
            if stem not in names or not re.fullmatch('[a-z0-9_]{8}',suffix): continue
            # Require the copied test and project structure produced by test/run.py.
            if not (area/'space-battleship/project.godot').is_file(): continue
            if not any((area/'test'/(stem+ext)).is_file() for ext in ('.gd','.py')): continue
            if not (area/'import.log').is_file() and not (area/'test.log').is_file(): continue
            if any(inside(w,area) for w in trees): note('KEEP worktree: '+str(area)); continue
            busy(); safe_ancestors(area)
            if time.time()-area.stat().st_mtime < CUTOFF:
                note('KEEP recent test copy: '+str(area)); continue
            note('Checking test copy: '+str(area))
            stack=[area]; candidates=[]; blocked=False
            try:
                while stack:
                    d=stack.pop()
                    for e in os.scandir(d):
                        p=Path(e.path)
                        if link(p): blocked=True; break
                        if e.name.lower()=='.git': blocked=True; break
                        if e.is_dir(follow_symlinks=False):
                            if e.name.lower() not in PRIVATE and e.name.lower() not in ('userdata','user','roaming','local','pycache','.runtime','.godot'):
                                stack.append(p)
                            continue
                        rel=p.relative_to(area).as_posix()
                        selected=rel in single or rel.startswith(allowed) or (p.parent==area/'test' and p.suffix in ('.py','.gd','.uid'))
                        if not selected: continue
                        if key(p) in tracked: blocked=True; break
                        if time.time()-p.stat().st_mtime<CUTOFF: kept+=1; continue
                        known=historical.get(rel,set())
                        if not known: kept+=1; continue
                        facts=digest(p)
                        if facts[0] in known: candidates.append((p,facts))
                        else: kept+=1
                    if blocked: break
                if blocked:
                    note('KEEP protected/link/tracked test copy: '+str(area)); continue
                if not candidates: continue
                note('Verified duplicate files %d (%.1f MiB): %s'%(len(candidates),sum(f[1] for _,f in candidates)/2**20,area))
                busy()
                # Fail closed if Git index changed after inspection.
                rr=subprocess.run(['git','-c','safe.directory='+str(owner),'-C',str(owner),'ls-files','-z'],capture_output=True)
                if rr.returncode or rr.stdout!=r.stdout: raise RuntimeError('Git index changed; stopped')
                for p,facts in candidates:
                    safe_ancestors(p)
                    if digest(p)!=facts: raise RuntimeError('File changed; stopped: '+str(p))
                    os.unlink(p); removed+=1; logical+=facts[1]
                note('Removed verified duplicates; logs/saves/unknown files retained: '+str(area))
            except OSError as ex:
                note('KEEP/ERROR '+str(area)+' | '+str(ex)); kept+=1
    note('Duplicate pass: removed %d Git-identical files; retained unmatched/recent entries %d.'%(removed,kept))
    note('Duplicate logical size %.2f GiB; observed additional D: free space %.2f GiB.'%(logical/2**30,(shutil.disk_usage('D:/').free-before)/2**30))

if __name__=='__main__':
    try: run()
    except Exception as ex:
        note('STOPPED: '+str(ex)); sys.exit(1)

