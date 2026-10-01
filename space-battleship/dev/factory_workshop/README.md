# Factory workshop layout trial

Based on `32991cc`. This is an opt-in, playable page proposal; the production page builder in `main.gd` is unchanged.

- Canvas: 1344×1160 logical pixels, inside the current 1364×1200 workspace. At the existing 0.875 scale the capture is 1176×1015. Main work cell 854×730; independent-project list 418×730; focused controls 1296×190.
- One selected machine is animated. Other projects retain their real AI counts and progress in the list; selection does not move AI or imply production dependencies. Locked projects expose no identity. The factory room is static opaque 2D geometry, with no added SubViewport, particle system or frame-by-frame control rebuilding.
- Research, generation, assignment and distribution call `BattleGame` unchanged. Existing 23-stage maps and approved iron artwork remain in use. The three other PNGs are reused from `de58f61`; their provenance is in `assets/hightech/machines/README.md`.
- Run `python test/run.py test_factory_workshop.gd --godot <engine>`. It creates an isolated project and disables saves. Within that isolated project, run the copied test with `-- --play` for live interaction or `-- --record` for a labeled 12-second video at 4× simulated time. Recording advances actual research, including completion and the next level; it does not set progress per frame.

For production adoption, `workshop.gd.setup(game)` is the new page entry. Its game-event listener and local refresh own the page. The old page's build/slot-sync/scientist-refresh/research-card refresh hooks in `main.gd` must be routed to this owner together; do not overlay it on the still-running old factory. Retain the existing tab unlock/visibility and page scale. That narrow integration is intentionally deferred until layout feedback and the independent performance budget are available.

This trial verifies rendering scope, reuse, allocation input and research progression; it is not a claim about whole-game frame rate on the user's machine.
