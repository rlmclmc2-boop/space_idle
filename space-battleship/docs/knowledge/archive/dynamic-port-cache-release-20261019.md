# Formal player release closure — 2026-10-19

Scope: register the reviewed d07f0b9 cache delivery in the actual player bundle and native acceptance inventory; retain source, engine, descriptor and exact DLL checks. No gameplay or art changes, no additional performance campaign, no main merge.

Formal DLL SHA-256: 137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78. Source and compiler-input hashes are separately recorded in evidence/new-hull-hardpoints/native-validation-hashes.json. The C++ source remains the reviewed 6e8d2ed9 version. Prior cache correctness and performance evidence remains test/evidence/dynamic-port-cache-win472-20261019/.

The launcher source anchor must include this inventory, archive and bundled DLL registration. Parent integration must preserve its ancestry. All player paths resolve from the launcher checkout. A generated DLL at the exact installation target is allowed in source scanning but still requires its full accepted SHA-256; other untracked DLLs remain rejected. Explicit installation preserves a mismatching previous DLL by hash.

Direct entry checks: 17 unit checks passed before source registration. Isolated relocation, old-library upgrade and short-window startup results are recorded in test/evidence/dynamic-port-cache-player-release-20261019/release.json at repository root. That record is authoritative for actual startup outcome. Historical acceptance files are retained unchanged.
