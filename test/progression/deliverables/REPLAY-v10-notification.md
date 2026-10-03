# v10 notification policy; numerical data unchanged from v22

Decode progression-v10-policy-increment.bundle.base64. Binary9039bytes SHA256 ece1149a15fe1af6605dc20d91e335cbd3021943328321207dc1983eaa046ed9. Prerequisite v22 source head971917f23cc4519de4ac4ee8f370e37b55bb0496; fetch progression-v22-source-increment.bundle first (after v21 source bundle). Newhead56aed23cbe7a5cf69b74ce0918e9d1dfbd3b94e1, ref refs/heads/evidence/v10-notification-policy. git bundle verify and git fetch /absolute/progression-v10-policy.bundle refs/heads/evidence/v10-notification-policy:refs/heads/qa-v10; git worktree add /tmp/qa-v10 qa-v10. Main unchanged.

```
python test/progression/build_qa.py --output /tmp/v10-core
python test/progression/run_entry.py --project /tmp/v10-core --entry res://qa/unlock_visit_batch.gd --label notification-queue-control
```

Root controlled3cases PASS: one actual visit legacy1 confirms Battleship only, leaves2 notifications/stage30; defaultv10 confirms3 separate native acknowledge calls, leaves0/stage31, no resources/jewels/time gained; synthetic40-validID safety queue acknowledges exactly32/leaves8/stage30. Each actual ack trace receives its own operation entry/count; aggregate trace preserved for compatibility. Formal game API still confirms one page, no future/off-visit auto-ack. Base autoplayer default1 unchanged; v10 drains at most32 before its normal visit actions. --single-unlock-per-visit keeps historical single-item ordering, older v9 frozen --policy-ref remains available. Existing live root and parent frozen runs remain old versions.

Parent independent7159/MAX900 observed clear30=54000.72, Battleship54790/crew55690/planet56590; forge71890,30→forge4.969h includes artificial notification delay. This is parent evidence, not root replay claim. New v10 actual30→34 preparation running separately; no corrected full-fresh result yet. Numerical calibration must not absorb this delay.

Wave diagnostic now has unique per-label output and optional PROGRESSION_WAVE_WEAPONS=mixed,laser,missile,cannon,longLaser. Root exact oldlegal35/profile into v22node1 all4win: mixed3.700/laser2.450/missile4.050/cannon7.317/beam4.617s. Only diagnostic elite1 and tool-isolation validation, not regionBoss60s or fullchain acceptance. Numerical datasha600bdb8c8fef41bdb8da2a671f88d4acf2ed749cef65799c5bf86c006820dfd7.
