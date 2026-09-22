# 核心规则测试地图（Phase 10）

仅把现行专项断言视为保护；COVERED 不代表覆盖所有输入。PARTIAL 保留明确缺口，不把历史综合探针或故障观察通过当作正确性保证。运行方式：`python test/run.py <TEST_FILE>`，写入全部在隔离副本。

| RULE | TEST_FILE | ASSERTION | STATUS |
|---|---|---|---|
| 伤害 ceil / 最小1 | test_rule_rounding.gd | Matching resistance / minimum one / Nonmatching | COVERED |
| 护盾溢出剩余原始伤害 / 装甲抗性 | test_rule_rounding.gd | Shield overflow / Physical overflow / Exact absorption | COVERED |
| 掉落倍率取整→自动损耗再次取整→事件与入账一致 | test_rule_rounding.gd | Drop rounds / Auto loss rounds independently / Manual credit | COVERED |
| 初始资源 / 升级费用向上取整 | test_rule_rounding.gd | Starting resources / Fractional final cost / deduct same cost | COVERED |
| 关卡倍率插值、端点截断 / 敌武器空字段回退 | test_rule_rounding.gd | Within-stage / base one / endpoints / own row / blank fallback不写源表 | COVERED |
| 充能次数、费用 round 与跨级 | test_charge_growth.gd | 1.5→2、2.25→2、费率跨级与分帧一致 | COVERED |
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
| 同种数量限制 / 旧档超限不自动拆除 | test_ship_equipment_limit.gd | within limit / rejects excess / legacy | COVERED |
| 卸下退款、取消、重复卸下 | test_unequip.gd | cancel preserves / exact refund / no double refund | COVERED |
| 换舰退款、等级重置、保留科技与通关 | test_ships.gd | refunded / resets levels / other progress retained | COVERED |
| 护盾升级保损及恢复延迟 | test_state_ownership.gd | absolute missing capacity / delay / hit resets / cap | COVERED |
| MAX预算边界、10次与逐次一致、级数上限 | test_bulk_upgrades.gd; test_equipment_limits.gd | exact ten-level budget / all-or-nothing / cap | COVERED |
| 自动生产间隔、飞行、拾取损耗 | test_auto_gen_resources.gd | interval / full13 / loss7 | COVERED |
| 击杀掉落、手动/自动拾取 | test_charge.gd; test_auto_gen_resources.gd | smelter only enemy iron / full pickup / auto loss | COVERED |
| 炼铁炉、非自身收入峰值、寿命 | test_furnace_income.gd | base150 / peak200 / expire / no amplification | COVERED |
| 60秒收入窗口、资源分离、支出不扣收入 | test_resource_display.gd; test_furnace_income.gd | exact boundary / expired zero / spending | COVERED |
| 离线收入、上限、倒时钟、非法率 | test_offline_resources.gd | 77/8 / 4h / zero cap / rollback / invalid | COVERED |
| 资源守恒 | test_unequip.gd; test_bulk_upgrades.gd; test_charge.gd | refund、逐级成本、共享短缺扣费、prepaid credit | COVERED |
| 目标位置排序 / 抗性优先 / 全抵抗回退 | test_target_resistance.gd | non-resistant first / positional ties / all resistant | COVERED |
| 导弹分配、占用目标、少敌全齐射 | test_target_resistance.gd | distinct targets / unlocked target / one target salvo | COVERED |
| 普通弹失锁不重选 / 新弹重选 | test_projectile_lifecycle.gd | trajectory / next fire；显式安装对应武器与两目标夹具 | COVERED |
| 失锁直飞、出屏删除、死亡发射者弹体 | test_projectile_lifecycle.gd | flies straight / leaving screen / dead shooter / player death | COVERED |
| BOSS/末敌清弹及同帧致死弹不再结算 | test_boss_projectile_clear.gd; test_final_encounter.gd | no lethal hostile resolution / last small group | COVERED |
| 战斗冷却推进 / 前进重置 / 暂停 | test_travel_cooldowns.gd; test_state_ownership.gd | full cooldown / no early fire / independent countdown | COVERED |
| 现实时间收入窗口 | test_resource_display.gd; test_furnace_income.gd | 显式时间戳的60秒边界 | COVERED |
| 离线资源/研究/充能上限 | test_offline_resources.gd; test_scientists.gd; test_charge_growth.gd | cap / zero / exact completion boundary | COVERED |
| 加载：资源收入先于充能扣款，再研究，再保存 | test_save_boundaries.gd | Offline credit precedes charge / settled save；局部观察子类实际调用原方法，断言load→charge→research→save→player | COVERED |
| version1、旧levels、缺loadout、矛盾首槽优先 | test_state_ownership.gd | legacy migration / conflict first slot / missing levels | COVERED |
| 缺字段、资源小数修复、重复保存加载 | test_save_boundaries.gd; test_state_ownership.gd | fractional123.5→124 / negative clamp / Missing fields / Repeated load | COVERED |
| 重复加载不重复离线收入/研究 | test_offline_resources.gd; test_scientists.gd | reload cannot claim twice | COVERED |
| .tmp 替换、写失败错误事件 | test_save_boundaries.gd | replace existing / no temp / open failure旧档字节不变 / rename失败事件且保留临时数据（现状观察） | COVERED |
| 保存完整故障恢复 | test_save_boundaries.gd | 已覆盖open/rename失败；未模拟断电、写入中磁盘满/损坏，U-008，不能保证所有故障原子性 | PARTIAL |
| QA删除后旧场景不得复活档案 | test_delete_save.gd | disk cleared / no resurrection / new game save | COVERED |
| 页签解锁/重锁/全隐藏 | test_tab_unlocks.gd | preserves selected / fallback / selected -1 | COVERED |
| 科研无拖拽、配置扩展、旧顺序兼容 | test_hightech_construction.gd; test_hightech_slots.gd | no drag / 12 projects / compact legacy holes / retained nodes | COVERED |
| 换舰草稿 | test_ship_tab.gd | selection no immediate switch / draft rebuild保持 / profile深比较不提交不退款 | COVERED |
| 卸下确认弹窗 | test_unequip.gd | dialog / cancel / confirmed empty | COVERED |
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
| 历史10关/20级/解锁即安装/旧loop假设 | test_game.gd | 非当前规则基线；U-017 | OBSOLETE |
| 旧autoGenRes固定字符串快照 | test_auto_gen_resources.gd | 已删除旧10,2,10,40数值快照；6条现行语义断言保留 | OBSOLETE |
| 玩家炮口恒为x+70 | test_enemy_weapon_positions.gd | 已删除；现行槽位炮口规则由test_ship_visuals独立保护 | OBSOLETE |

## 本轮变化与边界

初始地图存于 `work/refactor-phase10/TEST_MAP_BEFORE.md`。状态先按静态断言映射，再以实际运行修正；不按覆盖率计分。
驻守专项原夹具只设置config.movement，实际舰船速度另有权威字段；仅修正内存夹具位置，原28条规则断言不改。
历史综合测试迁出的伤害/取整/弹体/插值/敌武器回退已在专项通过后删除原段。其余历史职责未完全确认，保留U-017，不声称整个文件已修复。
存档重复收益测试把新经过的充能时间与重复结算分开；现有offline专项继续保护非零离线上限下的重复收益。

## 未决问题入口

U-017/U-018/U-019/U-020/U-021及其他有效未决项统一查[STATUS](../space-battleship/docs/STATUS.md)。本表只维护规则→断言映射；故障观察不等于安全保证，不另保存问题调查历史。
