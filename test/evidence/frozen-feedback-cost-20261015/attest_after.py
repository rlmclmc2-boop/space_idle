"""Verify both isolated projects still match branch and receipt after sampling."""
from pathlib import Path
import hashlib
import json

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
BASE = Path('D:/CodexBuild/space_idle/frozen-feedback-cost-qa-20261015')
receipt = json.loads((E / 'receipt.json').read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


out = {}
for case in ('laser', 'mixed'):
    project = BASE / case / 'space-battleship'
    source = receipt['qa_sources'][case]
    for name, key in [('combat_stress_fixture.gd', 'fixture_sha256'), ('cost_driver.gd', 'driver_sha256'),
                      ('qa_cost.gd', 'counter_sha256'), ('bin/space_native.dll', 'dll_sha256')]:
        assert sha(project / name) == source[key], (case, name)
    for name, values in source['patched'].items():
        assert sha(project / 'scripts' / name) == values['qa_sha256']
        assert sha(ROOT / 'space-battleship/scripts' / name) == values['source_sha256']
    count = 0
    for part in ('scripts', 'addons'):
        for file in (ROOT / 'space-battleship' / part).rglob('*.gd'):
            relative = file.relative_to(ROOT / 'space-battleship')
            if relative.as_posix() in ('scripts/native_execution_session.gd', 'scripts/main.gd'):
                continue
            assert (project / relative).read_bytes() == file.read_bytes(), (case, relative)
            count += 1
    for name in ('project.godot', 'main.tscn', 'level_editor.tscn'):
        assert (project / name).read_bytes() == (ROOT / 'space-battleship' / name).read_bytes()
    out[case] = {'other_gd_files_identical': count, 'dll_sha256': source['dll_sha256'],
                 'patched': source['patched'], 'fixture_sha256': source['fixture_sha256']}
(E / 'source-after.json').write_text(json.dumps(out, indent=2) + '\n', encoding='utf8')
print(json.dumps({case: data['other_gd_files_identical'] for case, data in out.items()}))
