# independent-rewrite-20261024

完成：基于 b4729b9a9803458b5ac19a4945c2fe0d5f76e51f 独立设计，首稿 0a69bc12 未通过审阅；本次已按六项反馈统整四份文档，修订稿待审阅。
交付：docs/independent-rewrite/README.md、architecture.md、gameplay.md、content-and-delivery.md。
范围：正常玩法、单一状态/执行、native 缺失规则补齐、现有 GPU/表现保留、Excel 唯一权威、存档/工具/测试重写与实施次序。

修订：
- 所有增长量统一有限精度 Amount，取消精确材料账本、逐级累计费用、前缀缓存和异步长报价；给出几何/进化材料费用反函数。
- 编辑器删除按用途划界；F8/F9 模拟、分析、候选生成、批次用途保留，以新 Session/native 重写必要入口。
- 首页列明授权改变、S1–S4 建议与撤回项；撤回退出强存、重铸写盘前置、CD 比例重算、换装锁阻止开火和重铸自动领奖。
- 船员初始 Lv0 与需求指数校正；玩家炮/希格斯保留发射同刻射线命中；换小舰只取消尾部装备 ID，不迁移机库存。
- 无人机业务算法及业务测试重写，不默认复用旧代码；纯表现和高效 native/GPU 为明确保留例外。
- 只读检查 Excel XML：现有公式与缓存保留；equipment_evolution 以数据库属性/材料费用/正式显示调用链核实有效，不据 JSON 存在恢复历史成长。

证据：设计文档含基线源码与工作簿定位，以及旧状态/重复工作/依赖的明确删除映射。
验证：仅检查 Markdown 内链、围栏和 Git whitespace；未运行游戏、构建或任何测试，也未重算 Excel。
限制：未读取 design/complete-rewrite-spec、docs/rewrite-design（含项目内同名路径）；未实施、未合 main；Git 唯一交付。
审阅点：S1 保存未领取普通拾取物、S2 教程不阻塞、S3 共享任务顺序/科研余时、S4 工具入口与快捷键；各有不采用时的行为。后续实现使用 sol medium。
剩余：用户审阅后再实施；无执行环境或权限阻塞。
