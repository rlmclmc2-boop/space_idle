# S07 反应炉缓存正确性（A05）

- 前置 S06 已关闭；基线 main `ba3e9ce4b12fb250850b176478dcafd48e696840`。
- 本阶段实现线程 `01a15c98-6ebc-74c1-ba8a-b2db5720c02f`；运行候选 `s07/reactor-cache` @ `19879285e68f0e1b7ad722d7e27dd402ad4ab6ec`，tree `e6f66e8e31f35054191e9a089c6ce41818d96102`。**双审待进行，未合 main，阶段保持 review。**
- main 候选仅 `space-battleship/scripts/game.gd` 一行：升级完成等级及扣费后、发资源/反应炉事件前调用现有 `invalidate_stat_cache()`。它统一递增 revision、清空装备属性缓存、标记战斗源脏并重编译现有规则。原生 guard 仍在状态写入前，只执行一次。没有改成长、容量、价格、奖励或保存策略。
- 测试脚本和以下原始日志仅留审计分支。统一证据索引在 `RESULT.json`；总 SHA256 表按 Git blob 计算。

## 复现与结果

在隔离目录复制工程与测试，进程级 `APPDATA` / `LOCALAPPDATA` 指向该目录；Godot `D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`，版本 `4.7.2.stable.official.ed1daf0bf`。先导入，再 `--headless --path <isolated-game> --script <isolated-test>`。native 专项在隔离工程中放入 `tools/player_runtime/space_native.dll` 及扩展描述文件并重新导入，断言真实 `SpaceCombatKernel` 类存在。

| 日志 | 预期 / 实际 | 结果 |
|---|---|---|
| `logs/baseline-repro.log` | main 原始脚本在激活第一颗星球征服的免费充能后升级，预热缓存仍为 223251、revision 4 不变；8/20 断言失败，exit 1 | 缺陷复现 |
| `logs/reactor-cache.log` | 修复后容量 100→150、缓存 223251→228328 且与新鲜计算一致；revision 4→5、编译一次、事件各一次。无奖励路径 350→350；20/20，exit 0 | PASS |
| `logs/native-import.log`、`logs/reactor-native.log` | 匹配 DLL 实际加载；成功升级仅一次 native handoff、revision、编译和事件；取消的 native owner 拒绝升级且等级/缓存/事件不变；11/11，exit 0 | PASS |
| `logs/reactor-regression.log` | 原反应炉用例，0 failures，exit 0 | PASS |
| `logs/stat-cache-regression.log` | 原缓存专项，9177 checks、0 failures，exit 0 | PASS |
| `logs/compiled-rules-regression.log` | 原编译规则专项，172 checks、0 failures，exit 0 | PASS |
| `logs/existing-native-suite-failure.log` | 扩展专项运行到既有 `advance_hightech_bulk` 调用，当前 `presented_battle_game.gd` 无该函数，发生 SCRIPT ERROR；进程已中断 | 已知不相关测试阻塞，未计为 PASS |

Godot 日志均含 `Failed to read the root certificate store`，与 S00 已登记的此 Windows 沙箱证书库诊断一致；本次未改安全设置。首次复现脚本类型推断解析错误已修正后重跑，正式复现与修复日志均无其他脚本/解析错误。`test/run.py` 的退出码门禁仍按 P04 不进入 main；此处逐项检查完成标志、退出码与原始日志。现有较大 native 专项因上述旧接口错误不能声称通过；S07 所需 native 断言由真实 DLL 的独立窄项测试完成。

## 审查交接

父级与原 astra 应对同一运行 SHA `19879285e68f0e1b7ad722d7e27dd402ad4ab6ec`、本审计提交冻结的证据快照分别审查。核查一行运行变动、测试覆盖、native 实际能力、失败专项归因及 main 文件白名单。任一方未 PASS 前不得集成或关闭。S06 临时分支删除仍待专项授权，本阶段未操作。
