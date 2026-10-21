# S06 独立分析器依赖闭合（AR06）

- 基线 main：`5a4d52957f68b22ef47e0ad91cbe787292872d83`。
- 运行候选：`ba3e9ce4b12fb250850b176478dcafd48e696840`，tree `5ed9ae14f65312b73a8d558054c07069380cb007`，分支 `s06/analyzer-deps`。
- 本目录仅为审计与测试证据，不进入 main。双审均待父级和原 astra 独立结论；不自行集成或关闭。

## 运行文件与理由

- `space-battleship/tools/analyzer_required_data.json`：分析器独立产品清单，显式列出 66 个脚本、17 个 JSON、字体、两份包内工作簿及包外 `mon.xlsx`。
- `space-battleship/tools/build_result_analyzer.py`：复制清单并在写入前核验字面脚本/数据引用与动态数据声明；拒绝所有非预期 `ERROR:`、`SCRIPT ERROR` 与 `Parse Error`，仅精确容许一次已知 Windows 证书库诊断；`--engine` 允许明确指定相同版本引擎。
- `space-battleship/scripts/mon_group_xlsx.gd`：现有 `mon.xlsx` 使用 inline string，没有 `xl/sharedStrings.xml`，仅在该成员存在时读取，避免启动时无意义的 ZIP/XML 错误。
- `space-battleship/scripts/cycle_level_panel.gd`：可选的邻近历史结果目录不存在时返回空结果，避免空目录安装时访问不存在目录；不改变工作簿位置和写出规则。

审计 `architecture/boundary_checks.json` 列出的 23 个静态直接缺项逐一与原 builder 计算结果相等，全部在新清单中。继续追踪传递引用后总闭包为 66 个脚本。`hyperspace_config.gd` 的动态数据名与实体 schema 的 `frozen_inputs` 均在清单。包外 `mon.xlsx` 沿用 marker 中 `source_mon` 绝对源路径与原有邻接优先读取；没有复制到包内，也未修改便携/邻接工作簿约定。

## Windows 4.7.2 验证

工作树从固定 main 的浅克隆构造；`analyzer-s06-final` 原先不存在，是本次全新目录。使用 `D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe`：

```powershell
python tools/build_result_analyzer.py --engine D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe --output C:\Users\Administrator\Documents\Codex\2026-10-21\task-8\analyzer-s06-final
D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Administrator\Documents\Codex\2026-10-21\task-8\analyzer-s06-final --quit-after 120
D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Administrator\Documents\Codex\2026-10-21\task-8\analyzer-s06-final --script res://s06_smoke.gd
```

每次运行设置包内独立 `APPDATA` 与 `LOCALAPPDATA`；`s06_smoke.gd` 仅验证时叠加，不在产品清单或 main。导入、实际入口 120 帧、最小分析均 exit 0；最小分析生成一组输入和一条 pair，得到 `S06_ANALYSIS_PASS tests=1 candidates=1`。检查见 `checks.json`，原始输出见 `logs/import.log`、`logs/entry.log`、`logs/analysis.log`。导入和入口无 `SCRIPT ERROR`、`Parse Error` 或其他产品错误。

三个 Godot 日志各有 `Failed to read the root certificate store`。这是本 Windows 沙箱的证书库读取环境错误；没有调整安全设置，也没有将该错误吞掉。首次误将 Godot console 包装器复制为 `analyzer.exe` 时得到 `Invalid wrapper executable name`，随后使用同版本主可执行文件完成上述正式验证；该包装器错误不是脚本失败。最终构造不借用开发工程的未声明文件；外部 `mon.xlsx` 是已声明保留的工作簿输入。

不宣称 Windows 导出包、native/GPU 或完整模拟器验收；这些不属于本阶段的独立依赖验证。审查需核对运行 SHA、冻结证据 SHA、清单和日志后分别给出 PASS。

## 上轮双审返工

父级和原 astra 对 `670a158b` / `8d1d47bd` 均 FAIL：导入进程返回 0 时的未预期 `ERROR:` 可漏过，且先前 SHA256 表按工作区 CRLF 计算，与 Git blob 不符。现运行候选 `ba3e9ce4` 在同一分支修复门禁；`s06_log_gate.py` 的 7 项审计侧用例覆盖有效日志、已知证书诊断、exit 0 的字体资源错误、重复/伪造证书诊断及脚本/解析错误，原始结果见 `logs/gate.log`。新空目录重新导入、入口 120 帧、最小分析均 exit 0。当前哈希以 Git blob 标准化字节重算，参见 `checks.json`、`EVIDENCE_BLOBS.json` 与总校验表。旧双审结论不适用于新 SHA。
