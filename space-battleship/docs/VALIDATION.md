# 验证与证据

## 2026-09-14 分表增量配置

- `tests/test_config_workbooks.py` 在 `../config-incremental-verification/` 临时子目录使用总表副本运行，8个用例全部通过：单表公式/缓存/样式保留且与全表投影一致；无变化零工作簿解析/零JSON写入；只解析单个修改文件；非法数据保留JSON与旧指纹；缺公式缓存整批拒绝；缺分表不静默忽略；同名同步与未改文件不重写；提交故障回滚已替换文件。
- 全表 `tests/test_import.py` 在项目副本运行通过；行数按实际来源核对，不再固定旧10关/20级。与增量路径复用同一转换/校验实现。
- 复制 scripts/tools/data/tests/场景及必要 assets 到 `../config-incremental-verification/game/`；APPDATA/LOCALAPPDATA 指向副本自身目录。最终 Godot 编辑器扫描退出0，图形 `tests/test_config_panel.gd` 14项断言全部通过、退出0，覆盖真实拆分按钮、排除总览、读取/无变化、暂停/5倍速、同进程重载及QA实例/路径状态保留。未运行无关战斗模拟。
- 视觉查看副本 `preview-config.png`：新增拆分/目录按钮与读取目录提示无重叠。Windows OS.execute 中文结果传输已改为 ASCII JSON 转义，由QA解码显示，图形断言验证成功提示及无变化提示。
- 本次仅在正式项目创建六份独立 Excel 与清单，未正式增量导入、未改写总表或玩家存档；游戏运行 JSON 未因测试改变。下一次读取首次建立指纹缓存，以后只解析修改过的分表。已测试拆分保留原始单元格XML与样式，不声称执行了 Excel 公式重算。
- 环境仍有既有 Windows 根证书读取提示；最终无本次脚本解析/运行错误。代码只新增配置流程，没有改动同期武器美术等逻辑。

## 2026-09-13 本次整理

| 检查 | 结果与局限 |
|---|---|
| 原表结构/公式缓存 | 7张表；257个公式用受限独立求值核对缓存，无差异/未支持公式。未改写或重算原文件。证据：audit/source-check.json |
| 原表 → 临时JSON → 当前JSON | 导入成功（10关/6敌机/7群/103装备行），结束时差异0；非原地导入 |
| `tests/test_import.py` | PASS：真实导入、数据行数、defaults保留、坏文件失败时保留原JSON；不代表全部输入边界都覆盖 |
| Godot隔离编辑器扫描 | 本地Godot v4.7.2.stable.official.ed1daf0bf；退出0，无脚本解析失败；有Windows根证书读取错误提示 |
| `tests/test_game.gd` | 最新副本/隔离用户目录运行：71 checks，0 failures，退出0；详细输出及测试输入哈希见 audit/game-check.json |
| `tests/test_config_panel.gd` | 同一最新副本、另一个隔离用户目录，有图形运行：11项检查通过、退出0，见 audit/qa-check.json；导入、暂停/继续、5倍速、场景重载/存档/QA实例保留、隐藏重显、来源历史持久化均覆盖 |
| 视觉布局 | 未额外验收像素布局；集成测试通过不等于完整视觉QA。图形测试同样出现根证书读取提示，不影响本次本地断言 |

测试解释：test_game 在内存覆盖部分武器伤害/CD/成本作为机制基准，数据文件保持不变；其“uses Excel”断言名不代表检查真实源表值。10关通关使用强化装备，尚未验证真实初始数值平衡，见 U-013。更早失败已由外部测试更新解决，不作为当前阻塞。

## 后续任务命令

### 2026-09-14 武器美术

- 内置 image_gen 生成三种PNG，检查均含真实alpha并原样保存至 assets/weapons；提示词随素材README保存。
- 必要脚本、data、assets及场景配置复制至 `../weapon-art-verification/`，隔离 APPDATA/LOCALAPPDATA。编辑器资源导入与扫描退出0；临时 capture_weapons.gd 有图形专项运行退出0，三张纹理正常加载，绘制敌我六发弹体，覆盖向右、向左倾斜及空目标。
- 已检查副本 weapons-preview.png：三种轮廓、配色可分辨，透明背景及朝向正常。scan.log/scan.err、capture.log/capture.err 无脚本错误，仅既有Windows根证书提示。纯美术接入未运行无关完整模拟/Excel导入。

### 2026-09-14 敌人生命显示

- 独立副本 `../enemy-health-verification/` 隔离 APPDATA/LOCALAPPDATA，编辑器扫描退出0；临时 tests/probe.gd 验证13组格式输入，全部通过，包含0、两位数、123、1230、单位边界及K/M/B/T。
- 有图形检查 normal.png/boss.png，普通敌舰当前/最大生命置于舰体右侧避免相邻槽遮挡，BOSS面板显示缩写。最终探针退出0；日志 scan.log/scan.err、test.log/test.err 仅既有Windows根证书提示。只改显示，未运行无关战斗模拟或改写玩家存档。

### 2026-09-14 资源收益切换

- 必要项目文件复制至 `../resource-rate-verification/`，APPDATA/LOCALAPPDATA 隔离，使用 `--script res://tests/test_resource_display.gd -- --capture` 有图形运行，未使用玩家存档。
- 编辑器扫描退出0；专项9项全通过、退出0：默认总量、按钮来回切换、实际手动/自动入账、扣费不影响收入、UI重建保留模式、资源分类、60秒边界淘汰及无收入归零。
- 已查看副本 resource-rate.png：顶部按钮与铁/钛每秒速率可读、无重叠。日志 scan.log/scan.err、test.log/test.err；有既有Windows根证书提示。未运行无关完整模拟/Excel导入。

### 2026-09-14 关卡旁 BOSS 信息

- 独立副本 `../boss-info-verification/` 复制 scripts/data/场景配置及 tests/test_boss_info.gd，隔离 APPDATA/LOCALAPPDATA，未使用玩家存档。
- Godot 4.7.2 编辑器扫描退出0，有图形专项8项全通过、退出0：未遭遇未知、普通敌群不揭示、BOSS遭遇揭示、死亡与重刷保留、未通关发现记录存档往返、不同关卡隔离、旧已通关存档兼容。
- 检查 boss-known.png 与 boss-unknown.png：信息位于关卡标题右侧，与循环选择及进度条无重叠。日志 scan.log/scan.err、test.log/test.err 仅有既有 Windows 根证书提示；未运行无关完整模拟或QA导入测试。

### 2026-09-13 护盾回归修复

- U-014 根因为 test_game.gd 硬编码旧恢复比例和等待时间，与当前 data/game_data.json 的 shield 1级 para2/para3 不一致；game.gd 正确读取当前配置。本次只修改测试及文档，不修改游戏恢复逻辑或运行数值。
- 复用原 advance/check，为护盾建立独立 BattleGame，跳过敌群以避免较长等待期间受击干扰；断言读取配置，覆盖等待期间不恢复、等待结束后每秒恢复量、再次受击重置等待及恢复上限。
- 复制 scripts/data/tests/test_game.gd 与场景配置至 `../shield-verification/`，隔离 APPDATA/LOCALAPPDATA。为确认此前完整模拟唯一失败项已消除，运行完整 test_game.gd：103项全部通过，退出0；编辑器扫描退出0。
- 日志：副本 scan.log/scan.err、test.log/test.err。仅既有 Windows 根证书提示，无脚本错误；未运行无关 Excel/QA 导入测试，未使用玩家存档。

### 2026-09-13 指定循环关卡与跨关死亡回退

- 独立副本 `../loop-retreat-verification/`，复制 scripts/data/场景配置与 `tests/test_loop_retreat.gd`，隔离 APPDATA/LOCALAPPDATA；未读取或修改玩家存档。
- Godot 4.7.2 编辑器扫描退出0；最终有图形回归18项全部通过、退出0，覆盖已通关选择限制、开启立即切换、持续重刷、独立目标存档、跨关剩余距离、目的位置敌群重放、非默认/零距离、精确关卡边界、第一关截断，以及跨关落在BOSS后方时在落点重新触发BOSS。
- 真实场景实例的下拉选择和开关信号已验证，窗口截图 loop-ui.png 已检查，关卡选择与循环状态无遮挡。未执行无关完整战斗/Excel/QA导入测试；既有 U-014 不在本次范围。
- 日志：副本 scan-out.log/scan-err.log、test-out.log/test-err.log；仅既有 Windows 根证书提示，无脚本解析或运行错误。

### 2026-09-13 自动拾取独立取整验证

- 在 `../auto-rounding-verification/` 复制 scripts/data 与场景配置，隔离 APPDATA/LOCALAPPDATA；从 test_game.gd 提取本次3项资源断言运行，不执行无关模拟。
- 3项全部通过，退出0：3×1.1掉落为4；自动损耗40%后提示/余额/本局累计均为3；手动拾取4后累计为7。静态确认标签直接使用整数 drop.amount，拾取提示使用 collect 事件 amount。
- Godot 4.7.2 编辑器扫描退出0；存在既有Windows根证书提示。日志为副本 scan.log/scan.err、test.log/test.err，探针为 tests/resource_probe.gd。旧合并取整验证属于历史规则，已由本次用户指令替代。

### 2026-09-13 掉落显示验证

- 掉落标签复用 number()，传入 ceilf(float(drop.amount))；静态检查确认仅更改显示参数，不回写掉落中间值或改变自动拾取损耗计算。
- 复制必要项目文件至 `../resource-display-verification/` 并隔离 APPDATA/LOCALAPPDATA，Godot 4.7.2 编辑器扫描退出0，无脚本解析错误；存在既有Windows根证书提示。日志为副本 scan.log/scan.err。
- 本次为单行显示修复，未运行无关模拟或QA导入测试，未进行窗口视觉验收。

### 2026-09-13 失去目标后弹体继续飞行

- 在 `../projectile-flight-verification/` 独立副本与隔离 APPDATA/LOCALAPPDATA 运行；保留当前资源取整等外部修改。
- 最终有图形 `tests/test_game.gd`：100项、99通过、1失败，退出1；唯一失败为既有 TODO U-014。无脚本解析/运行错误，仅既有Windows根证书提示。日志为副本 `visual.log`、`visual.err`。
- 覆盖激光/火炮不换靶且直线飞行、导弹无活目标后继续飞行、出屏清理、敌舰死亡后弹体在普通波次/BOSS通关后继续移动与命中、玩家死亡后敌弹继续飞行、无目标弹体实际场景绘制。未改无关护盾逻辑，未重跑Excel或QA配置面板测试。

### 2026-09-13 资源取整验证

- scripts/tests/data、project.godot、main.tscn 复制至 `../resource-rounding-verification/`，APPDATA/LOCALAPPDATA 指向该副本独立目录；未读写玩家存档或修改原表/运行数值。
- Godot 4.7.2 隔离编辑器扫描退出0；模拟86项、85通过、1失败、退出1，资源相关断言全部通过。唯一失败为既有护盾恢复检查，见 U-014；仍有Windows根证书提示。
- 新增7项覆盖中间倍率精度、倍率与损耗完成后单次取整（3×1.1×0.6 → 2，提前取整会误得3）、手动拾取/事件/本局累计、成本判定和扣除、起始资源、整数存档往返；更新自动拾取及旧小数存档期望。
- 仅在副本撤销本次4处资源实现作对照，护盾断言同样失败，同时出现9项资源期望失败；恢复副本实现。日志：test-out.log/test-err.log、baseline-out.log/baseline-err.log、scan-out.log/scan-err.log。保留同期外部后退距离修改；不改无关护盾实现或断言。

### 2026-09-13 backRange 验证

- 只读核对 config!A8:C8；临时导入对比仅 config 新增 backRange，随后现有导入器更新运行JSON。未修改原表。
- 独立副本运行 test_import.py 通过；test_game.gd 为79项、1失败，非默认/零后退距离新增断言均通过。换用新隔离用户目录仍复现；在副本撤回本次后退代码与新增夹具后同一护盾断言仍失败，见 TODO U-014。
- 日志：`../weapon-target-verification/backRange3.log`、`backRange3.err` 与 `baseline.log`、`baseline.err`；既有Windows根证书提示仍存在。副本源码已恢复为当前改动。

### 2026-09-13 武器死亡换靶验证

- 仅复制 scripts/tests/data、project.godot、main.tscn 至 `../weapon-target-verification/`，APPDATA/LOCALAPPDATA 指向副本下独立目录，未使用玩家存档。原项目 `.runtime` 写入被拒绝，改用工作区内独立副本。
- Godot 4.7.2 隔离编辑器扫描退出0；`tests/test_game.gd`：77 checks、0 failures、退出0。日志位于副本 test.log/test.err、scan.log/scan.err。仍有既有Windows根证书读取提示。
- 新增6项断言覆盖激光/火炮失去目标后清理且不伤害其他敌人、下次开火选择活敌、导弹死亡换靶及无活敌时清理。原有模拟继续通过；本次未执行无关Excel导入或图形QA。

在项目根执行，`python` 必须含 openpyxl；设置 GODOT 为实际引擎路径。不要将本机 Codex 安装路径写成必需依赖。

```sh
python tools/inspect_knowledge.py --sheet equipment --range A44:N45
python tools/inspect_knowledge.py --output docs/audit/source-check.json
python tests/test_import.py
```

test_import.py 使用 `.runtime` 下临时目录，首次需创建 `.runtime`。审计退出1可能表示发现配置差异，并不等于工具崩溃。工具不会改原表或运行JSON；完整审计只在来源/数据核对任务执行。

Godot首次接手先导入类缓存，再运行模拟测试。PowerShell示例（用**项目副本**运行，避免并行代码修改和QA覆盖）：

```powershell
$env:APPDATA = '<隔离目录>/roaming'
$env:LOCALAPPDATA = '<隔离目录>/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
& '<Godot可执行文件>' --headless --path '<项目副本>' --editor --quit
& '<Godot可执行文件>' --headless --path '<项目副本>' --script res://tests/test_game.gd
```

QA测试用有图形环境的同样副本，运行 `--script res://tests/test_config_panel.gd`；同时将原表置于副本父目录，创建副本 `.runtime`，隔离 user:// 偏好并检查实际Excel来源。此测试会临时更改副本JSON并显示附属窗口；仅重定向 APPDATA 不会隔离 res://data。headless普通游戏不自动创建QATools，不能直接用它运行这份图形集成测试。本次QA测试与game-check记录的同一源码副本一致。

验证范围随任务选择：只改文档检查链接/来源/状态；数值改动检查原表缓存、导入差异及受影响模拟；战斗改动跑对应规则及模拟；UI/QA改动另做按钮和真实窗口交互。不为文档整理修改既有测试期望。
