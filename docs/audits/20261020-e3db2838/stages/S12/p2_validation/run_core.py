from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, time
root=Path(__file__).resolve().parent
args=argparse.ArgumentParser()
args.add_argument("--runtime",type=Path,default=root.parent/"p2-runtime"/"space-battleship")
args.add_argument("--script",choices=("core_probe.gd","query_probe.gd","finite_price_probe.gd","finite_max_probe.gd"),default="core_probe.gd")
options=args.parse_args()
runtime=options.runtime.resolve()
names=("currency_integer.gd","currency_ledger.gd","currency_host.gd","equipment_price.gd","currency_storage.gd","equipment_price_bounds.gd","equipment_max_query.gd")
for name in names:
    shutil.copyfile(runtime/"scripts"/name,root/"scripts"/name)
shutil.copyfile(Path(r"C:\Program Files\Git\mingw64\etc\ssl\certs\ca-bundle.crt"), root/"ca-bundle.crt")
project=root/"project.godot"
text=project.read_text(encoding="utf-8")
if "[network]" not in text:
    project.write_text(text+'\n[network]\ntls/certificate_bundle_override="res://ca-bundle.crt"\n',encoding="utf-8")
run=root/"evidence"/("core-"+str(time.time_ns()))
run.mkdir(parents=True)
env=os.environ.copy()
env["APPDATA"]=str(run/"Roaming")
env["LOCALAPPDATA"]=str(run/"Local")
Path(env["APPDATA"]).mkdir()
Path(env["LOCALAPPDATA"]).mkdir()
cmd=[r"D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe","--headless","--path",str(root),"--script",options.script]
start=time.monotonic()
try:
    proc=subprocess.run(cmd,env=env,capture_output=True,timeout=120)
    stdout,stderr,code=proc.stdout,proc.stderr,proc.returncode
except subprocess.TimeoutExpired as exc:
    stdout,stderr,code=exc.stdout or b"",exc.stderr or b"",124
(run/"stdout.log").write_bytes(stdout)
(run/"stderr.log").write_bytes(stderr)
marker=b"P2_QUERY_COMPLETE" if options.script=="query_probe.gd" else b"P2_PRICE_COMPLETE" if options.script=="finite_price_probe.gd" else b"P2_MAX_FINITE_COMPLETE" if options.script=="finite_max_probe.gd" else b"P2_CORE_COMPLETE"
passed=code==0 and marker in stdout and not any(x in stdout+stderr for x in (b"SCRIPT ERROR",b"Parse Error",b"ERROR:",b"P2_FAIL"))
receipt={"status":"PASS" if passed else "FAIL","command":cmd,"exit_code":code,"seconds":time.monotonic()-start,"appdata":env["APPDATA"],"localappdata":env["LOCALAPPDATA"],"source_sha256":{name:hashlib.sha256((root/"scripts"/name).read_bytes()).hexdigest() for name in names},"stdout_sha256":hashlib.sha256(stdout).hexdigest(),"stderr_sha256":hashlib.sha256(stderr).hexdigest()}
(run/"receipt.json").write_text(json.dumps(receipt,indent=2),encoding="utf-8")
print(json.dumps({"status":receipt["status"],"evidence":str(run)}))
print(stdout.decode("utf-8",errors="replace"))
print(stderr.decode("utf-8",errors="replace"))
sys.exit(0 if passed else 1)

