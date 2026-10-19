# enemy-base-eight-20261019
基准main 5b3eb6b6。导入父提供f9af8473透明底八种基础敌舰，四列两行；仅替换texture，geometry_texture/中心判定/数值/精英BOSS不改。
范围：源图、data/ship_weapon_visuals.json八行、敌舰贴图consumer定位和既有战场截图夹具。必要扩读：scripts/enemy_visual_identity.gd、battlefield.gd/main.gd贴图和截图入口；test下匹配enemy/opening/art既有夹具。技能目录仅token-opt/doc-compact/ctx-compress，无美术专属技能，遵循ART_GUIDELINES。

完成：按先看源图后裁切导入；anchor越四等分边界，采用实际透明间隙分区；alpha连通体保留全部11实体（swarm4），清除离散近透明残留并留软边。8张887×1774透明PNG、720px内容宽度，保持源图比例；数据只改8条texture，geometry_texture/其它配置及文件与5b3eb6b逐字节/深比较一致。
验证：check_enemy_base_eight_assets.py通过；真实main场景QA编队两行8舰，身份无fallback，双方发射并62次伤害结算；显示alpha中心最大误差0.000001907。原始全窗口PNG1372×883与1952×1256，未裁切/缩放/拼贴；见evidence/enemy-base-eight-20261019。Godot4.6.3 Linux llvmpipe/GDS nativefalse，仅资产验证不作原生性能结论。
交付独立art/enemy-base-eight-static分支；源图/可复现裁切脚本/manifest/归属README/两张实际图与最小检查均纳入。无游戏脚本、数值、精英/BOSS挂件修改，不合main。无剩余阻塞，父审效果后处理合并。
