# enemy-grid-fit-20261019
基准02725575；最终范围只交现有敌方区域5列×3行网格实图及尺寸，不改舰体比例/生产配置，精英BOSS多格规格未展开。
范围：QA夹具test/test_enemy_grid_preview.gd及evidence/enemy-grid-20261019；只读main的BATTLE_VIEW_SIZE/创建draw层、enemy_fixed_layout固定15舰纵向范围及现有8舰QA fixture。
测量：完整战场572×960；敌方带从battle clip顶部0至原15舰fixed_rows前沿960×0.52=499.2。top100是单位中心内缩，不是整块区域起点。区域572×499.2，5×3单格114.4×166.4逻辑单位。原始PNG1372×883，投影单格80.408×116.983实际像素，独立像素线检测为列80–81、行117。尚未扣血条/状态，也未计算舰体可用框。
验证：真实main场景，沿用8舰原尺寸原位置、存档禁用QA编队，双方发射并结算伤害后暂停截图；PNG原始输出未裁切缩放拼贴，15格/6竖4横线检查通过。git diff027对scripts/data/assets/config_excel/addons为空。Godot4.6.3 Linux llvmpipe/GDS路径，仅预览标尺不作原生性能结论。
交付：同独立art/enemy-base-eight-static分支追加最小提交，不合main；无剩余阻塞，后续尺寸/多格方案按看图后的新范围处理。
