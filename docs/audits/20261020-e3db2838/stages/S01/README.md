# S01 可靠验收门禁：审计侧交付

基线 `main=e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`；审计入口父提交 `19b231ea05daf8018977fc87269c5b10c0f4c3e2`。S00 已双 PASS 并关闭。S01 实施线程为 `01a15a61-fd87-7064-a145-397991b320e8`，当前状态为 `review`。运行 SHA=`N/A`，integration=`N/A`。本阶段仅在审计分支提交门禁、六类合成样例及两个后续 S02 测试的完成标志；本记录不宣称 S01 closed。

## 接口与判定

从仓库根目录运行：

```powershell
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_policy.gd --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_config_workbooks.py --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe
```

`gate.py` 调用既有 `test/run.py` 的隔离入口，继承其 `--timeout`、`--headless`、`--godot` 参数，读取合并 stdout/stderr，并核对：退出码必须为 0；对应完成标志恰好一次；所有 Godot `SCRIPT ERROR` / 解析或脚本加载错误及 Python traceback/语法错误不得有未声明项。外层超时也失败；原 runner 的超时返回 124 同样失败。失败原因以 `S01_GATE_FAIL` 输出，成功输出 `S01_GATE_PASS`。

`test_save_policy.gd` 在全部断言完成且零失败时才输出 `S01_COMPLETE:test_save_policy.gd`；`test_config_workbooks.py` 在 `unittest` 成功后才输出 `S01_COMPLETE:test_config_workbooks.py`。仅这两个 S02 所需测试接入；其他历史测试不由此门禁声称覆盖。

确有意产生脚本/解析错误的测试，可逐次传 `--expect-error 'SCRIPT ERROR: 完整诊断文本'`。声明按整行字面值和次数比较：声明未出现、额外错误、重复次数不符均失败。泛化 `Traceback` 不能作为预期声明。当前接入的两个测试没有预期错误声明。

## 六类样例与实际结果

环境：Windows NT 10.0.19044、Python 3.12、Godot `4.7.2.stable.official.ed1daf0bf`。命令：

```powershell
python docs/audits/20261020-e3db2838/stages/S01/test_gate.py
```

2026-10-20 UTC 执行结果：`Ran 6 tests in 0.553s`, `OK`。样例均启动真实子进程，所用数据为合成输出：

| 类别 | 预期 | 实际 |
|---|---|---|
| 合法成功，exit 0，完成标志一次 | PASS | PASS |
| 完成标志后 exit 7 | FAIL | `exit code 7` |
| 子进程超时 | FAIL | `exit code 124` |
| exit 0，无完成标志 | FAIL | `completion marker count 0` |
| `SCRIPT ERROR` + exit 0 + 完成标志 | FAIL | `unexpected diagnostic` |
| 完整声明的故障行 + exit 0 + 完成标志 | PASS；另有未声明或声明缺失时 FAIL | 三种情况均按预期判定 |

另用本机 Godot 4.7.2 在隔离 `test/work/s01-gate-probe/` 执行审计已有的 `evidence/probe_test_gate.gd`：进程实际 exit 0，同时输出 `SCRIPT ERROR: Invalid access to property or key 'required_field' on a base object of type 'Dictionary'.`。门禁对该原始日志返回 `completion marker count 0` 与 `unexpected diagnostic (1)`；这确认本机引擎的真实错误格式被识别。探针目录是临时工作物，不随 Git 提交。Godot 另输出根证书存储错误；它不属于本阶段定义的脚本/解析错误，仍由后续产品入口核查归因。

两个真实专项在 S01 不执行：`test_save_policy.gd` 和 `test_config_workbooks.py` 有 S00 登记的既有失败，S02 将修正夹具并在本门禁下运行。此处只验收门禁本身和完成协议。A08 的**审计侧门禁已实现**；main 的 `test/run.py` 保持原样，其 A08 缺陷未按本阶段声明关闭。未改产品代码、游戏数值或 main；不进入 S02。

## 待双审

原交付 `044c3c19f8fa8f788d5d7328005ac42d46b33d03` 的双审反馈：父级为 PENDING，astra 为 FAIL；两者指出的唯一阻断均为唯一实施计划尚将 S01 写作 `not_started` 且缺阶段待审记录。父级另已核查门禁行为并重跑六项子进程测试和八项边界断言，行为符合预期。本次只修订计划状态、待审记录与摘要，不变更门禁实现。该原交付的审查结论不延用为新 SHA 的 PASS。

复核文件：`stages/S01/gate.py`、`stages/S01/test_gate.py`、`test/test_save_policy.gd`、`test/test_config_workbooks.py`、本记录和唯一实施计划。最终审计交付 SHA 仍需父级与原 astra 对同一 SHA 分别 PASS，未解决项归零后才可关闭。若需返工，继续在本 S01 线程。
