"""Optional enemy shield fields preserve legacy input and reject malformed values."""
import copy
import json
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from import_workbook import validate_projection
source=json.loads((ROOT/'space-battleship/data/game_data.json').read_text())
validate_projection(source)
for field,value in [('shield',-1),('shield',True),('shieldRecovery',float('nan')),('shieldDelay',-0.1),('shieldType',True),('shieldType',3)]:
    changed=copy.deepcopy(source)
    changed['enemies']['1088'][field]=value
    try:validate_projection(changed)
    except (ValueError,TypeError):continue
    raise AssertionError((field,value))
legacy=copy.deepcopy(source)
for row in legacy['enemies'].values():
    for field in ['shield','shieldType','shieldRecovery','shieldDelay']:row.pop(field,None)
validate_projection(legacy)
print('Enemy shield schema: authored data, omitted legacy fields and 6 invalid cases passed')
