# AI 科技树功能实现

- 基线：`feat/ai-tech-tree-20261017@81968778c275798529770fcb0fec1eaa23866b66`；规格为 `docs/ai-tech-tree-20261017@8c09669b` 的 `docs/tasks/AI_TECH_TREE_20261017.md`。页面契约：`docs/tasks/AI_TECH_PAGE_CONTRACT_20261017.md`。
- 范围：科技逻辑、配置、测试和 main 接线；美术提交 `dac53d39627d7f5f83d192d838bd12f3999cf2bd` 已接收。不得修改 D:/放置或合并 main。
- 验证：Godot `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`；headless 34/34 通过；真实主场景 GUI 23/23 通过；配置与投影各 8 行通过。原始日志与截图见 `test/evidence/ai-tech-tree-20261017/`。
- 接线修复：页面投入信号为 `iron`、`uranium`；main 映射到模型资源 ID `1`、`2`。GUI 验证已覆盖扣款、不足与恢复、切页返回、隔离存档重载。
- 边界：`0<R<1` 的联合因子仍按 `1+log10(R)/5`，不钳制。下一步由父线程审查任务分支并决定 main 合并。
