# 暂定51aae1ac素材 +07覆盖 · 候选接入实机证据

用户暂定当前造型并停止改稿。本次导入已定素材与07已确认覆盖尺度，沿用原隔离展示，不生成新图，不启用生产1/2/4配装，不合main，交父审。

| 舰体 | 精英2炮 · 原窗口实机 | BOSS4炮 · 原窗口实机 |
|---|---|---|
| 锚定 | [实机图](anchor-elite.png) | [实机图](anchor-boss.png) |
| 反应 | [实机图](reactive-elite.png) | [实机图](reactive-boss.png) |
| 护盾 | [实机图](shielded-elite.png) | [实机图](shielded-boss.png) |
| 指挥 | [实机图](command-elite.png) | [实机图](command-boss.png) |

[指挥BOSS -35度](command-boss-turn--35.png) / [+35度](command-boss-turn-35.png)。全部10张为实际main.tscn的1372×883原窗口PNG，未裁切/缩放/拼图。额外转向帧沿用原夹具功能；只有炮身区域像素变化，固定舰体和底座不转，差异范围见summary.json。

## 接入

素材为51aae1ac的cannon-em-appearance-review-10/cannon-design.png，逐字节相同。prepare_ranked_assets.py仅技术性清理alpha、裁切、等比缩放并旋转180°为down-forward；runtime路径保持assets/weapons/integrated_ranked_20261020/cannon-rotating.png。独立PNG不带固定底座，不程序重画，manifest记录轴心与嵌入式发射口。

逐底座覆盖直接采用07测量的外承载面95%目标及舰体边界限幅后的源画布/UV宽度，写入武器manifest.coverage。24个静态底座坐标、舰体展示大小不变。原最小暗凹槽比例不再作为尺寸上限。实际像素宽由当前游戏rect和屏幕变换决定，本次为17.4–23.6px；没有按旧静态设计板的估算像素再次放大。

已有隔离夹具明确安装2/4 cannon-mon用于八版展示，两普通护航仍各1武器；数值1/2/4只保留接口。夹具为每个presentation component复制可视profile，按对应尺寸计算发射口，生产profile不变。QA-only renderer在canonical路径按该component端口画同一纹理；retained body节点接受独立尺寸/端口元数据，保持原生产绘制流程，不改production脚本。

## 本次直接验证

资产检查一次通过（asset-check.json）：选中源PNG/哈希/alpha/方向、轴心和发射口、07覆盖精确映射；八舰体和24底座冻结。原隔离夹具一次实际图形运行932检查0失败（内含既有438身份/接口检查，没有另开独立单测/复测）。首次实际49次开火、62次命中。原始日志run.log和逐舰逐炮结果ranked.json；汇总summary.json。

已检查精英retained和BOSS canonical实际效果、2/4独立组件、炮图pivot与固定底座精确对齐、默认图发射口与隔离live muzzle对齐、07归一覆盖、展示框/名称/血盾、互不重叠及0/±55度框内，另导出原有±35度转向帧。预期armour mismatch负向warning保留，无SCRIPT ERROR/FAIL。Linux Godot4.6.3/GDS隔离场景；native identity/view仍只是原夹具内函数桥接，不声称native完整战斗或性能验收。

相对51aae1ac，8张舰体PNG逐字节不变；舰体manifest去除独立gun字段后完全相同；ship_weapon_visuals.json只更新未启用的movable_gun描述，所有其他行、武器profile、active硬点/槽、1/2/4接口点与计数均不变。生产scripts/game_data/Excel、伤害/冷却/倍率、编队/船中心判定不变。存档关闭且使用隔离XDG目录，未接触用户存档。无执行阻塞，候选未合main。

复现入口保留：python space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py；ENEMY_RANKED_EVIDENCE指定证据目录后python test/check_enemy_ranked_assets.py；原test/test_enemy_ranked_art.gd复制进隔离工程，RANKED_OUTPUT指定输出目录图形运行。这里只记录本次已有执行，不安排后续独立复测。
