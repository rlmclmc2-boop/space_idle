# 首段验证

基线 `6a8388c26387f76bc3d3047ef8b5042026ae7cf1`；候选 `refactor/readiness-material-wakeup`。
产品变更仅 main/battlefield 初始化边界与现有材料提交—船员调度调用链。

| 现有用例 | 结果 | 证据 |
|---|---|---|
| test_crew_dirty.gd | 30 checks, 0 failures | crew.log |
| test_hyperspace_material_economy.gd | 137 checks, 0 failures | materials.log |
| test_save_startup_rejection.gd | 11 checks, 0 failures | startup.log |

使用 Godot 4.7.2，现有 `test/run.py` 导入隔离项目及用户目录。启动最终验证命令：
`python test/run.py test_save_startup_rejection.gd --headless --godot <Godot_v4.7.2-stable_win64.exe>`。
船员及材料最终验证复用 run.py 已导入的同一隔离项目，复制最终用例，各设独立 APPDATA/LOCALAPPDATA，再运行 `Godot --headless --path <isolated-project> --script <existing-test>`；可用同一 run.py 命令替换用例名复现。所有测试进程已结束，保留以上日志，本轮临时副本已清理。

新增覆盖：缺材料停用后真实兑换到账恢复；合并到账不顺延原截止时间；兑换重放无重复通知；领取失败无通知，成功领取和重放只发布一次完整状态；正式 main.tscn 坏档拒绝后不构建战场且保留存档字节，成功启动构建战场。

同步修正的旧夹具：进化费用按目标等级收费，停在配置间隔前一级；启动用例改读 economy.resources，并释放上一实例；已废弃的缺字段 v4 接受预期改为现行完整快照恢复（当前校验明确拒绝缺字段）。首次失败日志保留供复核，没有修改产品存档校验来迁就夹具。

环境已有根证书读取警告；材料用例退出报告对象/资源残留，未出现脚本错误，退出码 0。本轮不扩展治理无关残留。未验证所有历史探针，不代表完整架构验收。
