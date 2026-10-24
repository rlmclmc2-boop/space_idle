# architecture-decisions-20261024
目标：九项已定玩法直接进入运行正文和配置映射；只文档。
基准：e3750a31e0d6d0cb1c83ec31a8c8009fd69c20ca；分支design/game-architecture-from-main-b4729b9。
完成：README及01-09同步。进化保留、禁止第二代连发、暴击0/必暴无爆伤无二抽、超空间1层免费/探索至少10秒、星系平均每秒、仅本步任务完成尾段舍去、保留排序、加载新战场/导入离线微粒、普通价格分批一致。
费用：普通<1e15按同价等级段累加既有单价，全用Amount；极端整批max(T,rawSum)几何和，恒价直接线性，无隐账或4096前缀。
计时：删除独立advance_status，所有战斗效果到期只由native推进一次；即时炮仍在出生调用内命中。
配置：09新增目标字段表；覆盖总表至EOF含旧字段值/指纹与基准逐字符一致。equipment_evolution字段按现存JSON映射，其他已删成长项不恢复。
验证：十篇Markdown链接/围栏通过，旧D编号和advance_status残留为零，git diff --check通过；父线程独立检查通过。
交付边界：仅设计及自身归档，不改xlsx/JSON/游戏，无游戏测试、不合main；无未决玩法选项，实施仍需用户授权。
