# architecture-cannon-cost-20261024
目标：统一近似批量费用；按main实际普通炮/Higgs行为更正文档。
基准：06126185223d9f860cb0187c31895d19002fa8c1；事实基准main b4729b9a9803458b5ac19a4945c2fe0d5f76e51f。
范围：仅README与02～07相关正文、测试定义及自身归档；未改游戏/Excel、未合main。
完成：下一等级Q单价作锚、全数量Amount几何和、MAX同报价；删除逐级前缀和上下界双报价；说明分批报价差异且不补差。
完成：我方普通炮发射同次即时命中；Higgs冻结射线/命中点、同次按距起点结算；敌炮飞行接触、连锁到达结算独立保留。
证据：battlefield.gd:7实际装配presented_battle_game.gd:142；game.gd:2332/2344及rail_geometry.gd冻结带宽/候选；combat_execution_kernel.h:1511原生普通我方炮即时命中。所读源码与main基准无差异。
验证：十篇Markdown链接/围栏/八组待决引用通过，git diff --check通过；费用例65/143/140直接列入测试定义。未运行游戏测试。
待决：原八组不变；本次两项不新增歧义。独立分支提交推送，父线程检查后交付。
