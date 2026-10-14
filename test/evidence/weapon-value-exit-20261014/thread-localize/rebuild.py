from pathlib import Path
import subprocess,json,shutil
ROOT=Path.cwd();E=ROOT/'test/evidence/weapon-value-exit-20261014/thread-localize';W=ROOT/'test/work/battle-fix-20261013/thread-probe-native'
(W/'src').mkdir(parents=True,exist_ok=True);(W/'bin').mkdir(exist_ok=True)
for name in ['space_native.cpp','combat_execution_kernel.h','combat_presentation.h','combat_retained_presentation.h']:
 data=subprocess.check_output(['git','show','63bfa881:space-battleship/addons/native_battle/src/'+name])
 (W/'src'/name).write_bytes(data)
p=W/'src/space_native.cpp';s=p.read_text(encoding='utf8');s='#define WIN32_LEAN_AND_MEAN\n#define NOMINMAX\n#include <windows.h>\n'+s
s=s.replace('void initialize(ModuleInitializationLevel level)', '#include "thread_probe.h"\n\nvoid initialize(ModuleInitializationLevel level)').replace('ClassDB::register_class<SpaceMotionLease>();','ClassDB::register_class<SpaceThreadProbe>();ClassDB::register_class<SpaceMotionLease>();');p.write_text(s,encoding='utf8')
shutil.copy2(E/'thread_probe.h',W/'src/thread_probe.h')
for command in json.loads((E/'direct-commands.json').read_text()):subprocess.run(command,cwd=W,check=True)
