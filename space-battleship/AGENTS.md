@startup docs/knowledge/CURRENT.md
@roles executor,reviewer,maintainer
@route docs/READ_ROUTE.md#<task-kind>; exact section only
@read explicit-targets-only; expansion=gap+exact-scope; no recursive links
@policy docs/READ_PROTOCOL.md#<needed-section>; on demand
@authority user>repo; one-fact-one-owner; preserve unrelated edits
