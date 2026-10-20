# S00 基线与执行准备

实施线程 `01a15a4c-ea59-75a6-afea-513fefe8a0c0`。证据日期：2026-10-20 UTC。只调查和归档；运行代码 SHA 为 `N/A`，未修改产品、测试入口或 main。本记录与实施计划共同组成待双审的审计交付。

## Git 基线和交付边界

| 项目 | 核查结果 |
|---|---|
| 仓库 | `rlmclmc2-boop/space_idle` |
| 审计基线 | `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3` |
| 远端当前 main | `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`；GitHub `compare_commits(base=e3db2838…,head=main)` 为 `identical`, `ahead_by=0`, `behind_by=0`, `files=[]` |
| 本机独立检出 | `git rev-parse HEAD` 为同一 SHA；`git status --porcelain=v1` 为零行；`git diff --stat e3db2838… main` 为空 |
| 唯一审计入口 | `audit/code-review-e3db2838-20261020` 的 `d67662d6f0f71ebc08e9ef6a0c76a2ce9cca0da4`，`docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md`；写入前该提交与远端审计分支相同 |
| main 与审计基线 | 无提交、文件或树差异；原始玩家工作区 `D:\放置` 有大量 Godot 生成文件变动，未在该工作区清理或写入，验收以独立干净检出和远端 Git 对比为准 |

审计历史的 A01—A08 和 AR01—AR07 仍是未关闭的问题清单；审计分支文档不是运行修复。后续运行阶段须从届时实际验收的 main SHA 起步，按计划分离运行改动与审计证据。

## 授权和状态

- D01/D02：持续成长大数、不新增等级上限、保留公式及取整；D03：同档单写入者、第二实例阻止写入，均已由用户答复“按”批准。这里只登记，不实施。
- P04 已明确：`test/run.py` 等验收工具仅在审计侧交付，main 不纳入。S00 不实现 S01 门禁，也不把 A08 标为修复。
- P05：父级记录 `BJNLPC-0459` connected、attached、已授权，并说明本线程创建时使用环境 ID `ccarenv_b64_Y2NhcmVudl82YWMwMTAxZGQxMWM4MTkxYmFjMGYwYmY4MjllMzU1Yg`，目录显示名为 `BJNLPC-0459`。本线程 `hostname.exe` 与 DNS 主机名也返回 `BJNLPC-0459`；`COMPUTERNAME` 环境变量及 `.NET MachineName` 返回 `DESKTOP-I3QUONB`。这是名称来源差异，现有证据不支持“另一台机器”的结论；控制面环境 ID 的归属由父级核对。
- 当前阶段状态为 `review`，两位审查者的结论均待填写；未集成 main，未关闭 S00，S01 不可启动。

## Windows 4.7.2 / native / GPU / 隔离能力矩阵

以下只读探测及合成小工程均在本线程的已授权 Windows 环境执行，写入仅限可写目录 `.s00_probe/`。线程标识 `CODEX_SESSION_ID` / `CODEX_THREAD_ID` 均为 `01a15a4c-ea59-75a6-afea-513fefe8a0c0`。独立的 `hostname.exe` 和 `[System.Net.Dns]::GetHostName()` 均输出 `BJNLPC-0459`；`COMPUTERNAME` 与 `[System.Environment]::MachineName` 输出 `DESKTOP-I3QUONB`。父级提供的任务创建环境 ID 对应 `BJNLPC-0459` 显示名。故先前以旧名称推断“目标机未执行”的判断撤回；显示名、环境变量与 OS 主机名不是同一证据来源。

合成 native 探针首次直接运行时 `S00_NATIVE_CLASS=false, exit=2`，因为新工程尚未由 Godot 生成 `.godot/extension_list.cfg`；编辑器首次扫描生成扩展登记后，实际类加载成功。编辑器导入进程在等待时被中断，不能把导入退出状态写成通过。未运行玩家游戏、未用个人存档。

| 能力 | 当前授权环境的证据与结论 | 尚待验证的范围 |
|---|---|---|
| Windows 与指定引擎 | Windows NT 10.0.19044；`D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --version` 输出 `4.7.2.stable.official.ed1daf0bf`：**available**。 | 真实玩家入口与发布包未运行，留 S22。 |
| native 构建输入 | `build_native.ps1` 固定的 `godot-cpp` 提交 `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` 与检出一致；4.7.2 API SHA-256 为要求的 `d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`；LLVM MinGW 与 Python/SCons 路径存在：**输入静态就绪**。 | **源码重新构建未执行，构建能力/新产物未验证**。后续在隔离 D: 构建目录运行固定脚本，记录退出码、源码及新 DLL 哈希；不把路径存在当成构建通过。 |
| 匹配 DLL 与实际加载 | `tools/player_runtime/space_native.dll` SHA-256 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78` 与 `native-validation-hashes.json` 一致。合成工程导入后 `ClassDB.class_exists("SpaceCombatKernel")=true`、exit 0：**现有匹配 DLL 加载 available**。 | `D:\CodexBuild\space_idle\native-stable\bin\space_native.dll` 为旧哈希 `04e7be92c92637a72dde5f71ccc57a865ad20842e00aca63fd628b86e321590f`，不能作为新构建证据；运行提交变化后还需重新核对匹配。 |
| GPU 图形入口 | `nvidia-smi -L` 识别 NVIDIA GeForce RTX 2060；非 headless、`gl_compatibility` 合成工程运行五帧，输出 `OpenGL API 3.3.0 NVIDIA 610.88`、`S00_DISPLAY=Windows`、`S00_RENDERER=NVIDIA GeForce RTX 2060`、exit 0：**最小图形入口 available**。 | 游戏 UI、原生战斗和发布包的图形验收留 S22。 |
| 用户目录隔离 | 探针将进程级 `APPDATA` / `LOCALAPPDATA` 指向 `.s00_probe/userdata/`，Godot 数据确实写入该目录：**隔离机制 available**。`test/run.py` 另为每次测试建独立 `test/work/<test>-*` 并设置 Windows 与 XDG 用户目录。 | 产品新档/保存/重开的隔离验收未执行；后续只用合成进度，不碰真实玩家存档。 |

三个 Godot 探针均输出 `ERROR: Failed to read the root certificate store`，但版本、native 加载和 GPU 探针的相应退出码如上。该错误留在真实产品入口检查时归因，不据此宣称产品故障或产品验收通过。GPU 小工程通过也不代表游戏 UI、原生战斗或发布包通过。

本环境能力核查的可复核命令与输入（仓库根目录；`$probe` 指向新建的、位于可写目录中的空项目）：

```powershell
$godot = 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe'
& $godot --version
git -c safe.directory='D:/CodexBuild/space_idle/godot-cpp' -C 'D:\CodexBuild\space_idle\godot-cpp' rev-parse HEAD
Get-FileHash 'D:\CodexBuild\space_idle\api\extension_api.json', 'tools/player_runtime/space_native.dll' -Algorithm SHA256
& 'C:\Windows\System32\nvidia-smi.exe' -L
```

合成项目只含 `project.godot`（`config_version=5`）、`bin/space_native.dll`（复制自 `tools/player_runtime/`）、根目录 `space_native.gdextension`（复制自 `space-battleship/addons/native_battle/space_native.gdextension.in`）及如下两个 `SceneTree` 脚本。以进程级 `APPDATA=$probe/userdata/roaming`、`LOCALAPPDATA=$probe/userdata/local` 运行。编辑器首次扫描生成 `.godot/extension_list.cfg` 后，执行 `& $godot --headless --path $probe --script "$probe/probe.gd"`；输出 `S00_NATIVE_CLASS=true`、退出 0。`gpu_probe.gd` 用 `& $godot --path $probe --rendering-method gl_compatibility --script "$probe/gpu_probe.gd"`；输出 Windows/NVIDIA RTX 2060、退出 0。

```gdscript
# probe.gd
extends SceneTree
func _initialize() -> void:
    print("S00_NATIVE_CLASS=", ClassDB.class_exists("SpaceCombatKernel"))
    quit(0 if ClassDB.class_exists("SpaceCombatKernel") else 2)

# gpu_probe.gd（独立文件）
extends SceneTree
func _initialize() -> void:
    call_deferred("run_probe")
func run_probe() -> void:
    for i in range(5):
        await process_frame
    print("S00_DISPLAY=", DisplayServer.get_name())
    print("S00_RENDERER=", RenderingServer.get_video_adapter_name())
    quit(0)
```

## 既有失败、夹具与门禁问题（未在 S00 重跑）

| 项目 | 已有证据 / 解释 | S00 归类与后续 |
|---|---|---|
| `test_save_policy.gd` | 原审计首次 48 checks、5 failures（含隔离目录断言）；修正隔离目录后重跑为 48 checks、4 failures。剩余项涉及时间戳重载精确相等、强化购买、分支与重载联动；31 级强化当前费用约 `1.0737e11`，原夹具仅给 `1e9` 碎片。 | **既有失败，产品缺陷未定**；S02 分离夹具和时间语义，保留正确 oracle，不能为绿灯改规则。 |
| `test_config_workbooks.py` | 原审计 14 tests、1 error；`test_hightech_limit_and_offline_max_validation` 所用 `level.xlsx!D4` 缺公式缓存。 | **既有夹具/工作簿错误**；S02 修正可重复输入并核对实时配置，不改游戏公式。 |
| `test/run.py` | 原审计 `probe_test_gate.gd/.log` 证明 `SCRIPT ERROR` 可伴随 exit 0，现入口仅按退出码可能误判通过。 | **门禁缺陷 A08**；S01 在审计侧实现可靠完成/错误协议。main runner 按 P04 保持未修。 |
| Windows/native/GPU 产品验收 | 原报告在 Linux Godot 4.6.3 上核查，未执行 Windows 原生 DLL、真实 GPU 和最终 EXE。 | **真实产品仍未验证**；S00 已在当前授权环境确认指定引擎、现有匹配 DLL 加载、GPU 最小入口及隔离机制，源码重建与玩家产品/发布包另待执行。 |

原报告的 16 个既有专项为 14 通过、2 未通过；这不是本阶段的新测试结果。A01—A07 与 AR01—AR07 仍按唯一计划的后续阶段处理，不因准备工作而关闭。

## 阶段验证清单与唯一下一任务单

| 阶段 | 最小需准备的验证类别（实际执行仍按该阶段范围） |
|---|---|
| S01 | 合法成功、exit 非零、超时、无完成标志、`SCRIPT ERROR + exit 0`、精确声明的预期故障；仅审计侧门禁。 |
| S02 | save_policy 的受控资源/时间夹具，config_workbooks 的公式缓存和现行配置 oracle；用 S01 门禁。 |
| S03—S04a | 合成存档字段往返、备份选择与坏档安全失败、双进程单 writer；Windows 文件锁行为在目标机核实。 |
| S05—S08 | 空 staging 依赖闭包、分析器最小入口、反应炉缓存与 native guard、配置双故障恢复。 |
| S09—S12 | D01/D02 契约及边界例，容量/分配/剩余/费用的持续成长和交易闭环。 |
| S13—S21 | 状态边界与命令时序、native 交接、测试能力声明、执行器范围与小型差分。 |
| S22—S24 | 指定 Windows 产品包、分析器、GPU/原生、新档保存重开与实际入口；最终 main 回归与审计链。 |

**下一阶段仅 S01，待 S00 双 PASS 并由父级关闭后启动。** 父级任务单应填：base main `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`（启动时复核）；前阶段 closed 证据；仅审计分支 `docs/audits/20261020-e3db2838/stages/S01/` 和必要验证工具文件；P04 审计侧限制；实现退出码、未预期脚本/解析错误、完成标志、精确预期错误声明的门禁；以表中六类样例验证，记录目标引擎/命令/预期与实际。禁止改产品代码、全量翻修历史测试、合 main、进入 S02。最终运行 SHA=`N/A`，提交审计证据 SHA 后等待父级与原 astra 对同一 SHA 双审；任何返工留在 S01 原线程。

## 本阶段交接

- 审查对象：本文件及唯一实施计划的 S00 状态、P04/P05、S01 边界。运行 SHA `N/A`；main 无集成，`integration=N/A`。
- 待父级和原 astra 分别写入 PASS/FAIL/PENDING/BLOCKED、审查证据 SHA 和未解决项。本实施线程不代填结论，不关闭阶段或线程。
- 仅审计文档变更，依据仓库 `docs/TEST.md` 不运行游戏专项；本阶段能力探针不是产品回归。
