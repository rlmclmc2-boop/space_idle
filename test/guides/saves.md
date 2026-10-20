# 存档导入导出与重启

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 存档导入导出 | `test_save_transfer.gd --headless` 检查迁移、大数、只读预览、验证拒绝、备份/安装失败、回滚与中断恢复；`test_save_transfer_ui.gd` 使用真实末位保存页签/按钮/文件列表/确认输入，检查解锁前后顺序、草稿和焦点保留，`SAVE_TRANSFER_DEMO` 指向 v4 星系演示 JSON，`SAVE_TRANSFER_EVIDENCE` 可指定截图目录，验证导出、取消、正常重载、星系导航、往返与备份导入。`python test/run.py test_save_import_recovery.py --headless --godot <Godot路径>` 自建隔离工程，再由 Python 驱动通过真实进程死亡与新进程启动检查五种恢复状态（含首次无原档）、三种存活事务保护（Linux）。图形专项验证 Godot 内置文件窗口；原生 Windows 文件窗口及 Web 不在此验证范围。 |
| 存档与重启 | `test_save_policy.gd --headless` 检查真实时间定时/手动触发、间隔、业务内存提交、故障保护及备份恢复；去掉 `--headless` 检查设置界面。`test_journey_resume.gd --headless` 检查手动存档及不写盘的退出/重启。旧帧合并、即时写盘和异步候选夹具只描述旧机制，不作为当前保存验收入口；第二轮历史证据见 [报告](../../space-battleship/PERFORMANCE_OPTIMIZATION_2.md)。 |
