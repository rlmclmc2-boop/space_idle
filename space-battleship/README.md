# 太空战舰 — 启动与操作

AI从[AGENTS](AGENTS.md)开始；领域规则查[PROJECT](docs/PROJECT.md)，实现定位查[ARCHITECTURE](docs/ARCHITECTURE.md)。本页供人类启动、配置与迁移操作，不作为另一份游戏规则表。

## 启动和QA

- 修改 UI 文字：双击项目内 [UI文案表.bat](UI文案表.bat)，只改“UI文字”列，保存后重启游戏。参数自动校验，操作及发布说明见 [UI 文案表](docs/UI_TEXT.md)。
- Windows双击工作区`启动.cmd`运行游戏；项目`打开编辑器.cmd`打开Godot工程；`关卡编辑器.cmd`打开独立配置编辑器，三者用途不同。
- 游戏/工程启动脚本使用`engine/Godot_v4.7.2-stable_win64.exe`。独立关卡编辑器也可设`SPACE_BATTLESHIP_GODOT`；它使用`.runtime/level-editor-user/`独立用户目录。
- 日常启动直接使用已有资源缓存，跳过Godot资源导入；首次启动、缺少脚本类缓存/导入目录，或新增图片、声音、字体尚无`.import`描述文件时自动导入，失败查看`.runtime/startup-import.log`。替换已有资源后，在QA点击「大重启」重新导入并启动；资源导入不读取Excel。游戏运行只需引擎和已有投影。
- F1显示QA，关闭面板仅隐藏；暂停及1X/2X/5X在QA，偏好保存于`user://qa_settings.cfg`。空格/Esc按当前状态确认解锁、关闭帮助或暂停。
- 「重启游戏」在同进程重载场景；「大重启」保存进度/QA设置后，由辅助进程等待旧进程退出、导入磁盘资源再启动，应用代码更改，不自动读Excel。大重启保存失败留在原会话，导入失败不启动。
- 大重启忙碌时不要重复操作；错误看`.runtime/full-restart.log`及`full-restart-import.log`，修正后从启动入口重开。普通重启保存失败边界见[STATUS](docs/STATUS.md) U-008，不能推定与大重启一致。
- 「删除存档」是人类明确选择的破坏性操作：重置游戏进度，保留QA偏好和配置；旧场景停用保存以防回写。它不是排障或测试的默认步骤；AI保护约束见AGENTS。

## 配置操作

当前源与投影关系见[ARCHITECTURE](docs/ARCHITECTURE.md)。Python需openpyxl/lxml，可用`SPACE_BATTLESHIP_PYTHON`指定解释器；游戏本身无需Python。

1. 日常编辑独立分表：在表格软件中计算并保存`config_excel/`对应Excel → QA「读取配置」→ 成功后「重启游戏」。不要先同步总表。
   星球探索分别编辑 `planet.xlsx`（星球参数）、`level.xlsx`（经验系数）、`crew.xlsx`（升级经验）、`config.xlsx`（探索指数）；解锁关卡仍由 `unlock.xlsx` 统一管理。
   关卡解锁统一编辑 `config_excel/unlock.xlsx`：门槛改 `level`，提示改 `title/desc`；`name/type/target` 是配置及存档身份，不随名称改字。0表示初始开放，`mode=cleared` 指定关通关，`reached` 保留宝石累计进度语义。同关多项各占一行。原分表解锁字段已移除，旧总表字段被忽略；不要把它们作为解锁编辑入口。
2. 只有明确要用所选总表替换对应分表时，才用「拆分／同步 Excel」；它排除总览，更新同名表，不合并两处编辑、不删除无关文件。先备份并核对差异；旧总表与现行字段不兼容问题见STATUS U-018。
3. 普通导入不重算Excel公式，缺缓存应回表格软件计算保存；跨表公式可能阻止拆分。失败查看具体文件/单元格，不用猜默认值或手工JSON补数来绕过。
4. 无变化会显示无变化；导入/同步/重载期间按钮互斥。关卡编辑器的公式、备份与恢复按[LEVEL_EDITOR](docs/LEVEL_EDITOR.md)，不同入口的事务能力不能互相推定（U-019/U-020）。

## 只读定位

按稳定name/id与字段键找表，旧资料行号可能失效。项目根示例（范围按目标调整）：

```sh
python tools/inspect_knowledge.py --source config_excel/equipment.xlsx --sheet equipment --range A1:N6
```

指定`--sheet`必须同时指定`--range`；默认只打印结果。确需完整来源审计时才省略范围，并用`--output ../test/work/<任务>/source-check.json`保存证据。审计退出1可能代表来源变化、缓存问题或投影差异，不等于崩溃；旧总表审计结果不能证明独立分表仍与它一致。

## 跨电脑交接

### Windows release（一键发布）

双击工作区根目录 `build_release.bat`。成功后只分发 `release/SpaceBattleship.exe`，不需要复制本项目、引擎、Python、Excel、node_modules 或任何开发工具。自动化调用可用 `build_release.bat --no-pause`；默认成功或失败都保留窗口，失败返回非 0。

打包入口以自身所在文件夹查找唯一 Godot 工程（`project.godot` 与 `tools/build_release.ps1`），不要求 D 盘或固定的工程文件夹名，也不依赖启动时的工作目录。移动工程时保留工作区内工程、`test/` 和入口脚本的相对布局。构建日志会输出检测到的工程与输出根目录；导出副本中的模板路径每次重新绑定到当前工程，源预设即使残留旧电脑绝对路径，也不会沿用或被改写。找不到工程或找到多个工程时明确报错，不猜测目标。

- 目标为 Windows 10/11 x64，显卡及驱动需要支持 OpenGL 3.3（Godot GL Compatibility）。使用 Godot 4.7.2 **正式 release 模板 + Embed PCK**，引擎、GDScript 字节码、运行 JSON、图片、中文字体及字体许可证内嵌为单个 GUI EXE；音效由原有代码生成，无外部音频文件。不使用自解压、多文件安装器或开发引擎充当发布程序。
- 存档通过 Godot `user://` 写到 `%APPDATA%\SpaceBattleship\progress.json`，目录由 Windows 用户环境自动确定，无需手工配置环境变量；不会写到 EXE 旁边，也不会读取开发用 `.userdata`。发布版禁用 F1 QA、QA 偏好、截图作弊参数、控制台包装程序及常规日志。现有开发入口保持原行为。
- 构建读取当前 `data/game_data.json`、`data/ui_text.json` 和 `data/ui_text_contract.json`，不自动导入/重算/重置 Excel 和 JSON。Noto Sans SC 及 OFL 许可证放在 `assets/fonts/`，不需要玩家预装中文字体。
- 首次在另一台**构建电脑**准备：放入官方 `engine/Godot_v4.7.2-stable_win64.exe`；执行 `powershell -NoProfile -ExecutionPolicy Bypass -File space-battleship/tools/install_release_template.ps1`。模板安装脚本从官方 Godot release 下载约 1.3 GB 模板包，校验固定 SHA512，只提取 `engine/templates/4.7.2.stable/windows_release_x86_64.exe`。也可从同一官方包手工提取该文件。缺失、错误版本或损坏的工具会阻断构建，不自动降级。
- 构建顺序：独占锁 → 将旧 release 隔离到 `test/work/release-*/previous-release-not-current` → 检查工具 → 复制必要运行输入到隔离目录 → 导入/编译 → release 导出及 PCK 内嵌 → 检查唯一文件、PE GUI/x64/PCK 及系统 DLL → 同一输入另建 release 验证包 → 删除本次中间项目 → 隔离验证资源与禁用 QA → 删除验证程序 → 最终 EXE 正常入口渲染、写档并重开 → 最后发布。源码、正式玩家目录不参与测试写入。
- 任一阶段失败立即退出，日志给出阶段、核心错误及路径；未验证 EXE 删除，旧产物保持隔离，不回填到 release。完整日志在工作区 `build.log`，分阶段日志与截图在 `test/work/release-*`。修复后重新双击，完整重跑。不要把 `previous-release-not-current` 当作本次发布结果。
- 自动验证是本机隔离环境测试，并不等同于已经在另一台干净 Windows 真机验收；跨机验收只需复制最终 EXE，首次启动后确认字体/图片/声音、存档与重开恢复。平台系统 DLL、显卡驱动及操作系统属于运行前提，不是随包携带的开发依赖。

失败保护专项：`powershell -NoProfile -ExecutionPolicy Bypass -File test/test_release_failures.ps1`，在 `test/work/` 内构造缺工具、语法错误、坏模板和运行验证失败，检查非零退出码、旧版本隔离及残缺 EXE 清除。`test/verify_release.gd` 只进入独立验证程序，不进入最终 EXE。Godot 4.7 正式模板禁止外部 `--script` 注入，不能用编辑器运行代替发布验证。验证程序检查内部断言；最终 EXE 另从正常入口启动，保留真实渲染帧与存档/重开证据。

### 开发工程交接

保持工作区根`启动.cmd`、`太空战舰.xlsx`、`test/`和`space-battleship/`的相对布局。项目携带脚本、tools、场景、project.godot、data投影、config_excel（含manifest）、assets、Godot UID/导入描述、文档与启动脚本；不要只复制源码而遗漏素材/分表。
引擎二进制另行提供并匹配启动路径；安装上述Python依赖。缓存`.godot/.runtime`不作为交接必需品；正式`.userdata`属于个人进度，不是设计资料，续接进度须另行由所有者备份。其他平台不能执行.cmd，发布支持仍见U-010。
测试操作见[test/README](../test/README.md)，美术交付见[ART_GUIDELINES](docs/ART_GUIDELINES.md)。重构审计文件保留作本次历史，普通任务不需要读取。
