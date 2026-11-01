# 2026-11-01 每日资料清理结果

静默执行日志。审核主体为本整理执行者的文档/版本/哈希静态检查；没有新增游戏、视觉、性能或独立复测，也未重开已取消的全游戏历史调查。

## 已实际推进的分支

以下均为原分支单父、仅资料清理提交，普通push后逐分支ls-remote回读一致。没有操作原组工作目录、覆盖现场WIP或合入功能代码。

| 原分支 | 本轮提交 | 移出保存资料 | 更新文稿 |
|---|---|---:|---:|
| `main` | [`61bde20c1d96167624379ceed41cb0293bb00119`](https://github.com/rlmclmc2-boop/space_idle/commit/61bde20c1d96167624379ceed41cb0293bb00119) | 141 | 11 |
| `art/equipment-materials-main-20261029` | [`fb28b60ef8b35c236b15bedb4590dffbc1e7b556`](https://github.com/rlmclmc2-boop/space_idle/commit/fb28b60ef8b35c236b15bedb4590dffbc1e7b556) | 0 | 14 |
| `implement/reactor-centered-godot` | [`4278ef9334cf313c0a1ab4ae4ab321fc6b464f96`](https://github.com/rlmclmc2-boop/space_idle/commit/4278ef9334cf313c0a1ab4ae4ab321fc6b464f96) | 1245 | 12 |
| `design/clear-zone-host` | [`912f5924ab7eb5082703108264f4378b3c9a435a`](https://github.com/rlmclmc2-boop/space_idle/commit/912f5924ab7eb5082703108264f4378b3c9a435a) | 73 | 5 |
| `feat/amount-safe-previews` | [`3dd45f5761d04251bb55478c34898781f8a4d0c3`](https://github.com/rlmclmc2-boop/space_idle/commit/3dd45f5761d04251bb55478c34898781f8a4d0c3) | 1 | 3 |
| `feat/planet-single-side-ui`（原组实际消费） | [`c375d26ea80dd653f2b5ad068a220d9e48d36cba`](https://github.com/rlmclmc2-boop/space_idle/commit/c375d26ea80dd653f2b5ad068a220d9e48d36cba) | 1346 | 6 |
| `docs/design-entry-cleanup-20261031` | [`8e6d5af48db9384cdebd5add54c9754a0165d254`](https://github.com/rlmclmc2-boop/space_idle/commit/8e6d5af48db9384cdebd5add54c9754a0165d254) | 0 | 7 |

装备为清除历史导航、失效状态和修复当前规范入口，未再改已合main的运行物；反应堆、公共壳及后台分别移出确认保存资料。本工作区文档分支已快进。根线程后续确认：反应堆原工作区已快进4278ef93、整体原工作区已快进912f5924，均clean；这是原组现场报告，本线程另核远端SHA一致。星球原组已实际消费并推送c375d26e。装备与后台工作区是否拉取未另作声明。

## main 实际发布

父协调核差异范围、最新授权和152路径归档后，明确继续既有main纯清理。发布前fresh fetch确认main仍为`e845ca58afd39184c3d4c5743021480e393adf74`，候选唯一父与范围未变；随后普通快进推送`61bde20c1d96167624379ceed41cb0293bb00119`并fresh fetch／ls-remote回读一致，没有force、功能合并或保护绕过。远端树与候选完全相同，141件保存资料已不在main，11份文档已更新；152个修改前路径仍与归档blob一致，当前设计入口本地目的文件全部存在、旧历史导航已去除。源码、配置及实际资产未变。[发布回读与可恢复性](main-publication.json)。

此前未发布的原因是本整理执行者自行把“parent reviews before main merge”泛化到每日纯清理，并非遇到权限、分支保护或审批拒绝；本次不再保留“main未根审／未实际清理”的当前状态。main清理包含移除已裁定失效的ConfigBundle加载/查询包装和保存配置hash命令，不改变实际实现。星球两张批准图及原组站体WIP保留；用途未明制造资料仍保留，不能声称全仓历史已全部清零。

## 原组消费回执

星球实际提交`c375d26ea80dd653f2b5ad068a220d9e48d36cba`移出1346件、修改6份；其tree `62bb50e24a9d8582222e97b01b3d6be96e9f1def`与准备候选`0a606e5f6a4eee36446a7f843e1809ec4e6fa31e`完全相同。本线程核了单父、文件计数、远端完整SHA及两张批准图仍存在。原组报告1352条来源映射、1335个唯一blob SHA256复核，并保全站体脚本/blend/glb WIP；该哈希与现场保全结论明确归原组，不冒称本线程新增现场复测。反应堆、整体原工作区已快进且clean由根转交，远端分别仍为4278ef93／912f5924。[完整消费回执](consumption.json)。

## 最新状态核对与保全

装备运行源e845ca58本轮完成；main现为其文档清理后继61bde20c，运行字节不变；反应堆0bc17ae4 R12仍只记录作者证据、没有独立整页/目标硬件性能通过；公共壳2d4cb2af仅R12源闭包准备。星球取回acccaf4c时已至14e342c1 R114，未使用任务初始R112/R113作为最新结论。本轮11与当前路由不再沿用ee802997中的装备返修/B01旧退回作为当前状态。

先推送保全提交`3d983bf93594188805f5e808574dd471874c7160`并fresh fetch回读，再生成制作树清理提交。共2864条来源记录、1393个不同Git blob；原固定源、归档路径Git blob与逐字节SHA256全部一致。原始资料复用既有archived-sources；修改前入口及缺失版本保存于corrections/20261101-cleanup。既有R12/R114独立证据包未改，不把目录存在或本次hash检查说成媒体视觉复审。

[逐文件来源/哈希](preservation.json) · [精确最终计划](plan.json) · [发布及验证结果](result.json) · [未决保留项](held-items.json)。

七个候选合计检查2428个本地文件引用、671个本地锚点及22个固定Git目的文件，均无缺失。修复了装备与反应堆原有断开的当前合同/入口链接，未从旧候选恢复第二套规范。所有候选diff --check通过，非文档生产源码/配置/实际资产blob完全不变。

制造元数据中仍有用途未完全排除的内容（例如control-materials-sources.json内runtime_regions）；按本轮要求保留，不声称所有分支全部留档物已经清零。原组确认消费用途后才能移出纯保存部分。没有拒绝、待批准网络动作或结果不明的写入。
