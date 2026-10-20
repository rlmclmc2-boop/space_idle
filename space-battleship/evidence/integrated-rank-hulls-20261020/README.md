# 新确认稿：融合固定底座 + 独立旋转炮身

唯一设计依据：15a102ac3bee1b43d14e6f9666b8f19c10b21a06的integrated-turret-bases-approved-20261020.png。分支从6fe75f56开始，不包含已否决ca60668b及炮位微调提交。8张旧升级runtime底图已被新融合结构替换，旧挂点已被新图24个固定底座凹槽的实际像素中心替换。

| 舰体 | 精英：融合2底座、独立2炮身 | BOSS：融合4底座、独立4炮身 |
|---|---|---|
| 锚定 | [实机图](anchor-elite.png) | [实机图](anchor-boss.png) |
| 反应 | [实机图](reactive-elite.png) | [实机图](reactive-boss.png) |
| 护盾 | [实机图](shielded-elite.png) | [实机图](shielded-boss.png) |
| 指挥 | [实机图](command-elite.png) | [实机图](command-boss.png) |

[指挥BOSS炮身左转35°](command-boss-turn--35.png) / [右转35°](command-boss-turn-35.png)。与正向图比较，只有四个可动炮身附近像素变化，其他场景像素完全相同，固定甲板/底座不跟转；差异像素数量和范围见summary.json。转向补图是实际暂停场景的贴图旋转探针，不作为该角度射击结算验收。

全部10张PNG为实际main.tscn默认1372×883原窗口输出，未裁切/放大/拼图。QA关闭存档、保持血量，实际交火后暂停并清理瞬时弹道/浮字。蓝框/规格标题与按舰名构造的BOSS标题仅在隔离夹具中，不改生产文案或编队表。

## 资产拆分与接入

1. imagegen只参考本次15a102ac确认稿生成integrated-empty-bases-atlas.png：保留甲板、白灰结构肩、酒红八角固定底座、深色轴心凹槽，移除可动白色炮身与黑炮管。24个固定底座是舰体像素的一部分，不由Godot程序绘制或追加圆盘。
2. integrated-gun-source.png是单独可动白色炮身/黑色长炮管，未包含固定酒红底座。runtime为assets/weapons/integrated_ranked_20261020/cannon-rotating.png；manifest记录机械轴心与真实炮口。敌舰用down-forward资源，源图仅技术性旋转180°。
3. prepare_ranked_assets.py按8个独立连通舰体隔离源像素，清理alpha边缘、等比归一化到887×1774；测量每个底座暗凹槽中心，生成source/canvas/UV坐标与凹槽宽度，自动同步仅美术display_size和未启用接口。不会用旧素材/旧点阵替代，也不程序重画舰体。源图与两份完整生成请求保留在art_sources/enemy-fleet-20261019。
4. 精英2×2/BOSS3×2展示框、42/60顶部血盾/名称预留保持；每种舰体的两档用同一源像素尺度在原框内等比显示，保留新稿相对体量关系。实际body allowance写入display_size，没有横向拉伸、没有编队占位规则。
5. dev/qa/integrated_turret_preview.gd只画独立炮身纹理四边形，围绕机械轴心旋转，不画第二个底座。隔离适配器按静态凹槽宽度的90%设置白色炮身宽度，并在内存复制可视炮口向量，使贴图枪口与live muzzle一致；生产武器参数没有改。

## 范围与验证

数值仍只接口：normal1/elite2/BOSS4的slot_counts不变。生产没有自动应用接口；game_data/Excel、装备条目数、damage/CD/倍率、原生产炮口profile和active硬点/slot_map、编队脚本与逻辑位置不变。普通8舰PNG逐字节保留。仅升级贴图、展示体量和预留底座坐标/独立炮身资源更新。隔离场景显式安装2/4炮、两艘普通护航仍1炮。候选不合main，待父审。

资产检查通过：8图true-alpha/比例/连通组件/核心/来源hash，24底座数量与像素/UV/接口一致；独立枪体RGBA/方向/机械轴心/炮口与hash；新源图逐字节等于父交接15a102ac。旧普通图/原几何、生产挂点/slot_map及所有数值/编队文件冻结检查通过。

主场景908检查0失败（含438身份/只读接口检查）：精英2/BOSS4独立组件；枪身pivot精确重合静态底座中心；默认贴图枪口精确匹配隔离live muzzle；炮身约11.6–14.1屏幕像素宽，住房不互叠；0/±55°纹理包围框在展示框内、转动住房有底座肩承载；血盾/名称与源alpha中心保持。首次实际45次开火/55次命中。负向armour mismatch warning是预期，无SCRIPT ERROR/FAIL。native authority/view选图与尺寸为函数级桥接验证，Linux Godot4.6.3 llvmpipe/GDS；不声称native整场或性能验收。

复现：python art_sources/enemy-fleet-20261019/prepare_ranked_assets.py；python test/check_enemy_ranked_assets.py；python test/check_enemy_base_eight_assets.py。隔离工程复制test_enemy_ranked_art.gd到res://，图形运行RANKED_OUTPUT指定test/work本次目录；RANKED_UNIT=1可headless单测。只改美术及接口/隔离展示，不扩展共享伤害组合或编队密度验收。无执行阻塞。
