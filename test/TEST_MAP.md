# 核心规则断言索引

仅把现行专项断言视为保护；COVERED 不代表覆盖所有输入。PARTIAL 保留明确缺口，不把历史综合探针或故障观察通过当作正确性保证。运行方式：`python test/run.py <TEST_FILE>`，写入全部在隔离副本。

| RULE | TEST_FILE | ASSERTION | STATUS |
|---|---|---|---|
| 伤害 ceil / 最小1 | test_rule_rounding.gd | Matching resistance / minimum one / Nonmatching | COVERED |
| 护盾溢出剩余原始伤害 / 装甲抗性 | test_rule_rounding.gd | Shield overflow / Physical overflow / Exact absorption | COVERED |
| 掉落倍率取整→自动损耗再次取整→事件与入账一致 | test_rule_rounding.gd | Drop rounds / Auto loss rounds independently / Manual credit | COVERED |
| 初始资源 / 升级费用向上取整 | test_rule_rounding.gd | Starting resources / Fractional final cost / deduct same cost | COVERED |
| 关卡倍率插值、端点截断 / 敌武器空字段回退 | test_rule_rounding.gd | Within-stage / base one / endpoints / own row / blank fallback不写源表 | COVERED |
| 反应炉能源、逐级费用与MAX | test_reactor.gd; test_reactor_config.py | 配置源一致、100×1.2^(L−1)、100×1.4^(L−1)、x10与MAX逐级扣费 | COVERED |
| 科学家逐人费用 round | test_scientists.gd | Third cost / Ten purchase equals ten sequential rounded costs | COVERED |
| 大数研发与显示 | test_large_numbers.gd | 大数预算、等级、有限时间退出和显示不溢出 | COVERED |
| 战斗/前进/驻守 | test_guard.gd | 巡航到达、无移动、清敌等待、重复驻守 | COVERED |
| 跃迁已通关 / 拒绝未通关 | test_loop_retreat.gd | warp cleared / rejects uncleared | COVERED |
| 死亡回退 / 三种驻守处理 | test_guard.gd; test_loop_retreat.gd | 原点/就地/取消、跨关、恢复生命 | COVERED |
| 通关等待、立即过关、重复点击 | test_skip_clear.gd | acknowledgment / repeated click / automatic countdown | COVERED |
| 暂停冷却/生产/研究 | test_travel_cooldowns.gd; test_furnace_income.gd; test_scientists.gd | Pause freezes / preserves | COVERED |
| delta截断 / 子步 / 1X、2X、5X | test_time_steps.gd | delta 0.04/0.1/0.8 × speed 1/2/5；每步≤1/60、总和与前进距离 | COVERED |
| 在线模拟时间与现实保存计时 | test_time_steps.gd | Online save interval / UI clock / pause state deep equality | COVERED |
| 同名槽位等级与冷却独立 / 首槽卸下 | test_state_ownership.gd | independent levels、0.7/0.2冷却、remaining slot | COVERED |
| 空槽与槽位数组不共享实例 | test_ships.gd; test_state_ownership.gd | Empty layout / array identity / explicit old empty | COVERED |
| 同种装备无数量上限 / 旧数量字段不限制安装 | test_ship_equipment_limit.gd | within limit / Legacy same-kind cap no longer restricts installation | COVERED |
| 换舰保留成长、资源与通关 | test_module_refit.gd | 换舰不退款、不重置模块等级；资源与模块成长保留 | COVERED |
| 护盾升级保损及恢复延迟 | test_state_ownership.gd | absolute missing capacity / delay / hit resets / cap | COVERED |
| MAX预算边界、10次与逐次一致、级数上限 | test_bulk_upgrades.gd; test_equipment_limits.gd | exact ten-level budget / all-or-nothing / cap | COVERED |
| 自动生产间隔、飞行、拾取损耗 | test_auto_gen_resources.gd | interval / full13 / loss7 | COVERED |
| 击杀掉落、手动/自动拾取 | test_reactor.gd; test_auto_gen_resources.gd | smelting only enemy iron / full pickup / auto loss | COVERED |
| 炼铁炉、非自身收入峰值、寿命 | test_furnace_income.gd | base150 / peak200 / expire / no amplification | COVERED |
| 60秒收入窗口、资源分离、支出不扣收入 | test_resource_display.gd; test_furnace_income.gd | exact boundary / expired zero / spending | COVERED |
| 离线微粒、上限、倒时钟、旧存档 | test_offline_resources.gd | 每完整秒、12小时、零上限、回拨、旧离线速率不结算 | COVERED |
| 资源守恒 | test_module_refit.gd; test_bulk_upgrades.gd; test_reactor.gd | 换舰不退款、逐级成本、反应炉分配不扣铀且不超过总能源 | COVERED |
| 目标位置排序 / 抗性优先 / 全抵抗回退 | test_target_resistance.gd | non-resistant first / positional ties / all resistant | COVERED |
| 导弹分配、占用目标、少敌全齐射 | test_target_resistance.gd | distinct targets / unlocked target / one target salvo | COVERED |
| 普通弹失锁不重选 / 新弹重选 | test_projectile_lifecycle.gd | trajectory / next fire；显式安装对应武器与两目标夹具 | COVERED |
| 失锁直飞、出屏删除、死亡发射者弹体 | test_projectile_lifecycle.gd | flies straight / leaving screen / dead shooter / player death | COVERED |
| BOSS/末敌清弹及同帧致死弹不再结算 | test_boss_projectile_clear.gd; test_final_encounter.gd | no lethal hostile resolution / last small group | COVERED |
| 战斗冷却推进 / 前进重置 / 暂停 | test_travel_cooldowns.gd; test_state_ownership.gd | full cooldown / no early fire / independent countdown | COVERED |
| 现实时间收入窗口 | test_resource_display.gd; test_furnace_income.gd | 显式时间戳的60秒边界 | COVERED |
| 离线微粒/统一倍率 | test_offline_resources.gd; test_time_steps.gd; test_chrono_ui.gd; test_chrono_login.gd; test_offline_config.py | 12小时储量、旧档、现实时间扣费、游戏时间、后台x1在线收益；每次启动报告实际新增微粒含零收益，配置扩展 | COVERED |
| 加载：只结算微粒并保存 | test_save_boundaries.gd | load→save→player；不推进离线充能或研究 | COVERED |
| 当前存档版本内旧levels、缺loadout、矛盾首槽优先 | test_state_ownership.gd | legacy migration / conflict first slot / missing levels | COVERED |
| 缺字段、资源小数修复、重复保存加载 | test_save_boundaries.gd; test_state_ownership.gd | fractional123.5→124 / negative clamp / Missing fields / Repeated load | COVERED |
| 重复加载不重复领取微粒、离线不推进研究 | test_offline_resources.gd; test_save_boundaries.gd | 重载只结算新增离线时间 | COVERED |
| .tmp 替换、写失败错误事件 | test_save_boundaries.gd | replace existing / no temp / open failure旧档字节不变 / rename失败事件且保留临时数据（现状观察） | COVERED |
| 保存完整故障恢复 | test_save_boundaries.gd | 已覆盖open/rename失败；未模拟断电、写入中磁盘满/损坏，U-008，不能保证所有故障原子性 | PARTIAL |
| QA删除后旧场景不得复活档案 | test_delete_save.gd | disk cleared / no resurrection / new game save | COVERED |
| 页签解锁/重锁/全隐藏 | test_tab_unlocks.gd | preserves selected / fallback / selected -1 | COVERED |
| 科研无拖拽、配置扩展、旧顺序兼容 | test_hightech_construction.gd; test_hightech_slots.gd | no drag / 12 projects / compact legacy holes / retained nodes | COVERED |
| 换舰候选选择 | test_module_ui.gd | selection no immediate switch / 点击确认后换舰 | COVERED |
| 科技滚动位置与页签保持 | test_hightech_slots.gd; test_hightech_construction.gd | scroll after refresh / selected tab / focus | COVERED |
| 通关解锁弹窗阻止自动推进 | test_skip_clear.gd | Unlock acknowledgment is preserved | COVERED |
| 伤害文本独立数字、位置避让 | test_damage_text.gd | 同帧与连续命中、真实文字边界不相交 | COVERED |
| 舰船/炮口/敌舰位置 | test_ship_visuals.gd; test_enemy_ship_visuals.gd; test_enemy_weapon_positions.gd | occupancy / muzzle / effect / symmetric mounts | COVERED |
| 资源总量/速率切换与重建保持 | test_resource_display.gd | toggles current total / rebuild preserves rate | COVERED |
| 科学家MAX即时按钮、暂停也更新 | test_scientist_affordability.gd | 0→1e100→0、paused/unpaused | COVERED |
| 读取不得修改profile、loadout、生命、冷却 | test_state_ownership.gd | Read purity深比较 + slot array identity | COVERED |
| 装备等级与玩家冷却唯一槽位状态 | test_state_ownership.gd | stale legacy ignored / no runtime levels / transient cooldowns | COVERED |
| 旧levels仅加载/保存兼容边界 | test_state_ownership.gd | derived first level / runtime unaffected | COVERED |
| MAX可购买性与原规则等价 | test_scientist_affordability.gd | scientist_purchase参照与profile纯度，500组参数各检查等价/纯度 | COVERED |
| 免费首人、递减费用、多资源、大数、锁定 | test_scientist_affordability.gd | 五种费用、五种预算、四种人数、锁定 | COVERED |
| 科学家正数量购买不变 | test_scientists.gd; test_scientist_affordability.gd | 十人与逐人实际扣费一致、0/1/10可购买性 | COVERED |

## 使用边界

本表是可复用断言索引，不是待办或必跑清单；COVERED 项不要求重复执行。已退役规则和已完成的一次性验收记录不保留。具体选测与运行见 [README](README.md)，有效未决项统一查 [STATUS](../space-battleship/docs/STATUS.md)。
