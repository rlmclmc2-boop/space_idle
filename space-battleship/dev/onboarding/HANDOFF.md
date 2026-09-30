# Beginner guide prototype (unreviewed)

Branch: codex/beginner-onboarding; base d3dae74. No gameplay or save cadence changes.

Runnable checkpoint: optional state-driven guide, localized text, main UI setup hook, fresh/legacy save opt-in boundary. Equipment adapter supports existing panel and proposed semantic get_action_anchor API. Guide flags use normal profile persistence, never trigger a save.

Pending: focused fresh/legacy, already-equipped/upgraded, dismiss/reopen, insufficient-resource, modal/pause, moved-anchor checks; visual capture/review. Equipment integration is independent and must be checked once the equipment branch is applied. Do not merge into main before parent review.

Linux validation uses isolated test/work/onboarding/space-battleship and XDG directories under /tmp/onboarding-user. Native .blend authoring sources are excluded from that disposable copy because this environment has no configured Blender importer. Runtime GLB/assets remain present. Source worktree is not a player-save test environment.
