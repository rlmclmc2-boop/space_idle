# S0 portable integration evidence

Base: `413a748736a7e37600ebc8221f022161ae6c4cab`. Python 3.12, openpyxl,
Godot 4.7.2 official (`ed1daf0bf`). Engine used:
`C:/Users/Administrator/Documents/Codex/2026-10-20/task/space_idle/space-battleship/engine/Godot_v4.7.2-stable_win64.exe`.

- `analyzer-import.log`: exact fresh package build/import, exit 0.
- `portable-smoke.log`: final real-entry run, exit 0, 10461 rows match the official
  projection, `BATTLE LAB STANDALONE failures=0`. Includes eight intentional
  startup rejection reports (ordinary/canonical generation and replay, battle,
  upgrade, pair validation, runner). No script/parse error. Certificate-store
  error and deliberately excessive numeric exponent warning are also present.
- `output-parity.log`: actual emitted workbook reopened through the official
  monGroup converter; both groups equal JSON, one completed multi-wave level,
  original preview metadata retained in evaluated records.
- `first-negative.log`: prior integration run, exit 1. Positive path and full
  projection passed; the new negative scenario caught BalanceGame's write after
  failed parent construction. This was fixed before the final build.

These logs are unedited. They do not establish arbitrary external-input
validation equivalence, historical-save continuity, performance, or S1–S5.
The create_battle rejection fixture stops at player-record validation; its
post-construction guard was reviewed statically, not separately fault-injected.

## Reproduce

Run from the repository root. Choose a **new, empty** output path and the engine
above (or another explicitly verified Godot 4.7.2 binary). The package builder
isolates import user paths. The Python below isolates runtime paths and reads
only the checked-in workbook; it never accesses player saves.

```powershell
python space-battleship/tools/build_result_analyzer.py --output test/work/s0-reproduce --engine <Godot-4.7.2.exe>
```

Execute this Python from the same root after building:

```python
import json, os, pathlib, subprocess, sys
import openpyxl
sys.path.insert(0, "space-battleship/tools")
from import_workbook import read_rows, convert_sheet

p = pathlib.Path("test/work/s0-reproduce").resolve()
book = openpyxl.load_workbook("space-battleship/config_excel/mon.xlsx",
                             data_only=True, read_only=True)
expected = convert_sheet("mon", read_rows(book.worksheets[0]))
book.close()
projection = p / "official-mon.json"
projection.write_text(json.dumps(expected, ensure_ascii=False), encoding="utf-8")
env = os.environ.copy()
env.update(APPDATA=str(p / ".smoke-user/roaming"),
           LOCALAPPDATA=str(p / ".smoke-user/local"),
           SPACE_MON_PROJECTION=str(projection))
for key in ("APPDATA", "LOCALAPPDATA"):
    pathlib.Path(env[key]).mkdir(parents=True, exist_ok=True)
with (p / "smoke.log").open("w", encoding="utf-8") as log:
    result = subprocess.run(
        [str(p / "runtime/analyzer.exe"), "--headless", "--path", str(p),
         "--script", str(pathlib.Path("test/test_battle_lab_standalone.gd").resolve())],
        env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
text = (p / "smoke.log").read_text(encoding="utf-8")
assert result.returncode == 0
assert "BATTLE LAB STANDALONE failures=0" in text
assert "STANDALONE projection comparison failures=0" in text
assert "SCRIPT ERROR" not in text and "Parse Error" not in text and "FAIL:" not in text

outputs = list((p / "results").glob("level_run_*/**/generated_levels.json"))
output = max(outputs, key=lambda item: item.stat().st_mtime_ns)
data = json.loads(output.read_text(encoding="utf-8"))
book = openpyxl.load_workbook(output.with_name("monGroup.xlsx"),
                             data_only=True, read_only=True)
groups = convert_sheet("monGroup", read_rows(book.worksheets[0]))
book.close()
assert data["status"] == "completed" and len(data["levels"]) == 1
assert len(groups) == 2 and groups == data["groups"]
assert all("formation_positions" not in row for row in groups.values())
assert all("formation_positions" in row["enemy_group"] for row in data["evaluated"])
print("PORTABLE AND OUTPUT PARITY PASS")
```
