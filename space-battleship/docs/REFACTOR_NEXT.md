# 第五段唯一续接入口（仅交接，尚未开始实现）

最终远端 main 基线：`19c9cfdf98e8bbef44ffebcd5ba09bff55fdec6a`，已正常推送并回读确认。

第四段代码候选 `e7db96bf0ab62d0608d6c360deef40941d44405d`、验证证据 `ad39f2dbe0ee8e2d862a087865c646132bfe498a` 已获 dot 与现有 Astra high 范围一致 PASS。main 过滤交付仅包含 `scripts/crew_system.gd`、`scripts/game.gd`、既有 `test/test_crew_dirty.gd` 与 `test/test_planet.gd`；这四个文件与已审候选逐一相同，docs/logs 未进入 main。

第四段合入前验收通过：既有 `test_ordinary_entry.gd --scenario game`，非 headless，导入成功；原 `main.tscn` 首启 26/0、重开 18/0、领取后重开 7/0，两次恢复 `mismatches=[]`，截图已检查。此为真实主场景及真实 writer 路径验收，不声称已验证 `play_main.py` 发布启动器。

未解限制：`test_save_boundaries.gd` 的科研恢复断言 `Real reopen restores selected research, paid progress and input to its owner` 在候选及原基线 `27681c38` 均失败；四阶段同为 write 31/0、reopen 30/1、latest 17/0、recovery 19/0。已证实非第四段新增，根因尚未定位，不能据此判定是测试还是游戏缺陷。没有删除断言或扩修。

本轮到此停止实现。后续获准执行时，先从 Git 读取此入口及 AGENTS.md，确认远端 main，保护个人存档与脏工作区。第五段从上述最终 main 基线继续，不重做第四段；本入口不表示已授权实施第五段。

## 第五段目标与边界

- 由现有启动边界持有一份舰队静态描述符，`presented_ship_view` 与 `logical_fleet_pose` 共同读取。
- 删除两处重复图片扫描及挂点准备；`capture_preparation` 保留实例专属初始姿态。
- 静态结果不含 Node、Game、实时成员或可变姿态。
- 保留已有敌舰纹理缓存。
- 不做跨实例全局缓存、泛化框架、热加载、玩法尺寸或 GPU 改造。
- 不修改无关资产、配置数值、个人存档，不使用 Library。

## 验证与交付

按实际改动复用既有炮位、生命周期、正式入口首启／重开验证；使用隔离项目及隔离存档，保留既有断言，失败先定位，不为通过而扩修无关问题。运行规则以仓库 AGENTS.md 与定位到的既有验证入口为准，不新建测试体系。

实际执行沿用 Astra medium，架构与审计沿用 high。提交可审查 Git 候选，交由 dot 与现有 Astra high 双审；不得自行越过双审合入 main。上下文开始压缩即提交交接并停止。本文件仅在候选分支交接，不进入 main。
