# rewrite-stage1
目标：按 a815d2a 的 game-design/README.md 与 07 第5节实施第一阶段。
基线：b4729b9a9803458b5ac19a4945c2fe0d5f76e51f；分支 rewrite/stage1-foundation。
范围：独立Excel编译、C++ Amount与绑定、独立fixture、native headless入口、SaveFiles骨架。
禁止：合入main、触碰个人存档/原检出未提交内容、提前推进第二阶段。
停止：首阶段交付后等待dot及独立审核；上下文开始压缩即停。
精确扩读：06数据合同全文；05第5节native接口；现native头与构建脚本；正式Excel表头及类型行用于schema。
风险：现核仍用double，第二阶段迁移Amount；保存仅基础协议，不声称完整长期状态恢复。
下一动作：实现基础组件并用隔离目录运行受影响测试。
