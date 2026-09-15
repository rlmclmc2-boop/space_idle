# 测试目录

Windows 运行器创建临时副本后启用父目录权限继承，让命令行与截图查看工具均可访问产物；不额外授予超出 `work/` 父目录的权限。

测试源码统一在本目录，工作副本、日志、截图、测试存档和审计结果统一放入 `work/`（不提交 Git）。禁止在工作区根新建验证目录；完整规则见 [AGENTS](../space-battleship/AGENTS.md) 和 [VALIDATION](../space-battleship/docs/VALIDATION.md)。

在工作区根执行 `python test/run.py test_import.py`、`python test/run.py test_config_workbooks.py` 或 `python test/run.py test_config_panel.gd`。Python 需安装 openpyxl/lxml；引擎默认使用项目 `engine/` 中的 Godot，也可通过 `--godot` 指定。每次仅运行指定测试。

运行器复制必要项目文件和总表到独立目录，隔离玩家存档，Godot 测试默认有图形。成功后保留产物供检查，使用完可删除 `work/` 内对应目录。

`legacy/` 保留旧专项探针源码，仅供复用参考；不能直接视为当前规则的验收标准。旧验证副本与历史截图、JSON 审计产物已按用户要求清理，历史测试结论仍记录于 VALIDATION。

2026-09-15 高科技重做后，科学家/点数/迁移/界面验证入口为 `test_scientists.gd`、配置为 `test_scientist_config.py`、拖拽为 `test_hightech_slots.gd`。旧计时/切换测试已在有效断言迁移后删除，历史从Git查询；不能恢复旧计时假设作为新版验收。

舰船槽位、重复装备独立升级、换舰重置与资源返还验证入口为 `test_ships.gd`。

战舰页签、已解锁战舰筛选与换舰时装备配置验证入口为 `test_ship_tab.gd`。

2026-09-15 重构基线：`test_ships.gd` 覆盖默认/空槽独立性、旧levels/cooldowns写入及旧档迁移；`test_bulk_upgrades.gd` 覆盖五类装备的单级/10级/MAX一致性。科学家描述/离线上限/进度UI、炼铁炉拾取与寿命的有效历史断言已分别纳入 `test_scientists.gd`、`test_furnace_income.gd`。装备属性/上限测试必须显式安装空槽装备，解锁不等于安装。阶段结果见 [重构方案](../space-battleship/REFACTOR_PLAN.md)。

Phase 5状态边界与读取纯度：`test_state_ownership.gd`；旧levels只通过原始存档字典输入，普通夹具直接设置槽位等级/槽位冷却。完整阶段证据见REFACTOR_PLAN第8节；历史综合探针限制见TODO U-017。
