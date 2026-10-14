# Ordinary enemy omnidirectional ports

Base: `e7cc31e026fd390b24daa188256ee7f5f33a67e9` (accepted main). Scope: supported ordinary enemy gun/energy turret presentation only. Bosses, leaders and unsupported components retain the original painter. Player and native kernel are unchanged.

`retained_enemy_contacts.gd` removes MountRecord/build_weapon and the per-component aim lookup, aimed transforms and weapon body/stroke submissions. DisplayRecord owns immutable port descriptors compiled from authoritative component hardpoints. Two retained port layers rebuild on width/screen-scale changes; descriptors invalidate with existing shape/source/appearance changes. Hull position/angle still follows the authoritative body. Health, shield, entry, death, identity replacement and membership handling remain.

Logical component poses, muzzle coordinates, collisions, firing, damage and projectile simulation remain owned by existing geometry authority/native kernel. The static disk covers the full logical muzzle sweep plus one physical pixel; no muzzle is moved. Six existing hull PNGs are reused. New SVG source/provenance is documented beside the assets.

Validation: graphical `test/test_retained_native_display.gd`, isolated APPDATA/LOCALAPPDATA under test/work/enemy-port-user, Godot 4.7.2 OpenGL compatibility / RTX 2060. Final: **86 checks, 0 failures**, exit 0. Includes authoritative muzzle opaque-pixel coverage and bounded aim-sweep coverage, stable port commands/transforms, RNG/kernel non-advancement on render, shield/scale/handoff/identity/death/reset and Boss fallback. The original two native-display fixtures remain; six-size gallery uses configured cannon-mon and laser_mon IDs.

First run: 71 checks / 1 failure caused by a test counter baseline crossing an intentional renderer toggle; fixed by taking the baseline immediately before shield mutation. Initial log retained. Gallery's unconfigured cannon_mon spelling corrected to cannon-mon; production aliases unchanged.

Screenshots: ordinary-six-ports.png (all six hull sizes, both emitter styles), boss-original-painter.png (fallback unchanged), retained-native-on.png and retained-native-direct.png (native fixture). Frames are paused correctness fixtures, not performance samples. No performance rerun; net frame savings unknown. Existing accepted native DLL reused, SHA256 `45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e`; no rebuild.

Remaining work: normal unsupported classes and leader/Boss rendering still use existing dynamic painter; logical aim remains necessary. No claim of eliminating entire enemy sync or meeting a frame-time threshold.
