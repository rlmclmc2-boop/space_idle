# 四舰精英/BOSS候选与1/2/4只读接口

基准main108080a7。按父交接3887ead570b7c1a58aed84a5dd15669fc6d03195确认图，imagegen制作四舰各精英/BOSS透明静态图。只做原主体加挂件；普通8PNG逐字节未变。静态素材不烘焙炮台，现有生产武器仍独立绘制。原图/完整请求/生成器见art_sources/enemy-fleet-20261019/elite-boss-*及prepare_ranked_assets.py；运行资产与manifest位于assets/ships/enemy/elite_boss_20261020/。

| 舰体 | 精英2×2 / 隔离2炮台 | BOSS3×2 / 隔离4炮台 |
|---|---|---|
| 锚定 | [anchor-elite.png](anchor-elite.png) | [anchor-boss.png](anchor-boss.png) |
| 反应 | [reactive-elite.png](reactive-elite.png) | [reactive-boss.png](reactive-boss.png) |
| 护盾 | [shielded-elite.png](shielded-elite.png) | [shielded-boss.png](shielded-boss.png) |
| 指挥 | [command-elite.png](command-elite.png) | [command-boss.png](command-boss.png) |

全部1372×883原始主场景窗口；未裁剪、缩放或拼图。中央升级舰+两艘普通护航；QA保存关闭/保持血量，实际交火后暂停清理瞬时弹道/浮字，蓝框和英文规格标签仅QA辅助。BOSS中文标题取隔离内存中的对应舰名，未更改生产文案/敌舰表。2×2框228.8×266.667，舰体204.8×212.667，顶部42留血盾；3×2框343.2×266.667，舰体319.2×194.667，顶部60留名称+血盾。按真实旋转AABB等比fit，不横向拉伸，也不为外圈缩船。

身份只用已发布combat_tier：elite选精英图；boss/ultimate且encounter_leader才选BOSS图，护航不提升。无size>=4推断；任意size1..6身份测试覆盖。缺少升级图退回原普通图，原armour不匹配回退保留。display_span仅表示展示规格，未引入网格打包、占位分配、重排、容量限制或overflow规则；生产enemy_formation/fixed_layout/native runtime等逐字节未变。自然编队密度不在本轮隔离资产展示验收中，编队重设计继续暂停。

## 用户最新收窄：武器数只提供接口

生产10461敌舰记录：10453条单武器，2/4/6/8武器各2条；四舰27条记录全单武器。GDS实际循环按equipment逐条冷却，非longLaser调用原db.enemy_attack_damage后fire，longLaser保留原锁定路径。审计见weapon-interface-audit.json。game_data.json、全部Excel、game.gd和数据库/数值实现均未变；不重写装备数量、不开启倍率、不倍增总伤害。

新增只读配置ship_weapon_visuals.json.enemy_weapon_interface和scripts/enemy_weapon_interface.gd:describe：normal1/elite2/BOSS4、独立slot_map、可旋转main炮台挂点，坐标为alpha居中的显示canvas归一化坐标。返回深拷贝，不写enemy、装备、冷却或伤害。生产没有调用该接口的消费者；原有生效hardpoints和slot_map保持逐字段相同。明确启用的后续消费方需将接口坐标适配到显示/模型基准并另行处理配装与伤害预算，接口不替其决定预算。

本组图通过test_enemy_ranked_art.gd显式QA adapter把挂点适配到显示舰体，并仅在内存为精英安装2、BOSS安装4个独立旋转cannon组件；护航仍1个现有武器。616检查覆盖实际组件数量、独立owner/muzzle、旋转挂点、原生产单武器几何保持、框内血盾/名称、alpha中心、native authority选图和view尺寸等；438身份/接口检查已包含在616内。静态alpha还核对每个预留挂点位于不透明装甲上。中心最大误差0.000031逻辑单位，原geometry_texture/生产武器硬点及全部普通视觉行保持。

验证：新8图alpha/比例/组件/核心/挂点/配置与冻结文件检查通过；普通8图资产检查通过；升级场景616检查0失败，普通8舰显示及血盾回归96检查0失败（base-regression.png/json、base.log）。负向armour mismatch的warning是预期；没有SCRIPT ERROR/FAIL。Linux Godot4.6.3 llvmpipe/GDS，native view为函数级桥接验证，不声称native整场/性能验收。只改展示和只读接口，不扩展攻击/共享效果测试。

复现：python test/check_enemy_ranked_assets.py、python test/check_enemy_base_eight_assets.py；隔离工程复制test/test_enemy_ranked_art.gd到res://，RANKED_UNIT=1可headless；图形运行RANKED_OUTPUT指定test/work本次目录。普通回归复用test_enemy_base_eight_battle.gd与ENEMY_BASE_OUTPUT。父审后再处理合并，本轮不合main。无执行阻塞。
