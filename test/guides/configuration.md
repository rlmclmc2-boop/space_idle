# 配置导入与编辑器

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 配置导入 | 按所改分表选择 `test_crew_import.py`、`test_unlock_import.py`、`test_equipment_growth_import.py`、`test_jewel_furnace_import.py`、`test_reactor_config.py`、`test_scientist_config.py` 或 `test_offline_config.py` |
| 配置工具与编辑器 | `test_config_workbooks.py`、`test_level_editor.py` / `test_level_editor.gd`、`test_config_panel.gd`；输入/事务边界用 `test_config_input_matrix.py` |


S3 公共边界：`test_config_input_matrix.py` 在完整隔离快照上覆盖当前 importer/editor、崩溃恢复、真实 Python/Godot/PowerShell 排他、恢复期间外部写入竞争、CLI 恢复位置以及构建捕获后源变化。它替代旧直接 `atomic_batch` 行为刻画；恢复失败必须保留材料。`test_level_editor.py` 保留公式、ZIP 部件、来源冲突及回滚断言；无效源比例现在应拒绝发布，之前有效的运行代际保持不变。两者通过 `test/run.py` 运行，需要 openpyxl/lxml；`test_level_editor.gd` 另验实际 UI 工作线程。
