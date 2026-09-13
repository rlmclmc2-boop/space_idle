# 舰船与防御属性

## CONFIRMED · 原表

- 玩家以 armour 的 para1 作为生命，耗尽爆炸并后退：equipment!B4、L4:L23。护盾先于装甲扣除，可在持续未受击后恢复：B24、L24:N43。伤害及溢出算法只见 [combat](combat.md)。
- 敌机：mon!A4:H9 的激光/火炮常规舰、对应弱舰、抵抗物理/能量的 BOSS；数值保留 `data/game_data.json.enemies` 并按 [DATA](../DATA.md) 回溯，不另做 Markdown 数值表。
- 敌机字段：equipment=装备引用，dmgMultiple=武器伤害乘数，health=基础生命，armourType=抗性类型，res=掉落描述，size=占格数。十格编队解释见 [map](map.md)。

## CONFIRMED · 当前代码

`BattleGame.player` 为 `{x,y,armour,shield}`；装备等级/解锁在 profile，非玩家对象。`stat()` 按装备等级查行；`max_shield()` 在未解锁时为零；`reset_player()` 回满现有最大生命/已解锁护盾。
敌人实例复制 enemies 数据行，附加 uid、slot、x/y、hp/max_hp、res_ratio、boss、cooldowns。`spawn_group()` 按 size>1 标为 BOSS；生命按关内倍率向上取整。没有单独舰船 class、品质或舰船等级系统；范围见 U-009。

接口/验证：`scripts/game.gd` 的 stat/max_shield/reset_player/spawn_group；`tests/test_game.gd` 搜索 Shield waits、Shield regenerates、Hit restarts shield delay、Shield recovery caps、Armour upgrade。恢复夹具读取当前 para2/para3，隔离敌群干扰，覆盖等待、每秒恢复、受击中断及上限。成长与即时升级行为只见 [progression](progression.md)。未覆盖边界见 TODO U-006。
