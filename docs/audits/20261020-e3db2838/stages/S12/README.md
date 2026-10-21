# S12 装备报价接入：当前候选与待决范围

状态：`awaiting_decision`，A07 未关闭。基线 main `31e79337741bf9860d69fff21dae6be994dacd00`。当前运行候选分支 `impl/s12-transaction-integration`，提交 `23acd13f7e863d8b8d763299f23352c6b1996886`；这是可复核候选，**尚非双审最终运行 SHA**。实施线程 `01a15dcd-a9fa-76f2-a28f-312cf153a002`。审计父提交 `b21f839ae26dd2554bb3ad7cf27614c3545a433c`。

## 已接入的玩家路径

- `equipment_quote.gd` 由 S11 已双审原型迁入，仅更名与更新文件注释；`database.gd` 将正式单价交给同一核心，战斗属性成长公式保持原状。
- `game.gd` 的单次、x10、MAX 和缓存累计使用逐级已取整价格的整数和；足额预计算全部币种余额，再做 native 交接、扣费、升级。旧 `{m,e}` 整数钱包在保存可表示域内转精确整数，交易后的 `{v:1,i:"..."}` 保存编码适用于两种普通资源。退款先汇总原逐级报价和材料，再统一入账。
- `native_execution_session.gd` 批量计划用相同费用和扣费函数预核验；超出 native 属性域时由已有同步 handoff 交给 legacy，未付费时保持原 native owner。
- `equipment_tab.gd` 给 MAX 总价加提示；价格与余额沿用 `NumberFormat` 的大数显示，不用缩写值结算。

上述只是当前候选的变更范围。没有更改伤害成长、配置经济公式或 main。

## 已完成的本地验证

环境：Windows、Godot 4.7.2 console SHA256 `C8F0A6BC45A19B33541501E57F6F7CD972AB18453743266339D495CBBE846643`；原生 `space_native.dll` SHA256 `04E7BE92C92637A72DDE5F71CCC57A865AD20842E00ACA63FD628B86E321590F`。测试用 DLL 置于隔离检出工程的 `bin/`，由项目扩展描述文件装载，不提交 DLL 或生成缓存。原生脚本检查 `SpaceCombatKernel` 类已加载。三次最终运行的退出码均为 0：

| 入口 | 结果 | 证据 |
|---|---:|---|
| `res://test/audit_s12_transactions.gd` | 26/26 | `probes/audit_s12_transactions.gd`, `logs/transactions.log` |
| `res://test/audit_s12_native.gd` | 27/27 | `probes/audit_s12_native.gd`, `logs/native.log` |
| `res://test/test_equipment_switch_cooldown.gd` | 24/24 | `logs/equipment-switch.log` |

交易探针覆盖 3873 级 `{m:1,e:400}` 足/不足额、事件与脏标记、整数余额精确扣除及 JSON 往返、合法旧钱包往返、十次单买与 x10 的资源及材料一致、逐级和、MAX 缓存一致及购买后失效、退款材料、无法保存精确余额时的副作用前拒绝。native 探针覆盖实际 DLL 的有限单次/批量保留 native、超域单次/批量先 handoff 后购买、未付费单次/批量在 handoff 前拒绝。两份日志都有本机根证书读取诊断，测试本身无其他脚本错误。

复核时从运行候选 SHA 检出完整工程，把本目录 `probes/` 两个脚本以同名复制到 `space-battleship/test/`，用已核对的 DLL 和扩展描述文件做 Godot 编辑器导入，再执行：

```powershell
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path space-battleship --script res://test/audit_s12_transactions.gd
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path space-battleship --script res://test/audit_s12_native.gd
& 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path space-battleship --script res://test/test_equipment_switch_cooldown.gd
```

本地为缩短传输使用稀疏工作树；完整编辑器导入出现的缺失美术预载错误不作为通过证据。上述直接脚本测试没有该类错误。尚未完成完整玩家 UI 启动/重载验收、正式测试门禁或双审。

## 范围待决与退出条件

额外费用消费者：`space-battleship/scripts/player_loadout_generator.gd:268-271` 把报价转 float 后补钱包；`balance_autoplayer.gd:83-85` 和 `balance_metrics.gd:73-74` 把报价转 float 用于模拟器。S12 目标明确包含玩家购买、批量/MAX、扣费、缓存、显示、相关保存和 native；S20 另有模拟器数值域政策关口。请父级与原 astra 先共同确定这些消费者在 A07/S12 的责任边界或修订阶段，不由实施线程单独扩大模拟器范围。当前候选不得据此宣称 A07 闭环。

还需针对同一最终运行 SHA 和冻结证据 SHA 获得父级 dot 与原 astra 独立 PASS、未解决项为空，再由父级决定 main 集成及本地入口验收。本线程不自行合 main、开启下一阶段或关闭阶段。
