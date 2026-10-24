# 首阶段当前调整

基线：97d244450824c4db5ae20a3b921fc79bd072d869。
最新用户要求覆盖原方案冲突部分：删除 schema 和输入清单，不把字段/引用规则搬到代码；删除 ConfigBundle、阶段测试/fixture/runner 与验证记录。整体架构完成后再整体测试，当前只检查编译，唯一测试例外为独立 Amount 的直接 C++ 正确性测试。
实际保留：Excel 目录到普通 JSON 的转换；共享 C++ Amount/绑定；实际保存骨架及文件替换原语；既有 native/GPU 与资产。
配置消费：直接加载 generated/config.json；改值通过 Excel 再导入，不提供查询包装或替代测试体系。
交付：仅本轮删改和编译结果，提交推送后交审；不进入第二阶段、不合 main。发生压缩立即停止交接。

交接现场先在当前工作区以 de0c3f9c 保存；原 task-6 工作树保留不动。保留 foundation/tests/amount_value_tests.cpp，并明确其编译命令和唯一例外边界。
