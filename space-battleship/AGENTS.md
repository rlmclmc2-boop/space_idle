@role dot|executor -> foundation/README.md for current build/runtime/verification entry points
@state current user handoff + active Git branch/commit; no cross-task reads
@must user>repo; preserve unrelated edits; no inferred gameplay/number/config/save approval
@must Git branch+commit handoff; parent reviews before main merge; exclude Library/credentials/saves/cache
@must affected-correctness verification only; current phase -> foundation/README.md; docs-only -> no game test
@read explicit targets only; expansion=gap+exact-range; no recursive links
