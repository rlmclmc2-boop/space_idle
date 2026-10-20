# 审计交付索引

- [完整报告](REPORT.md)：与已交付报告逐字节一致，结论未作修改。
- [基线与环境](evidence/baseline.json)。
- `evidence/probe_*.gd`、`probe_atomic.py`：五个独立审计探针；同名 `.log` 为实际观测证据。
- `evidence/test_*.log`：既有专项的原始输出，`*_rerun.log` 为报告采用的纠正环境后的重跑结果；初次运行日志也保留。
- `evidence/results.json`、`combat_results.json`、`run_checks.py`、`run_combat_checks.py`：本次运行记录和驱动脚本。
- `evidence/import.log`：隔离工程导入日志。
- `SHA256SUMS.json`：报告及证据文件的 SHA-256 清单。

所有证据来自已完成的同一次审计。本次整理未重新运行诊断，未更改结论。报告中的 `/tmp`、`/workspace` 路径保留其历史含义；本分支的可移交文件位于本目录。

探针原样保留原执行路径，不应直接针对玩家工程或个人用户目录运行。复现时使用报告固定的提交和隔离工程、独立用户目录；脚本中的路径需对应隔离副本。发布清单探针依赖按报告 A03 所述另行构造的 staging。此目录不包含玩家存档、用户目录、凭据、素材导入缓存或构建产物。
