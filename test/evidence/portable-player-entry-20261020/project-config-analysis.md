# Player checkout `project.godot` analysis

Read-only comparison on 2026-10-20: accepted `main` `d2293ce9` versus the actual player's uncommitted `space-battleship/project.godot`. The file changed by 26 added / 10 removed lines, mostly Godot editor serialization. No original file or save was changed during this analysis.

| Setting | Accepted main | Player checkout | Runtime meaning with pinned Godot 4.7.2 |
| --- | --- | --- | --- |
| `animation/compatibility/default_parent_skeleton_in_mesh_instance_3d` | absent | `true` | **Material difference.** Godot 4.7 defaults to `false`; `true` preserves the pre-4.6 parent-skeleton behavior for `MeshInstance3D`. |
| `application/config/features` | `PackedStringArray("4.3", "GL Compatibility")` | `PackedStringArray("4.7", "GL Compatibility")` | Editor version feature tag advanced to 4.7. No game source reference to the version tag was found. |
| `display/window/stretch/aspect` | `"keep"` | absent | Same effective value: Godot 4.7 default is `"keep"`. |
| `visuals/enemy_player_min_gap` | `0.20` | `0.2` | Same number. |
| `visuals/enemy_scale_variance` | `Vector2(0.90,1.08)` | `Vector2(0.9, 1.08)` | Same two numbers. |

The editor also added its standard header and reordered sections/keys; other setting values are unchanged. The header, version tag, default omission, and compatibility setting are consistent with a newer Godot editor saving an older project. This is an inference from the file, not a recorded editor action.

Godot's [4.7 ProjectSettings reference](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html) states that the skeleton compatibility setting defaults to `false`, that `true` restores the older parent behavior, and that disabling it in an existing project can require upgrading scene files. The same reference gives `"keep"` as the stretch aspect default. A read-only scan parsed **all 65 tracked `.glb` files** in the project: none contains a glTF `skins` array or a node `skin` field. A tracked scene/resource search found no `Skeleton3D` or explicit `skeleton` assignment. `ship_body_baker.gd` explicitly rejects `Skeleton3D` and skinned `MeshInstance3D` assets from its static-mesh bake. Therefore no current asset dependency on this setting was found. A future skinned asset would require a separate configuration review.

## Unified configuration decision for this candidate

The local `true` compatibility setting is not required by the current project, so this candidate does **not** add it to the shared `project.godot`. All computers use the same committed project configuration. The dirty local file remains untouched and is isolated by the launcher when necessary. This does not assert that the setting has no possible effect on future models; it records the checked current resource inventory.

A pull simulation cloned accepted `main` `d2293ce9`, copied the actual player's dirty `project.godot` into that isolated clone, then fast-forwarded to candidate `fcd6d44a` without editing the config. The fast-forward succeeded, and the local config SHA-256 stayed `c9716e3eeb59e2ee5412549077b79f35cac9c96907a61c9c88e2fabb0154191a`. Launching the new `玩游戏.cmd` selected committed main in the managed mirror, imported assets, ran for 120 frames, and exited 0; the original clone's config hash remained unchanged. This verifies the local-entry handoff path without updating the actual player checkout.

## Comparison considered before main acceptance

1. Recognize only this local 4.7 editor migration and run directly from the original checkout. This is smaller in code and storage but runs a configuration not shared by all computers, so it does not meet the uniform-config requirement.
2. Retain the current committed-runtime mirror for uncommitted runtime changes. It uses the same accepted config on every computer and leaves the local file/save intact. Its cost is another full checkout and update logic; this cost is specifically for reconciling a semantically different local config with preservation, not for handling comments or number formatting.
3. Commit the compatibility setting into the shared project. Current assets provide no need for it, so this candidate does not make that config change. Reconsider if skinned content is later introduced.

Python/Godot download and verification, and installation of the matching bundled DLL, address separate missing or mismatched runtime dependencies. They do not depend on whether the local project file is accepted directly or isolated in a mirror.
