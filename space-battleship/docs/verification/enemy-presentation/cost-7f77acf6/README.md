# Enemy presentation hot-path cost comparison

Code revisions: baseline `b29e442ef8ce5bf3d93e3c4346dd898f2d694308`, original
candidate `7f77acf6cffd5b1a11b147a8d38dafea3424ccb8`, revised candidate
`f4ccf4cacca2e064f84670a3e772385db7da440f`. This evidence commit does not change
production code. Main has not been merged.

## Finding and correction

The original candidate has a material hot-path regression. The pilot pair showed
+17.40% to +19.08% median elapsed time. Its wire/ratio projection occurred during
each effective hit/recovery, including repeated changes before the next snapshot.

The revision keeps the existing dirty collection, with hp/shield field bits in
its entries. Hits and recovery only mark those bits. `enemy_views()` coalesces
each dirty field into one projection of the final already accepted typed Amount
when a snapshot is requested. Death-only invalidation has zero health bits, so it
does not reformat amounts. There is no new event stream, version layer, lifecycle
identity, admission validation, RunState failure path or simulation in the read.
Static maximum text, geometry and birth identity remain unchanged.

Formal three-way results (median of three trials, milliseconds; positive = slower):

| Fixed workload | Baseline ms | Original ms | Revised ms | Original vs baseline | Revised vs baseline |
|---|---:|---:|---:|---:|---:|
| loss-hidden | 1305.758 | 1500.445 | 1310.672 | +14.91% | +0.38% |
| loss-visible | 1251.723 | 1462.756 | 1350.635 | +16.86% | +7.90% |
| recovery-hidden | 1287.351 | 1492.030 | 1268.972 | +15.90% | -1.43% |
| recovery-visible | 1290.643 | 1508.133 | 1328.082 | +16.85% | +2.90% |

All 36 runs matched their scenario's attack history, damage by source, hp/dead
facts, simulation clock and persistent-state hash exactly. Each timed sample
advances 2000 times by 0.05 seconds and executes 80008 player attacks. Initialization,
a separate 100-step warmup and final readback are excluded from timing. Variants
alternate order within each trial. No process-frame await, FPS limit, rendering
or UI loop participates.

The hidden-read results isolate the remaining native simulation hot path: revised
medians are +0.38% and -1.43% versus baseline, within the spread of these samples.
This is not a claim of a statistically proven speedup or zero overhead. Visible
reads still cost +7.90% and +2.90% in the measured end-to-end native loop. Baseline
does not publish/invalidate shield fields; these visible reads are not feature-
equivalent. The remaining difference must stay visible in review rather than be
described as fully eliminated. Battle/GDScript presentation assembly and full UI
performance are outside this comparison.

## Evidence

- [benchmark.gd](benchmark.gd): the executed fixed workload, derived from the
  existing controlled descriptor probe with three actors and eight cannon sources.
- [run_cost.py](run_cost.py): executed alternating-run orchestration and equality checks.
- [build_variant.py](build_variant.py): executed baseline/revised incremental build helper.
- [comparison-samples.json](comparison-samples.json) and
  [comparison-summary.json](comparison-summary.json): all formal samples and medians.
- [raw/](raw/): original stdout for each of the 36 formal runs; each is checked
  byte-for-byte against the recorded JSON result during archival.
- [pilot-samples.json](pilot-samples.json) and [pilot-summary.json](pilot-summary.json):
  initial two-way discovery results. Their per-run stdout was overwritten by the
  formal run filenames; no reconstructed raw pilot logs are asserted.
- [baseline-build.log](baseline-build.log), [revised-build.log](revised-build.log)
  and corresponding build JSON: actual successful incremental compilation records.
- [revised-correctness.log](revised-correctness.log): rerun of the unchanged
  [44-check probe](../7f77acf6/probe.gd), `PROBE_FAILURES=0`, exit 0.
- [manifest.json](manifest.json): exact revisions, source/DLL/archive hashes,
  pinned tools, load shape, ordering, equivalence checks and limitations.

The original candidate DLL was copied from the previous verified build before
building baseline. Baseline and revision used the same existing temporary build
directory and binding library; only that build copy's kernel header was replaced.
No new workspace, checkout or independent testing thread was created. The existing
uncommitted `.uid/.import` files were not deleted or staged.

## Independent reproduction

Use the pinned dependencies in [the prior manifest](../7f77acf6/manifest.json) and
[foundation build instructions](../../../../foundation/README.md). The archived
helpers retain the actual machine paths used for this run. For another machine,
adapt only their repo/build/output/tool paths and the benchmark script path.
The workload, step count, ordering and timing loop must remain unchanged.

1. Build the native extension once using the normal build script to populate a
   single temporary `native-stable` directory and its binding library.
2. For each revision in `manifest.json`, use `git show REV:space-battleship/addons/native_battle/src/combat_execution_kernel.h`
   to replace only the build-copy header, not the working source. Invoke SCons
   with the identical arguments recorded in the build JSON. Preserve each DLL
   as `baseline.dll`, `candidate.dll`, or `revised.dll`, with a corresponding
   `.gdextension` file pointing to it. The archived build helper demonstrates
   the exact commands; its `baseline` mode extracts baseline and its other mode
   uses the current working header. Rebuilding original `candidate` therefore
   requires extracting the original 7f77acf6 header explicitly.
3. Point the archived run helper's constants to those manifests and `benchmark.gd`,
   then run `python run_cost.py baseline candidate revised`. It records all 36
   stdout files, samples, medians and exact simulation-fact equality assertions.
   Keep new results separate from this archive.

A direct individual run, with the desired DLL manifest selected, is:

```powershell
$env:SPACE_IDLE_NATIVE_EXTENSION = '<variant>.gdextension'
& $env:SPACE_IDLE_GODOT --headless --path '<repo>/space-battleship' --log-file '<new-run>.log' --script '<archive>/benchmark.gd' -- 1.0 visible
```

Use recovery `0.0` or `1.0`, and `hidden` or `visible`. Expect `COST_JSON=...`,
exit 0, 2000 measured steps and 80008 attacks. No baseline shield output is
silently invented for the equality check; shared simulation evidence is compared.
