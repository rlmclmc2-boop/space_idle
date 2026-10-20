"""Exercise real import and ensure failed input never overwrites working JSON."""
from pathlib import Path
import subprocess
import tempfile
import json
import sys
import openpyxl
from current_workbook_fixture import build_current_master, seed_current_data

root=Path(__file__).resolve().parents[1]/'space-battleship'
area=Path(__file__).resolve().parent/'work'
area.mkdir(exist_ok=True)
sys.path.insert(0,str(root/'tools'))
from import_workbook import SECTIONS
source=area/'current-master.xlsx'
build_current_master(root,source,SECTIONS)
book=openpyxl.load_workbook(source,data_only=True,read_only=True)
expected_levels=sum(1 for r in list(book['level'].values)[3:] if r[0] is not None)
expected_laser=sum(1 for r in list(book['equipment'].values)[3:] if r[0]=='laser')
book.close()
with tempfile.TemporaryDirectory(dir=area) as folder:
    folder=Path(folder)
    target=folder/'game_data.json'
    seed_current_data(root,folder)
    script=root/'tools/import_workbook.py'
    result=subprocess.run([sys.executable,str(script),str(source),str(target)],capture_output=True)
    assert result.returncode==0,result.stderr.decode('utf-8',errors='replace')
    data=json.loads(target.read_text(encoding='utf-8'))
    assert len(data['levels'])==expected_levels and len(data['equipment']['laser'])==expected_laser
    data['defaults']['autoCollectDelay']=12
    target.write_text(json.dumps(data),encoding='utf-8')
    subprocess.run([sys.executable,str(script),str(source),str(target)],check=True,capture_output=True)
    assert json.loads(target.read_text(encoding='utf-8'))['defaults']['autoCollectDelay']==12
    before=target.read_bytes()
    invalid=folder/'invalid.xlsx'
    invalid.write_bytes(b'invalid workbook fixture')
    result=subprocess.run([sys.executable,str(script),str(invalid),str(target)],capture_output=True)
    assert result.returncode!=0 and target.read_bytes()==before
    assert not target.with_suffix('.json.tmp').exists()
print('PASS: import, data rows, defaults preservation, failure preserves JSON')
