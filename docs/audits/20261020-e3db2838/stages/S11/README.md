# S11 装备报价大数原型（待双审）

基线 main `31e79337741bf9860d69fff21dae6be994dacd00`；冻结契约 `0442a1b627a07fa1af0d0671cdeb97dd070c5efc`；前置 S10 closed 审计提交 `852d8b9af92cf922b010b2ed2b7555e26cffd0c8`。本阶段仅审计侧文件，运行 SHA `N/A`，main 未改。审计分支中的 `space-battleship/test/audit_s11_equipment_quote.gd` 是供 S12 移入正式路径的候选，不由游戏加载。

## 实现与旧接口映射

| 原接口或消费者 | S11 候选 | S12 接入位置 |
|---|---|---|
| `database.gd:68-95 equipment_cost/equipment_growth` | `quote_row(row, target_level, evolution)`；一级、无整数后缀或无倍率时直接 ceil 基价；有限域逐字保留 float 公式和顺序；溢出后才用十进制整数乘积、同一两位量级量化及最终 ceil | 由数据库提供 level=1 行，正式报价映射到每种货币 |
| `game.gd:926-936 upgrade_costs_for_level` | `batch(row, current, count, evolution)`，逐目标级调用 `quote_row`，每币种用 `ReactorInteger.add` 累计已取整单价 | 替换 float 总价累计；保留缓存签名和范围核验 |
| `game.gd:948-955 can_afford_upgrade_costs` | `affordable(wallet, costs)`；整数钱包精确比较，历史 `{m,e}` 钱包使用 S10 整数比较 helper | 交易前复核和 MAX 判定共用报价对象；保留材料解锁 guard |
| `game.gd:960-970 refund_equipment` | 逐目标级同一 `quote_row` 可给出返还额 | S12 用正式报价函数替换旧 `upgrade_cost_for_level` 的成本来源，保留原退款起点和事件 |

高阶按 `base × (1+multi)^(level−1)` 求目标级原值，不逐级递推**报价**、不求未量化几何和。精确十进制乘积采用现有 `ReactorInteger.cost_cursor`：其输入系数是 Godot binary64 操作数的十进制表示；原 float 已不能表达结果的域内，舍入取前两位和被舍弃的首位，恰好实现旧 `floor(v/step+0.5)×step` 的量级规则。各级价格和批量总价是现有 `{v:1,i:"..."}`/int 形式的整数，可与旧 `{m,e}` 钱包比较；缩写文字不参与比较。

测试脚本 `space-battleship/test/audit_s11_quote_test.gd` 调用真实 `ShipDatabase.equipment_cost` 逐项对照普通域，并读独立 `reference_oracle.py` 生成的 `audit_s11_quote_oracle.json` 对照 3873 级和 3901–3910 全溢出批量。受控行检查 99.9/100/149/150、一级 50、无倍率、溢出域半步与十进位进位、进化材料触发级。一次有限单价求和跨过 float 上界时仍保留整数总价。69 项断言全通过，原始输出在 `godot-test.log`。

## 复现

从仓库根目录执行：

```powershell
python docs/audits/20261020-e3db2838/stages/S11/reference_oracle.py
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path space-battleship --script res://test/audit_s11_quote_test.gd --log-file '<仓库绝对路径>\docs\audits\20261020-e3db2838\stages\S11\godot-internal.log' 2>&1 | Tee-Object docs/audits/20261020-e3db2838/stages/S11/godot-test.log
python docs/audits/20261020-e3db2838/stages/S11/verify_log.py
```

Windows Godot 4.7.2，Python 3.12。第一次全新 checkout 可先运行 Godot `--headless --path space-battleship --editor --import --quit` 建立 class cache；它产生的资产导入物不在交付清单。验收看 Godot 退出 0、`checks=69 failures=0` 和日志门禁。日志中一次系统根证书库读取错误是此 Windows 环境的已知诊断，测试门禁只精确放行该行及紧随的引擎位置行；其他 `ERROR`、`SCRIPT ERROR`、`FAIL` 均失败。

## 阶段边界和后续

S11 没有购买/扣费、MAX 游标、缓存、UI、native 或存档接入；这些要由 S12 对最终运行 SHA 单独验证。S11 的比较不等于实际扣费守恒证明。`max_equipment_level=2147483647` 是现有等级存储边界，没有新增政策上限。Godot 内存和运行时间随指数位数、批次数增加；没有声称任意巨大配置可在有限资源中算完。退款沿用同一单价即可，正式交易和钱包减法仍属于 S12。

本阶段状态：`review`；父级 dot 与原 astra 的同对象结论均 `PENDING`。证据快照以包含本目录、测试原型和唯一入口状态的审计提交完整 SHA 为准。
