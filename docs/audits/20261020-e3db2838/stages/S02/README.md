# S02 fixture and oracle review

Base main: `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`. S01 closure: `87fab83acecd6933d6a86ca50b172742333d1654`. Test revision: `505d5fa82f77128cb65b18bea769b67a695bed2f`. Runtime SHA and main integration: N/A.

Only `test/test_save_policy.gd` and `test/test_config_workbooks.py` changed. Product scripts, game formulas, workbooks, the S01 gate, and `test/run.py` did not change. All original assertions remain; the save suite gained one timestamp assertion and the workbook suite gained explicit formula/cache assertions.

## Minimal reproductions and oracles

| Case | Baseline cause and observation | Correct oracle and revision |
|---|---|---|
| Enhancement purchase | At level 30, current `enhance_config` has `cost_base=100`, `cost_growth=2`; the next level costs `100*2^30 = 107374182400` fragments. The prior fixture offered `1e9`, so purchase returned 0 and later persistence checks failed. Baseline S01 gate: save policy 48 checks, 3 failures (`Enhancement upgrade`, `Free branch selection`, `Timed save reloads`). | Seed `enhancement_cost()+1e9`; assert one purchase and exactly one configured debit. This is a funded fixture, not a formula change. |
| Branch selection | `weapons/critical` starts third. `branch_threshold_3=30`, `branch_position_offset_3=20`, so node 3 needs level 50 in that order. The fixture was level 31. | Reorder critical to first before selecting node 3; offset 0 makes its threshold 30. Assert the branch is unlocked, selection is dirty-only, and it persists after timed save. |
| Last save time | Comparing the UI to a second expression of the UI implementation's timezone conversion is circular. | Bound the saved Unix timestamp by system clock readings immediately before and after the manual click. Compare the UI text to locally observed calendar time at those endpoints, allowing a second boundary. |
| Formula cache | The current `level.xlsx!D64` has formula `ROUND(D63*10,0)` and cached value `1.6887759815123313e+60`; a generated workbook without the cached `<v>` is not a valid acceptance fixture. | Assert this authored `(formula, cache)` pair survives disposable master creation and split output. Remove only D64's cache in the negative case; assert the formula remains, the whole batch is rejected, and existing JSON is unchanged. No recalculation or invented numeric result. |

The OOXML inspection can be reproduced without Excel by reading `xl/worksheets/sheet1.xml` in `space-battleship/config_excel/level.xlsx` and inspecting cell D64's `<f>` and `<v>`. The negative case edits only that `<v>` in the isolated workbook copy.

## Verification

Environment: Windows, Godot `4.7.2.stable.official.ed1daf0bf`, Python from `D:\CodexTools\venv\godot-native\Scripts\python.exe` (openpyxl 3.1.5, lxml 6.1.3). Both commands used the S01 audit gate and isolated `test/run.py` workspaces:

```powershell
$env:PYTHONIOENCODING='utf-8'
& 'D:\CodexTools\venv\godot-native\Scripts\python.exe' docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_policy.gd --headless --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe
& 'D:\CodexTools\venv\godot-native\Scripts\python.exe' docs/audits/20261020-e3db2838/stages/S01/gate.py test_config_workbooks.py --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe
```

Result at test revision `505d5fa82f77128cb65b18bea769b67a695bed2f`: save policy `49 checks, 0 failures`, completion marker once, `S01_GATE_PASS`; workbook `Ran 14 tests in 106.037s`, `OK`, completion marker once, `S01_GATE_PASS`. `git diff --check` was clean. The Godot import logged its existing root certificate store warning; no test diagnostic or script error occurred. Raw isolated logs stay in ignored `test/work` and are not acceptance artifacts.

No product defect was established by these failures. Parent and original astra independently review the evidence commit; S02 remains open, and this record does not close it or authorize S03.
