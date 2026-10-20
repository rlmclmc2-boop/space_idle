from pathlib import Path
import sys,tempfile,json
from unittest.mock import patch
sys.path.insert(0,'/tmp/space-idle-audit/space-battleship/tools')
import config_workbooks as cw
with tempfile.TemporaryDirectory(prefix='atomic-audit-') as p:
 p=Path(p);a=p/'a.json';b=p/'b.json';backup=p/'backup/a.json'
 a.write_bytes(b'OLD_A');b.write_bytes(b'OLD_B')
 real=cw.os.replace;calls=[]
 def replace(src,dst):
  calls.append(str(dst))
  if dst==b:raise OSError('injected install failure')
  if dst==a and a.read_bytes()==b'NEW_A':raise OSError('injected restore failure')
  real(src,dst)
 try:
  with patch.object(cw.os,'replace',side_effect=replace):cw.atomic_batch({backup:b'OLD_A',a:b'NEW_A',b:b'NEW_B'})
 except Exception as e:print('ERROR',type(e).__name__,str(e))
 print('FINAL',json.dumps({'a':a.read_text(),'b':b.read_text(),'backup_exists':backup.exists(),'remaining_tmp':[str(x) for x in p.rglob('*.tmp')]}))
