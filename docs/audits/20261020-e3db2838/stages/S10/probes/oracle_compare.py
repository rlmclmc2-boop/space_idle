import subprocess,os,pathlib,decimal,re
p=pathlib.Path('s10_scratch/userdata');e=os.environ.copy();e['APPDATA']=str((p/'roaming').resolve());e['LOCALAPPDATA']=str((p/'local').resolve())
r=subprocess.run([r'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe','--headless','--path','.','--script','res://s10_scratch/oracle_probe.gd'],capture_output=True,text=True,env=e,timeout=30)
decimal.getcontext().prec=3000
D=decimal.Decimal
fails=[]
baseline=dict((int(n),int(v)) for n,v in re.findall(r'BASELINE_COST:(\d+):([0-9]+)',r.stdout))
for kind,level,value in re.findall(r'ORACLE_(CAP|COST|EARLY):(\d+):([0-9]+)',r.stdout):
 n=int(level)
 if kind=='CAP': expected=int(D(100)*D('1.5')**(n-1)) if n>=98 else int(float(100)*float(1.5)**(n-1))
 elif kind=='COST': expected=int((D(10)*D('1.35')**(n-1)).to_integral_value(rounding=decimal.ROUND_CEILING)) if 10*1.35**(n-1)>=9223372036854775808.0 else baseline[n]
 else: expected=int(D(100)*D('1.5')**(n-1)*2)
 ok=int(value)==expected
 print(kind,n,'PASS' if ok else 'FAIL',str(value)[:24], 'digits',len(value))
 if not ok:fails.append((kind,n,expected,value))
print('FAILURES',len(fails))
print(r.stderr[-500:])
raise SystemExit(1 if fails or r.returncode else 0)
