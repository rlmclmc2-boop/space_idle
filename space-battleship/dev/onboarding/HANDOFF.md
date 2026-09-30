# Beginner guide prototype (unreviewed)

Branch: codex/beginner-onboarding; base d3dae74. No gameplay or save cadence changes.

Runnable checkpoint: optional state-driven guide, localized text, main UI setup hook, fresh/legacy save opt-in boundary. Equipment adapter supports existing panel and proposed semantic get_action_anchor API. Guide flags use normal profile persistence, never trigger a save.

Verified: focused fresh/legacy, already-equipped/upgraded, dismiss/reopen, insufficient-resource, modal/pause, moved-anchor checks (28 assertions). Four GUI captures reviewed; reopened guide button moved off health HUD. Final GUI captures reviewed: no guide/HUD or unlock-button overlap. The same 28 checks pass with the updated equipment components copied into the disposable fixture. Pending: parent visual review and authorized branch publication. Equipment integration is independent and must be checked once the equipment branch is applied. Do not merge into main before parent review.

Linux validation uses isolated test/work/onboarding/space-battleship and XDG directories under /tmp/onboarding-user. Native .blend authoring sources are excluded from that disposable copy because this environment has no configured Blender importer. Runtime GLB/assets remain present. Source worktree is not a player-save test environment.

Evidence: test/work/onboarding/evidence-final/{01-intro,02-free-equip,03-resources,04-unlock,05-dismissed}.png. This is a focused guide check, not full game QA; fixtures drive actions through signals/state rather than physical mouse clicks. Runtime audio falls back to dummy on this cloud desktop. Headless shutdown reports the existing one-resource leak warning; no onboarding script or localization errors.
