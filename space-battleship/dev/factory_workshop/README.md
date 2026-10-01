# Factory workshop preview

The production page is `scripts/hightech_workshop.gd`, constructed by the normal main scene. It owns visible refresh and uses the existing game methods for research, AI and costs. The room and local welding renderer live beside it. Asset provenance: `assets/hightech/machines/README.md`.

Run `python test/run.py test_factory_production.gd --godot <engine>` for live production integration coverage, with isolated saves. In that isolated project, the copied test accepts `-- --record`: it waits for `.runtime/record-start` after creating `.runtime/record-ready`, then performs real AI controls while normal unpaused 1× gameplay runs. Capture the window externally for ten seconds.

`test_factory_workshop.gd` remains a standalone composition preview; its optional 4× simulation recording is not production-loop evidence. Neither preview establishes whole-game frame rate on other hardware.
