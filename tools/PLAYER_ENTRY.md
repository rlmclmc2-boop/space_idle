# 正式本地入口

唯一玩家入口为仓库根目录 `玩游戏.cmd`，固定使用 `D:\放置\space-battleship`；旧 `启动.cmd` 已删除。不会查找或启动 test/work、release 或其他副本。现有 .userdata 存档位置保持不变。

启动核对 main 分支、运行源码与验收基准、原生 DLL SHA256、唯一扩展描述符和 Godot 版本。随后原地增量导入并启动 main.tscn，不复制素材。失败时保留错误窗口。结果写入 .runtime/player-launch.json，导入与游戏日志分别为 player-import.log 和 player-game.log；这些本地文件不要提交。

本轮验收基准 e02501b3，原生库 SHA256 来自 test/evidence/enemy-intel-final-perf-20261016/SUMMARY.md。以后正式更新运行源码时须同步 tools/play_main.py 的已验收基准与配套 DLL 哈希，不能仅取消校验。此入口不下载、替换未知 DLL，不自动切分支或覆盖修改。

验证：Python 语法与 6 项入口防错测试通过（正确版本、候选分支、源码变化、旧 DLL、外部 DLL 路径、自动加载 PCK）。Windows 双击与本机 DLL 实际匹配尚待本地执行；未冒充已运行。仓库之外的旧快捷方式或未跟踪脚本不在本次 Git 删除范围。
