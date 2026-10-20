# Selected independent rotating emitter appearance

Final source: art_sources/enemy-fleet-20261019/approved-emitter-20261020.png, identical to selected51aae1ac and candidate707981f3. Prompt intent: short paired segmented steel rails/recessed aperture, bright white side support armor, burgundy couplers, one small amber indicator; compact body without cylindrical tank barrel or decorative light strips. No stationary base in this sprite.

prepare_ranked_assets.py performs alpha isolation/crop/uniform resize/180° conversion to down-forward320×640 RGBA. manifest.json contains converted pivot/aperture pixels, true housing width and exact final per-case/slot coverage from ranked-import.json. The coverage targets95% of the outer bearing with the approved per-mount hull clamp, not the smallest dark-well diameter.

Only the dormant interface and original isolated QA renderer consume the new per-mount plan. The showcase copies component presentation profiles in memory for aperture alignment, including retained body metadata. Production weapon type, numeric damage/CD/equipment, source weapon profiles, formation and centre-hit rules are unchanged. Normal/elite/BOSS1/2/4 remains an unapplied interface.

Evidence and exact release scope: evidence/em-turret-integration-20261020/README.md and RELEASE_SCOPE.md.
