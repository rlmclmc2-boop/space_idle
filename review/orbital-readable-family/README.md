# Orbital facility review evidence

Candidate: [`e16abb40f12ca25a547d381b4ac643b979124cb0`](https://github.com/rlmclmc2-boop/space_idle/commit/e16abb40f12ca25a547d381b4ac643b979124cb0), branch `art/orbital-readable-family`, based on main `af4953a2b0db9af74948a6b1d16d7e974271413a`. This evidence branch adds no production changes.

- `orbital-family-normal-phase12.png` and `orbital-family-normal-phase0.png`: original 1372 × 883 game framebuffer captures from actual `main.tscn` in an isolated synthetic QA fixture, saving disabled, four built facilities, visual time fixed at 12 and 0 seconds.
- `orbital-family-comparison-1to1.png`: main on the left, candidate on the right; original framebuffer crops pasted without resampling. Station uses time 0 (it is behind the planet at time 12); the other three use time 12. Each row compares the same time, runtime scale and orbital position.
- `orbital-readable-family-assets.zip`: all 16 changed asset/source/script/document files, retaining repository paths. `orbital-readable-family-text.patch` contains only text changes; binary changes are in the candidate branch and ZIP.
- `orbital-readable-family-report.txt`: exact scope, tests, native pixel sizes and baseline fixture failures. Library saving failed with a network error and returned no Library file IDs; these files are the readable Git fallback.

All screenshots show synthetic test gameplay only. No user save, username, account, private desktop content or original user screenshot is included. The evidence copies match the inspected local deliverables byte for byte.
