# 正式本地入口

唯一玩家入口为仓库根目录 `玩游戏.cmd`，固定使用 `D:\放置\space-battleship`；旧 `启动.cmd` 已删除。不会查找或启动 test/work、release 或其他副本。现有 .userdata 存档位置保持不变。

启动核对 main 分支、运行源码与验收基准、原生 DLL SHA256、唯一扩展描述符和 Godot 版本。缺 DLL 与哈希不符分别报错；通过校验后如缺少描述符，仅生成项目根目录的 `space_native.gdextension`。若已有其他描述符加载同一扩展，停止启动。随后原地增量导入并启动 main.tscn，不复制素材。失败时保留错误窗口。结果写入 .runtime/player-launch.json，导入与游戏日志分别为 player-import.log 和 player-game.log；这些本地文件不要提交。

图形验收可仅在启动进程环境中设置 `SPACE_BATTLESHIP_VERIFY_WINDOW=1`，再运行原 `玩游戏.cmd`。仍启动正式源码与完整窗口，但存档、启动记录和日志写入 `D:\CodexBuild\space_idle\player-entry-d975\window-check`，不读取正式玩家存档；素材仍原地加载。正常双击不设置此变量，继续使用原有 `.userdata`。

当前入口的运行源码基准为 `d9750f9f`，配套原生 DLL SHA256 为 `6bfa0d565eae83d96ee6e374d92b790a60a41cb52ae1d9209b23c90d1e7ef452`。须先安全发布含该源码的 main，再安装此 DLL；不能让旧源码与新库混用。最终候选的构建来源和验证见 `test/evidence/player-entry-native-20261016/final-candidate.json`。此前 `e02501b3` 的正式路径图形验证及更早 `274e973a` DLL 的来源保留在同目录 `receipt.json`，只作历史证据。以后正式更新源码时须同步基准与配套 DLL 哈希，不能取消校验。入口不下载、不自动切分支，也不覆盖未知文件。

本轮安装和运行验证的具体结果见同一证据目录。仓库之外的旧快捷方式或未跟踪脚本不在本次 Git 删除范围。
