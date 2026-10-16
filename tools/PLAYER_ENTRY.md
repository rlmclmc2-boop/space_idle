# 正式本地入口

唯一玩家入口为仓库根目录 `玩游戏.cmd`，固定使用 `D:\放置\space-battleship`；旧 `启动.cmd` 已删除。不会查找或启动 test/work、release 或其他副本。现有 .userdata 存档位置保持不变。

启动核对 main 分支、运行源码与验收基准、原生 DLL SHA256、唯一扩展描述符和 Godot 版本。缺 DLL 与哈希不符分别报错；通过校验后如缺少描述符，仅生成项目根目录的 `space_native.gdextension`。若已有其他描述符加载同一扩展，停止启动。随后原地增量导入并启动 main.tscn，不复制素材。失败时保留错误窗口。结果写入 .runtime/player-launch.json，导入与游戏日志分别为 player-import.log 和 player-game.log；这些本地文件不要提交。

图形验收可仅在启动进程环境中设置 `SPACE_BATTLESHIP_VERIFY_WINDOW=1`，再运行原 `玩游戏.cmd`。仍启动正式源码与完整窗口，但存档、启动记录和日志写入 `D:\CodexBuild\space_idle\player-entry-e025\window-check`，不读取正式玩家存档；素材仍原地加载。正常双击不设置此变量，继续使用原有 `.userdata`。

本轮运行源码基准为 `e02501b3`。此前五套性能验收 DLL 的 SHA256 是 `2cf90eda…`，其精确来源是 `D:\CodexBuild\space_idle\balance-recovery-progression-20261015\test\artifacts\ordered-beam-20261015\manifest.json`，清单记录构建源码 `274e973a`。到 `e02501b3`，执行内核加入反应装甲状态和紧凑激光兼容数据，表现层加入冷路径重建，保留表现层加入紧凑激光切换；因此三处原生头文件都已变化。本次从 `e02501b3` 的原生源码用已固定的 Godot C++ 10.0.0、Godot 4.7.2 API、llvm-mingw 20261006 和 SCons 4.11.1 在 `D:\CodexBuild\space_idle\player-entry-e025` 独立构建，产物 SHA256 为 `a4b646bc47690c17de732026d3a65f9936ffe4e8f06e0dff77143faea8376e7c`。来源文件及工具哈希见 `test/evidence/player-entry-native-20261016/receipt.json`。部署只将这个 DLL 安装至 `D:\放置\space-battleship\bin\space_native.dll`；描述符由入口生成。以后正式更新源码时须同步基准与配套 DLL 哈希，不能取消校验。入口不下载、不自动切分支，也不覆盖未知文件。

本轮安装和运行验证的具体结果见同一证据目录。仓库之外的旧快捷方式或未跟踪脚本不在本次 Git 删除范围。
