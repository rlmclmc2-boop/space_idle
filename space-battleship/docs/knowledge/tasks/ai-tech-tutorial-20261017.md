# AI factory tutorial follow-up

- Goal: explain first research selection, free base research, automatic continuation, preserved progress, and optional iron/uranium investment measured per second.
- Scope: existing text table and its contract, tutorial entry, and minimal `ai_tech_factory_page.gd` UI. No art assets, level numbers, loadout answers, save changes, or other playtest feedback.
- Base: `main@7350199bca810209f505561ddb7a5be1a7059bdd`; candidate branch: `feat/ai-tech-tutorial-20261017`. Parent reviews before main merge.
- Stop condition: target copy and page behavior pass focused text/function checks plus one serial GUI check; preserve original evidence.
- Locate: `docs/UI_TEXT.md` AI factory keys, `data/ui_text.json`, `data/ui_text_contract.json`, `scripts/ai_tech_factory_page.gd`, and the main tutorial entry.
- Known risk: an input labeled only with a resource name reads like a one-time purchase. Place `/秒` directly next to each input and make estimated time visible at selection.
- Result: in-page research guidance and `/秒` input labels use six new UI text keys; each selectable technology shows the next-level estimate at current speed. The removed drawer sentence exposed implementation detail.
- Evidence: `test/evidence/ai-tech-tutorial-20261017/`; UI catalog valid, focused headless 6/6, actual main-scene GUI 28/28. The original three stale singularity-duration failures are retained, and the corrected current-table tree suite passes 41/41. Updated drawer and shortage PNGs plus lightweight JPG previews are included.
- Next: hand the candidate to the parent for acceptance. No main merge.
