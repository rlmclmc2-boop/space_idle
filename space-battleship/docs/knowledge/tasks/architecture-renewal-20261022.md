# architecture-renewal-20261022

唯一入口：`../../../../docs/architecture/IMPLEMENTATION.md`。
状态：经济与成长持有权和保存迁移进行中。源自已审阅授权，覆盖现有 route 的 save/equipment-slot/specialty/combat-local。
扩读理由：需要确定实际写入者和提交边界；精确范围为 scripts/game.gd 的资源、成长和保存函数，直接调用的领域脚本，scripts/save_transfer.gd、progress_writer.gd，以及对应现有专项夹具。战斗和 native 在后续阶段按实际依赖扩读。

进度：首候选 28d9a6e7 的普通余额/反应炉/保存获双审局部通过。材料闭环运行候选 580aea8e 已提交；下一步迁移 ai_tech_tree.gd、game.gd 研究接口、main.gd 研究通知消费者和对应现有专项。未开展整体产品验收、不合 main。

科研闭环运行候选 c7d91ec6：等级/进度/投入/峰值/未读退出 profile，准备研究切片后由 Game 联合经济提交，保存验证后安装。相关验证通过。阶段 1 仍进行；下一闭环为装备状态、跨域换装/舰体提交，优先读取 game.gd 的 module/slot/loadout 与对应现有专项。

装备闭环运行候选 f04d88f524af7dabaa5711680903c39b109b3e70：装备/舰体/换装期限退出 profile；同源购买计划与经济联合提交、舰体/无人机裁剪通知边界完成。222 项相关检查通过，另有旧生成器大样本失败/超时如实记录，未扩展为前置工程。唯一入口的 c4 段记录证据与剩余职责；阶段 1 未完，待双审，不合 main。

共享强化迁移进行中：f04d88f5 已获双审局部通过。精确范围为 game.gd 强化成长/费用/门槛/历史、enhancement_growth.gd、分支与 UI 消费者、native 计数编译/同步/交接和 save_transfer.gd。验证复用费用、共享门槛/攻击、native 与现有四进程保存夹具；旧生成器未完成专项不扩展。

共享强化运行候选 e83ef208cc98ba3c74f17beec5b074e66412f704：等级/顺序/分支/精确历史、报价与贡献规则归 enhancement_growth；native 计数同步经完整提交，保存验证后安装。438 项必要检查通过，证据在唯一入口 c5。下一范围为 crew_system.gd 与 game.gd 船员/星球成长和保存的直接调用，按依赖再接星系。阶段 1 未完，待双审，不合 main。

强化复核修订 5ac08cdad818c175a537c3147b905e0198be4552：面板历史公式退出，运行查询输出领域结果；既有摘要专项 141 项通过。后续船员状态/经验/派遣/保存和星系待结算时间的跨域边界正在迁移，继续同一入口与分支。

船员运行候选 ccf124816e040a246b493e43653237c279510988：状态/保存/准备提交归船员域，Game 联合结算共享经验与派遣；300 项必要检查通过。下一精确范围：game.gd 星球函数、planet_buildings.gd、planet_buffs.gd、保存验证及其 UI/native 直接消费者。继续迁移星球，再接星系；不合 main。

星球运行候选 e1a1d9b7ac7a124763e1805d3d7d8e808ff9cd83：探索/建筑/征服退出 profile，当前快照严格安装，993 项相关验证通过。用户更新：不要求现有存档连续性，可新档，不为旧记录加兼容；改造后持久化可靠性仍必须保证，不删除个人存档。下一精确范围：galaxy_system.gd、galaxy_region.gd、galaxy_effect_aggregator.gd、Game/native 直接接线与既有星系专项。

加载顺序修订 46bdab29035abd4c8c95fc08472a279a9ab6f21b：所有领域安装后才建立贡献、协调容量和船员调度；extra_storage +反应炉岗位+超基础容量分配的真实四进程保存验证 71 项通过。强化修订和船员获双审局部通过，星球修订待复核；继续既定星系范围，不合 main。

星系运行候选 f94a3434be882e11596e8b7637e2d54af980a96d：区域和待结算/收入时间独立持有，profile 别名与旧加载修补退出；Game 具体协调器提交经济/native 与工作，通知前消费时间。v8 新格式真实重开正确，3,593 项必要验证通过，GPU 画面已目视核查，非产品性能验收。加载修订 46bdab29 已先独立推送。下一精确范围为 hyperspace_system/state/manual_session 与 Game 的余下持有权/保存/提交接线，随后按唯一入口闭合属性、外部时间和已批准的异空间返回语义；不合 main。

星系预览修订 75d6e4c1e7e2c024e1b163253926d3fff97265a9：两个既有入口改用完整领域快照安装，实际 GPU 运行成功，画面已检查。加载修订局部双审通过；星系主业务局部双审通过，预览修订待复核。继续异空间返回目标/会话/保存闭环，扩读 Game.tick/start/native cancel 和直接 UI 消费者、现有 manual/layers/departure/save 夹具；保留后续状态持有权和整体性能验收。

异空间返回运行候选 28647422cddd30e1827e5d135228d58ca5f4a91e：删除半场图及字段恢复，仅留返回目标，完整逻辑步后切换并按正常新开局返回；v9/子 v7 当前保存、真实四进程重开与 GPU 出口共 378 检查通过。未运行旧半场/旧档专项，不使其旧断言阻止新契约。下一范围继续 hyperspace_system/state/scheduler、profile.hyperspace 全部生产读写及对应已有专项，迁移领域持有权；整体产品性能未验收，不合 main。

异空间持有权候选 82c0059d22013e463f815efc0b38d099ebbb8142：状态/时钟/库存/领奖未读退出 profile；具体准备、版本复核、经济/native 协调提交和当前保存闭合，500 项必要检查通过。75d6e4c1、28647422 已获双审局部通过。本候选待审；下一精确范围为 economy_state.gd/growth_number.gd 及普通资源算术直接消费者，继续已批准有限精度与属性/时间阶段；材料整数不扩大近似。正式产品性能仍待验收，不合 main。

下一数值闭环已定位：GrowthNumber 算术遇到 {i} 会转入 ReactorInteger 逐位运算；经济另有 exact_budget/reactor_affordable/reactor_remainder，反应炉价格/MAX 维护逐位成本 cursor。需统一普通资源与价格路径；材料/核心、强化历史和反应炉分配整数具有不同职责，不能随资源近似一并改掉。当前仅完成直接依赖核查，尚未提交该数值改动。

有限精度运行候选 9b779670f0d9f0a58438e719b284af9fdbb1f02f：普通资源退出逐位整数和特殊反应炉钱包分支，批量/MAX 共用有限报价，保存 v10；材料/核心、强化历史及容量/分配整数边界保留，605 项必要验证通过。82c0059d 已获双审局部一致通过，本候选待审。下一精确范围为 game.gd stat/equipment_stat/invalidate_stat_cache、直接贡献聚合器、各领域贡献版本与 native 配置消费者，再接 tick/advance_shared_clock_and_economy 及主场景外部时钟；整体产品与性能未验收，不合 main。

属性与缓存运行候选 ddcd667eda1e13bd5dcc5b3ace5b28ed95700ba4：属性投影接管组合/取整/派生缓存，领域实际贡献版本取代全局清缓存；native 编译外部贡献同源，重复配置事件编译与科研逐查询整表 hash 退出。824 项必要检查通过，真实四进程保存/GPU 入口证据在唯一入口 c12。9b779670 已获双审局部通过。本候选待审，下一精确范围为 Game.tick/advance_shared_clock_and_economy、main._process、暂停/倍速/失焦和 galaxy_runtime 可见性接线；统一时间尚未改动，完整产品/性能与 native 收敛未完，不合 main。
