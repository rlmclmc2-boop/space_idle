from pathlib import Path
import json,os,shutil,subprocess,sys,time,hashlib
root=Path(__file__).resolve().parent
runtime=root.parent/"p2-runtime"/"space-battleship"
project=root/"game-project"
project.mkdir(exist_ok=True)
for name in ("scripts","data","assets","shaders","addons"):
    source=runtime/name
    if source.exists():
        shutil.copytree(source,project/name,dirs_exist_ok=True,ignore=shutil.ignore_patterns(".godot","__pycache__"))
shutil.copytree(runtime/"dev"/"toon_ship",project/"dev"/"toon_ship",dirs_exist_ok=True)
for name in ("project.godot","main.tscn"):
    shutil.copyfile(runtime/name,project/name)
config=project/"project.godot"
config.write_text(config.read_text(encoding="utf-8")+'\n[network]\ntls/certificate_bundle_override="res://ca-bundle.crt"\n',encoding="utf-8")
shutil.copyfile(root/"ca-bundle.crt",project/"ca-bundle.crt")
probe=root/"game_probe.gd"
if probe.exists():shutil.copyfile(probe,project/"game_probe.gd")
native_probe=root/"native_probe.gd"
if native_probe.exists():shutil.copyfile(native_probe,project/"native_probe.gd")
ui_probe=root/"ui_probe.gd"
if ui_probe.exists():shutil.copyfile(ui_probe,project/"ui_probe.gd")
chain_probe=root/"chain_probe.gd"
if chain_probe.exists():shutil.copyfile(chain_probe,project/"chain_probe.gd")
if any(flag in sys.argv for flag in ("--native-probe","--ui-probe","--chain-probe")):
    (project/"bin").mkdir(exist_ok=True)
    shutil.copyfile(runtime.parent/"tools"/"player_runtime"/"space_native.dll",project/"bin"/"space_native.dll")
    shutil.copyfile(runtime/"addons"/"native_battle"/"space_native.gdextension.in",project/"space_native.gdextension")
run=root/"evidence"/("game-"+str(time.time_ns()))
run.mkdir(parents=True)
env=os.environ.copy()
for key,folder in (("APPDATA","Roaming"),("LOCALAPPDATA","Local")):
    env[key]=str(run/folder)
    Path(env[key]).mkdir()
engine=r"D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe"
editor_settings=Path(env["APPDATA"])/"Godot"/"editor_settings-4.7.tres"
editor_settings.parent.mkdir(exist_ok=True)
editor_settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nnetwork/tls/editor_tls_certificates = '+json.dumps(str(root/"ca-bundle.crt").replace('\\','/'))+'\n',encoding="utf-8")
cmd=[engine,"--headless","--editor","--path",str(project),"--import","--quit"]
if "--probe" in sys.argv:cmd=[engine,"--headless","--path",str(project),"--script","game_probe.gd"]
if "--ui-check" in sys.argv:cmd=[engine,"--headless","--path",str(project),"--check-only","--script","scripts/equipment_tab.gd"]
if "--native-probe" in sys.argv:cmd=[engine,"--headless","--path",str(project),"--script","native_probe.gd"]
if "--chain-probe" in sys.argv:cmd=[engine,"--headless","--path",str(project),"--script","chain_probe.gd"]
if "--ui-probe" in sys.argv:cmd=[engine,"--headless","--audio-driver","Dummy","--path",str(project),"--script","ui_probe.gd","--","--capture"]
if "--gpu" in sys.argv:
    cmd.remove("--headless")
    cmd.append("--gpu")
try:
    startupinfo=subprocess.STARTUPINFO()
    startupinfo.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow=0
    proc=subprocess.run(cmd,env=env,capture_output=True,timeout=60,startupinfo=startupinfo)
    out,err,code=proc.stdout,proc.stderr,proc.returncode
except subprocess.TimeoutExpired as exc:
    out,err,code=exc.stdout or b"",exc.stderr or b"",124
(run/"stdout.log").write_bytes(out)
(run/"stderr.log").write_bytes(err)
passed=code==0 and not any(x in out+err for x in (b"SCRIPT ERROR",b"Parse Error",b"ERROR:",b"P2_FAIL"))
if "--probe" in sys.argv:passed=passed and b"P2_GAME_COMPLETE" in out
if "--native-probe" in sys.argv:passed=passed and b"P2_NATIVE_COMPLETE" in out
if "--ui-probe" in sys.argv:passed=passed and b"P2_UI_COMPLETE" in out
if "--chain-probe" in sys.argv:passed=passed and b"P2_CHAIN_COMPLETE" in out
meta={"status":"PASS" if passed else "FAIL","command":cmd,"exit_code":code,"appdata":env["APPDATA"],"localappdata":env["LOCALAPPDATA"],"source_sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/"scripts").glob("*.gd")},"overlay":"TLS public CA override; audit probe only; no game formula/config changes"}
(run/"receipt.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
print(json.dumps({"status":meta["status"],"evidence":str(run)}))
print(err.decode("utf-8",errors="replace")[-15000:])
if any(flag in sys.argv for flag in ("--probe","--native-probe","--ui-probe","--chain-probe")):print(out.decode("utf-8",errors="replace")[-5000:])
for image in Path(env["APPDATA"]).rglob("p2-ui-max.png"):
    if image.resolve().is_relative_to(run.resolve()):
        shutil.copyfile(image,run/"p2-ui-max.png")
sys.exit(0 if passed else 1)

