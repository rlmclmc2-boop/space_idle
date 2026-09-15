# 测试目录

## 按规则定位（Phase 10）

逐条状态、断言标签和仍缺少的验证见 [TEST_MAP](TEST_MAP.md)。普通规则任务先读下面对应的1～3个专项，不以 `test_game.gd` 作为整套基线。

| 修改内容 | 最小测试入口 |
|---|---|
| 资源取整 | `test_rule_rounding.gd`；涉及自动生产加 `test_auto_gen_resources.gd` |
| 装备槽位 | `test_state_ownership.gd`；涉及退款加 `test_unequip.gd`，数量限制加 `test_ship_equipment_limit.gd` |
| 战斗目标 | `test_target_resistance.gd`、`test_projectile_lifecycle.gd`；涉及末敌加 `test_boss_projectile_clear.gd` |
| 科学家 | `test_scientists.gd`、`test_scientist_affordability.gd` |
| 存档 | `test_save_boundaries.gd`、`test_state_ownership.gd`；离线资源加 `test_offline_resources.gd` |
| UI解锁 | `test_tab_unlocks.gd`；换舰草稿加 `test_ship_tab.gd` |
| 时间步进 | `test_time_steps.gd`；冷却加 `test_travel_cooldowns.gd` |

`test_time_steps.gd` 的局部子类只记录实际tick入参后调用原实现；没有替换算法或新增测试框架。

## 运行与证据

遵循[AGENTS](../space-battleship/AGENTS.md)的范围和保护规则。从工作区根执行：

```sh
python test/run.py test_rule_rounding.gd
```

运行器复制项目/配置/总表到`test/work/`，隔离APPDATA、LOCALAPPDATA、Python缓存；仅重定向用户目录不能隔离res://数据。Godot先导入类/素材缓存再跑测试，UI测试需要有图形环境；headless不会自动创建QA。
引擎默认取项目engine目录，可用`--godot`指定；Python需要openpyxl/lxml。Windows日志设置`PYTHONUTF8=1`，避免中文回显失败。运行器在work内启用父目录权限继承，方便查看日志/截图，不给父目录以外授权。
日志/截图/存档只在work，成功后保留证据，清理时仅删已确认的对应隔离目录。UI断言不代替视觉与真实交互核查；确认退出码及失败数，不能只看PASS字样。规则夹具可用明确内存参数，但不能据此宣称正式平衡已验收。

## 其他专项

| 任务 | 入口 |
|---|---|
| 退款/批量/舰船 | test_unequip.gd / test_bulk_upgrades.gd / test_ships.gd |
| 炼铁炉与收入 | test_furnace_income.gd / test_resource_display.gd |
| 充能费率与次数 | test_charge.gd / test_charge_growth.gd |
| 驻守/回退/过关 | test_guard.gd / test_loop_retreat.gd / test_skip_clear.gd |
| 关卡编辑器 | test_level_editor.py / test_level_editor.gd |
| QA与进程重启 | test_config_panel.gd / test_delete_save.gd / test_full_restart.py |
| 配置输入与故障 | test_config_input_matrix.py；4入口接受/错误/文件副作用及事务观察 |
| 科学家配置 | test_scientist_config.py |

表内测试都经run.py隔离。矩阵生成INPUT_MATRIX.json（完整结果）与.md（索引），故障现状观察通过不代表事务安全；未决问题统一查[STATUS](../space-battleship/docs/STATUS.md)，尤其U-018/U-019/U-020。test_game及legacy探针不是默认基线，不能恢复旧机制或放宽正确断言。

性能任务另用`python test/test_performance.py --label <证据名>`，由该脚本创建隔离副本并调用phase9_probe.gd，不通过run.py启动探针。默认三轮原始测量与三轮插桩；测量时不要同时跑其他测试。规则与测量门槛查DECISIONS，历史结果由Git/本次重构记录保留。
