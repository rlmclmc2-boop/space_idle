"""Exercise cold export provenance tolerance and rejection of a real level mismatch."""
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'test/progression/validate_source.py'
DATA = ROOT / 'space-battleship/data/game_data.json'
original_bytes = DATA.read_bytes()
original_read = Path.read_text
for mode in ['provenance-only', 'gameplay-level-mismatch']:
    def altered(path, *args, **kwargs):
        text = original_read(path, *args, **kwargs)
        if path.resolve() == DATA:
            value = json.loads(text)
            if mode == 'provenance-only':
                value['source_files'] = {key: '/tmp/other-checkout/' + Path(name).name
                                         for key, name in value['source_files'].items()}
            else:
                value['levels'][32]['atkRatio'] *= 1.01
            return json.dumps(value)
        return text
    Path.read_text = altered
    try:
        runpy.run_path(str(SCRIPT), run_name='__main__')
        assert mode == 'provenance-only', 'Gameplay mismatch was not rejected'
        print('CONTROLLED_METADATA_RELOCATION_PASS')
    except AssertionError as error:
        assert mode == 'gameplay-level-mismatch' and 'gameplay_changed' in str(error) and 'levels' in str(error), str(error)
        print('CONTROLLED_GAMEPLAY_MISMATCH_REJECTED', error)
    finally:
        Path.read_text = original_read
    assert DATA.read_bytes() == original_bytes, 'Validator rewrote source JSON'
print('SOURCE_JSON_UNCHANGED_PASS')
