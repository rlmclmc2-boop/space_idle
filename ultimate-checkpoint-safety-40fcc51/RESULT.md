# Paid-state checkpoint safety closeout

Source commit `40fcc51a8b20aa51f2cc683eda6b57490d685e70`, branch review/hyperspace-crew-reservation-ultimate-chain, QA only. Two source files changed: main CP atomic write now precedes every optional archive; main write failure retains both pending lists and stops before archival. Ultimate archive names include round, stable SHA256 drone identity prefix, committed sequence and operation. Archive failure remains explicit, retains pending in memory and cannot precede fresh primary paid state. Existing write-once file is never overwritten.

15 targeted persistence checks passed: real completed paid-chain source; round reset/same sequence uniqueness; drone identity uniqueness; real occupied archive collision; unchanged original archive; primary valid with original three paid receipts and balances; missing archive parent failure still leaves valid fresh primary and backup; primary write failure reports and preserves intent; actual source CP unchanged. Synthetic conditions apply only inside isolated persistence fixture: alternate round/name and deliberately occupied/missing paths. No new ticks, business payments, resource/record injection, or campaign continuation. Not a full longrun/recovery campaign. No repeat of parent verified25 chain or whole funding segment.

Isolated project own import completed,892 files, canonical fingerprint `86d2c0e12b27530b80bb473800896a78416541ffb95f630b9ccb7331817f3670`. Test ran identical files before commit with working manifest (included); final manifest changes only source_commit/dirty metadata. Test source is actual committed step27 CP SHA `482bd90bfc2dac0ad50439f3797a60639397f8edb4c51f8aee8302a79a04b5e9`; all effects confined to new fixture output directory.

Run after building/importing exact frozen project:
```
QA_ULTIMATE_PAID_SOURCE=/absolute/path/real-paid-step27-source.bin QA_CHECKPOINT_FIXTURE_OUTPUT=/absolute/path/new-nonexistent-fixture-directory godot --headless --path /absolute/path/project --script res://qa/test_ultimate_checkpoint_safety.gd
```
Use writable XDG directories. Preserve failed cases and raw artifacts. The full actual chain ran on old1f12 before review warning arrived; original three25/26/27 archives succeeded and are retained in preceding paid-chain evidence. This patch verifies collision/failure persistence separately, not through repeating natural preparation.

Disk cleanup receipts cover only own completed projects' `.godot` caches and their now-invalid import markers. Raw logs/source retained. Reimport required before using those old projects again. New import inputs were restored and every frozen source file checked. Initial build helper displayed a noncanonical compact-JSON fingerprint while preparing; canonical default-JSON sorted-files formula was corrected before fixture run and freeze. No CP was accepted under that preliminary digest.
