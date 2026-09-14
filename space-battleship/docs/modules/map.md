# 关卡、编队与推进

2026-09-14 用户要求配置编辑：关卡编辑器提供十槽敌群与遭遇列表编辑，保存复用现有跨表校验；重叠/越界仅警告，见 U-007。操作见 [LEVEL_EDITOR](../LEVEL_EDITOR.md)。

## CONFIRMED · 原表

总览!A5:A6、A16:D19、A47:C47 与 level/monGroup：关卡通过长度比例指定敌群遭遇位置。十个槽从上到下排列，null 为空，mon.size 表示占格数。
全灭普通敌群后继续前进，BOSS 击毁通关；总览!A10 允许任选已通关关卡并无限循环。2026-09-13 用户明确要求选择指定关卡后持续重刷，现已提供选择入口。
关内攻击/生命/资源倍率从上一关到本关线性成长，攻击/生命结果向上取整。D17 的数字示例与线性公式不一致，见 U-012。

## CONFIRMED · 当前代码

2026-09-14 用户重新定义 BOSS 战：每关遭遇列表的最后一场战斗为 BOSS 战，必须全灭该场敌群才通关；之前即使配置大型/BOSS飞船，击败后仍继续推进。最后一场可以全是普通小型飞船。`is_boss_encounter()` 按生成后 group_index 等于遭遇总数判定；size 只保留占格和现有舰体显示，不决定通关。

死亡后退距离来源为 `config!A8:C8` 的 `backRange`（2026-09-13 核对）。2026-09-13 用户确认：超过本关起点时，上一关末尾减去本次剩余后退距离；`begin_retreat()` 按各关 length 连续折算，第1关起点截断，按目的关重建敌群索引。旧 `defaults.deathRetreatDistance` 保留但不再参与计算。后退时长仍读取 `defaults.deathRetreatDuration`。

`ShipDatabase.ratio(level,progress,kind)`：上一关值（第1关用1）与本关值按 clamp(progress,0,1) 做 lerp；BattleGame progress=distance/length。敌人生命与掉落倍率在生成时确定，攻击倍率在出手时读取（战斗停止前进）。

2026-09-13 用户确认跨关回退落在上一关 BOSS 后方时重新触发该关 BOSS；保留剩余距离算出的落点，恢复生命后复用 spawn_group 在落点重放 BOSS，避免没有后续敌群而无限空驶。
`start()` 限制 1≤level≤highestLevel，清本次战斗、恢复玩家、进入 TRAVEL。`spawn_group()` 将距离设为遭遇位置并增加 group_index。按上述最后一场判定通关，不以走到 length 为胜利条件。跨关后退仅在落点越过目的关最后遭遇时重放最后一场；越过前置大型舰不重放它。
`clear_level()` 更新通关与解锁。等待 defaults.loopDelay 后，循环开启则重刷 profile.loopLevel，否则到下一关（上限为最后一关）；弹窗等待见 [progression](progression.md)。UI 从已通关关卡中选择目标，开启立即进入目标关卡；开启中改选也立即切换。关闭后恢复自动推进。目标独立保存，死亡退关不修改目标；重启恢复有效目标，旧存档缺少目标时关闭循环并要求选择。

追踪：level/monGroup/mon → JSON levels/groups/enemies → database.ratio、game.start/spawn_group/clear_level/tick → test_final_encounter、test_loop_retreat；编队重叠校验缺口见 U-007。
