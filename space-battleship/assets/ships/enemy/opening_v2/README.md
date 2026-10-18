# Opening enemy hulls, second set

These eight transparent top-down hulls were created in the prior art pass on
`art/playtest-ui-fixes-20261017@59df4250`. This branch reuses the original PNG
files without editing their pixels. `scout`, `sentry`, `interceptor`, `swarm`,
`anchor`, `reactive`, `shielded`, and `command` each have a separate silhouette.

The `enemy_visual_identity.gd` lookup selects a hull by encounter archetype;
`ship_weapon_visuals.json` supplies its weapon sockets. All files retain the
original transparent canvas and top-down bow-up orientation. Visual tint is
applied only by the battlefield renderer.
