"""Read-only post-sampling QA project source/DLL attestation."""
from pathlib import Path
import hashlib, json

E=Path(__file__).resolve().parent;ROOT=E.parents[2]
BASE=Path('D:/CodexBuild/space_idle/pulse-perf-qa-20261015')
before=json.loads((E/'source-manifest.json').read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
after={}
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 values={'session_sha256':sha(project/'scripts/native_execution_session.gd'),'driver_sha256':sha(project/'perf_driver.gd'),'dll_sha256':sha(project/'bin/space_native.dll')}
 assert values==before['qa_sources'][mode],(mode,values)
 count=0
 for relroot in ('scripts','addons'):
  for source in (ROOT/'space-battleship'/relroot).rglob('*.gd'):
   relative=source.relative_to(ROOT/'space-battleship')
   if relative.as_posix()=='scripts/native_execution_session.gd':continue
   assert (project/relative).read_bytes()==source.read_bytes(),relative
   count+=1
 for name in ('project.godot','main.tscn','level_editor.tscn'):
  assert (project/name).read_bytes()==(ROOT/'space-battleship'/name).read_bytes(),name
 assert (project/'combat_stress_fixture.gd').read_bytes()==(ROOT/'test/combat_stress_fixture.gd').read_bytes()
 values['other_gd_files_identical']=count
 after[mode]=values
(E/'source-after.json').write_bytes(json.dumps({'before_source_head':before['source_head'],'after':after},indent=2).encode('utf8'))
print(json.dumps(after,indent=2))
