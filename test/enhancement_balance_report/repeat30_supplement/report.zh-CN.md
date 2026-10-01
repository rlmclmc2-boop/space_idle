# 连发30与目标几何修正补充

> 本页导弹是基础BattleGame读取的基础表4发/1秒路径；正式5发/2.4秒的连发30比较另见[正式入口补充](../presented_repeat30/report.zh-CN.md)。

## 建议
保留连发30B的20%系数。校正目标位置后，B的多目标整波清除区间已可见：固定前置AA，快激光TTK从13.64降至12.69秒，16个配对种子中12个更快；基础表导弹（4发/1秒）从12.04降至11.48秒，10/16更快。单目标仍偏向A。没有改配置，也没有试调25%或30%。

B不是所有多目标输入的持续DPS赢家。固定AA时，激光B持续DPS低5.4%，导弹高1.9%；因此“更快清除”和“更高持续DPS”必须分开。这里支持一个有限、可解释的清除优势区间，不是所有装备/关卡的绝对平衡保证。

## 原证据失效范围
原夹具的敌人横坐标为500/580/660，四目标时另有740；实际战场宽572。它使部分敌人出场地，造成弹丸丢失、目标可达性和额外锁定收益偏差。不是单纯TTK右删失。

- 原completed_rows.csv中114行涉及进攻/联合多目标：swap1 32行、missile_multi 60行、production_missile 6行、joint_focus_many_sources 8行、joint_swap 8行
- 全部逐行标记在invalid_inherited_rows.csv，保留原CSV行号、阶段、配置/分支、种子。上述原行不得用于进攻平衡、整波TTK或弹丸与光束比较；旧多目标数值已由本补充取代，联合多目标解释撤回
- 原单目标证据和硬门仍可用。steady_many_sources虽保留了出界演员坐标，但武器冷却设999，合成来袭直接调用hit_player并按source_uid投递，不依赖演员位置；其防御结果不因该几何问题失效。没有重跑防御/大型联合矩阵
- 原report.zh-CN.md、node_niches.csv和summary.csv中的相关旧结论是历史记录，不应覆盖本补充的失效说明。原数据未删除

所有新夹具横坐标200/280/360，纵坐标230/228/226，均在572×696场地内。公共夹具现有每目标边界预检和断言。

## 连发30配对结果
有效强化30，实际装备150，其他分支固定未选，只比较连发--A/--B与AAA/AAB。持续DPS采用20秒不死亡目标；TTK使用相同有限HP，最长45秒，全部整波成功清除后才计TTK。单目标8种子，多目标16种子。

| 武器/目标 | 前置 | B持续DPS相对A | A→B整波TTK | B更快种子 |
| --- | --- | --- | --- | --- |
| 快激光/1 | 无 | −23.8% | 5.15→6.35秒 | 2/8 |
| 快激光/1 | AA | −12.8% | 4.37→4.59秒 | 3/8 |
| 快激光/3 | 无 | +2.8% | 17.34→16.14秒 | 9/16 |
| 快激光/3 | AA | −5.4% | 13.64→12.69秒 | 12/16 |
| 基础表导弹（4发/1秒）/1 | 无 | −12.1% | 5.27→6.52秒 | 0/8 |
| 基础表导弹（4发/1秒）/1 | AA | −12.2% | 4.20→5.33秒 | 2/8 |
| 基础表导弹（4发/1秒）/3 | 无 | +9.3% | 15.79→15.29秒 | 8/16 |
| 基础表导弹（4发/1秒）/3 | AA | +1.9% | 12.04→11.48秒 | 10/16 |

实际20秒多目标触发计数，16种子合计：激光无前置B额外锁定342次，A/B额外连发714/605次；固定AA额外锁定387次，连发965/805次。导弹对应额外锁定90/113次，连发197/163和271/215次。额外锁定不增加规范攻击计数；导弹每次锁定复制整轮4弹。单目标额外锁定为0。逐种子、规范攻击/连发/锁定数及配对SD在corrected_rows.csv和paired_summary.csv。

## 原引用比较的窄修正
各4种子，保持原比较的有效等级、分支与10秒输入，仅将目标移入场地：
- 熟练10每1秒换目标：A2114.7/B1443.5 DPS，A赢4/4；熟练20对应A6874.9/B8478.1，B赢3/4
- 连发10多目标导弹：A2308.3/B4273.8，B赢4/4；连发20：A7852.2/B9014.9，B赢3/4
- 暴击10多目标导弹：A2718.2/B3141.3，B赢4/4

这些方向支持旧表述的情境差异，但不能把4种子当总体保证。生产多目标武器跨类排名及联合多目标数值均未重新确证。

## 复现与边界
运行时冻结ef848c50042a0ee326f8a823721204bac7d2eedc，脚本/数据与其逐文件一致，Godot4.6.3。配置来自原唯一表；仅夹具中按原规范化方式调整快激光伤害/间隔，导弹保持生产装备表。存档禁用，用户目录隔离，精确1/60秒tick。

新结果424行：连发30共384行，引用修正40行；初始继承出界几何的探索记录全部排除。配对种子不保证随机数消耗相同；重复比较/重叠种子不是独立总体样本。持续DPS按实际敌HP移除计算，有限目标TTK会受过杀、目标切换和飞行时间影响。没有FPS、全关卡推进或经济平衡断言。

从仓库根复现：
1. python test/run_enhancement_branch_benchmark.py --stage repeat30 --commit ef848c50042a0ee326f8a823721204bac7d2eedc --timeout 360
2. 将test/work/enhancement-balance-evidence/repeat30.json复制为repeat30-base.json
3. REPEAT30_SEED_SET=extra REPEAT30_ENEMIES=3 python test/run_enhancement_branch_benchmark.py --stage repeat30 --commit ef848c50042a0ee326f8a823721204bac7d2eedc --timeout 240
4. 将本次repeat30.json复制为repeat30-extra.json
5. python test/run_enhancement_branch_benchmark.py --stage corrected_cited --commit ef848c50042a0ee326f8a823721204bac7d2eedc --timeout 90
6. python test/summarize_repeat30_supplement.py test/work/enhancement-balance-evidence/repeat30-base.json test/work/enhancement-balance-evidence/corrected_cited.json --extra-seeds test/work/enhancement-balance-evidence/repeat30-extra.json
