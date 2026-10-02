"""Validate normal export and protected source fields against the approved 40-template base."""
from pathlib import Path
import io,json,subprocess,sys,openpyxl
root=Path(__file__).resolve().parents[2];src=root/'space-battleship';base='04a5a307bcef9325efa9026e1ca94affa577e10d'
sys.path.insert(0,str(src/'tools'))
from import_workbook import validate_projection
from config_workbooks import incremental_import
x=json.loads((src/'data/game_data.json').read_text());validate_projection(x)
checked=0
compensation=root/'test/progression/candidates/enemy-pair-compensation-v1.json'
allowed=json.loads(compensation.read_text()).get('allowed_source_cells',{}) if compensation.exists() else {}
for file in (src/'config_excel').glob('*.xlsx'):
 rel=file.relative_to(root).as_posix()
 try:old=openpyxl.load_workbook(io.BytesIO(subprocess.check_output(['git','show',base+':'+rel],cwd=root)),read_only=True).active
 except subprocess.CalledProcessError:continue
 new=openpyxl.load_workbook(file,read_only=True).active
 headers=[c.value for c in old[1]]
 assert [c.value for c in new[1]][:len(headers)]==headers,rel
 if file.stem in ['mon','monGroup','equipment','battle_design','weapon_motion']:
  # Protect every original cell except explicitly versioned numerical compensation.
  for oldrow,newrow in zip(old.iter_rows(values_only=True),new.iter_rows(values_only=True)):
   expected=list(oldrow)
   if file.stem=='mon' and oldrow[0] in [int(k) for k in allowed]:
    for field,value in allowed[str(int(oldrow[0]))].items():expected[headers.index(field)]=value
   assert expected==list(newrow[:len(oldrow)]),(rel,checked)
   checked+=1
result=incremental_import(src/'config_excel',src/'data/game_data.json')
assert not result.get('changed'),result
print(json.dumps({'status':'pass','normal_projection':'valid','normal_import':'no changes','protected_source_rows':checked,'headers':'all old fields retain position','base':base}))
