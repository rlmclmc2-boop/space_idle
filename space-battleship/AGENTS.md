@role dot|executor -> python tools/read_budget.py route --role <role> --task <kind> [--task-id <id>]
@state docs/knowledge/TASKS.md -> tasks/<id>.md only; no cross-task reads
@must user>repo; preserve unrelated edits; no inferred gameplay/number/config/save approval
@must Git branch+commit handoff; parent reviews before main merge; exclude Library/credentials/saves/cache
@must affected-correctness verification only; battle shared effects -> docs/BATTLE.md; docs-only -> no game test
@read explicit targets only; expansion=gap+exact-range; no recursive links
