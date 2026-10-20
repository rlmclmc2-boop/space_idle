# S04a 单存档写入所有权：审查交付

状态：`review`；父级与原 astra 对同一运行及证据 SHA 的结论均待定。不得据此自行合入 main、关闭 S04a 或启动 S05。

| 对象 | SHA |
| --- | --- |
| 起点 main | `abb68a7f7014dafee73c2f8c48a856aaddec0456` |
| 纯运行候选 | `4efef1c2a2dad438dd515ee3dca0cbf77a8b14d6` |
| 运行 tree | `21fe58a96e3d4a3bd9430aa95adb34fdca6b68bd` |
| 审计起点 | `f451b5eaae9c57196a7a627ee452b83e85df27da` |
| 最终审计证据 | 本文件及摘要清单所在的审计提交；审查前回读完整 SHA |

## 范围与设计

`space_native.cpp` 新增 `SpaceSaveLock`：Windows 用 `CreateFileW` 独占打开持久侧文件；POSIX 用 `flock(LOCK_EX | LOCK_NB)`。进程关闭或崩溃时 OS 关闭句柄并释放所有权。侧文件留在原位；不读取其 PID、不凭文件存在性判断所有权，也不删除有效锁。获取失败按不能写处理。

| 必要运行文件 | 作用 |
| --- | --- |
| `space-battleship/addons/native_battle/src/space_native.cpp` | 实际 OS 排他句柄及生命周期，区别于 PID 标记。发行时须从该源码重建匹配 DLL。 |
| `space-battleship/scripts/progress_writer.gd` | 游戏档写入前持锁；普通保存、清档与恢复完成均校验所有权。读取保持无副作用；通用备份/导出目标不受游戏档锁误拦。 |
| `space-battleship/scripts/game.gd` | 持久游戏创建时取得所有权；失败时加载快照并关闭写入，跳过恢复的磁盘提交，继续运行。取得 OS 锁后，即使旧导入 PID 被复用，也可确认旧事务不再活动并完成恢复。 |
| `space-battleship/scripts/save_transfer.gd` | 导入创建标记前校验所有权；回滚/清理保留事务持有的 OS 锁；导出不准覆盖锁侧文件。原 PID 标记只用于判断中断导入事务，不再充当写入所有权。 |
| `space-battleship/scripts/main.gd` | 第二实例提示存档占用和只读运行，不停止主场景。 |

未改玩家进度合并、存档格式、数值或恢复优先级。未持锁实例直接调用保存、导入、清档、恢复收尾均返回 `ERR_ALREADY_IN_USE`（Godot 4.7.2 值 22）；同时测试主档、`.tmp`、`.bak`、导入中间文件及锁侧文件快照未变化。侧文件保留且可在正常退出后重获锁。

## 验证

主机 BJNLPC-0459，Windows，Godot `4.7.2.stable.official.ed1daf0bf`，Python 3.12。DLL 从运行候选的 C++ 源码，用本机固定版本 godot-cpp 和 LLVM MinGW 静态库编译；SHA-256 为 `21a6a85131796759bf220e4d7913e0ac2a1cf9d6c589d4176fa1b2b61ffe69d1`。DLL 只叠加在隔离测试工程，不纳入 Git。原生类由引擎加载并用于真实 Godot 双进程验证。构建没有在本线程重跑 Linux 产物。

从本审计分支根目录运行以下命令，`RUNTIME_ROOT` 指向已检出的上述运行候选，`DLL` 指向该候选重建的 Windows DLL：

```text
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_single_writer_s04a.py --headless --godot <Godot-4.7.2-console> --source-root <RUNTIME_ROOT> --native-dll <DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_recovery_s04.gd --headless --godot <Godot-4.7.2-console> --source-root <RUNTIME_ROOT> --native-dll <DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_transfer.gd --headless --godot <Godot-4.7.2-console> --source-root <RUNTIME_ROOT> --native-dll <DLL>
python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_policy.gd --headless --godot <Godot-4.7.2-console> --source-root <RUNTIME_ROOT> --native-dll <DLL>
```

| 验证点 | 预期 | 实际 |
| --- | --- | --- |
| 同档双进程 | 仅首进程持锁；第二进程不写，UI 继续运行并提示 | [合成摘要](dual_process_summary.json)：第二进程占用错误 22，UI processing=true，主档及所有写入中间/备份文件快照一致 |
| OS 锁语义 | 侧文件存在仍可重获；持锁时同档失败、不同档可用；杀进程后可重获 | `S04A_SINGLE_WRITER_PASS`；侧文件保留，竞争/异档/杀进程后结果符合预期 |
| S04 恢复矩阵 | 不丢完整备份，失败保留现场；旧 PID 复用不会阻止恢复 | 131 checks / 0 failures；`S01_GATE_PASS` |
| S03 传输与导入 | 往返及导入事务有效 | 158 checks / 0 failures；`S01_GATE_PASS` |
| S02 保存策略与 UI | 定时/手动保存及失败反馈 | 59 checks / 0 failures；`S01_GATE_PASS` |
| 启动拒绝 / 保存边界 | 无误盖、历史兼容 | 7/0 与 22/0；隔离用户目录 Godot 直接运行，退出 0 |
| Git 白名单 | 仅五个运行文件 | `git diff --check` 清洁；运行提交仅表列五文件 |

前四项由 `test/run.py` 新增的 `--source-root`、`--native-dll` 审计选项在隔离目录构造产品工程。原 S04/S03/S02 测试中同一进程交替创建多个测试游戏的夹具已按新契约显式交还所有权；测试改动仅在审计分支。单次独立进程验收的合成输入、相对路径文件快照及匹配 DLL 哈希归档在摘要 JSON，不含个人存档或凭据。Godot 输出已有的 Windows 根证书存储警告，不属于脚本解析或存档失败。

## 审查边界

需要父级与原 astra 各自检查：五文件必要性；Windows/POSIX OS 句柄语义；主档、导入和恢复所有写入口；失败保持原文件；第二实例仍运行；DLL 重建与实际入口。当前证据覆盖 Windows 合成双进程及异常终止，不宣称 Linux 运行、断电文件系统行为或发布包已验收。两方同对象明确 PASS、无未解决项后才可由父级集成 main 并执行本地真实入口验收。
