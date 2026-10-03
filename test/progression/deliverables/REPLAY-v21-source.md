# v21 source calibration transport

Download progression-v21-source.bundle.base64 in this directory and base64-decode. Binary494776bytes, SHA256a952a1dd2ab407c78087dbe98806604c767740df17dabaaf462affa2a4a96a93. git bundle verify requires7159cf3e1df6550d9b1af7776aabebd7f9d1b0eb. Fetch refs/heads/evidence/v21-calibration-source from the bundle into a new local ref/worktree. Exact sourceSHA52af7167ce2402de76d2f398a2ba6071248081bf.

```bash
curl -fL https://raw.githubusercontent.com/rlmclmc2-boop/space_idle/evidence/progression-handoff-7159cf3/test/progression/deliverables/progression-v21-source.bundle.base64 | base64 -d > /tmp/v21-source.bundle
sha256sum /tmp/v21-source.bundle
git bundle verify /tmp/v21-source.bundle
git fetch /tmp/v21-source.bundle refs/heads/evidence/v21-calibration-source:refs/remotes/qa-handoff/v21-source
git worktree add /tmp/space-idle-v21 refs/remotes/qa-handoff/v21-source
cd /tmp/space-idle-v21
python test/progression/validate_source.py
```

See test/progression/REPLAY-v21.md for exact engine, commands and controlled input fixtures. Source-only transport intentionally excludes large new operation archives; complete negatives and actual traces remain in root candidate historyd1e0145 and preceding completed-evidence commits. No old failure deleted. This is pending numerical calibration, not a new accepted frozen whole-game candidate. Parent7159 full fresh remains independent/frozen. Main untouched.

v21 normal importer/protected543 pass. Changes209level rows (income11–220 plus33/35andfutureenemy dependencies),25generatedregionBossrows health/damage; groups/galaxy unchanged. OrdinaryBoss35:6 beam29.367s already matches30; region35:9 beam107.483s FAIL60, so region HP.2→.11 anddamage×1.8 are independent hypothesis. First33growth78→70 addresses observedelite6wall;11–20income6.7→6.5 is mild stabilization across separate300s/+10 vs900s/MAX strategies. No attempt to micro-optimize~66s near4hfirstforge; approximate4h is accepted forv20segmenttime, wave/fullfresh stillpending.
