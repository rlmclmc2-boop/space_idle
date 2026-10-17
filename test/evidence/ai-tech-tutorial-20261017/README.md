# AI factory tutorial validation

- Base: `main@7350199bca810209f505561ddb7a5be1a7059bdd`.
- `catalog-check.log`: UI text table and contract validation, 2387 rows valid.
- `focused-headless.log`: six focused checks for the new tutorial text, `/秒` units, and estimated time before and during research; 6/6 passed.
- `gui.log` and `gui/*.png`: actual main-scene GUI validation, 28/28 passed. `00-choose-research.png` shows the research guidance and selectable estimates; `02-uranium-shortage.png` shows both input units and the per-resource shortage state. The other screenshots are the original captures from the same run.
- `headless.log`: the pre-existing broad tree suite reports three assertions still expecting singularity's former 60-second first level and 108-second next level. The current main configuration uses a 20-second first level. No gameplay configuration was changed.
- `headless-current-table.log`: those three assertions now derive the first and next duration from the current table using an independent power formula, and derive expected AI speed from the documented `(N+9)/10`; the tree suite passes 41/41. The original failing `headless.log` remains above.
- `focused-headless-followup.log`, `catalog-followup.log`, and `gui-followup.log`: after the prerequisite wording change, focused checks pass 6/6, text table remains valid, and the actual GUI passes 28/28.
- `followup/00-choose-research.png` and `followup/02-uranium-shortage.png` are original captures from the updated GUI. Same-named JPGs are 1720x1106 light previews for reviewing wording and layout. `make_previews.gd` performs the conversion.

Godot executable: `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`. Tests ran in an isolated project and user directory under `test/work/ai-tech-tutorial-20261017/`; no personal save was included.
