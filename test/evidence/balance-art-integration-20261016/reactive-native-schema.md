# 3-3 反应型原生准入：字段类型修复

权威 `data/game_data.json` 的敌人 271024 存有整数 `reactiveReduction: 1`。Godot 读取后遭遇对象与 native descriptor 的该值实际为 `TYPE_FLOAT` 1.0（失败探针 `native-reactive-admission.log`），而 `combat_execution_kernel.h` 的 `schema_integers` 要求 `Variant::INT`，导致 `SpaceCombatKernel.configure` 返回 false。此拒绝在美术合并前候选也存在；不是反应规则数值不被 kernel 支持。

修复仅在 `native_execution_compiler.gd` 复制 enemy descriptor 前校验可选 `reactiveReduction`、`reactive_stacks` 为有限整数值且各在 0–1、0–3 范围，`reactive_volley_at` 如存在则须为有限数值；之后只将复制描述符的两个整数字段转为 int。权威 JSON、运行中的敌人词典和 kernel 严格 schema 不变。恶意字符串、非整数、越界及非法时钟继续在准入前拒绝。

`test_reactive_native_descriptor.gd` 的原生 DLL 定点测试通过 25 项检查：真实 3-3 对象为浮点 1.0、描述符变为整数 1，延续战斗的浮点叠层 1.0 也转为整数并被 kernel 接受、源对象不变、严格 kernel 能配置、直接传入未归一化浮点仍拒绝、7 组非法输入被编译器拒绝且无战斗状态变动，最后真实 3-3 原生准入成功。原始输出见 `reactive-native-descriptor.log`。此检查只证明准入及边界；反应叠层的原生实战反馈待后续同点短事件检查。
