# 正式玩家入口

从仓库根目录双击 `玩游戏.cmd`。入口按脚本所在目录定位当前仓库，不依赖工作目录或固定盘符。

当前已审源码基点：`fda7be2c217a208067f97266f85497b83cbdd840`。父线程合入 main 时须保留该提交祖先关系；若改用 squash 或再修改游戏源码，需重新审定源码基点。入口只在 main 上运行，并拒绝相对基点的游戏源码变化和未审本地运行文件。

正式配套 DLL：[player_runtime/space_native.dll](player_runtime/space_native.dll)，SHA-256 为 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`。来源与验收清单：[native-validation-hashes.json](../space-battleship/evidence/new-hull-hardpoints/native-validation-hashes.json)。这是 d07f0b9 缓存交付的 Windows 4.7.2 实际构建；既有 5717 项正确性和 8 次有效高负载记录沿用，不重复扩测。

首次安装或升级旧 DLL：

```powershell
python tools/play_main.py --install-native
```

也可使用 `py -3`。显式安装先验证 main、源码和仓库 DLL，再写入 `space-battleship/bin/space_native.dll`。不同旧 DLL 按其 SHA-256 备份到 `.runtime/native-backup/`。正常启动严格拒绝缺失或旧 DLL。入口生成的固定 DLL 路径不被当成未审源码，但其完整哈希仍独立验证；其他未审 DLL 继续拒绝。

引擎必须位于 `space-battleship/engine/Godot_v4.7.2-stable_win64.exe`。入口验证版本 4.7.2、无旁置 PCK、唯一且匹配的扩展描述，增量导入后启动 `res://main.tscn`。存档使用当前工程 `.userdata`，日志和启动收据写入 `.runtime/`。

验收使用 `SPACE_BATTLESHIP_VERIFY_WINDOW=1` 将存档、日志和收据隔离到 `test/work/player-window-check/`；仅在此模式下可用 `SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES=120` 短启动后退出。入口始终启动自身仓库的正式工程。

本次发布专项结果：[release.json](../test/evidence/dynamic-port-cache-player-release-20261019/release.json)。历史 center-contact 记录保持原样。
