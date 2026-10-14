from pathlib import Path
import shutil
r=Path('D:/CodexBuild/space_idle/stable-integration');iso=r/'test/work/battle-fix-20261013/space-battleship'
for p in (r/'space-battleship/scripts').rglob('*.gd'):shutil.copy2(p,iso/p.relative_to(r/'space-battleship'))
P='preload("res://natural_probe.gd")'
p=iso/'scripts/game.gd';s=p.read_text(encoding='utf-8')
s=s.replace('func tick(dt: float) -> void:', 'func tick(dt: float) -> void:\n\t_natural_tick(dt)\n\t'+P+'.steps+=1\n\nfunc _natural_tick(dt: float) -> void:',1)
needle='func admit_native_compiled_execution(scope:String="native_rich15_layer2")->bool:'
if needle not in s:
 import re
 m=re.search(r'^func admit_native_compiled_execution\([^\n]+',s,re.M);needle=m[0]
args=needle[needle.index('(')+1:needle.index(')')]
s=s.replace(needle,'func admit_native_compiled_execution('+args+')->bool:\n\tvar stamp=Time.get_ticks_usec()\n\tvar success=_natural_admit(scope)\n\t'+P+'.admissions.append({"success":success,"us":Time.get_ticks_usec()-stamp,"game":production_time(),"group":group_index})\n\treturn success\n\nfunc _natural_admit('+args+')->bool:',1);p.write_text(s,encoding='utf-8')
p=iso/'scripts/native_execution_session.gd';s=p.read_text(encoding='utf-8');s=s.replace('func handoff_to_legacy(game:RefCounted,reason:String)->bool:', 'func handoff_to_legacy(game:RefCounted,reason:String)->bool:\n\tvar stamp=Time.get_ticks_usec()\n\tvar success=_natural_handoff(game,reason)\n\t'+P+'.transfers.append({"success":success,"us":Time.get_ticks_usec()-stamp,"game":game.production_time(),"reason":reason})\n\treturn success\n\nfunc _natural_handoff(game:RefCounted,reason:String)->bool:',1);p.write_text(s,encoding='utf-8')
