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
    note('Log: '+str(log_path))

if __name__=='__main__':
    try: run()
    except Exception as ex:
        note('STOPPED: '+str(ex)); sys.exit(1)
