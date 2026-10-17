# AI 科技页面接线契约

新页面由 `res://scripts/ai_tech_factory_page.gd` 创建，`setup()` 构建 1344×1160 的 Control，放入旧科技 Tab 的位置即可。它不读取游戏状态、不算研究或收益，也不触碰存档。功能方在游戏状态变化时调用 `set_snapshot(Dictionary)`。页面会发出 `research_requested(technology_id: String)` 与 `investment_requested(resource_id: String, amount: int)`，功能方处理后再推新快照。折叠操作由 `set_drawer_open(bool)` 内部完成。需要懒刷新时可传 `set_snapshot_provider(Callable)` 并调用 `invalidate()`。

快照字段：

- `technologies`：按所需展示顺序的数组，每项含 `id`、`tier`（`independent/basic/core/final`）、`name`、`level`、`effect_text`、`requirement_text`、`state_text`、`can_research`、`action_text`。页面只显示传入文字，不推断前置或科技数值。
- `active_id`：真实正在研发的科技；`display_id` 可选，主场景装置要展示的科技，缺省使用 `active_id`；`researching`、`progress`（0–1 实数）、`remaining_text`、`status_text` 描述唯一真实研究。
- `ai_text`、`speed_text`、`iron_investment`、`uranium_investment`、`iron_state`、`uranium_state`：底部投入与加速读数，全部由功能方根据真实模型格式化。
- 可选 `generation_text` 放在当前科技项上；页面以 `shown.generation_text` 读取，用于真实代际显示。首代无需编造多代素材。

科技美术 ID 为 `ai_singularity`、`weapon_accuracy`、`equipment_reinforcement`、`resource_refining`、`fragment_condensation`、`equipment_precision`、`uranium_extraction`、`joint_integration`；同时识别对应中文名称。实际配置字段名可由功能方映射到此快照。

场景无常驻树侧栏；点击“选择研究”会用覆盖抽屉显示完整科技列表及每项由配置给出的前置文字。收起后抽屉控件不可见，主场景占满宽度。美术动作不会改变任何游戏模型；隐藏时停止动画。
