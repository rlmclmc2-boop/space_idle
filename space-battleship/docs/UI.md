# UI: refresh/render/input
- View: 2048x1280 logical aspect-preserving scale; narrow windows letterbox.
- Screen: left battlefield, middle nav, right workspace. Unlock notice centered in left battlefield; never masks right workspace.
- Before edit map event -> changed data -> dependent controls/draw layers; use slot/key to constrain scope. Shared parent/tab is not a dependency.
- Local change: reuse control, write changed properties only. NO build_ui/scene reload/subtree rebuild. Structural change: smallest region; reorder by moving existing controls. Preserve unrelated instances, focus, draft, tab, scroll, active drag node.
- Full build only init/explicit reset/cfg reload or other global invalidation; explain why. Never fallback for failed refresh.
- Static vs animated layers separate. NO per-frame root/shared-ancestor queue_redraw. Hidden pages stop frame updates; reveal catches up. Pause+no change -> no property write/redraw.
- Refresh reads business state only; no copied authoritative state or mutation. UI snapshot requires control owner, dep keys, invalidation, release. No global refresh/cache framework to hide broad scope.
- Gem center: click candidate=preview; double-click=current empty socket else first unlocked empty socket in module, never overwrite. Explicit button=socket/replace. Full bag allows equal-size replacement; unsocket needs space. Installed socket button shows icon+level; full name/effect in hover/detail.
- VERIFY target+related feedback, unrelated instance/write/redraw unchanged. By risk cover hidden/reveal, pause, focus, scroll, drag; measure property writes, rebuilds, CanvasItem redraws separately. Report refresh scope.
