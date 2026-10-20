# 最终八舰与炮塔 · 精简发布候选

基线108080a7，最终内容来源707981f3。本分支只保留最终八舰、最终旋转武器、必要表现/只读接口与原隔离展示、复现来源和末次证据。[精确文件清单及功能差异](RELEASE_SCOPE.md)。否决中间稿、设计HTML板、重复报告和旧试验文件均不进入本候选。

| 舰体 | 精英2 · 原窗口实机 | BOSS4 · 原窗口实机 |
|---|---|---|
| 锚定 | [实机图](anchor-elite.png) | [实机图](anchor-boss.png) |
| 反应 | [实机图](reactive-elite.png) | [实机图](reactive-boss.png) |
| 护盾 | [实机图](shielded-elite.png) | [实机图](shielded-boss.png) |
| 指挥 | [实机图](command-elite.png) | [实机图](command-boss.png) |

[指挥BOSS -35度](command-boss-turn--35.png) / [+35度](command-boss-turn-35.png)。10张均为707981f3末次运行的1372×883原窗口PNG，逐字节保留，未裁切/缩放/拼图。ranked.json为同一次原始结果：932检查0失败，49次开火/62次命中，存档关闭、QA显式安装2/4炮、两普通护航各1炮。本次重打包没有重跑图形夹具或安排独立复测。

## 重打包验证

本分支上用自包含的最终输入重新导入，9张运行PNG全部与707981f3字节相同，素材检查通过。3个生产表现/接口脚本、QA renderer和GDS夹具与707逐字节相同；渲染元数据及展示配置只改来源路径，绘制字段值等同。因此保留的实机证据对应相同运行素材/绘制代码，不声称是新跑出的932检查。哈希和准确例外见repackage-check.json。既有native检查只是函数桥接，无native整场或性能声明。

复现资产：python space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py。素材检查：python test/check_enemy_ranked_assets.py（ENEMY_RANKED_EVIDENCE可重定向生成JSON）。原test/test_enemy_ranked_art.gd保留用于隔离Godot4.6.3工程/XDG目录中复现截图；本次未安排新的图形复测。

## 功能范围

相对108080a7，生产修改仅为最终八舰登记、按已发布tier/leader选图、展示尺寸适配，以及只读1/2/4接口。原active挂点/槽、武器profile、装备数量、伤害/CD/倍率、模拟几何、船中心判定、actor size和编队均不改。生产1/2/4配装未启用，2/4只在原隔离夹具中展示。

父线程main快进被自动审批拒绝，原因是707981f3有229个变更文件，超出所描述范围；main未改变。本轮仅准备精简候选，不合main、不代父线程重试被拒操作。
