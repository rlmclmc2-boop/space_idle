# 关卡、编队与推进

2026-09-15 用户要求：所有敌舰统一只占1格，十槽最多放十艘，size仅决定外观。编辑器移除按size推算的占格重叠/越界警告。操作见 [LEVEL_EDITOR](../LEVEL_EDITOR.md)。

## CONFIRMED · 原表

总览!A5:A6、A16:D19、A47:C47 与 level/monGroup：关卡通过长度比例指定敌群遭遇位置。十个槽从上到下排列，null 为空；旧size占格口径由上述用户要求替代。
全灭普通敌群后继续前进，BOSS 击毁通关；总览!A10 允许任选已通关关卡并无限循环。2026-09-13 用户明确要求选择指定关卡后持续重刷，现已提供选择入口。
关内攻击/生命/资源倍率从上一关到本关线性成长，攻击/生命结果向上取整。D17 的数字示例与线性公式不一致，见 U-012。

## CONFIRMED · 当前代码

2026-09-14 用户重新定义 BOSS 战：每关遭遇列表的最后一场战斗为 BOSS 战，必须全灭该场敌群才通关；之前即使配置大型/BOSS飞船，击败后仍继续推进。最后一场可以全是普通小型飞船。`is_boss_encounter()` 按生成后 group_index 等于遭遇总数判定；size只影响外观，不决定通关。敌舰中心为198+slot×44，索敌中央优先按单格slot排序。

死亡后退距离来源为 `config!A8:C8` 的 `backRange`（2026-09-13 核对）。2026-09-13 用户确认：超过本关起点时，上一关末尾减去本次剩余后退距离；`begin_retreat()` 按各关 length 连续折算，第1关起点截断，按目的关重建敌群索引。旧 `defaults.deathRetreatDistance` 保留但不再参与计算。后退时长仍读取 `defaults.deathRetreatDuration`。

`ShipDatabase.ratio(level,progress,kind)`：上一关值（第1关用1）与本关值按 clamp(progress,0,1) 做 lerp；BattleGame progress=distance/length。敌人生命与掉落倍率在生成时确定，攻击倍率在出手时读取（战斗停止前进）。

2026-09-13 用户确认跨关回退落在上一关 BOSS 后方时重新触发该关 BOSS；保留剩余距离算出的落点，恢复生命后复用 spawn_group 在落点重放 BOSS，避免没有后续敌群而无限空驶。
`start()` 限制 1≤level≤highestLevel，清本次战斗、恢复玩家、进入 TRAVEL。`spawn_group()` 将距离设为遭遇位置并增加 group_index。按上述最后一场判定通关，不以走到 length 为胜利条件。跨关后退仅在落点越过目的关最后遭遇时重放最后一场；越过前置大型舰不重放它。
2026-09-15 用户替代旧循环规则为“驻守”：战斗中开启驻守当前遭遇点；巡航中开启先到下一波再驻守（用户最终确认）。该波敌人全部消失后才开始计时，间隔=（该波位置距离−上一波位置距离）/config.movement；第一波从关卡起点计算。驻守期间不前进，计时结束复用 spawn_group 在原位置刷新同一波，不叠加活敌；暂停冻结计时，速度倍率随现有模拟时间生效。关闭驻守后继续正常推进。

最终遭遇仍复用 clear_level 通关解锁及清弹，待解锁提示确认后按驻守间隔刷新最终敌群；不自动换关。“立即过关”仍可离开驻守进入下一关。非驻守保持 defaults.loopDelay 自动换关。弹窗等待见 [progression](progression.md)。

“跃迁”独立保留已通关关卡选择，选择后立即进入该关并结束当前驻守。驻守死亡设置提供：0后退并取消（默认）；1后退后沿正常遭遇路线返回原驻守点（可跨关）；2后退后在落点保持驻守，不返回，刷新目的关落点对应的下一遭遇，落点已越过最终遭遇时重放最终遭遇。三项均保留现有后退距离与恢复规则，来源为2026-09-15用户确认。

驻守复用 profile.loop 开关，guardStage/guardIndex/guardDistance 保存目的点，guardDeath 保存死亡选项；重启在有效驻守点重新开始等待计时，不保存敌群或计时中间量。旧循环存档无驻守目的点时关闭驻守，旧已通关列表继续用于跃迁。

追踪：level/monGroup/mon → JSON levels/groups/enemies → database.ratio、game.start/spawn_group/clear_level/tick → test_final_encounter、test_loop_retreat；编队重叠校验缺口见 U-007。
