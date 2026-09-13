# 数据、来源与最小读取

## 事实归属

- **CONFIRMED（原表）**：指定原始输入 `../太空战舰.xlsx`。2026-09-14 用户授权拆分后直接编辑分表并增量导入，源关系与显式同步方向见下节；模块 Markdown 不能独立维护数值。
- **CONFIRMED（代码）**：现有脚本、运行 JSON 及默认值是“当前行为”证据，不自动成为用户批准的原策划。代码与表冲突保持两者，登记 TODO。
- **DERIVED**：必须列前提/来源与推导。**UNKNOWN**：仅在 TODO 集中记录，其他文件用问题 ID。
- `data/game_data.json` 是构建投影，不作为第二套手工平衡表；`defaults` 为原表以外参数的现有运行来源，导入器提供初始值并保留目标旧 defaults。`fallbacks` 为说明文字，真实补全算法在 database.gd。
- 指定总表、QA 选择的实验总表和编辑后的分表可能不同，不能推断自动一致。`audit/source-check.json` 为历史核对记录；当前来源追踪边界见 TODO U-001。

## 原表索引与 JSON 映射

### 2026-09-14 · 分表与增量配置（用户确认）

- 来源：用户要求新增拆分按钮，将所选总表中“总览”以外的表输出为独立 Excel；同名文件存在则更新；之后读取配置只处理修改过的配置。
- `config_excel/<工作表名>.xlsx` 为拆分后的可编辑配置来源，`.split_manifest.json` 保存对应关系和总表路径。首次已从指定总表生成 level/equipment/mon/monGroup/res/config 六份文件；总览不导出，未知附加工作表也会拆分，但目前只有这六种配置参与游戏投影。
- 修改总表：计算保存 → QA「拆分／同步 Excel」→「读取配置」→「重启游戏」。直接修改独立分表：计算保存 →「读取配置」→「重启游戏」。读取按钮不再读取总表；同步是显式用总表更新同名分表，不会合并两处编辑，也不删除无关文件。
- `tools/config_workbooks.py` 按 OOXML 包拆分，保留选中工作表单元格 XML（含公式和缓存）、格式及相关资源；清除其他工作表引用及计算链。跨表公式不静默改写，会定位单元格并拒绝拆分。导入不负责 Excel 重算，缺缓存时报告文件/单元格并保留旧投影。
- 首次/缓存失效时读取六张配置建立基线；之后用文件 SHA-256 检测修改，只对变化文件调用 openpyxl。未修改配置沿用现有 JSON，对合并结果进行跨表校验；无变化不解析工作表、不重写 JSON。读取过程中再次修改文件会中止并要求重试。
- `data/.import_state.json` 保存成功导入的文件指纹和目标 JSON 指纹，可重建；`game_data.json.source_files` 记录参与投影的分表绝对路径。JSON 和缓存一起提交，提交失败恢复已替换文件，失败数据不标记为已读。
- 原 `tools/import_workbook.py` 保留显式全表 CLI，供兼容审计使用；行转换/校验函数由增量导入复用，不再维护第二套数值规则。下面的历史范围按稳定字段定位，当前文件增删行后不能依赖旧坐标。

第 1 行为字段键，第 2–3 行为说明，第 4 行起为数据（总览除外）。按稳定 name/id 定位，增删行后更新坐标；不要只凭历史行号改表。

| Sheet / 范围 | 所属内容 | JSON 路径 |
|---|---|---|
| 总览!A3:D58 | 原始玩法、字段解释 | 规则解释进入 modules，不整表导出 |
| level!A4:F13 | 关卡 id/length/monGroup/atkRatio/lifeRatio/resRatio | levels[]；附加 groups[]={id,position} |
| equipment!A4:N23 | armour 1–20 级 | equipment.armour[] |
| equipment!A24:N43 | shield 1–20 级 | equipment.shield[] |
| equipment!A44:N63 | laser 1–20 级 | equipment.laser[] |
| equipment!A64:N83 | missile 1–20 级 | equipment.missile[] |
| equipment!A84:N103 | cannon 1–20 级 | equipment.cannon[] |
| equipment!A104:N106 | 三种敌方武器，仅 1 级 | equipment 中原始 `_mon`/`-mon` 键 |
| mon!A4:H9 | 6 敌机，武器引用、生命、抗性、掉落、占格 | enemies[字符串id]；equipment[]、drops[] 被解析 |
| monGroup!A4:C10 | 7 种十槽编队，null 为空 | groups[字符串id].slots[] |
| res!A4:B5 | 资源 ID/名称 | resources[字符串id] |
| config!A4:C8 | 起始装备、减伤、移动、自动拾取损耗、死亡后退距离 backRange | config[name]=para_1 |

装备通用字段：name+level 联合定位；dmg/CD 为单发伤害/冷却；dmgtype 见 combat；unlock 为通关条件（不把空白含义擅自补齐，见 U-004）；res_x 与 cost_x 配对表示**升到该行等级**的资源及数量。
para 含义：armour.para1=生命；shield.para1=容量、para2=每秒最大容量恢复比例、para3=受击后恢复延迟；laser/cannon.para1=弹速；missile.para1=目标数量、para2=弹速。来源：各装备首行 B 列说明。

## 公式与投影流程

当前公式按族：level!D5:D13 为 `ROUND(上一行*1.17,2)`，E/F 引用同一行前列；装备成长与铁成本的乘数/舍入以对应 E/I/L 单元格公式为准，不能在代码或文档再维护一套常量曲线。formula→缓存→JSON→ShipDatabase，运行时按等级查行，不执行 Excel 公式。

导入器使用 openpyxl `data_only=True`，**不重算公式**。须先在表格软件计算并保存；缺缓存或过期缓存先登记问题。工具处理全角分隔符并保留原字段；`mon.equipment` 的 `|` 解释有争议见 U-002。

只读定位（项目根，Python 环境须含 openpyxl）：

```sh
python tools/inspect_knowledge.py --sheet equipment --range A44:N45
python tools/inspect_knowledge.py --sheet 总览 --range A3:D10
python tools/inspect_knowledge.py --output docs/audit/source-check.json
```

审计在临时目录运行原导入器，将源表投影与当前 JSON 深比较；核对公式缓存并记录 SHA-256。仅支持本表出现的直接引用、ROUND 和四则运算，未支持公式会明确报 unsupported；不是通用 Excel 引擎。发现差异/来源变动返回 1。审计报告是生成证据，不手工编辑；不在普通任务中整份加载。

正式数值变更使用本页分表工作流：保存并计算所编辑的 Excel → 对应同步/读取操作 → 重启使用新数据 → 对应测试 → 更新状态及受影响文档。来源争议见 U-001；导入失败保留旧 JSON。扩展性限制见 U-007。
