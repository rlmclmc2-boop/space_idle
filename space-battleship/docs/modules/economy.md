# 资源与掉落

## CONFIRMED · 原表

res!A4:B5 定义铁、钛，JSON resources 为资源 ID → 名称。mon!G4:G9 为 `{id,数量,概率}`；总览!A7 规定鼠标划过全额拾取，超时自动拾取有损耗，损耗参数在 config!A7:C7。关内资源倍率见 [map](map.md)。

## CONFIRMED · 当前代码

`hit_enemy()` 死亡后逐条以 rng.randf()<chance 决定掉落，数量乘敌机生成时记录的 res_ratio，完成掉落计算后向上取整为 amount；没有额外通关奖金。掉落字典为 uid/x/y/age/id/amount，标签直接显示该整数。
`collect(manual)`：手动全额拾取；自动以整数 amount 乘 1-config.autoCollectReduce 后独立向上取整一次。profile.resources、run_resources 与 collect 事件共用同一结算量，提示由该事件生成，随后保存。

## CONFIRMED · 用户规则（2026-09-13 本次资源任务）

资源无小数，各资源计算完成后向上取整，中间计算不取整；自动拾取减免独立于掉落计算，单独取整一次，显示与实际获得一致（来源：同日用户最新指令“自动拾取的减免独立于这个规则”）。例如掉落 3×1.1 向上取整为4，自动损耗40%后 ceil(4×0.6)=3，提示与入账均为3。该指令替代此前倍率与自动损耗合并取整的规则。起始资源及旧存档余额在读入时向上取整；最终升级成本见 [progression](progression.md)。不改变非资源运算。
`collect_near()` 在未暂停时拾取鼠标周围距离<55 的掉落。超过 defaults.autoCollectDelay 自动拾取；换关、leave、关闭游戏会以自动系数结算残余掉落。默认等待/拾取半径为实现补充，来源边界见 U-005/U-006。
升级消耗归 [progression](progression.md)，原表值不在本文重复。

追踪：mon/res/config → JSON enemies.drops/resources/config → game.hit_enemy/collect/settle_drops/collect_near → test_game Hover collects、Timed pickup、Exit settles。新资源兼容性见 U-007。
