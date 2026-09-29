# 太空战舰：运行与交付

AI 入口：[AGENTS](AGENTS.md)。本页只列操作；规则、定位和测试分别见 [PROJECT](docs/PROJECT.md)、[ARCHITECTURE](docs/ARCHITECTURE.md)、[测试入口](../test/README.md)。

## 启动与编辑

| 操作 | 入口 |
|---|---|
| 运行游戏 | 工作区根目录 `启动.cmd` |
| 打开 Godot 工程 | 项目内 `打开编辑器.cmd` |
| 编辑关卡 | 项目内 `关卡编辑器.cmd`；[操作规则](docs/LEVEL_EDITOR.md) |
| 编辑玩家文字 | 项目内 [UI文案表.bat](UI文案表.bat)；只改“UI文字”，保存后重启；[操作规则](docs/UI_TEXT.md) |
| QA / 数值工具 | 开发版 F1 / F8 / F9；[模拟口径](docs/BALANCE_LAB.md) |

脚本默认使用 `engine/Godot_v4.7.2-stable_win64.exe`。关卡编辑器可通过 `SPACE_BATTLESHIP_GODOT`、`SPACE_BATTLESHIP_PYTHON` 指定程序；游戏运行不需 Python。

首启、缓存缺失或新素材缺 `.import` 时自动导入；失败查 `.runtime/startup-import.log`。替换素材或修改代码后，用 QA「大重启」保存、退出旧进程、重新导入并启动；失败查 `.runtime/full-restart.log`、`full-restart-import.log`，忙碌时勿重复触发。「重启游戏」仅在同进程重载场景。两者均不读取 Excel。

「删除存档」会清空进度，保留 QA 偏好和配置；仅在人明确选择时使用。

## 配置

编辑源为 `config_excel/*.xlsx`，运行投影为 `data/game_data.json`。日常流程：修改对应分表，在表格软件中计算并保存 → QA「读取配置」→ 成功后「重启游戏」。导入不计算 Excel 公式；缓存缺失时回表格软件保存。Python 需 `openpyxl/lxml`，可用 `SPACE_BATTLESHIP_PYTHON` 指定。

不要手改运行 JSON，也不要先用旧总表同步。仅明确要以所选旧总表**替换**分表时，才用「拆分／同步 Excel」；先备份并核对差异。它不合并两处编辑。旧表字段缺口见 [STATUS U-018](docs/STATUS.md)；关卡编辑器的校验与恢复见 [LEVEL_EDITOR](docs/LEVEL_EDITOR.md)。

## Windows 单文件发布

从工作区根目录运行 `build_release.bat`；自动化加 `--no-pause`。首次在构建电脑准备官方 `engine/Godot_v4.7.2-stable_win64.exe`，并运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File space-battleship/tools/install_release_template.ps1
```

脚本校验同版正式模板，提取 `engine/templates/4.7.2.stable/windows_release_x86_64.exe`；缺失或损坏时构建停止。构建读取当前 `data/game_data.json`、`data/ui_text.json`、`data/ui_text_contract.json`，不自动导入 Excel。成功只分发 `release/SpaceBattleship.exe`；目标为 Windows 10/11 x64、OpenGL 3.3。玩家不需工程、引擎、Python、Excel 或预装中文字体。

构建在隔离副本验证最终 EXE 的渲染、写档和重开。失败返回非零，未验证的 EXE 删除，旧版隔离；查工作区 `build.log` 和 `test/work/release-*`，修复后完整重跑。自动验证仅覆盖构建电脑；另一台干净 Windows 电脑仍需验收字体、图片、声音、存档及重开。玩家存档位于 `%APPDATA%\SpaceBattleship\progress.json`，不在 EXE 旁。

## 开发工程移交

保持工作区根 `启动.cmd`、`太空战舰.xlsx`、`test/`、`space-battleship/` 的相对布局。引擎另行提供；`.godot/`、`.runtime/` 缓存非必需。`.userdata/` 是个人进度，续接时由所有者单独备份。
