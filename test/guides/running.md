# 运行单项测试

从工作区根目录执行一个专项：

```powershell
$env:PYTHONUTF8 = "1"
python test/run.py test_rule_rounding.gd
```

- `run.py` 在 `test/work/` 创建项目与配置副本，并隔离用户目录和 Python 缓存。不得用正式玩家存档复现；仅改用户目录不能隔离 `res://` 数据。
- Godot 测试先导入素材；导入时间不算业务测试耗时。默认每个进程超时 180 秒，必要时显式指定 `--timeout`；`--godot` 可指定引擎。Python 导入专项需要 `openpyxl/lxml`；命令不可用时用已安装的 Python 可执行文件绝对路径替换 `python`。
- UI 专项需要图形环境；`--headless` 仅用于适用的逻辑/模拟专项。真实输入及性能测量串行运行。
- 核对退出码、失败断言及日志；UI 改动核对受影响画面与真实交互。产物仅在 `test/work/`。核对后删除本次运行中无用的隔离目录和临时数据；失败排查或交接所需证据先保留。不要清理仍在运行或与本次测试无关的目录。
