# 正式本地入口

玩家从仓库根目录运行 `玩游戏.cmd`。脚本以自身所在目录定位 `tools/play_main.py` 和 `space-battleship`，不依赖固定盘符，也不会切换分支、下载文件或读取其他游戏副本。

本轮验收源码基准为 `main@69ef148cd76151abab7851973a31c51483605498`。配套原生库的 SHA-256 为 `04e7be92c92637a72dde5f71ccc57a865ad20842e00aca63fd628b86e321590f`，随仓库放在 [player_runtime/space_native.dll](player_runtime/space_native.dll)。四份源码和验收 DLL 的逐项哈希记录见 [native-validation-hashes.json](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json)。

首次运行，或本机旧 DLL 哈希不符时，在仓库根目录执行：

```powershell
python tools/play_main.py --install-native
```

若本机只提供 `py` 启动器，可改用 `py -3 tools/play_main.py --install-native`。

安装命令先校验 `main` 分支、已验收源码和仓库内 DLL 哈希，再将 DLL 安装到 `space-battleship/bin/space_native.dll`。如已有不同 DLL，会先按其 SHA-256 备份到 `space-battleship/.runtime/native-backup/`。正常的 `玩游戏.cmd` 仍严格拒绝缺失或不匹配的 DLL；不会自动覆盖未知文件。

入口还验证 Godot 4.7.2、唯一扩展描述符及运行源码。引擎需放在 `space-battleship/engine/Godot_v4.7.2-stable_win64.exe`；入口不会下载它。通过校验后，仅在当前工程增量导入并启动 `res://main.tscn`。正常启动沿用工程的 `.userdata` 存档位置，日志及收据写在 `.runtime/`。

隔离验收可设置 `SPACE_BATTLESHIP_VERIFY_WINDOW=1`，将存档与日志写入 `test/work/player-window-check/`；可同时设置 `SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES=120` 让验证窗口自动退出。这两个变量不影响正常玩家启动。正式入口不搜索 `test/work`、`release` 或其他工程副本。
