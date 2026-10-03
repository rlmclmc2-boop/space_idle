"""Validate normal export and protected source fields against the approved 40-template base."""
from pathlib import Path
import io,json,subprocess,sys,tempfile,openpyxl
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
# Validate a cold normal export without rewriting the checked-out JSON/cache.
# Parsed tables and absolute provenance paths may change on another checkout;
# every gameplay section must remain identical.
with tempfile.TemporaryDirectory(prefix='progression-source-validation-') as folder:
 target=Path(folder)/'game_data.json'
 target.write_bytes((src/'data/game_data.json').read_bytes())
 result=incremental_import(src/'config_excel',target)
 exported=json.loads(target.read_text())
 gameplay_changes=[key for key in set(x)|set(exported)
                   if key!='source_files' and x.get(key)!=exported.get(key)]
 assert not gameplay_changes,{'gameplay_changed':gameplay_changes,'import':result}
 provenance_changes=[key for key in set(x.get('source_files',{}))|set(exported.get('source_files',{}))
                     if x.get('source_files',{}).get(key)!=exported.get('source_files',{}).get(key)]
print(json.dumps({'status':'pass','normal_projection':'valid','normal_import':'cold export has identical gameplay','parsed_tables':result.get('parsed',[]),'source_path_metadata_changes':provenance_changes,'protected_source_rows':checked,'headers':'all old fields retain position','base':base}))
