# 舰船与防御属性

## CONFIRMED · 原表

- 玩家以 armour 的 para1 作为生命，耗尽爆炸并后退：equipment!B4、L4:L23。护盾先于装甲扣除，可在持续未受击后恢复：B24、L24:N43。伤害及溢出算法只见 [combat](combat.md)。
- 敌机：mon!A4:H9 的激光/火炮常规舰、对应弱舰、抵抗物理/能量的 BOSS；数值保留 `data/game_data.json.enemies` 并按 [DATA](../DATA.md) 回溯，不另做 Markdown 数值表。
- 敌机字段：equipment=装备引用，dmgMultiple=武器伤害乘数，health=基础生命，armourType=抗性类型，res=掉落描述。原size占格口径已由2026-09-15用户要求替代为外观等级；十格编队解释见 [map](map.md)。

## CONFIRMED · 当前代码

- **2026-09-15 用户要求**：敌舰无论size多大均只占1格，size仅选择敌方PNG及决定大致显示大小。DERIVED 映射：size 1～6依次为 scout-1slot、medium-1slot、medium-2slot、large-4slot、large-6slot、super-8slot；超过6沿用最大外观。画布高度32～44像素随等级递增，水平镜像朝左而不倒置；血条、编号及发射展开适配舰体，弹体从左侧舰缘发出。

- **CONFIRMED · 2026-09-15 用户指令 / ship!H1:H8**：para_6 → `sameEquipmentLimit`，为当前舰船每种同名装备的数量上限，武器与防御均适用；须为正整数。安装校验与选择器共用equipment_count/equipment_limit，卸下后释放名额。兼容策略：旧档已超限实例暂保留，不自动卸下退款（卸下仍需确认），但禁止继续增加该种装备。

- 2026-09-15 用户要求舰船大小按 ship.para_5：投影为 `size`，来源 `config_excel/ship.xlsx` ship!G1:G8。DERIVED：复用战场每格44逻辑像素，将素材完整画布高度设为 `size×44`，保留宽高比和透明边距；不是伤害/碰撞规则变更。
- `scripts/ship_visuals.gd` 集中维护各舰素材真实槽位中心与内径。武器透明边距在绘制时裁去，可见宽度为槽内径78%并再乘独立 `MODULE_VISUAL_SCALE`，避免舰体按占地缩放后炮台不可辨；炮口位于放大模块右侧中心。导弹齐射错位限制在舱口内，发射粒子使用实际弹体起点并跟随战场震屏。

`ship` 分表提供 5 艘我方舰船的 `weaponSlots`、`defenseSlots`、`movement`、`unlock`。`profile.selectedShip` 保存当前舰船，`profile.loadout.weapons/defence` 按槽位保存 `{key,level}`；空槽不参与战斗，重复装备各自计算属性、冷却和升级。换舰页签仅列出已解锁战舰，目标舰装备由用户在确认前配置；换舰退还当前槽位的升级投入，目标槽位回到 Lv.1，并调用 `start(1,false)`；`cleared`、高科技、科学家和其他进度保留。
Phase 5状态边界：装备等级唯一所有者是`profile.loadout[category][index].level`；旧`levels`只在version 1加载时覆盖首个同名槽位，缺失/非法值沿用1级优先，其他重复槽位保留各自等级。保存临时字典从首槽派生`levels`（未安装为1），不写回运行profile。空槽不因旧等级重装。`ensure_loadout`仅在加载/重建解锁时归一化，安装/卸下/换舰直接构造合法槽位；普通槽位/属性查询不归一化、不替换数组。直接修改测试档案后需要显式维护这些约束。

`BattleGame.player` 为 `{x,y,armour,shield}`；`stat()` 汇总当前已装同类装备，`max_shield()` 在未安装护盾时为零；`reset_player()` 回满现有最大生命/护盾。
敌人实例复制 enemies 数据行，附加 uid、slot、x/y、hp/max_hp、res_ratio、boss、cooldowns。兼容字段 enemy.boss 仍按 size>1 标记大型舰外观及武器偏移，已不决定是否BOSS战、通关或清弹；战斗身份归 [map](map.md) 的最后一场规则。生命按关内倍率向上取整。没有单独舰船 class、品质或舰船等级系统；范围见 U-009。

接口/验证：`scripts/game.gd` 的 stat/max_shield/reset_player/spawn_group；`../test/test_game.gd` 搜索 Shield waits、Shield regenerates、Hit restarts shield delay、Shield recovery caps、Armour upgrade。恢复夹具读取当前 para2/para3，隔离敌群干扰，覆盖等待、每秒恢复、受击中断及上限。成长与即时升级行为只见 [progression](progression.md)。未覆盖边界见 TODO U-006。
