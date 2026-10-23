# fleet-static-stage5
目标：启动边界准备共享静态舰队描述符；实例姿态保留 capture_preparation。
范围：presented_ship_view、logical_fleet_pose、game 直接启动调用和必要既有测试。
禁止：玩法数值、资产、个人存档、全局缓存、Library、合 main。
基线：19c9cfdf98e8bbef44ffebcd5ba09bff55fdec6a。
停止：上下文压缩、未授权范围或阻塞。
定位：scripts/{game,presented_ship_view,logical_fleet_pose}.gd；扩读缺口为静态炮口准备与测试运行方法，读取对应函数、test/guides/{running,ship-art}.md。
风险：浮点变换顺序、静态数据与实例状态混用；已知存档科研恢复失败不扩修。
下一步：提取静态准备，复用既有验证。

完成：候选代码提交 07d5ce22；6 个运行时文件与既有 probe_native_admission_stale_pose.gd，新增 fleet_static_descriptors.gd。未推送、未合 main。
实现：ship_view._ready 每实例构建静态描述符，视图与逻辑共读；图片扫描和 imported socket 提取仅在此处；无人机显示安装使用已捕获挂点；capture_preparation 保留实例初始姿态。
验证：test_dynamic_native_ports.gd --headless 5717/0，675 点最大误差 0.0000682394 px；test_player_mount_seating.gd --headless 90 samples/0，最大误差 0.0003388001 px；probe_native_admission_stale_pose.gd --headless 42/0（含静态纯值、独立实例、重捕获共享和姿态断言）；test_ordinary_entry.gd --scenario game 图形模式 26/0、18/0、7/0，两次 mismatches=[]。全部通过 test/run.py 的隔离项目和隔离 user dir。
引擎：C:/Users/Administrator/Documents/Codex/2026-10-23/task-4/godot/Godot_v4.7.2-stable_win64_console.exe，仅调用未改该工作区。四次导入成功；日志包含系统证书库读取警告，无 SCRIPT ERROR。
证据：同级 fleet-static-stage5-evidence/ 保存原始日志、专项 JSON 与普通入口三阶段 JSON、四张截图。截图已目视检查保存、改造、重开与领取后主界面。未验证 play_main.py 发布启动器。既有科研存档恢复失败未重跑、未扩修。
交付：代码与证据独立提交；等待 dot 与现有 high 审计。docs/knowledge/archive 证据不进 main。本次隔离副本完成后清理，保留上述证据。
