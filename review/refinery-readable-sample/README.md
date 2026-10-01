# Refinery readability sample

Review evidence for sample commit `81ce45fa6a9fe6b2f4a40261840272f27b377e23` on `art/refinery-readable-sample`. This evidence branch adds no production changes.

- `after-normal.png`: existing 1372 × 883 game framebuffer capture of the sample in `main.tscn`, using an isolated synthetic QA fixture with saving disabled, four built facilities, and visual time fixed at 12 seconds.
- `comparison-1to1.png`: baseline on the left and sample on the right. Each 65 × 65 game framebuffer crop is pasted at its original size, without resampling.

Both images show synthetic test gameplay only. They contain no user save data, usernames, accounts, private desktop content, or original user screenshots. These are the existing captures; no new rendering was performed for this evidence branch.

The refinery cell remains 48.77 screen pixels wide in both captures. The visible refinery footprint changes from approximately 33 × 21 to 28 × 22 pixels. The sample simplifies the refinery into broad tanks and a pump body while keeping its existing runtime scale, orbit, click target, Facility/Motion transforms, and animation ownership.
