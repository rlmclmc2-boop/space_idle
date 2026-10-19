# Fifteen-cell display layout

Ordinary1×1, elite(size≥4)2×2, persisted encounter leader/BOSS3×2. Existing eight static hulls retain their source aspect. Display-only packing is shared by Main and the simulation geometry owner; game actor coordinates, source tables and numeric widths remain intact. Cell assignments survive actor death and ownership handoff. No new elite/BOSS artwork is added.

The measured maximum own hull `Heavy_Battleship` has all five weapons; its actual opaque hull/weapon planes and complete visible shield envelope begin atY605.436. Testing every turret at−85/0/+85° does not bring the envelope farther forward. The old enemy band ending499.2 left106.236units; the new band ends400, retaining205.436units, above the existing192-unit configured gap. The key image is `boss-front.png` (actual nearest visual-envelope gap217.436units; its enlarged BOSS ends atY388): BOSS occupies the frontmost two rows, with escorts outside its3×2 reservation, and both fleets' full hulls/health/shield displays remain visible.

| Footprint | Allocated size (logical) | Hull/protection interior maximum |
|---|---:|---:|
| Ordinary1×1 |114.4×133.333|90.4×79.333|
| Elite2×2 |228.8×266.667|204.8×212.667|
| BOSS3×2 |343.2×266.667|319.2×194.667|

Side/bottom insets are12. Ordinary/elite top inset42 reserves meters/status/gap; BOSS top inset60 also reserves its title. Bodies fit by a single uniform factor including actual idle rotation; protection is scaled only in drawing, without changing its numerical packet. First-row entry travel is capped so meters/title cannot slide outside the top edge. Yellow rectangles in QA captures mark actual assigned cells; the grid/ruler is test-only.

Important source-data limit: some existing groups require more than15cells (e.g. group1009 has15actors including two2×2 elites, requiring21cells). Such groups retain their entire previous layout atomically. No actors are hidden/dropped and approved footprints are not silently shrunk. The source audit lists these encounters; additional-row/other overflow policy remains unresolved. These fallback groups do not satisfy the new cell/clearance acceptance; the400-band and192-gap guarantees apply only to successfully packed groups. This candidate is not merged into main.

Captures run actual `main.tscn` with save-disabled held-health QA actors and in-memory tier flags. They demonstrate real attacks/hits and rendering, not natural encounter balance. Local Godot4.6.3 Linux/OpenGL llvmpipe/GDS path; no physical-GPU or shipping Windows/native performance acceptance is claimed. The boundary checks additionally publish/consume the simulation geometry frame to verify both display paths use the same allocation and sizing.

Validation: `test/test_enemy_grid_layout.gd` has a `GRID_CASE=unit` mode (1330 checks, zero failures), and four graphical cases `ordinary`, `elite`, `boss-top`, `boss-front` (581 boundary/frame/centre checks, zero failures). All images are original1952×1256 window renders. `summary.json` links their fire/hit counts, gap and alpha-centre results. Maximum alpha-centre error is0.00000853units. The front-BOSS image distinguishes the conservative area reservation205.436 from the actual nearest complete-envelope gap217.436.

`numeric-preservation.json` verifies byte-identical data, eight sprites, eight geometry sources, Game/kernel and unchanged numerical width functions againstca239dd3. `source-group-audit.json` audits2330 source groups:2142 fit,188 require over15cells and keep the full old layout (187 elite-tier,1 normal-tier). Legacy groups without explicit tier are audited without final-checkpoint promotion. `test/audit_enemy_grid_groups.gd` regenerates this read-only audit. No overflow policy has been assumed beyond the conservative fallback.

Replay in an isolated imported project: copy the two `test/*enemy_grid*.gd` files to the project root; provide `GRID_OUTPUT=<evidence folder>`, isolated XDG directories, and run the layout script with `GRID_CASE=unit` headlessly or each of the four case names graphically. The fixture changes QA actors and the selected group's tier flag only in RAM; production tables are never written. Grid outlines and clearance labels exist only in the QA script.
