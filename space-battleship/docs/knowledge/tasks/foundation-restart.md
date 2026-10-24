# 首阶段当前调整

基线：97d244450824c4db5ae20a3b921fc79bd072d869。
最新用户要求覆盖原方案冲突部分：删除 schema 和输入清单，不把字段/引用规则搬到代码；删除 ConfigBundle、阶段测试/fixture/runner 与验证记录。整体架构完成后再整体测试，当前只检查编译，唯一测试例外为独立 Amount 的直接 C++ 正确性测试。
实际保留：Excel 目录到普通 JSON 的转换；共享 C++ Amount/绑定；实际保存骨架及文件替换原语；既有 native/GPU 与资产。
配置消费：直接加载 generated/config.json；改值通过 Excel 再导入，不提供查询包装或替代测试体系。
交付：仅本轮删改和编译结果，提交推送后交审；不进入第二阶段、不合 main。发生压缩立即停止交接。

交接现场先在当前工作区以 de0c3f9c 保存；原 task-6 工作树保留不动。保留 foundation/tests/amount_value_tests.cpp，并明确其编译命令和唯一例外边界。

## 剩余跨模块依赖：待用户确认必要性

依最新要求，以下只登记事实与选择，不由实现线程判定必要或验收保留：

| 双方 | 当前依赖内容及用途 | 可选替代 |
|---|---|---|
| Godot 适配层 → Amount | amount_api.hpp 包含值类型并调用公开运算/编码接口，用于 Godot 调用统一算术 | 保留公开接口依赖；或增加编译边界，将值实现移到独立编译单元 |
| SaveFiles → FoundationDisk | 通过 ClassDB 中的固定类名和 replace 方法调用平台 flush/文件替换 | 保留该调用；或由宿主传入文件替换函数 |
| native 初始化/构建 → Amount 绑定、磁盘原语和战斗类 | space_native.cpp 同时包含并注册它们，SConstruct 构建一个 DLL | 同 DLL 拆分编译单元；或拆成独立扩展/DLL |
| SaveFiles ↔ 配置身份 | 构造时要求调用方传入 config_hash，读存档时要求 configHash 完全匹配；导入器已不生成该标识 | 由宿主确定兼容策略并传入标识；或去掉保存层的配置身份匹配，交给业务入口决策 |

独立 Amount 测试只依赖该模块公开接口，是用户明确允许的唯一测试例外。Excel 导入器不依赖 Amount；保存层不解释 Amount 金额。上述必要性须交父级请用户确认，本轮未据此新增封装或改变存档协议。
