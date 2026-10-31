# 首阶段调整历史（非当前交接）

本页保留早期用户决定及实现来源；“当前”“本次”“发生压缩立即停止”等执行指令已结束，不适用于接替任务。现行入口：[game-design/README](../../game-design/README.md)。保存/配置身份的设计冲突仍见[裁定清单](../../game-design/review/conflicts.md)，不以本页替代冲突裁定。

基线：97d244450824c4db5ae20a3b921fc79bd072d869。
最新用户要求覆盖原方案冲突部分：删除 schema 和输入清单，不把字段/引用规则搬到代码；删除 ConfigBundle、阶段测试/fixture/runner 与验证记录。整体架构完成后再整体测试，当前只检查编译，唯一测试例外为独立 Amount 的直接 C++ 正确性测试。
实际保留：Excel 目录到普通 JSON 的转换；共享 C++ Amount/绑定；实际保存骨架及文件替换原语；既有 native/GPU 与资产。
配置消费：直接加载 generated/config.json；改值通过 Excel 再导入，不提供查询包装或替代测试体系。
交付：仅本轮删改和编译结果，提交推送后交审；不进入第二阶段、不合 main。发生压缩立即停止交接。

交接现场先在当前工作区以 de0c3f9c 保存；原 task-6 工作树保留不动。保留 foundation/tests/amount_value_tests.cpp，并明确其编译命令和唯一例外边界。

## 模块依赖：用户已确认处理

以 478c0e5fc73382eeee8565d93a9029479a8c08b5 为基线，用户确认删除保存与配置哈希的绑定，保留其余三项依赖：

| 双方 | 确认后的处理 |
|---|---|
| Godot 适配层 → Amount | 保留公开运算/编码接口调用 |
| SaveFiles → FoundationDisk | 保留 ClassDB 固定类名及 replace 平台文件替换接口 |
| native 初始化/构建 → Amount 绑定、磁盘原语和战斗类 | 保留同一个 native DLL 的注册和发布 |
| SaveFiles ↔ 配置身份 | 已移除构造/读取参数、封套字段、写入任务字段和强制匹配判断；只按目录读取存档 |

文件 checksum、payloadHash、格式/代际检查、A/B 槽与主备指针、异步写入和失败处理继续保留。独立 Amount 测试仍是唯一测试例外；本次不新增保存测试。Excel 导入器不依赖 Amount，保存层不解释 Amount 金额。完成受影响脚本编译检查后提交推送交审，不进入第二阶段，不合 main。
