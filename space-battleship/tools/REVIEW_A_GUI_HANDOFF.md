# 独立 GUI 试玩：辅助入口

本页只交接实际用过的画面捕获和普通鼠标输入。它们不选关、不控制战斗、不读存档、不代替亲自试玩。评测规范入口：`docs/TEST.md`；按 `python tools/read_budget.py route --role dot --task test` 路由到 `docs/READ_ROUTE.md#test`。评分要求由评测任务单独给出，本页不含评分。

## 本次环境路径

- 引擎版本：Godot 4.7.2 stable，安装包目录 `D:\CodexTools\godot-4.7.2-stable\`，可用于下面命令的控制台程序 `Godot_v4.7.2-stable_win64_console.exe`，同目录另有 `Godot_v4.7.2-stable_win64.exe`。原试玩记录了版本和启动参数，但没有单独记录当时所用的两个 EXE 变体，故不把该细节说成已核实。
- A 的项目路径：`C:\Users\Administrator\Documents\Codex\2026-10-18\task\space_idle\space-battleship`；原运行以项目目录作为 `--path`，OpenGL3 渲染。
- A 当时本地的运行依赖：`C:\Users\Administrator\Documents\Codex\2026-10-18\task\space_idle\space-battleship\space_native.gdextension`，其 `windows.debug.x86_64`/`windows.release.x86_64` 均指向 `res://bin/space_native.dll`；DLL 在 `C:\Users\Administrator\Documents\Codex\2026-10-18\task\space_idle\space-battleship\bin\space_native.dll`。这两个文件是本地运行依赖，**不在本工具提交中**；其他工作区先确认自己的构建产物。

## 隔离新档 + 连续 Viewport 帧

在自己的项目工作区运行以下 PowerShell；将四个路径换成自己的工作区位置。`APPDATA` 和 `LOCALAPPDATA` 都指向专用空目录，避免读取个人存档。捕获脚本直接加载 `res://main.tscn`，每秒保存一张完整游戏 Viewport JPEG，编号不断递增。该序列不是逐帧视频，逐秒之间的动作仍须靠实际 GUI 观察和事件标记记录。

```powershell
$gameRoot = 'C:\Users\Administrator\Documents\Codex\2026-10-18\task\space_idle\space-battleship'
$godotExe = 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe'
$freshRoot = Join-Path $gameRoot '.isolated-review-own-run'
$captureRoot = Join-Path $gameRoot 'evidence\own-review\formal'
New-Item -ItemType Directory -Force -Path (Join-Path $freshRoot 'AppData'), (Join-Path $freshRoot 'LocalAppData'), $captureRoot | Out-Null
$env:APPDATA = Join-Path $freshRoot 'AppData'
$env:LOCALAPPDATA = Join-Path $freshRoot 'LocalAppData'
$env:REVIEW_A_CAPTURE_DIR = $captureRoot
& $godotExe --path $gameRoot --script res://tools/review_a_capture.gd --rendering-driver opengl3
```

为真正的新档，每次运行选此前未使用的 `$freshRoot`。只读截图脚本本身不清理或覆盖档案；结束后保留证据和自行写的事件标记。不要把隔离存档、缓存、DLL 或凭据加入 Git。

## GUI 点击与移动

从捕获画面读取窗口客户区坐标，先确认实际游戏 PID，再使用已校验 HWND 的普通鼠标消息。脚本输出输入前后最新帧路径、PID、窗口句柄及成功/失败状态。下面只是语法示例，坐标须由当下画面自行确定。

```powershell
& (Join-Path $gameRoot 'tools\review_a_input_probe.ps1') -GamePid <实际Godot进程PID> -X <画面X> -Y <画面Y> -Action Click -CaptureDir 'evidence\own-review\formal'
& (Join-Path $gameRoot 'tools\review_a_input_probe.ps1') -GamePid <实际Godot进程PID> -X <画面X> -Y <画面Y> -Action Move -CaptureDir 'evidence\own-review\formal'
```

脚本不会查找或打开游戏进程；传错 PID 或窗口无效时应停下重新核实。它只发点击/移动消息，不做自动路线。

## 窗口枚举失败时的执行上下文

`b33124bb` 与本工具分支的点击核心相同；后者仅增加了 `-Action Move`。B 遇到的 `enum_ok=False windows=0` 在本机可用**只读** Win32 枚举重现：同为 Windows Session 1，`DESKTOP-I3QUONB\CodexSandboxOffline` 下 `EnumWindows=False`（Win32 last error 0），`DESKTOP-I3QUONB\Administrator` 下 `EnumWindows=True`。这表明 `Get-Process.MainWindowHandle` 非零并不能证明调用脚本的 shell 可枚举该 GUI。其关键要求是调用方有同一可访问的 Windows desktop/身份上下文；是否复用同一个 PowerShell 进程，单靠现有记录不能断言为必要条件。原成功操作的每次进程身份没有另存日志，因此也不将它说成已核实。

为尽量排除上下文差异，可在**同一个长驻、能正常枚举窗口的 PowerShell** 中设定上述隔离环境、启动图形版 EXE，并在实际画面有新帧后调用点击脚本。下面的 `$x/$y` 必须由刚看到的画面给出；不要原样执行占位值：

```powershell
$godotGui = 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
$game = Start-Process -FilePath $godotGui -ArgumentList ('--path "' + $gameRoot + '" --script res://tools/review_a_capture.gd --rendering-driver opengl3') -PassThru
# 等待采集目录出现新帧，并由实际画面选定 $x、$y；保持此 PowerShell 会话。
& (Join-Path $gameRoot 'tools\review_a_input_probe.ps1') -GamePid $game.Id -X $x -Y $y -Action Click -CaptureDir 'evidence\own-review\formal'
```

该做法没有在 B 工作区复测，也不保证任意两个 shell 共享 desktop。若仍显示 `enum_ok=False`，先核对两边身份/desktop，不要把 `MainWindowHandle` 非零当成已通过输入验证；不要改 `safe.directory` 或 Windows 安全设置。
