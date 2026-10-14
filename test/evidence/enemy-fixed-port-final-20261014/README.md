# Committed fixed-beam outlet semantics

Follow-up to c52334c0. A shot already marked fixed_enemy_port selects enemy_fixed_ports.launch_position directly in both active geometry providers and visual muzzle lookup, independent of current encounter tier. No configuration-system changes, kernel rebuild or new rotation fallback. Ordinary unmarked births still select by current encounter; existing Boss births remain unchanged.

The existing retained-native test now changes tier to Boss while a transferred hostile beam source remains alive, checks validity and unchanged logical/visible origin, checks no Main enemy aim calls, then checks numeric provider/publication agreement and no numeric enemy aim calls. Tier is restored afterward. Result: **188 checks, 0 failures, exit 0**, graphical Godot 4.7.2 with the same accepted DLL and isolated fixed-port-user directories. No broad suite rerun.
