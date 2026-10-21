# S12 中途证据与待裁定设计

当前运行候选 `1f7c160e`（完整 SHA 见 Git）；阶段仍开放，不能据此验收或合入 main。父级和原 astra 已将本次新编码直接破坏的分析器消费者纳入 S12，有限域算法和购买顺序未调整。

| 直接消费者 | 入口及失败链 | 本次最小适配 |
|---|---|---|
| `player_loadout_generator.gd:upgraded_profile` | fleet runner 调用；`module_level=100, delta=120` 使 220 级 laser 报价为整数字典，旧 `float(costs[id])` 报错；进化材料原先误放入 resources | 按资源/材料所属钱包补足；整数报价走精确比较，普通有限值维持原 `maxf`；材料超出现有 int64 域报告错误 |
| `balance_autoplayer.gd:act/buy_scientist` | Balance Lab 正常策略路径，费用/余额比率及随后钱包读取直接 `float(dict)` 报错 | 有限投影计算原比率和原评分；材料从材料钱包读取；不可投影时标记错误并停止本次策略 |
| `balance_metrics.gd:spend/sample` | 升级事件 `balance_game.observe → on_event → spend`；采样读取购买后余额 | 报表有限投影；不可投影时记录错误，runner 返回错误状态，不写入假 0/INF |
| `balance_game.gd:generate_scientist/upgrade_reactor` | 购买后直接读取资源余额以计算报表支出 | 用差额的有限投影；不可投影时记录错误；普通有限域继续原支出统计 |

`probes/audit_s12_consumer_probe.gd` 和 `logs/consumers.log`：原 laser 220 输入、生成器升级、材料钱包归属、策略投影、支出事件投影通过，`S12_CONSUMERS failures=0`。`probes/audit_s12_transactions.gd` 与 `logs/transactions-recheck.log`：材料精确余额 `9007199254741003` 真实购买、便携 JSON、导入校验、重新加载保持单位；后续 `+1/-1` 精确；材料退款越出现有 int64 域时无钱包副作用，37/37 通过。

## 未实施：远距离旧钱包的紧凑精确交易

当前候选的 `MAX_EXACT_WALLET_DIGITS=8000000` 预检仍会永久拒绝原合法 `{m:1,e:1000000000}` 钱包支付小额报价。16 MiB 是整份便携文件限额，不能拿它作为所有交易的钱包位数上限。此项仍是 A07 阻断，尚未声称通过。

供父级和原 astra 审核的最小工程方案：保留旧 `{m,e}` 为基值，新增有版本的紧凑钱包表示 `{v:2,base:{m,e},delta:{v:1,i:"..."},sign:-1|1}`，其中 `delta` 是累计精确整数差额，保持远距离指数基值不展开。比较与可支付性先比较指数/前缀；当报价接近基值时才局部展开并规范化为已有精确整数。远距离扣费、收入、退款更新有符号差额，零差额恢复旧形状。保存、便携校验、重载均识别版本并保持基值与差额，普通数值域继续原路径。`GrowthNumber` 的 `valid/parts/compare/add/subtract` 及资源收入链必须识别该形状；UI 文本须标识或正确投影，不能把小额变化静默四舍五入为已经消失。材料钱包沿用独立 int64 规则，不套用此资源钱包表示。边界输入若无法精确计算，必须在真实交易副作用前明确拒绝，并列出具体原因，而非建立新的永久游戏上限。

此为评审方案，不是已批准的存档契约或运行代码。需确认相邻消费者和旧存档恢复语义后才实施。S20 整体模拟评分政策不在本设计内。

## 已授权的分支清理收据

父级先核验四个旧远端分支相对当前 main 均无独有提交，用户随后明确允许删除无用分支。本线程只对 `s06/analyzer-deps`、`s07/reactor-cache`、`s08/config-recovery`、`s10/reactor-numeric` 执行 `git push origin --delete`；Git 返回四个 `[deleted]`，随后 `git ls-remote --heads origin` 查询四名均无输出且退出 0。main、审计和 S12 候选分支未删除，本地未提交文件未清理。
