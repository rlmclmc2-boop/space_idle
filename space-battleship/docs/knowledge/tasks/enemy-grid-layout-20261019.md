# enemy-grid-layout-20261019
基准ca239dd3；普通1×1、精英2×2、BOSS3列×2行，等比填入占格区域，留血条/护盾/顶部空隙，周围避让，8种资产不重画。仅显示布局/尺寸；保留原战斗人数/关卡/数值及中心命中。
入口：scripts/enemy_fixed_layout.gd（sync,width,ensure,position），main.gd enemy_pose/enemy_hull_rect，battlefield.gd enemy_status_layout；retained_enemy_contacts.gd hull/meter。native镜像走simulation_geometry_authority.gd同FIXED_LAYOUT。只读game.gd encounter_tier/spawn_group和data/game_data.json groups的tier/count，核对多格总占用是否可容纳。验证QA普通15/精英/BOSS真实main及边界、中心、无交叠、数据不变；独立分支提交，不合main。
风险：15个逻辑单位与多格物理格存在潜在超载；先检查实配并给非重叠显示退路，禁止删敌或改表。

扩读/改动：simulation_geometry_authority.display_frame及simulation_geometry_view.apply发布只读占格计划，防止原生拥有战斗时显示仍读Main旧计划；battle_slice.close转移计划以保留死亡空位。实际第五档满武器含护盾包络前缘605.436，旧499.2空隙106.236，按原配置192交战空隙目标收敌区下界至400（400/3单格高），极限±85°炮台同测。
