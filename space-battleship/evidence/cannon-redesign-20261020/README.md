# 独立炮身重做候选

用户认可舰体、否决上一版炮的外观。本分支仅替换旋转炮贴图：收拢白色侧甲为整体壳体，使用更粗的深色炮管和大块明暗面。八张舰体PNG、24个固定底座及接口坐标均与419d5687完全相同。

| 舰体 | 精英2炮 | BOSS4炮 |
|---|---|---|
| 锚定 | [原窗口](anchor-elite.png) | [原窗口](anchor-boss.png) |
| 反应 | [原窗口](reactive-elite.png) | [原窗口](reactive-boss.png) |
| 护盾 | [原窗口](shielded-elite.png) | [原窗口](shielded-boss.png) |
| 指挥 | [原窗口](command-elite.png) | [原窗口](command-boss.png) |

[左转35度](command-boss-turn--35.png) / [右转35度](command-boss-turn-35.png)。全部10张为真实main.tscn的1372×883原窗口PNG，无裁切、缩放、拼图。隔离预览关闭存档、保持血量、明确装入2/4炮；两普通护航各1炮。转向探针只旋转炮贴图，不是转向角射击结算验收。

源图compact-gun-source.png由imagegen生成，完整请求compact-gun-request.json保留在art_sources/enemy-fleet-20261019。原生成文件保留在/workspace/generated_images/exec-9c41a322-12e4-48e8-a60f-1dc234d37c6e.png。导入器仅清理alpha/裁切/等比缩放/方向转换，并更新炮轴心、炮口元数据；不程序重画。runtime仍为assets/weapons/integrated_ranked_20261020/cannon-rotating.png，独立旋转，无追加固定底座。

最小验证：资产检查通过；与419d5687逐字节比较，8舰体PNG、所有底座坐标、production scripts/data/config_excel均未改。实际主场景908检查0失败，41次开火/53次命中；炮图轴心与底座重合、默认炮口匹配、0/±55度在框内、壳体不互叠、±35度转向仅改变四个炮身附近像素。详细结果见ranked.json、summary.json和asset-check.json。预期armour mismatch负向warning保留，无SCRIPT ERROR/FAIL。Linux Godot4.6.3，隔离GDS预览；未做native完整战斗或性能验收。

数值1/2/4仍仅接口；生产装备、伤害、冷却、倍率、编队不变。未合main，等待视觉审阅，无执行阻塞。

复现：python space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py；ENEMY_RANKED_EVIDENCE指定新证据目录后运行python test/check_enemy_ranked_assets.py。将test/test_enemy_ranked_art.gd复制进隔离工程，以RANKED_OUTPUT指定截图目录，图形运行godot --script res://test_enemy_ranked_art.gd。
