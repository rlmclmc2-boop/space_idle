# S08 配置事务可恢复：实施与验证

- 实施线程：`01a15cbc-2bea-7616-8273-5af69cf2d01c`
- 基线 main：`19879285e68f0e1b7ad722d7e27dd402ad4ab6ec`
- 运行候选：`cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8`，树 `dc633257c72cb8202b5f121455b36cba79443663`，分支 `s08/config-recovery`
- 运行文件：`space-battleship/tools/config_workbooks.py`、`space-battleship/tools/level_editor_store.py`。两者均为配置导入及关卡编辑器直接运行所需；无测试、日志或审计文件进入运行提交。
- 复现与测试：`s08_atomic_recovery.py`；原始输出：`fault_injection.log`。命令 `python s08_atomic_recovery.py`，Windows Python 3.12，退出码 0。脚本从指定 Git blob 和运行源 AST 提取目标函数，因此不依赖本环境未安装的 `lxml`；它只覆盖事务函数及编辑器 `execute` 的文件流程，不代表整个工作簿导入或游戏入口验收。首次尝试直接导入 `config_workbooks` 因本环境缺 `lxml` 失败，之后改为 AST 隔离注入。

基线故障注入按 `os.replace` 调用序列令 B 安装失败、A 回滚再失败：磁盘为 A新/B旧，旧版临时文件已被 `finally` 清理。候选同一注入下抛出 `RecoveryRequired`，JSON 命令层有 `recovery_required=true`、`recovery_path` 和 `rollback_failed`；该路径下清单列出绝对目标、原件文件、原件及替换件 SHA-256。测试核对两份原件哈希，混合状态仍有旧版 A/B；人工用清单原件恢复 A 后，两者均为旧版。单失败时自动逆序回滚并清理生成的事务目录；成功时清理生成的事务目录。编辑器先独立提交旧版备份与清单，再安装正式文件；二次失败时独立备份和事务日志同时存在。

恢复操作：停止编辑器及配置导入；按返回的 `recovery_path/manifest.json` 核对每个 `original_sha256`，逐项检查目标当前哈希，再用 `original` 文件恢复旧版。清单中 `original=null` 的目标原先不存在，应由操作者核对后决定是否移除。恢复完成且故障原因排除后重新发起编辑器保存或工作簿导入。原件、独立编辑器备份及清单由操作者确认后再清理；运行代码不会自动删除失败恢复材料。恢复目录位于项目 `.runtime/config-recovery/<uuid>`，编辑器备份位于 `.runtime/level-editor-backups/<uuid>`；此布局及保留策略交父级与原 astra 双审。

限制：这仅是安装失败时的可恢复回滚；多文件提交期间或进程/机器突然中断仍可能出现混合版本，不能宣称跨文件 ACID。审计前不合 main、不关闭 S08，也不清理 S06/S07 分支。
