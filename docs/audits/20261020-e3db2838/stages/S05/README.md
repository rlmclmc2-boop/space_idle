# S05 玩家发布依赖修复证据

- 基线 main：`01ddfcaf678321fafae51162b3bb6665b34e4301`
- 待双审纯运行候选：`5a4d52957f68b22ef47e0ad91cbe787292872d83`
- 运行树：`2f161d9aac91d8d615770d9480d7dd6d9247b00d`
- 运行分支：`s05/player-release-deps`
- 平台：Windows，Godot 4.7.2 stable official，Python 3.12，PowerShell 5.1；测试使用临时独立克隆和隔离 `APPDATA`。
- 可核查的原始输出与退出码：`logs/missing-*.log`、`logs/new.log`、`logs/reopen.log`、`logs/import-diagnostic.log`；机器可读检查摘要：`checks.json`；运行 Git blob 清单：`RUNTIME_BLOBS.json`。各日志开头记录实际命令、隔离路径和退出码；导入日志仅摘录原始诊断行，省略进度动画。

## 范围和 main 文件理由

- `space-battleship/tools/player_required_data.json`：玩家产品必需配置、26 个直接文件与三个直接运行目录的单一清单。包含原 12 项及缺失的 `ai_tech_tree.json`、`equipment_evolution.json`、`space_enemy_reward_early_frozen.json`；`shaders` 是 `battlefield.gd` 等脚本直接预加载的运行目录。原先另列的扩展和表现资源也在同一清单中声明，没有移动素材。
- `space-battleship/tools/build_release.ps1`：必要发布构建工具，从上述清单复制资源；源缺项、staging 缺项、清单异常或副本散列不同均阻止发布。测试脚本、日志、审计记录未进入运行候选。

不迁移 `dev/toon_ship` 素材目录，不改分析器产品构建，也不调整游戏数据或存档规则。S05 只关闭依赖修复；Windows 最终产物验收和 S22 发布验收均未据此宣称完成。

复现准备：从 main `01ddfcaf...` 单独检出，将本阶段两个运行文件叠加；把与本机已验收玩家入口相同的 Godot 4.7.2 编辑器、匹配 Windows 导出模板放入 `space-battleship/engine/`，把已验收 `tools/player_runtime/space_native.dll` 复制到 `space-battleship/bin/space_native.dll`，并由仓库的 `space_native.gdextension.in` 生成同名 `.gdextension`。上述本机安装物不进入 Git。所有测试在临时工作目录和隔离用户目录执行，未读取玩家存档。

## 复现、执行和结果

| 检查 | 命令 / 条件 | 预期 | 实际 |
|---|---|---|---|
| 原 12 项缺失 | 原发布清单与 `database.gd`、`hyperspace_reward_binding.gd` 比对 | 找到三项 | 三项确实不在原清单 |
| 直接 JSON 依赖 | 从 `database.gd`、`hyperspace_reward_binding.gd`、`hyperspace_config.gd`、`hyperspace_entity_validation.gd`、`hyperspace_route_loader.gd`、`hyperspace_appearance.gd`、`main.gd`、`ui_text.gd` 提取字面 `res://data/*.json` | 全在清单 | 15 项，缺项 0 |
| 冻结奖励散列 | SHA256 `space_enemy_reward_early_frozen.json` 对比 `hyperspace_reward_binding.gd` 常量 | 一致 | `98cd28eff0860449fabaee6c5b8b9e705ec076da49181726e593b1cac0e2b64a` |
| 空 staging | 运行 `powershell.exe -NoProfile -File space-battleship/tools/build_release.ps1`；检查其新建的 `test/work/release-*/project` | 15 项配置、26 个逐项文件、三个目录齐全且文件与源散列相同 | Stage runtime inputs 通过；15+26 项齐全且同散列；`shaders` 已复制，Godot 导入无脚本/资源缺失错误 |
| 三个缺项各自注入 | 临时将每项源 JSON 改名，逐次运行同一发布脚本后恢复 | 非零、Stage runtime inputs、指出文件名 | 三次均 exit 1 且明确 `Missing required player data: <path>`；原文件已恢复 |
| 初始化、新档、保存重开 | 将本目录 `s05_probe.gd` 放进上述 staging，隔离 `APPDATA/LOCALAPPDATA/USERPROFILE/TEMP`；Godot `--headless --path <staging> --script res://s05_probe.gd -- new` 后以 `reopen` 再运行 | 数据库两项非空、奖励契约有效、真实 `save_progress()` 成功、重开保留资源 4321 | 两次 exit 0；`S05_NEW_SAVE_OK data=15 resources.1=4321`、`S05_REOPEN_OK resources.1=4321`；`startup_error` 为空，`save_enabled=true` |
| Windows 完整发布构建 | 同一发布脚本继续 Godot 导入 | 完整导入并导出 | **BLOCKED**：当前 CodexSandboxOffline 进程不能读取 Windows 根证书库，Godot 报 `ERROR: Failed to read the root certificate store.`；发布脚本正确阻止继续，未生成或发布新产物。目标 Windows 构建/实际包验收留 S22。 |

首次导入还揭示原 staging 遗漏 `res://shaders/retained_flights.gdshader`，报 `SCRIPT ERROR: Parse Error: Preload file ... does not exist`。加入 `shaders` 后复跑，脚本/资源缺失错误消失；剩余唯一导入错误为上述系统证书库读取。隔离探针的两次运行也输出同一证书库环境错误，但完整执行了数据库、奖励契约和保存重开检查。不能把该探针结果当作无错误的完整发布构建。

本地待检树和远端运行树逐字节一致：`2f161d9aac91d8d615770d9480d7dd6d9247b00d`；两个运行文件的 Git blob 分别为 `6c337fea7a31b1de5e118c6a147611072843d10c` 与 `f172c0c76d947fecef119ea7d4c31c7c6c9cfcd5`。
