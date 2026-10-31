# 配置来源快照：config.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### config.xlsx


**config**：38条。字段按原列顺序：

`name`, `des`, `para_1`。


### config 数值


**config**

| name | des | para_1 |
|---|---|---|
| startEquip | 飞船初始具有的装备，格式为name,name，equipment表的名字。默认为1级。 | armour,laser |
| dmgReduce | 护甲类型对应时，减少的伤害 | 0.5 |
| movement | 飞船的移动速度，单位是秒 | 50 |
| autoCollectReduce | 自动拾取时的损耗 | 0.5 |
| backRange | 死亡时后退距离 | 200 |
| offlineMax | 离线时长(h） | 12 |
| autoGenRes | 画面上自动生成的资源,格式为生成间隔秒,种类,数量,移动速度. | 30,2,5,40 |
| scientistCost | 格式资源倍率,资源种类1\|资源消耗1,资源种类2\|资源消耗2....支持资源种类无限扩展 | 1.2,1\|100,2\|5 |
| hightechLimit | 高科技投入AI的科研点数衰减 | 1 |
| techPointGet | 高科技点数获取 | 1 |
| hightechCostGrowthLevel | 高科技耗时指数增长阈值，当前等级超过此值后生效 | 50 |
| jewelDrop | 宝石碎片掉率 | 0.2 |
| chronoParticlesPerSecond | 每离线秒获得的超时空微粒 | 1 |
| chronoDefaultSpeed | 进入游戏及微粒不足时恢复的倍率 | 1 |
| chronoSpeeds | 倍率\|每现实秒微粒消耗，逗号分隔 | 1\|0,2\|1,3\|2,4\|3,5\|4,6\|5,7\|6,8\|7,9\|8,10\|9 |
| reactorEnergyBase | 反应炉1级总能源 | 100 |
| reactorEnergyGrowth | 反应炉每级总能源倍率 | 1.5 |
| reactorUpgradeBase | 反应炉1级升级铀消耗 | 10 |
| reactorUpgradeGrowth | 反应炉每级升级费用倍率 | 1.35 |
| reactorBoostExponent | 模块能源提升指数；提升百分比为分配能源的该次幂 | 0.8 |
| reactorUraniumId | 反应炉升级消耗的资源ID | 2 |
| reactorModules | 反应炉可分配模块ID，逗号分隔 | weapons,defence,smelting,condensation |
| reactorInitialLevel | 新存档反应炉初始等级 | 1 |
| reactorPercentScale | 提升百分比换算分母 | 100 |
| reactorAllocationStep | 能源滑杆最小步长 | 1 |
| playerVisualScaleFrigate | 我方护卫舰显示倍率，仅影响舰体贴图 | 1.3 |
| playerVisualScaleDestroyer | 我方驱逐舰显示倍率，仅影响舰体贴图 | 1.1 |
| playerVisualScaleCruiser | 我方巡洋舰显示倍率，仅影响舰体贴图 | 1.2 |
| playerVisualScaleBattleship | 我方战列舰显示倍率，仅影响舰体贴图 | 1.3 |
| playerVisualScaleHeavy_Battleship | 我方重型战列舰显示倍率，仅影响舰体贴图 | 1.4 |
| enemyVisualScaleSize1 | 敌方 size 1 显示倍率，仅影响舰体贴图 | 1.2 |
| enemyVisualScaleSize2 | 敌方 size 2 显示倍率，仅影响舰体贴图 | 1.2 |
| enemyVisualScaleSize3 | 敌方 size 3 显示倍率，仅影响舰体贴图 | 1.4 |
| enemyVisualScaleSize4 | 敌方 size 4 显示倍率，仅影响舰体贴图 | 1.5 |
| enemyVisualScaleSize5 | 敌方 size 5 显示倍率，仅影响舰体贴图 | 1.5 |
| enemyVisualScaleSize6 | 敌方 size 6 显示倍率，仅影响舰体贴图 | 1.7 |
| explicitEnemyPlayerMinGap | 显式超空间阵型与玩家舰体包络的最小发射空白，按战场高度比例；不改变普通阵型、船体尺寸或战斗数值。 | 0.12 |
| equipmentSwitchCooldownSeconds | 同一武器或防御槽位换装后再次换装的游戏秒数 | 10 |
