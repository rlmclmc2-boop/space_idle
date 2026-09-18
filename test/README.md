# 测试目录

## 按规则定位（Phase 10）

逐条状态、断言标签和仍缺少的验证见 [TEST_MAP](TEST_MAP.md)。普通规则任务先读下面对应的1～3个专项，不以 `test_game.gd` 作为整套基线。

| 修改内容 | 最小测试入口 |
|---|---|
| Windows 单文件发布 | 根目录 `build_release.bat --no-pause` 完整导出并验证；`powershell -NoProfile -ExecutionPolicy Bypass -File test/test_release_failures.ps1` 验证缺工具/编译/导出/运行失败保护；`verify_release.gd` 由构建器放入独立 release 验证包，不经 run.py，不进入最终 EXE |
| 资源取整 | `test_rule_rounding.gd`；涉及自动生产加 `test_auto_gen_resources.gd` |
| 装备槽位 | `test_state_ownership.gd`；涉及退款加 `test_unequip.gd`，数量限制加 `test_ship_equipment_limit.gd` |
| 装备计算成长 | `test_equipment_growth.gd` / `test_equipment_growth_import.py`；批量购买加 `test_bulk_upgrades.gd` |
| UI局部刷新/绘制 | `test_local_ui.gd`（控件身份、写入/绘制范围、真实点击/拖拽、隐藏页补齐、局部解锁）；升级用`test_upgrade_ui.gd`（真实输入、动态MAX、事件不重建）。定向性能用`test_upgrade_ui_probe.gd`经run.py隔离，3轮两种预算，勿并行其他性能测试 |
| 持续锁定光束 | `test_long_laser.gd`（延迟首击、线性增长/封顶、断束重锁、敌我挂载、时间步与画面）；回归`test_projectile_lifecycle.gd`、`test_travel_cooldowns.gd` |
| 坚韧与死亡 | `test_tenacity_survival.gd`：受击期减速恢复、微量回盾后连续溢出致死、不同容量和镶嵌位置、1e24容量下微小剩余生命；可选`res://.runtime/save-fixture.json`仅在隔离副本装载 |
| 护盾溢出 | `test_shield_overflow.gd`：普通/防御宝石路径、抗性、恰好破盾、溢出致死及激光/火炮/导弹/持续光束 |
| 伤害跳字 | `test_damage_numbers.gd`：200ms聚合、暴击、两条上限、三种模式、完整详情、实际光束/导弹/多目标压力与截图；回归`test_weapon_fx.gd`、`test_long_laser.gd`及`test_local_ui.gd` |
| 炮台旋转 | `test_turret_rotation.gd`：独立追踪/转速/暂停/回正/卸装换舰、旋转炮口与主光束、五舰型旋转包络；回归`test_weapon_fx.gd`、`test_long_laser.gd` |
| 我方舰船显示倍率/炮台 | `test_player_visual_scale.gd`：五舰型1.0/1.25对比、全部挂点可见炮口、逻辑出生点不变、边界和多舰布局预览；回归`test_weapon_fx.gd`与`test_long_laser.gd` |
| 离膛遮挡/绘制层级 | `test_muzzle_visibility.gd`：清除闪光和后坐后检查三类离膛弹体像素可见、业务状态不变；回归`test_weapon_fx.gd`与`test_long_laser.gd` |
| 武器表现 | `test_weapon_fx.gd`：三阶段截图、视觉不写战斗状态、转向平滑、固定尾迹、暂停/清理/粒子上限、无关UI保留；回归`test_projectile_lifecycle.gd`与`test_long_laser.gd` |
| 战斗目标 | `test_target_resistance.gd`、`test_projectile_lifecycle.gd`；涉及末敌加 `test_boss_projectile_clear.gd` |
| 战点切换画面 | `test_battle_transition_ui.gd`：真实波次切换、背景像素连续性、星空拖尾渐变/暂停、静态层不重绘、宝石面板不自动打开 |
| 科学家 | `test_scientists.gd`、`test_scientist_affordability.gd`；重建首帧按钮闪动用`test_hightech_flicker.gd` |
| 存档 | `test_save_boundaries.gd`、`test_state_ownership.gd`；离线资源加 `test_offline_resources.gd` |
| 宝石 | `test_jewels.gd`（200容量/拾取/合成/分解/镶嵌/10种效果/存档）；`test_jewel_fragments.gd`（旧字典迁移、统一倍率/小数、实际收入、离线幂等/溢出/随机批量）；`test_jewel_ui.gd`（真实点击、局部写入/重绘/隐藏恢复与截图）；`test_jewel_import.py`（来源一致、重复ID、分表发现与缓存） |
| UI解锁 | `test_tab_unlocks.gd`；换舰草稿加 `test_ship_tab.gd` |
| 一键合成 | `test_jewel_combine_all.gd`（连锁/分组/保护标记/配置上限/碎片补位/异常回滚/单次保存通知/读档）；`test_jewel_ui.gd`（实际按钮、合并结果、高亮、无操作提示与局部刷新）；共用生成逻辑回归`test_jewel_fragments.gd` |
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
| QA与进程重启 | test_config_panel.gd / test_delete_save.gd / test_full_restart.py；普通重启保存失败用 test_restart_save_failure.gd |
| 配置输入与故障 | test_config_input_matrix.py；4入口接受/错误/文件副作用及事务观察 |
| 科学家配置 | test_scientist_config.py |

表内测试都经run.py隔离。矩阵生成INPUT_MATRIX.json（完整结果）与.md（索引），故障现状观察通过不代表事务安全；未决问题统一查[STATUS](../space-battleship/docs/STATUS.md)，尤其U-018/U-019/U-020。test_game及legacy探针不是默认基线，不能恢复旧机制或放宽正确断言。

性能任务另用`python test/test_performance.py --label <证据名>`，由该脚本创建隔离副本并调用phase9_probe.gd，不通过run.py启动探针。默认三轮原始测量与三轮插桩；测量时不要同时跑其他测试。规则与测量门槛查DECISIONS，历史结果由Git/本次重构记录保留。
