# architecture-renewal-20261022

唯一入口：`../../../../docs/architecture/IMPLEMENTATION.md`。
状态：经济与成长持有权和保存迁移进行中。源自已审阅授权，覆盖现有 route 的 save/equipment-slot/specialty/combat-local。
扩读理由：需要确定实际写入者和提交边界；精确范围为 scripts/game.gd 的资源、成长和保存函数，直接调用的领域脚本，scripts/save_transfer.gd、progress_writer.gd，以及对应现有专项夹具。战斗和 native 在后续阶段按实际依赖扩读。
