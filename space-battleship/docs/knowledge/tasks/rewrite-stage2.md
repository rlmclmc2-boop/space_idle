# rewrite-stage2

状态：第二阶段实现完成，等待 dot 与既有 Astra 对最终提交审核；审核前暂停。
方案唯一入口：a815d2a843976e22cb3fb24e7683d4a54c65fd3f 的 docs/game-design/README.md，实施顺序 07 第 2 步。
分支：rewrite/stage1-foundation；第一阶段 ca676e0e 已双审通过；不进入第 3 阶段、不合 main、不另开线程。

接续保全：原 task-5/space_idle 的 HEAD cd0746c67652ea0800b08208a012654c047a1892，20 项未提交改动完整保全为 2852d4e；通过 Git 克隆到 task-6/space_idle 继续。未覆盖原工作树，未复制或操作个人存档。

交付：GameSession 直连同一 native 核；Amount 金额与 int64 历史、共享 evaluate_module、模块缺损权威、四武器与命中、连续波次/撤退、航行/驻守、掉落唯一 ID 与拾取、定时铀、两种收入窗口、正式与独立 Excel 编译入口。
付费等级：静态普通成长和按付费等级授予的进化进入实际伤害/容量；盾以同级装甲取整值和表内基础比例计算，再执行属性取整。equipment_evolution.xlsx 是静态进化参数来源。购买命令、AI/反应炉实际成长等按第 3 阶段实施。
几何：combat_setup 调用共用 enemy_formation.positions，以 Excel 几何参数计算；15 槽及空位保留源索引；玩家所有启用空槽保留类别、序号、付费等级。native 目标排序锚读取配置。

验证：18 个编译器用例、原生 Amount 边界用例、48 个同核 headless 场景通过。含 2/20 级真实命中、盾容量、普通与 1e500 多模块缺损分摊/容量更新不回血/撤退重置、空位和 15 槽编队。
正式 Excel：48 表、14583 行；120 现实秒，118.4 游戏秒，7104 固定步，关卡 1 已通关且到达关卡 2；57 次攻击、773 次来袭，铁 142、铀 9，无业务错误。
证据：tests/evidence/stage2-final.json；可复现命令及依赖见 tests/README.md 第二阶段章节。
边界：headless 验证，不代表 GPU/完整页面或第三阶段缺失强化/传说已验收；此次未触碰个人存档，测试保存仅在隔离目录。
下一动作：推送最终提交后暂停，由 dot 与既有 Astra 审核同一提交。发生压缩即停止并交接。
