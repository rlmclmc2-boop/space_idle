# 当前：宽扁装甲炮塔设计 04，等待外观确认

03941bf5的细长尖状设计已被否决。本轮先按正常整舰比例自查，旋转主体改为宽扁厚实的装甲炮塔，短细炮管只小幅突出。

1. [先看正常尺寸前后对比](../../art_sources/enemy-fleet-20261019/cannon-design-review-04/normal-comparison.png)
2. [八版整舰、转向与细节板](../../art_sources/enemy-fleet-20261019/cannon-design-review-04/design-board.png)
3. [设计说明与HTML入口](../../art_sources/enemy-fleet-20261019/cannon-design-review-04/README.md)

以上均是静态设计示意，未接入游戏。舰体和固定底座原PNG、生产资源、挂点和数值配置均未改。不合main，等外观确认。下方仅保留已否决的旧实机候选，不是当前送审图。

---

# 历史实机候选：45fe11a2（已否决）

7b081cee因原尺寸下仍像小灰团而未验收。本次继续同一任务，仅重画独立旋转炮：一体浅色后壳、宽深色炮管、连续钢灰方向面，删除小面板和细刻线。独立炮身宽度由暗凹槽的90%改为110%，壳体承载仍在原固定底座肩部内。舰体PNG、24个固定底座及坐标保持不动。

[原尺寸并排前后对比](compare.html)：1372×883原图按自然尺寸显示，无裁切/缩放/拼接；每张截图仍为独立PNG。也可分别打开下表的前后图。

| 舰体 | 精英：修改前 / 当前 | BOSS：修改前 / 当前 |
|---|---|---|
| 锚定 | [前](anchor-elite.png) / [当前](revision2/anchor-elite.png) | [前](anchor-boss.png) / [当前](revision2/anchor-boss.png) |
| 反应 | [前](reactive-elite.png) / [当前](revision2/reactive-elite.png) | [前](reactive-boss.png) / [当前](revision2/reactive-boss.png) |
| 护盾 | [前](shielded-elite.png) / [当前](revision2/shielded-elite.png) | [前](shielded-boss.png) / [当前](revision2/shielded-boss.png) |
| 指挥 | [前](command-elite.png) / [当前](revision2/command-elite.png) | [前](command-boss.png) / [当前](revision2/command-boss.png) |

当前[左转35度](revision2/command-boss-turn--35.png) / [右转35度](revision2/command-boss-turn-35.png)。固定舰体和底座不跟转；旋转图为实际暂停场景的贴图转向探针，不是该角度的射击结算验收。

所有截图均来自真实main.tscn，原窗口1372×883。隔离夹具关闭存档、保持血量、明确安装精英2炮/BOSS4炮，两普通护航仍各1炮。没有生产配装启用、数值倍率、攻击冷却或编队修改。蓝框只供QA测量。

当前源图及完整请求：art_sources/enemy-fleet-20261019/bold-cannon-source.png和bold-cannon-request.json。唯一舰体风格依据15a102ac；旧compact-gun-source.png留作未验收历史。导入器只做alpha清理/裁切/等比缩放/180度方向转换，记录实际轴心、炮口及源图粗炮管横截面；不程序重画。原生成文件保留在/workspace/generated_images/exec-84a5bfdb-68d5-48a0-bd9c-f3b86d0efb78.png。

当前验证和测量见[revision2/README.md](revision2/README.md)及该目录的ranked.json、summary.json、asset-check.json。根目录旧PNG/JSON是7b081cee对比基线，不代表最新候选。Linux Godot4.6.3隔离GDS场景，不声称native整场或性能验收。未合main，待外观审阅。
