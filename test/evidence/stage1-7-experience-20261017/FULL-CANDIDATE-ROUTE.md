# 完整候选 1–7 新档路线（2026-10-17）

- 游戏提交：`2388a87`（功能 `efd703a`、美术 `f3fbdc2`、关卡 `196cffc` 的预集成）。Godot 4.7.2，`BattleGame.new(ShipDatabase.new(), false)`，固定 `tick(1/60)`，无资源、血量或关卡进度注入。脚本 `space-battleship/dev/qa_stage1_7_route.gd` 自动购买、换装、分配反应炉、选择研发；每关最多 8 次正常重试。此为游戏逻辑新档路线，不代替后续人工 GUI 实玩。
- 无 AI 投入、持续光束路线原始输出：[full-route-no-ai-invest.txt](full-route-no-ai-invest.txt)。第 2 关前三次于第 5/5/6 点撤退，第四次以导弹 5、装甲 6 通关；含重试累计 214.62 游戏秒。3–7 关均首试通关。第 7 关结束长激光 19、护盾 17、反应炉 8、铁 11431、异空间 `true`。
- 第 6/7 关持续光束各 9 点：整关 67.00/70.75 秒，交战合计 40.00/43.75 秒，末点剩余护盾 9733/20534。相同装备投资下仅将武器替换为脉冲激光，原始输出：[full-route-pulse-control.txt](full-route-pulse-control.txt)；整关 87.05/90.08 秒，交战合计 60.06/63.08 秒，末点剩余护盾 3430/13597。两路线均通关，因此优势明显但不是强制唯一解。
- 反应炉零投入对照：[full-route-no-reactor.txt](full-route-no-reactor.txt)。该次运行在参数化命令加入前，脚本设置为反应炉目标恒 1 且不分配，其余仍为相同正常购买路线。第 6 关首次于第 7 点撤退、第二次通关；第 7 关在最多 8 次尝试中持续于第 8/9 点撤退，最终装备同为长激光 19、护盾 17。反应炉升级与分配在本路线中有决定性生存收益。
- AI 工厂每秒投入 10 铁的正常路线：[full-route-ai-invest.txt](full-route-ai-invest.txt)。相较零投入，6 关后武器精准研究进度 `32.999…→48.4375`；7 关后装备强化进度 `19.75→51.25`，研究完成等级不变。7 关时间 `70.75→70.00` 秒，结束铁 `11431→10077.8`。该投入在 6/7 关的即时体感偏弱，应由功能设计方评估；未据此改动机制。
- 进化配置为每 20 级一次；19→20 需要 10 个 `degenerate_matter`，首档属性系数 1.6。路线到第 7 关结束武器 19 级且异空间刚解锁，尚未获得材料，没有把 20 级进化伪装成已完成。

复现：在完整项目及匹配本机扩展下运行 Godot `--headless --path <project> --script res://dev/qa_stage1_7_route.gd`；附加 `-- --pulse-control`、`-- --reactor-control` 或 `-- --ai-invest` 选择对照。原始输出的 `QA_ROUTE_SCENARIO`、`QA_ROUTE_POINT`、`QA_ROUTE_RETRY`、`QA_ROUTE_STAGE` 为核对入口。
