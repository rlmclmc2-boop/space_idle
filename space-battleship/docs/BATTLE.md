# BATTLE: weapon/buff/gem integration
SRC: authorized tables/user-approved exceptions. Stable battle behavior: PROJECT.
- New/changed attack -> trace public fire/damage path; reuse attack trigger -> shared modifiers -> damage -> hit/kill triggers. NO per-weapon effect copies or bypass for timing/target/visual differences.
- Check double/additional shot, crit, damage bonus, CD, gem, buff, affix, hit/kill effects. For beam/charge/AOE define attack vs hit boundary, modifier timing, count, source. Cover charge, periodic hit, interruption, retarget, kill; no missed/duplicate/recursive triggers.
- VERIFY affected attack-type × common-effect combinations, including old weapons; record applies/excluded + evidence. Single-weapon pass != compatibility.
- Unsupported effect requires table/user approval; record scope/behavior in PROJECT, add validation/player notice if needed. Missing impl != unsupported rule; unresolved -> STATUS.

- Contact centre (2026-10-19): both fleets aim/hit at the fixed ship centre. Texture outlines are display-only; straight-shot numerical tolerance is +/-0.5 presentation units. Keep live PNG centre, projectile endpoint and settlement aligned.
