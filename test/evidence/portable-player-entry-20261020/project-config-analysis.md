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

Godot's [4.7 ProjectSettings reference](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html) states that the skeleton compatibility setting defaults to `false`, that `true` restores the older parent behavior, and that disabling it in an existing project can require upgrading scene files. The same reference gives `"keep"` as the stretch aspect default. A read-only scan parsed all 50 checked-out `.glb` files under `space-battleship/assets`: none contains a glTF `skins` array. A tracked scene/resource search found no `Skeleton3D` or explicit `skeleton` assignment. Therefore no current asset dependency on this setting was found, but future skinned assets could be affected.

## Options before main acceptance

1. **Smallest launcher change for this checkout:** Recognize only this reviewed 4.7 editor migration in `project.godot` and run directly from the original checkout. Preserve the file byte-for-byte; reject any other project setting or runtime source edit. This removes the full Git mirror and its update/reset logic. Acceptance of the `true` compatibility setting is a configuration decision because it differs from the pinned 4.7 default.
2. **Keep committed-runtime isolation:** Retain the current mirror for uncommitted runtime changes. It launches successfully and protects the original file/save, but uses the committed config without the player's `true` compatibility setting. It also stores another full project checkout and maintains it across updates. This isolation is not necessary to handle mere formatting and numeric normalization; its relevant purpose here is the skeleton compatibility difference.
3. **Review a 4.7 config migration as a separate game change:** Commit an approved compatibility setting into main, then accept formatting-only editor rewrites in the launcher. This still requires an explicit configuration review and does not justify silently replacing the player's file.

Python/Godot download and verification, and installation of the matching bundled DLL, address separate missing or mismatched runtime dependencies. They do not depend on whether the local project file is accepted directly or isolated in a mirror.
