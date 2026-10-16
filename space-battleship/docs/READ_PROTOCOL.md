# 限量读取与交接

## 启动

项目可控制的入口是两层短 `AGENTS.md`，再按角色、任务种类和任务 ID 读取白名单片段。命令：`python tools/read_budget.py route --role executor --task ui-text --task-id <id>`；dot 使用 `--role dot`。真实任务锚点见 `READ_ROUTE.md` 的 `##` 标题。角色的完整规则分别在 `docs/roles/EXECUTOR.md`、`DOT.md`；已知任务 ID 只读 `docs/knowledge/tasks/<id>.md`，未知时只看 `docs/knowledge/TASKS.md` 索引，不读其他任务。首次定位可暂不传 ID，执行前须确定并维护自己的记录。执行者与 dot 共同遵守 `AGENTS.md` 的必需边界。

平台可能自动注入其他上下文，仓库规则不能阻止或计量。`read_budget.py` 只限制通过它返回的内容，不能拦截其他读取命令；使用者须遵守入口的精确范围。源文件扫描字节、返回字符、真实计费 TOKEN 分开记；字符只是输出压力代理，拿不到平台计费数据就不推算节省比例。

## 查找

路径参数相对 `space-battleship/` 解析，绝对路径仅用于明确指定的外部日志或工具生成的临时结果。先用 `files --glob` 查名字，再用 `grep --path --query` 查单文件符号，最后用 `slice --path --start --count` 读至多 80 行。JSON 先 `json --keys` 查结构，再用 `--key`、`--where`、`--fields` 提取；键名含句点时以 `/` 分隔层级，如 `entries/battle.finale_cleared`。Excel 用 `xlsx --sheet --find --columns`。差异用带明确路径的 `diff`；运行日志先保存原始文件，再用 `log` 查错误及邻行。

工具默认 stdout 上限 1800 字符，错误也限量；超限给总量、临时原件路径和 `slice` 续读命令，不静默截断关键错误。必要原始输出保存在文件，仅回传短摘要和路径。不要整库全文、重复全文、无界 `rg`、缓存、个人存档或 `test/work`。扩读前写明缺少的事实、准确路径与行段/符号及理由，只扩这一段，不递归展开链接。已有直接证据足够时停止。

## 执行与验收

短自足任务记录含目标、范围与禁止项、完成条件、基准提交、需读定位、待验证风险和下一动作。执行者按 `roles/EXECUTOR.md` 交变更清单、短结论、证据路径；dot 按 `roles/DOT.md` 审新增实现与必要原件。优先等待完成通知。失败先定位，再重跑失败项和直接影响项。按风险选最小必要测试，受影响行为与已识别风险覆盖后停止；无依据不扩矩阵或独立复测。`docs/TEST.md`、`docs/BATTLE.md` 的正确性约束继续适用。

## 记忆与增长

`knowledge/INDEX.md` 只存公开稳定事实和决定的定位，附来源提交、范围与失效触发；动态任务用 `knowledge/tasks/<id>.md`，结束后移入 `archive/` 并从索引去除。归档不默认读。聊天全文、用户权限规则、私人记忆与安全规则不写成永久授权。写规范前按 `.agents/skills/doc-compact/SKILL.md` 去重：优先删除、引用或合并；核对入口大小、唯一权威位置、链接和适用范围，避免每个任务叠加新规则。

Git 分支与提交是唯一交接载体；不把 Library、凭据、玩家存档、缓存或大型产物打包。未经父批准不合入 `main`，不改全局 Codex 配置，不永久删除未知或不可恢复数据。
