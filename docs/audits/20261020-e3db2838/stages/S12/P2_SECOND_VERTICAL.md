# P2 second vertical WIP — incomplete, no runtime verdict

Authority: [P2 plan](P2_INTEGRATION_PLAN.md), [wiring contract](P2_WIRING_PREREQUISITES.md), and the [unique entry](../../IMPLEMENTATION_PLAN.md). Main remains `31e79337741bf9860d69fff21dae6be994dacd00`.

Runtime branch `s12/p2-integration` now contains `15e9f764c7c14d30ff81004092c09a75caaef814`, tree `6c1cbe1e4021766967cce7686f385d70234b4c71`. Local checkpoint `35533838ad7b04940d46ed0be6ed96fc32e3309e` has the identical tree. The remote commit uses the first remote WIP as its parent; no force push, main merge, or approval is implied. The interrupted connector tree upload did not produce this tree; the ref was subsequently advanced by ordinary Git push after readback confirmed the old head and absent tree.

## Connected paths and exploratory checks

The second WIP migrates equipment MAX wrappers, equipment cards/inspector/confirmation, sequential batch planning, crew pending receipts and aggregate native prediction together. Prices retain a fixed request budget while current income continues. Confirmation consumes the displayed content against a fresh current-wallet ticket. Ordinary x1/x10 remain synchronous. Native prediction consumes the completed plan rather than running another MAX. Failed late transfer keeps the purchased prefix and blocks the old kernel from advancing. Resource display, analysis projection and the synthetic loadout generator use the narrow resource boundary. No global GrowthNumber or C++/DLL change was made.

The following development receipts are under `p2_validation/evidence/`; they are **exploratory**, not a final same-byte certification. Current probe sources are archived alongside them. The Game runner hashes materialized scripts, but these early receipts do not pin probe hashes. UI measurements preceded the final native prefix guard change; they cannot alone validate this checkpoint's entire tree.

| Run | Actual result and limits |
|---|---|
| `game-1792644292810484900` | Headless real main.tscn equipment UI: 8 checks passed; pending under continuous income, confirmation without early debit, exact displayed fee charged, clean shutdown. Missing GLBs were imported first in the isolated project. |
| `game-1792644322223173900` | Real GPU main.tscn, NVIDIA RTX 2060/OpenGL 3.3, 9 checks passed. Screenshot `p2-ui-max.png` shows approximate count, 12%/integer-tail and refund warning, full mathematical fee, and confirmation. |
| `game-1792644386329492700` | Real pinned DLL: 25 checks passed; ordinary/MAX aggregate install, exact descriptor, native save lock and CW1 disk reload, late handoff failure/prefix/old-kernel block, semantic save-preflight refusal before live/native effects. |
| `game-1792644453945039300` | **FAIL retained**: full save accepted material int `9007199254740993`, disk token was exact, subsequent semantic read rejected it. No claim of high-material support. |
| `game-1792644598853296200` | Normal material value 1000: 26 checks passed; ordinary/portable/candidate validation, real import/rollback and old-live backup, complete-backup selection, invalid import preserving primary, actual crew MAX scheduler with continuous income and one final receipt, finite/out-of-domain projection and exact generator budget. This intentionally does not close the high-material failure. |

All runs used isolated APPDATA/LOCALAPPDATA. No personal save, credential, cache or synthetic save payload is included. Pinned DLL SHA256 is `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f`; engine SHA256 remains `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`.

## Exact remaining scope request

High-material input: `profile.hyperspace.materials.degenerate_matter = 9007199254740993` as a Godot int. `save_progress()` returned OK and wrote that exact JSON token. `ProgressWriter.read_progress_result -> _check_progress_file -> SaveTransfer.prepare_disk_data -> prepare_data -> HyperspaceState.valid:72 -> HyperspaceConfig.integer -> number` then rejected it because `number` requires absolute value below `9e15`. Both SaveTransfer and Game load call this validator; token/schema changes alone cannot satisfy the approved nonnegative-int64 material contract.

Requested minimum whitelist addition: `space-battleship/scripts/hyperspace_state.gd`, only the material-balance check inside `valid()`, replacing `C.integer` there with `CurrencyStorage.valid_int64`. Other fields, material exchange/reward policy, and formulas remain outside this request. This file is **unchanged pending parent and existing astra review**. The proposed check preserves the plan's material int64 domain; rejection safety is not capability PASS.

## Open work

The four-class ten-cold-process matrix completed 40/40 at `p2_validation/evidence/cold-1792651156512517400/`; `freeze.json` was written before the first process and pins exact Git script bytes of this WIP, inputs, probe and engine hashes. Every process has independent APPDATA/LOCALAPPDATA, stdout/stderr and a receipt. Its query timings include request preparation, Game dependency checks, pumping/polling and cancellation in each frame, while one real credit continues per frame. Maximum aggregate query-frame work was 338 us, heartbeat 18494 us, and cancellation request to actual worker stop 28844 us, against 4000/50000/100000 us. Maximum measured query completion: exact256 101488 us, middle 1051221 us, far 2867681 us; cancellation terminal observation 367850 us. Total time is report-only. Far count was 848867438 and middle count 47959.

This single-slot query matrix does not include final UI frequency, multi-slot aggregate preparation/commit, full load/save/portable RSS or active combined income/research/drop/autosave measurements. It does not close historical full-public-ledger/10000-block failures. These remain open, as do the high-material validator correction and unproved host-level/large-refund boundaries. No local result closes P2/S12/A07. Final runtime/evidence must be frozen again and receive same-object dual review before parent integration.

Recovery note: after turn interruption the runtime workspace was clean at the local checkpoint. Process command-line enumeration via Win32_Process was denied; no alternate enumeration or unknown-process termination was attempted. No currently held test session was inferred from that failed command. Historical logs and failure files were preserved.
