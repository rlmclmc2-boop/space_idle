# S12 transaction candidate: complete review object

Runtime `68205410956f555e021eb955095769e7a3896df5` on `impl/s12-transaction-integration`; audit branch contains this file, probes, and logs. Main remains `31e79337741bf9860d69fff21dae6be994dacd00`. S12/A07 remain open pending independent dot and original-astra PASS on this exact runtime and the final audit commit.

## Prior joint rejection and corrections

Both reviewers rejected runtime `42cc37c6d3470ab2e195df9c302de617a7402fa6` with evidence `79bead0bd6be8124eb94067141ccfc07b02ef3be`. That pair is historical, not an accepted baseline.

| Review failure | Correction in current runtime | Regression |
|---|---|---|
| Reactor level 140 with v3 uranium: x10 spent 67,584 more than ten singles | `reactor_exact_budget` recognizes v2/v3, so batch accumulation and debit use the same exact integer path | `review-failures-6820541.log`: x10 and ten singles have equal final wallet |
| Jewel furnace peak `1e308`, drop `{m:2,e:308}`: pickup erased before `float(amount)` failed | Validate and compute the jewel receipt before removing the drop; cashflow stages accept growth/sparse values, check the whole save, then credit and emit. Preview uses the same read-only earned calculation. Jewel furnace rolling peak and schema accept growth values and reload them. | Real furnace and natural jewel pickups, next furnace input, portable/disk validation and reload in `review-failures-6820541.log` |
| `refund_all_equipment` credited laser resources and emitted before armour material overflow failed | Aggregate every module quote, validate every resulting credit and the save, then commit the entire refund | Failure has identical profile/event list; successful aggregate equals individual refund totals in `review-failures-6820541.log` |
| MAX cached `-1` forever for ordinary `1e100` wallet; reactor restarted; x10 disabled during MAX | Persist per-signature equipment and reactor quote cursors. A call advances at most 512 levels or 40 ms and returns pending `-1`; the next call resumes. Equipment UI retries pending quotes; reactor UI retries MAX while x1 and x10 remain available for independent validation. Projected batch MAX also resumes before spending. | Ordinary MAX, projected MAX batch, reactor MAX and no-effect pending checks in `review-failures-6820541.log`; sparse case in `sparse-runtime-6820541.log` |
| 50,000-product cashflow threshold permanently refused valid input | Sparse multiplication computes at most 512 block products per call and retains the normalized partial sum plus pair cursor. Cashflow cache retains every pending job; completed entries alone are evicted, so simultaneous jobs cannot starve. Pickups/furnace retry without credit or drop removal while pending. | Independent 80×80 decimal multiplication oracle, nine concurrent jobs, actual pickup/furnace completion in `review-failures-6820541.log` and `sparse-runtime-6820541.log` |
| Native batch descriptor could be prepared despite a later single-purchase save-size rejection | Preflight the same per-slot projected debit and save predicate, then check the complete projected loadout/wallet. An unexpected slot failure prevents descriptor commit and hands off the old native owner. | Target Windows DLL, an unexpired 16 MiB `resourceSamples` fixture with `production_time`, rejection before purchase/event/handoff/descriptor in `native-6820541.log` |
| Linux parse error in `reactor_panel` and absent main-scene check | Explicitly type inferred UI values, materialize tracked assets/shaders omitted by sparse checkout, rebuild the pinned Windows DLL, then parse and start the main scene | `windows-editor-6820541.log`, `windows-main-6820541.log` exit 0 without script errors or missing native class |

Single high-level equipment quotes used a quadratic full-decimal power, taking 0.9 s at level 3873, 5.8 s at 10000, and exceeding a 30 s observation at 50000. For levels above 4000, the new path multiplies outward decimal bounds at increasing precision until both bounds imply the same rounded leading digits. This is exact relative to the S11 decimal-factor inputs: a result is returned only when every value between the lower and upper bounds rounds to the same price. Ambiguous boundaries fall back to the original exact algorithm. At more than 10,000 output zeroes, the exact rounded integer is represented as sparse v3 blocks; this is a representation choice, not a level or exponent ceiling. The direct purchase/debit, sum, refund, display and generator consumer accept that price. The old exact algorithm agreed in 8 independent cases; the billion-level quote returned in 26 ms and its real single purchase, exact debit identity and portable validation passed.

## Reproduction and limits

Windows Godot 4.7.2 console SHA256 `C8F0A6BC45A19B33541501E57F6F7CD972AB18453743266339D495CBBE846643`; newly built native DLL SHA256 `095FC9E31E31A095997BCD08251A77A89910267353CCEFF0759848BDB53B6EA1`. The DLL and local `.gdextension` descriptor were used only for validation and are not committed. Existing Godot processes held the old local DLL, so the matching new build was loaded from a distinct ignored `bin/` filename. The tracked asset directories were restored through Git sparse checkout for the main-scene run; generated `.import` changes were excluded from the runtime commit.

From the repository's `space-battleship` directory, run `D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://test/<probe>.gd` using the audit `probes/` copies as `test/` files. The Windows editor check uses `--headless --path . --editor --quit`; the main-scene check uses `--headless --path . --quit-after 120`. Their exit codes were zero. Godot printed sandbox-specific root CA and user log path errors, recorded verbatim; it printed no S12 script parse/load errors or missing `SpaceSaveLock` after the new DLL loaded.

| Probe and log basename | Outcome |
|---|---|
| `audit_s12_review_failures.gd` / `review-failures-6820541.log` | 40/40 |
| `audit_s12_quote_bounds.gd` / `quote-bounds-6820541.log` | 10/10, billion-level 26 ms |
| `audit_s12_transactions.gd` / `transactions-6820541.log` | 56/56 |
| `audit_s12_native.gd` / `native-6820541.log` | 40/40 |
| `audit_s12_sparse_runtime.gd` / `sparse-runtime-6820541.log` | 25/25 |
| `audit_s12_sparse_core.gd` / `sparse-core-6820541.log` | 3290/3290 |
| `audit_s12_consumer_probe.gd` / `consumers-6820541.log` | 0 failures; unsupported analysis numeric domain reports an explicit error |

The four user-authorized obsolete remote branches `s06/analyzer-deps`, `s07/reactor-cache`, `s08/config-recovery`, and `s10/reactor-numeric` were absent in a successful `git ls-remote --heads origin` check. `main`, the audit branch, and the S12 candidate branch remain. No main merge or next stage was started.

The local source checkout still has uncommitted generated `.import` files and ignored validation artifacts. The runtime commit contains only necessary scripts. All test sources, logs and this record are audit-only.
