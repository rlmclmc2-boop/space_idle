# enemy-grid-rank-audit-20261019
只读核查，基准ba31b3c2；未修改游戏代码、编队、表或入场逻辑，不跑游戏测试。
结论：旧15槽是最多15个非空actor锚点，不是已按1/4/6物理格消耗设计。enemy_formation.positions每个非空源slot产生一个位置，按size排序放后排/中央，没有多格占地字段。全体源组非空actor数均≤15。
原标记：group.combatTier为normal/elite/boss/ultimate；game.encounter_tier读组tier（缺省只在关底回退boss），spawn_group将wave tier复制到每舰combat_tier并设置boss布尔。publish_encounter_geometry仅在boss/ultimate挑最大size单舰，持久化encounter_leader，不在死亡后晋升护航。源敌舰行没有独立elite/rank/tier/boss字段。
新增判定问题：enemy_grid_layout.footprint将所有非leader且size≥4当2×2精英，这是此次新增的推断，非原有精英标记；确实将普通组33010的271019大舰扩大成精英。此前188是这套新增假设的占格需求统计，不能称为原编队超编，也不能据此证明188组需改表/减舰。187组虽是elite波次，但没有独立证据把其中两个size4认定为两艘舰级精英。
组33010: combatTier=normal; slots=[null,271013,271013,271013,271013,271013,271013,271013,271013,271013,271013,271013,271013,271019,null]; 原13舰，新假设按size4 [271019]各4格、其余12舰各1格，合16格。源行无个体精英/BOSS字段。
组1009: combatTier=elite; slots=[1043,1044,1045,1044,1043,1046,1047,1047,1047,1046,1047,1047,1047,1047,1047]; 原15舰，新假设按size4 [1046, 1046]各4格、其余13舰各1格，合21格。源行无个体精英/BOSS字段。
组1010: combatTier=elite; slots=[1048,1049,1050,1049,1048,1051,1052,1053,1052,1051,1054,1055,1056,1055,1054]; 原15舰，新假设按size4 [1051, 1051]各4格、其余13舰各1格，合21格。源行无个体精英/BOSS字段。
BOSS对照1017: combatTier=boss，15槽中仅slot7=1087(size5)，其余null；游戏会将该舰选为encounter_leader，候选3×2=6格。这个BOSS判定来自真实leader字段，和size≥4精英推断不同。
定位：scripts/enemy_formation.gd:positions；scripts/game.gd:encounter_tier/publish_encounter_geometry/spawn_group；scripts/enemy_grid_layout.gd:footprint；data/game_data.json groups1009/1010/33010/1017。下一步由父线程/用户明确舰级精英对应规则，本轮未改代码或分批策略。
