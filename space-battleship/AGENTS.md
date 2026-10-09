# Agent entry

Godot/GDScript idle auto-battle. Read this entry, then search the target and load only task-relevant rules. Preserve unrelated edits. User instructions outrank docs. Do not infer approval for gameplay, numeric, configuration-source, or player-save changes from current implementation. One fact has one authority.

Start/resume/handoff: follow [WORKFLOW](docs/WORKFLOW.md). Close evidenced player problems, not just assignments; reopen actionable owned findings before declaring completion. User authorization and stop conditions always bound continuation.

Git 上传/下载已获用户授权；协作交接优先 Git 分支与提交，Library 仅补充。未验收改动用工作分支；main 须父验收后合入并回读远端。只提交任务文件。明确例外：用户允许把本轮三方纯测试存档及精简恢复检查点公开备份到 rlmclmc2-boop/space_idle 的工作分支并回读，此许可不扩大为详细报告。仍排除用户本地玩家档、凭据、缓存、临时产物、截图/原图及聊天内容。

## Routes — load only when triggered

| Task | Read |
|---|---|
| Locate code/data | [ARCHITECTURE](docs/ARCHITECTURE.md) |
| Stable gameplay | [PROJECT](docs/PROJECT.md) |
| Open issue / long-term decision | [STATUS](docs/STATUS.md) / [DECISIONS](docs/DECISIONS.md) |
| Combat / weapon / buff / gem | [BATTLE](docs/BATTLE.md) |
| UI / rendering / input / text | [UI](docs/UI.md) / [UI_TEXT](docs/UI_TEXT.md) when editing player text |
| Tests | [TEST](docs/TEST.md); commands in [test README](../test/README.md) |
| Balance / simulation / performance | [BALANCE_LAB](docs/BALANCE_LAB.md); [BALANCE_PERFORMANCE](docs/BALANCE_PERFORMANCE.md) for sim speed |
| Crew / art / level editor | [CREW](docs/CREW.md) / [ART_GUIDELINES](docs/ART_GUIDELINES.md) / [LEVEL_EDITOR](docs/LEVEL_EDITOR.md) |
| Task token budget | [token-opt](.agents/skills/token-opt/SKILL.md) |
| Long context / handoff | [ctx-compress](.agents/skills/ctx-compress/SKILL.md) |
| Any persistent rule or doc write | [doc-compact](.agents/skills/doc-compact/SKILL.md) |

Use `caveman` skill at ultra level for chat; read its SKILL.md on first use. User preference overrides. Keep code and documents in normal, clear prose. Apply doc-compact to future rule writes.
