# architecture-renewal-20261022

唯一入口：`../../../../docs/architecture/IMPLEMENTATION.md`。
状态：经济与成长持有权和保存迁移进行中。源自已审阅授权，覆盖现有 route 的 save/equipment-slot/specialty/combat-local。
扩读理由：需要确定实际写入者和提交边界；精确范围为 scripts/game.gd 的资源、成长和保存函数，直接调用的领域脚本，scripts/save_transfer.gd、progress_writer.gd，以及对应现有专项夹具。战斗和 native 在后续阶段按实际依赖扩读。

进度：首候选 28d9a6e7 的普通余额/反应炉/保存获双审局部通过。材料闭环运行候选 580aea8e 已提交；下一步迁移 ai_tech_tree.gd、game.gd 研究接口、main.gd 研究通知消费者和对应现有专项。未开展整体产品验收、不合 main。

科研闭环运行候选 c7d91ec6：等级/进度/投入/峰值/未读退出 profile，准备研究切片后由 Game 联合经济提交，保存验证后安装。相关验证通过。阶段 1 仍进行；下一闭环为装备状态、跨域换装/舰体提交，优先读取 game.gd 的 module/slot/loadout 与对应现有专项。

装备闭环运行候选 f04d88f524af7dabaa5711680903c39b109b3e70：装备/舰体/换装期限退出 profile；同源购买计划与经济联合提交、舰体/无人机裁剪通知边界完成。222 项相关检查通过，另有旧生成器大样本失败/超时如实记录，未扩展为前置工程。唯一入口的 c4 段记录证据与剩余职责；阶段 1 未完，待双审，不合 main。
