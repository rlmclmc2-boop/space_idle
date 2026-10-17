# AI 科技树功能实现

- 基线：`feat/ai-tech-tree-20261017@81968778c275798529770fcb0fec1eaa23866b66`。本线程独立检出，只负责逻辑、表、测试及 main 接线；页面与资产归美术线程。不得修改 D:/放置或合并 main。
- 规格：`docs/ai-tech-tree-20261017@8c09669b` 的 `docs/tasks/AI_TECH_TREE_20261017.md`；页面契约：`docs/tasks/AI_TECH_PAGE_CONTRACT_20261017.md`。
- 范围定位：`scripts/ai_tech_tree.gd`、`scripts/ai_tech_view_model.gd`、`scripts/game.gd` 的科技状态与收益、`scripts/main.gd:build_hightech_tab`、`config_excel/ai_tech_tree.xlsx`、`test/test_ai_tech_tree.gd`。
- 已验证：Godot `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`；科技规则 33/33 通过；配置与投影各 8 行通过。原始日志位于本工作区 `test/work/test_ai_tech_tree-w632mpbh/`。
- 当前阻塞：美术方 `scripts/ai_tech_factory_page.gd:138` 定义 `_input(parent, rect, resource_id)`，与 Godot `Control._input(InputEvent) -> void` 签名冲突。新增测试断言使 headless 结果为 `34 checks, 1 failure, exit 1`。页面源码由美术方修复后重跑。
- 待办：父线程分配 GUI 串行窗口后验收实际页面；父审后决定 main 合并。`0<R<1` 的联合因子仍按 `1+log10(R)/5`，不钳制。
