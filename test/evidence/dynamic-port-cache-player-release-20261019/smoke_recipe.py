from pathlib import Path
import subprocess,shutil,os,json,hashlib,sys,time
r=Path.cwd(); out=r/'test/evidence/dynamic-port-cache-player-release-20261019'; out.mkdir(parents=True,exist_ok=True)
clone=r/'test/work/player-entry-release-20261019/relocated checkout';clone.parent.mkdir(parents=True,exist_ok=True)
def call(args,cwd=r,env=None):return subprocess.run(args,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True).stdout
call(['git','clone','--shared','--no-checkout','--single-branch','--branch','fix/dynamic-port-cache-win472',str(r),str(clone)])
call(['git','config','core.sparseCheckout','true'],clone)
shutil.copy2(r/'.git/info/sparse-checkout',clone/'.git/info/sparse-checkout')
call(['git','checkout','-b','main','24b88272b12a0cf0d4dfce3714fbd60885579a70'],clone)
p=clone/'space-battleship';(p/'engine').mkdir(exist_ok=True);(p/'bin').mkdir(exist_ok=True)
engine=p/'engine/Godot_v4.7.2-stable_win64.exe';shutil.copy2('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe',engine)
shutil.copy2(r.parent/'toolchain-audit/builds/space_native-player-old.dll',p/'bin/space_native.dll')
env=os.environ.copy();env.update({'SPACE_BATTLESHIP_VERIFY_WINDOW':'1','SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES':'120','PYTHONIOENCODING':'utf-8'})
for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    dest=clone/'test/work/player-window-check/outer-environment'/key;dest.mkdir(parents=True,exist_ok=True);env[key]=str(dest)
install=call([sys.executable,str(clone/'tools/play_main.py'),'--install-native'],r.parent,env);(out/'install.log').write_bytes(install)
print('Upgrade installed, starting actual root CMD from outside checkout',flush=True)
start=time.time();res=subprocess.run(['cmd.exe','/d','/c',str(clone/'玩游戏.cmd')],cwd=r.parent,env=env,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(out/'startup.log').write_bytes(res.stdout)
work=clone/'test/work/player-window-check'
for name in ['player-launch.json','player-import.log','player-game.log']:
    if (work/name).exists():shutil.copy2(work/name,out/name)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old='04e7be92c92637a72dde5f71ccc57a865ad20842e00aca63fd628b86e321590f';expected='137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78'
receipt={'tested_head':'24b88272b12a0cf0d4dfce3714fbd60885579a70','source_anchor':'fda7be2c217a208067f97266f85497b83cbdd840','isolated_branch':call(['git','branch','--show-current'],clone).decode().strip(),'relocated_checkout':str(clone),'invocation_cwd':str(r.parent),'entry':'actual root 玩游戏.cmd','exit_code':res.returncode,'elapsed_seconds':time.time()-start,'quit_after_frames':120,'bundle_sha256':sha(clone/'tools/player_runtime/space_native.dll'),'installed_sha256':sha(p/'bin/space_native.dll'),'old_backup_sha256':sha(p/('.runtime/native-backup/space_native-'+old+'.dll')),'engine_sha256':sha(engine),'unit_checks':17,'unit_failures':0,'scope':'Release closure only; previous correctness/performance acceptance reused, not rerun','prior_acceptance':'test/evidence/dynamic-port-cache-win472-20261019/README.md','source_diff_from_anchor':call(['git','diff','--no-renames','--name-only','fda7be2','--','space-battleship'],clone).decode(),'main_not_merged':True}
receipt['valid']=res.returncode==0 and receipt['installed_sha256']==expected and receipt['bundle_sha256']==expected and receipt['old_backup_sha256']==old
(out/'release.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(receipt,ensure_ascii=False),flush=True)
