# 累计征服详情消费与同版验证

固定所有者实现 `feat/amount-safe-previews@daaa7abecb6ab74e87a74908d3e79c7dc88d123e` 已获原双审限定通过；本候选将该提交的 `src/systems/planet.gd` 原样作为依赖带入，UI 只调用 `conquest_facts`、订阅 `conquest_changed`，不私读或自行计算累计来源。前一视觉候选 `4368ca57` 的船坞 GLB/球面在本轮 UI 实机图中复用；不改变共享宿主/main。

左侧探索详情新增低频“征服奖励”折叠项：本星球已征服和探索经验共享状态与“已征服星球累计奖励”四行分开，四行直接使用提供方的 `display_text`，不混入设施当前因子或全系统最终属性。读口失败显示具体不可用原因。初次绑定、切星、替换 Session 后的新页面各读一次；局部通知只置相应的星球/累计脏标记，折叠或模块隐藏时保留，显示帧再读取。旧页面退出树时显式断开旧 Planet 信号，回调还检查绑定实例及待释放状态。

`aa6183c1` 独审指出读口失败时两类脏标记均清除但旧缓存仍在；若之后仅累计通知使读取成功，原逻辑只更新奖励，可能在清除错误后投影旧球标记。本轮修正为**由错误恢复的第一次成功读取同时接纳本球事实和累计行**；平常成功路径仍按各自脏标记局部更新，不轮询。新增 [失败态原图](evidence/conquest-recovery-04-unavailable.png)、[恢复态原图](evidence/conquest-recovery-05-current-planet2.png)、[定向探针](evidence/conquest-recovery-probe.gd.txt)、[4.7.2运行日志](evidence/conquest-recovery-runtime.txt)、[入口脚本检查](evidence/conquest-recovery-main-check.txt)和 [SHA256](evidence/conquest-recovery-sha256.json)。探针先在选中第二球时将已参与征服源设为非有限值，使读口明确失败并不投影旧缓存；恢复源后，用真实 `Planet.restore_state` 征服未选中第三球，原信号对当前第二球只有 `cumulative_changed=true`。运行断言确认错误消失、第二球仍为未征服且不共享、累计行与提供方相同；探针和入口检查退出0。夹具改动均限独立临时运行，不改变生产配置或所有者代码。

实际 Godot `4.7.2.stable.official.ed1daf0bf`、项目 native 和配置运行记录见 [探针](evidence/conquest-ui-probe.gd.txt)、[日志](evidence/conquest-ui-runtime.txt)、[入口脚本检查](evidence/conquest-main-check.txt)、[首球](evidence/conquest-01-planet1.png)、[第二球累计](evidence/conquest-02-planet2-cumulative.png)、[换 Session 后](evidence/conquest-03-after-session-replacement.png)及 [SHA256](evidence/conquest-sha256.json)。定向探针及入口脚本检查退出0，覆盖首球35等级/1强化/10%充能/100幸运、第二球征服后50等级/2强化/20%充能/200幸运、切球共享标记、deferred刷新、折叠期间仅置脏和展开消费；实际调用宿主 `_replace_session` 后确认新页面绑定新 Planet、旧信号断连，旧 Planet 后续通知不影响新页面。夹具显式授予关卡开放并合成两个已征服状态，截图仅证明 UI 消费与隔离，不代表自然游玩解锁、完整重铸事务或完整 M7/V7 通过。运行的 ALSA 缺设备回退为 dummy，与脚本检查及探针断言无关。

本节以下是实现前的消费约束，保留供比较。

依据接口组固定 `1865da2f` 的 `docs/game-design/contracts/planet.md` §11 及父线程通知：只读设计已限定双审通过，接口实施者正在完成；本 UI 不新增查询实现、不私读或自行计算。正式接线等固定实现候选与其审查结论。

在左侧探索详情内提供低频“征服奖励”折叠项，仍属于当前选中星球；先显示其已征服/共享经验状态，再明确分组显示“已征服星球累计奖励”四行，不与精炼厂当前因子混合。累计范围是所有已接纳征服源，不是当前星球独占效果，也不是所有系统叠加后的最终属性。读取提供方 `display_text`，失败展示不可用原因，不用0伪造成功。

候选 `conquest_facts(planet_id)` 仅在正式绑定的 Session Planet 上调用；首次绑定、切星、Session 重绑各读取一次。`conquest_changed(changed_planet_ids,cumulative_changed)` 只将对应部分置脏：选中 ID 被列入才重取星球标记/共享经验，累计变化才重取累计行。隐藏详情仅保留脏标记，展开时消费；普通时钟、人员、自动探索及领取不触发累计刷新。重绑断开旧信号；候选 restore/reforge 对象不订阅。通知不是整个协调事务提交完成证明，消费时遵守所有者最终通知边界。

原计划时尚未接线；当前候选的实际覆盖与限制以上述同版运行记录为准，不宣称完整 M7/V7 验收。
