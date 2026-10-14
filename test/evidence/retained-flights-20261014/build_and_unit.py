from pathlib import Path
import json,subprocess,shutil,os
r=Path('D:/CodexBuild/space_idle/stable-integration');w=r/'test/work/retained-flights';iso=r/'test/work/battle-fix-20261013/space-battleship';b=json.loads((r/'test/evidence/muzzle-demand-20261014/astra-matched-build-receipt.json').read_text(encoding='utf-8'))
subprocess.run([b['compiler'],*b['compile_flags'],str(r/'space-battleship/addons/native_battle/src/space_native.cpp'),'-o',str(w/'space_native.o')],check=True)
subprocess.run([b['compiler'],*b['link_flags'],str(w/'space_native.o'),'D:/CodexBuild/space_idle/godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a','-o',str(w/'space_native.dll')],check=True)
shutil.copy2(w/'space_native.dll',iso/'bin/space_native.dll');shutil.copy2(r/'test/test_retained_flights.gd',iso/'test_retained_flights.gd')
env=os.environ.copy();env.update(APPDATA=str(iso.parent/'roaming'),LOCALAPPDATA=str(iso.parent/'local'))
with (w/'unit.txt').open('w',encoding='utf-8') as log:
 p=subprocess.run(['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://test_retained_flights.gd'],stdout=log,stderr=subprocess.STDOUT,env=env,timeout=50)
text=(w/'unit.txt').read_text(encoding='utf-8');print(text[-4000:]);assert p.returncode==0 and 'RETAINED_FLIGHTS_UNIT_OK' in text and 'ERROR' not in text
