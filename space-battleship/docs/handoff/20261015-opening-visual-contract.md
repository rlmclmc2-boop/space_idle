# 前三关战斗数据供表现绑定

本文件绑定 `20261015-opening-18-plan.md` 与独立表现分支的 `docs/art/opening-three/CONTRACT.md`。表现草图仍待父审，不因本表自动放行。数值与机制由本分支 Excel、生成配置和执行器负责；表现只读运行时数据与事件。

| `mon.id` | `archetype_id` | 固定身份 | 机制 | 建议原型映射 |
|---:|---|---|---|---|
| 270001 | `scout` | 轻侦察 | 能量射击、低血 | needle |
| 270002 | `sentry` | 物理哨兵 | 物理射击、能量克制 | needle 的另一明确变体，待审 |
| 270003 | `interceptor` | 能量拦截 | 能量射击、较高优先级 | needle 的另一明确变体，待审 |
| 270004 | `swarm` | 蜂群轻艇 | 一次出现至少 10 架、低血 | needle 缩小变体，待审 |
| 270005 | `anchor` | 装甲锚点 | 少量、高生命、物理克制 | anvil |
| 270006 | `reactive` | 连击削减舰 | 0.16 秒同轮、2.2 秒间隔、20%×至多 3 层 | anvil 的明确机制变体，待审 |
| 270007 | `shielded` | 间歇护盾舰 | 基础盾 600，1.8 秒无命中后每秒恢复最大盾 8% | crown |
| 270008 | `command` | 指挥舰 | 高生命、物理射击 | crown 的无盾变体，待审 |

敌机运行时字典保留 `id`、`archetype_id`、`uid`、`hp/max_hp`、`shield/max_shield`、`shield_hit_at`、`shieldDelay`、`shieldRecovery`。只有 `reactive` 有 `reactiveReduction=1`；击中后同步 `reactive_stacks`（0–3）、`reactive_multiplier`（1.0、0.8、0.6、0.4）、`reactive_volley_at`。旧/原生路径的 `hit` 事件均有目标 `uid`；对 `reactive` 另带 `reactive_stacks`、`reactive_multiplier`。表现可按 `uid` 读目标，不能从较小伤害数字猜减伤。两路径都在结算命中时更新，零层代表首轮或窗口重置。击中未造成实际盾增量时不显示恢复；盾量实际增长才可显示回流。

玩家护盾恢复延迟是全舰有效命中后 2 秒；临防、装甲吸收也重置所有护盾模块。敌方护盾恢复同样按敌机每次实际命中重置。护盾发亮必须依据 `shield/max_shield`，不可用角色外形推断。当前没有独立、可靠的攻击前兆 `start/end` 事件；表现不要基于冷却自行预测必然命中。`fire`、`projectile_impact`、`hit`、`explode` 是现有反馈来源。`hit` 暂无统一 `attack_id/mitigated_amount/reason` 结构，现阶段仅能准确呈现减伤层数和倍率；如要显示具体免伤值，需下一轮接口审核。

本分支不改外形或长卷。美术原型建议若和实际属性冲突，以此处 `archetype_id` 与真实数值为准，再由父审映射。
