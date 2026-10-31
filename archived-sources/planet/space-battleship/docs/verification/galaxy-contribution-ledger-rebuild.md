# Galaxy 恢复贡献账本：定向验证

候选基点：`main@e93c221239a10d377b2ca89dd395ebcfa99c9819`。只修复 Galaxy 空账本首次构建；不包含 `5f85d3c5` 三项展示提案、比例命令或 main 合入。

规则依据：[03 §6–7](../game-design/03-progression.md#6-星系建设)、[模块职责](../../foundation/README.md#当前模块职责与跨模块契约)。active 节点按既有等级生效，重铸保留星系进度。恢复后清空派生账本，Session 初始化及 prepare_reforge 已调用无 changes 的 contributions；修复由 Galaxy 自己重建既有 active 来源，后续继续按 changes 替换来源。没有展示查询补账、配置/存档字段/玩法变更。

## 可复现证据

从 `space-battleship/` 执行（输出目录须已存在；不写个人存档）：

```powershell
python foundation/import_excel.py --output "$env:TEMP/galaxy-ledger-rebuild/config.json"
$env:SPACE_IDLE_GALAXY_PROBE_CONFIG = "$env:TEMP/galaxy-ledger-rebuild/config.json"
$env:SPACE_IDLE_NATIVE_EXTENSION = 'D:/CodexBuild/space_idle/native-stable/space_native.gdextension'
& 'D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP/galaxy-ledger-rebuild/final-probe.log" --script res://foundation/tests/_galaxy_contribution_restore_probe.gd
```

探针使用现行配置编译产物和原生 FoundationAmount，仅装配局部星系进度。手算期望：同区殖民环1级+2级→经验1.3，船坞3级→装备1.3，能源阵列4级→容量1.4，晶体5级→碎片1.5；铁2级、铀3级，生产率10/20、时长10秒→收入10/30。未完成施工节点不参与。

| 检查 | 结果 |
|---|---|
| 全新无 active 默认倍率、growth_changed=false | 通过 |
| restore_state 后无 changes 重建四种倍率、growth_changed=true | 通过 |
| 区域铁铀收入、非 active 排除 | 通过 |
| 重建不修改进度/RNG；重复调用不翻倍、growth_changed=false | 通过 |
| 空账本且只传一个 change，仍保留其他 active 来源；不改调用方 changes | 通过 |
| 后续殖民环2→3级替换来源，经验1.4；旧发布账本不被修改 | 通过 |
| 再次恢复原进度后经验回到1.3 | 通过 |

Godot `4.7.2.stable.official.ed1daf0bf`；上述探针退出0。相同探针对基点的单文件源码退出1，失败于恢复四种倍率、growth_changed、区域收入、首次部分 changes 和再次恢复；修复版消除这些失败。原生 DLL SHA256：`CE6761C5DBD96F7262FFB5418FD2794AFE52B6BF9A3164DB5EA528D8B790DD75`；配置输出 SHA256：`308B8F8089750DB99E0190526F2F1FDE91EE2950C5229567D295860B04D077DE`。

`--headless --path . --script res://src/main.gd --check-only` 退出0；候选文件 `git diff --check` 通过。探针启动有系统根证书读取提示，离线配置/Amount检查完成。未执行完整 Session 保存/恢复/重铸事务、完整游戏验收或跨星系场景；这些不能由本局部探针声称通过。未改 Session、存档或只读展示端口。原有179项生成文件修改与262项未跟踪元数据全部保留，未提交。

原始日志后补归档（未重跑）：[基点失败](galaxy-contribution-ledger-evidence/baseline-engine.txt)、[修复通过](galaxy-contribution-ledger-evidence/final-probe.txt)，以及[哈希与源码关联清单](galaxy-contribution-ledger-evidence/manifest.json)。日志按原字节保存；清单关联固定Git源码、执行探针及配置哈希，并区分工具退出码与引擎日志本身所含证据。此前探针草稿错误/中断尝试的日志已被覆盖，未补造。
